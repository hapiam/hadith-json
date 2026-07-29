import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, run AFTER `rebuild_from_fawaz.dart`,
/// idempotent (a re-run against an already-fixed file finds no more
/// matching groups, since merged rows no longer duplicate any sibling's
/// Arabic text).
///
/// REPLACES the Bukhari portion of the retired `fix_fawaz_internal_
/// duplicates.dart` approach (which deleted rows outright and lost their
/// citation numbers -- see DUPLICATE_HADITH_INVESTIGATION.md's "2026-07-29
/// correction" section for the full story of how that was found wrong via
/// direct sunnah.com verification). Muslim is NOT handled by this script --
/// see the same doc section for why Muslim needs separate, deferred work
/// (fawaz's own hadithnumber field does not reliably track sunnah.com's
/// real citation numbers for Muslim, confirmed by direct content
/// mismatches; that problem is bigger than and orthogonal to the
/// duplicate-row question this script solves for Bukhari).
///
/// Root cause (now correctly understood): fawaz's raw Arabic edition
/// contains internal duplicate rows -- two or more different
/// `hadithnumber`s carrying byte-identical Arabic text. Verified directly
/// against sunnah.com (11/11 sampled groups, spread across the whole book,
/// group sizes 2 and 3, both the "one placeholder + one resolved" and
/// "all resolved, same reference" sub-patterns): every single one is a
/// genuine sunnah.com COMPOUND CITATION -- one real page, one hadith text,
/// cited under multiple consecutive numbers (e.g. "Sahih al-Bukhari 272,
/// 273" or "299, 300, 301", visible directly in sunnah.com's own page
/// title and "Reference:" field). fawaz's own `reference: {book:0,
/// hadith:0}` marker on one member of a group does NOT mean that row is
/// scraper garbage to discard -- it means fawaz's parser only recovered
/// ONE of the citation's multiple legitimate numbers.
///
/// Fix: merge each such group into ONE row (the lowest idInBook --
/// sunnah.com always lists the lowest number first in its own compound
/// reference, and any number in the group resolves to the same page), with
/// `reference.text`/`url` rewritten to the TRUE compound form matching
/// sunnah.com exactly, e.g. `"Sahih al-Bukhari 272, 273"` /
/// `"https://sunnah.com/bukhari:272"`. The dropped rows' citation numbers
/// are NOT lost -- they live on in the surviving row's `reference.text`.
///
/// `idInBook`/`id` are deliberately LEFT AS-IS on every surviving row --
/// NOT renumbered/compacted. An earlier version of this script renumbered
/// sequentially to close the resulting gaps, which fixed one UX problem
/// (a confusing jump in the reader, red-flagged "gaps" in the chapter table
/// of contents) but created a worse one, caught by the user: every
/// subsequent citation number would silently drift away from sunnah.com's
/// real numbering by one for every merge before it, compounding across the
/// book, so the very last hadith would no longer read "7563" -- the number
/// this book is actually known by -- but something hundreds lower. 273 is
/// a REAL number in sunnah.com's own continuous 1..7563 sequence (confirmed
/// directly: bukhari:298, 299/300/301 compound, 302 -- consecutive, nothing
/// skipped in the true numbering); it just doesn't get its own ROW anymore
/// since 272's row already carries its content. Keeping `idInBook` frozen
/// at its true original value is what keeps the book's numbering anchored
/// to 7563 at the end, at the cost of `idInBook` no longer being perfectly
/// gapless -- the reader UI needs to treat that gap as expected (see the
/// compound-citation label already available in `reference.text`), not
/// re-render it as an error, which is a UI fix, not a numbering one.
///
/// Usage: dart run tool/fix_bukhari_compound_citations.dart
void main() {
  const path = 'db/by_book/the_9_books/bukhari.json';
  const rawPath = 'db/editions/files/ara-bukhari.min.json';

  final rawData = jsonDecode(File(rawPath).readAsStringSync());
  final rawHadiths = (rawData is Map ? rawData['hadiths'] : rawData) as List;
  final rawRef = <int, (int, int)>{};
  for (final h in rawHadiths) {
    final map = h as Map;
    final hadithNum = (map['hadithnumber'] as num).toInt();
    final ref = map['reference'] as Map;
    rawRef[hadithNum] = ((ref['book'] as num).toInt(), (ref['hadith'] as num).toInt());
  }

  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  String norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final byKey = <String, List<Map<String, dynamic>>>{};
  for (final h in hadiths) {
    final arabic = h['arabic'] as String? ?? '';
    if (arabic.length < 15) continue;
    byKey.putIfAbsent(norm(arabic), () => []).add(h);
  }
  final groups = byKey.values.where((g) => g.length > 1).toList();

  final toDrop = <int>{};
  final compoundLabelByIdInBook = <int, String>{};
  var merged = 0;
  var skipped = 0;
  for (final group in groups) {
    final withRef = group
        .map((h) => (h, rawRef[h['idInBook'] as int]))
        .toList();
    final placeholders = withRef.where((e) => e.$2 == (0, 0)).toList();
    final resolved = withRef.where((e) => e.$2 != (0, 0)).toList();

    final isCompoundCitation =
        (placeholders.isNotEmpty && resolved.isNotEmpty) ||
        (resolved.length == group.length &&
            resolved.map((e) => e.$2!).toSet().length == 1) ||
        (resolved.isEmpty); // both/all placeholder, identical content

    if (!isCompoundCitation) {
      skipped++;
      stdout.writeln(
        '  SKIPPED (differing real references, likely genuine repetition) '
        'idInBook ${group.map((h) => h['idInBook']).join(',')}: '
        'refs ${withRef.map((e) => e.$2).join(' / ')}',
      );
      continue;
    }

    final sorted = group.toList()
      ..sort((a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int));
    final numbers = sorted.map((h) => h['idInBook']).join(', ');
    final lowest = sorted.first;
    compoundLabelByIdInBook[lowest['idInBook'] as int] = numbers;
    for (final h in sorted.skip(1)) {
      toDrop.add(h['idInBook'] as int);
    }
    merged++;
  }

  final kept = hadiths.where((h) => !toDrop.contains(h['idInBook'] as int)).toList()
    ..sort((a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int));

  // Rewrite compound reference.text on surviving merge-target rows -- the
  // only field this script changes on a kept row. idInBook/id are left
  // exactly as they were (see this file's own top doc comment for why).
  for (final h in kept) {
    final label = compoundLabelByIdInBook[h['idInBook'] as int];
    if (label != null) {
      final ref = Map<String, dynamic>.from(h['reference'] as Map);
      ref['text'] = 'Sahih al-Bukhari $label';
      h['reference'] = ref;
    }
  }

  final maxIdInBook = kept.map((h) => h['idInBook'] as int).reduce((a, b) => a > b ? a : b);
  data['hadiths'] = kept;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$path: ${hadiths.length} -> ${kept.length} rows '
    '($merged groups merged into compound citations, ${toDrop.length} rows folded in; '
    '$skipped groups left untouched as likely genuine repetition). '
    'idInBook left as-is (not renumbered), max idInBook now $maxIdInBook.',
  );
}
