import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, idempotent (a re-run against an already-
/// cleaned file finds nothing beyond `fawazMax` to check, since the tail
/// shrinks each run -- but is a no-op once no more matches exist).
///
/// See DUPLICATE_HADITH_INVESTIGATION.md, Category 2, for the full
/// investigation. Summary: `db/by_book/the_9_books/malik.json` appends 140
/// rows past fawaz's own maximum (`fawazMax = 1858`, fawaz's own hard
/// content ceiling across all 6 translated languages -- see README.md's
/// "Muwatta Malik: 1,858, not 1,942") as supposedly-new Arabic-only
/// content. Diacritic-normalized comparison against the existing 1..1858
/// range found 125 of those 140 rows (89%) are duplicates of content
/// fawaz already covers -- appended under a fresh `idInBook` because the
/// merge step that built this file appended by position (anything past
/// `fawazMax`) rather than checking whether the content already existed
/// somewhere in 1..1858. Spot-verified against a false-positive risk (see
/// the investigation doc) -- confirmed genuine, not over-aggressive
/// normalization.
///
/// This script drops those confirmed-duplicate rows only. It deliberately
/// does NOT renumber `idInBook`/`id` on the surviving rows (leaving gaps
/// where duplicates were removed): unlike the hadithunlocked-sourced books
/// (see `fix_lulu_marjan_duplicates.dart`), `id` in this file is NOT a
/// clean `bookId * 1000000 + idInBook` formula throughout -- most of the
/// range is an older sequential id inherited from the original AhmedBaset
/// spine, used as `merge_muallimai_enrichments.dart`'s own join key against
/// muallimai's grade/reference data. Renumbering could silently break that
/// join if this file is ever re-merged from muallimai's source again, so
/// `id`/`idInBook` are left untouched on every surviving row -- only
/// deletion, no renumbering.
///
/// Usage: dart run tool/fix_malik_duplicates.dart
void main() {
  const path = 'db/by_book/the_9_books/malik.json';
  const fawazMax = 1858;

  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  String norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final coveredKeys = <String>{
    for (final h in hadiths)
      if ((h['idInBook'] as int) <= fawazMax) norm(h['arabic'] as String),
  };

  final kept = <Map<String, dynamic>>[];
  var dropped = 0;
  for (final h in hadiths) {
    final idInBook = h['idInBook'] as int;
    if (idInBook > fawazMax && coveredKeys.contains(norm(h['arabic'] as String))) {
      dropped++;
      continue;
    }
    kept.add(h);
  }

  data['hadiths'] = kept;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$path: ${hadiths.length} -> ${kept.length} rows ($dropped tail duplicates of the 1..$fawazMax range dropped, idInBook/id left untouched on survivors)',
  );
}
