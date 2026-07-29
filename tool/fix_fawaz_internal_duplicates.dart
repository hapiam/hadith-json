import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, run AFTER `rebuild_from_fawaz.dart`,
/// idempotent (a re-run against an already-cleaned file finds no more
/// matching groups).
///
/// See DUPLICATE_HADITH_INVESTIGATION.md, Category 1, for the full
/// investigation, and `sources/amrayn.com/FAWAZ_INTERNAL_DUPLICATION.md`
/// for the earlier (2026-07-24) discovery of the same underlying pattern
/// via a different method (amrayn cross-matching) that was never converted
/// into a fix at the time.
///
/// Root cause: fawaz's own raw per-language editions
/// (`db/editions/files/ara-{book}.min.json`) contain internal duplicate
/// rows -- two different `hadithnumber`s carrying identical Arabic text.
/// In the large majority of cases one side has fawaz's own "couldn't
/// determine chapter/position" placeholder marker
/// (`reference: {book: 0, hadith: 0}`) while the other has a real,
/// resolved `reference`; `rebuild_from_fawaz.dart`'s neighbor-inference
/// pass already assigns the placeholder side a sensible `chapterId` (so it
/// doesn't look broken), but never recognized it as *the same hadith* as
/// its resolved twin -- both survive as separate spine rows. Confirmed
/// directly against fawaz's raw file (not the spine, which doesn't
/// preserve fawaz's original per-row reference.book/hadith once
/// `rebuild_from_fawaz.dart` regenerates its own idInBook-derived
/// `reference.text`/`url`).
///
/// This script re-reads fawaz's raw file purely to recover that
/// placeholder signal, groups the already-built spine's rows by
/// diacritic-normalized Arabic text, and for each group:
///   - exactly one placeholder + rest resolved -> drop the placeholder
///     row(s), keep the resolved one.
///   - every member resolved, all sharing the same real
///     reference.book/hadith -> keep the lowest hadithnumber, drop the
///     rest (a genuine fawaz double-count of one citation, not a
///     placeholder situation -- confirmed to exist for Bukhari
///     hadithnumber 272/273, both citing sunnah.com Book 5 Hadith 25).
///   - anything else (e.g. every member is a placeholder, or resolved
///     members disagree on their real reference) -> left untouched and
///     printed for manual review, same "human glance" policy this repo
///     already uses for fuzzy matches elsewhere (see README.md's
///     `arabic_match.dart` section).
///
/// Deliberately does NOT renumber `idInBook`/`id`/`reference` on
/// surviving rows -- `reference.text` embeds the exact idInBook number
/// ("Sahih al-Bukhari 272"), so renumbering later rows to close a gap
/// would require regenerating every subsequent citation string too; left
/// as a gap instead, same choice made in `fix_malik_duplicates.dart`.
///
/// Usage: dart run tool/fix_fawaz_internal_duplicates.dart
void main() {
  const books = ['bukhari', 'muslim'];

  String norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  for (final book in books) {
    final rawFile = File('db/editions/files/ara-$book.min.json');
    final rawData = jsonDecode(rawFile.readAsStringSync());
    final rawHadiths = (rawData is Map ? rawData['hadiths'] : rawData) as List;

    // hadithnumber -> {book, hadith} from fawaz's own reference field.
    final rawRef = <int, (int, int)>{};
    for (final h in rawHadiths) {
      final map = h as Map;
      final hadithNum = (map['hadithnumber'] as num).toInt();
      final ref = map['reference'] as Map;
      rawRef[hadithNum] = ((ref['book'] as num).toInt(), (ref['hadith'] as num).toInt());
    }

    final spinePath = 'db/by_book/the_9_books/$book.json';
    final spineFile = File(spinePath);
    final data = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = (data['hadiths'] as List)
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();

    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final h in hadiths) {
      final key = norm(h['arabic'] as String);
      // Empty/near-empty Arabic (e.g. Muslim's Introduction section,
      // chapterId 0, genuinely content-less noSourceContent rows) collapses
      // many unrelated entries onto the same key -- never treat these as
      // real content duplicates, no matter what their reference looks
      // like.
      if (key.length < 15) continue;
      byKey.putIfAbsent(key, () => []).add(h);
    }
    final groups = byKey.values.where((g) => g.length > 1).toList();

    final toDrop = <int>{}; // idInBook values to remove
    var placeholderDrops = 0;
    var sameRefDrops = 0;
    var allPlaceholderDrops = 0;
    var skipped = 0;
    for (final group in groups) {
      final withRef = group
          .map((h) => (h, rawRef[h['idInBook'] as int]))
          .toList();
      final placeholders = withRef.where((e) => e.$2 == (0, 0)).toList();
      final resolved = withRef.where((e) => e.$2 != (0, 0)).toList();

      if (placeholders.isNotEmpty && resolved.isNotEmpty) {
        for (final e in placeholders) {
          toDrop.add(e.$1['idInBook'] as int);
          placeholderDrops++;
        }
        continue;
      }

      if (resolved.length == group.length) {
        final refs = resolved.map((e) => e.$2!).toSet();
        if (refs.length == 1) {
          final sorted = resolved.toList()
            ..sort((a, b) => (a.$1['idInBook'] as int).compareTo(b.$1['idInBook'] as int));
          for (final e in sorted.skip(1)) {
            toDrop.add(e.$1['idInBook'] as int);
            sameRefDrops++;
          }
          continue;
        }
      }

      if (resolved.isEmpty) {
        // Every member is a chapterUnknown placeholder in fawaz's own raw
        // data -- content-identical (guaranteed by the grouping) and none
        // of them carries any real citation to prefer, so which one
        // survives is arbitrary; keep the lowest idInBook.
        final sorted = group.toList()
          ..sort((a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int));
        for (final h in sorted.skip(1)) {
          toDrop.add(h['idInBook'] as int);
          allPlaceholderDrops++;
        }
        continue;
      }

      skipped++;
      stdout.writeln(
        '  SKIPPED (manual review) $book idInBook ${group.map((h) => h['idInBook']).join(',')}: '
        'refs ${withRef.map((e) => e.$2).join(' / ')}',
      );
    }

    final kept = hadiths.where((h) => !toDrop.contains(h['idInBook'] as int)).toList();
    data['hadiths'] = kept;
    spineFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln(
      '$spinePath: ${hadiths.length} -> ${kept.length} rows '
      '(${toDrop.length} dropped: $placeholderDrops placeholder-side, $sameRefDrops same-reference dupes, '
      '$allPlaceholderDrops both-sides-placeholder dupes; $skipped groups left for manual review)',
    );
  }
}
