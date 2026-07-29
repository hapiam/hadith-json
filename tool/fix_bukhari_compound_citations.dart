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
/// After merging, `idInBook`/`id` are renumbered sequentially across the
/// whole book to close the gaps merging leaves behind -- unlike
/// `fix_malik_duplicates.dart`'s deliberate choice to leave gaps (that
/// book's `id` is a legacy join-key elsewhere), Bukhari's `id` is fully
/// synthetic (`globalIdOffset + hadithNum`, see `rebuild_from_fawaz.dart`)
/// with nothing depending on its specific value, and leaving gaps here
/// caused a real, confirmed UX regression: the reader's own row numbers
/// visibly "jumped" over the merged number, and the chapter table of
/// contents' gap-anomaly detector painted large stretches of the book red,
/// misreading every intentional merge as a data hole. Renumbering restores
/// a clean, gapless `idInBook` sequence while `reference.text` keeps the
/// true original number(s) permanently, regardless of what internal
/// `idInBook` a row is later renumbered to.
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

  // Rewrite compound reference.text on surviving merge-target rows BEFORE
  // renumbering, so the label reflects the TRUE original sunnah.com
  // numbers, not the post-renumbering idInBook.
  for (final h in kept) {
    final label = compoundLabelByIdInBook[h['idInBook'] as int];
    if (label != null) {
      final ref = Map<String, dynamic>.from(h['reference'] as Map);
      ref['text'] = 'Sahih al-Bukhari $label';
      h['reference'] = ref;
    }
  }

  // Renumber idInBook/id sequentially to close the gaps merging left.
  final firstOriginal = kept.first['idInBook'] as int;
  final firstOriginalId = kept.first['id'] as int;
  final globalIdOffset = firstOriginalId - firstOriginal;
  for (var i = 0; i < kept.length; i++) {
    final newIdInBook = i + 1;
    kept[i]['idInBook'] = newIdInBook;
    kept[i]['id'] = globalIdOffset + newIdInBook;
  }

  data['hadiths'] = kept;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$path: ${hadiths.length} -> ${kept.length} rows '
    '($merged groups merged into compound citations, ${toDrop.length} rows folded in; '
    '$skipped groups left untouched as likely genuine repetition). '
    'idInBook/id renumbered 1..${kept.length}.',
  );
}
