import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, idempotent (a re-run with no remaining
/// duplicates is a silent no-op).
///
/// See DUPLICATE_HADITH_INVESTIGATION.md, Category 3, for the full
/// investigation. Summary: al-Lulu wal-Marjan (`db/by_book/hadithunlocked/
/// lulu-marjan.json`) has 69 rows (59 groups) that are exact-duplicate
/// content of another row in the same book -- confirmed by diacritic-
/// normalized Arabic-text matching AND, for the first group, by fetching
/// hadithunlocked.com's own live page directly: the duplicate is genuinely
/// present on the source's own rendered page (two different item numbers
/// for the same citation), not something introduced by our scrape or
/// import step. Unlike the fawaz-internal-duplicate case (Bukhari/Muslim),
/// there is no "placeholder vs resolved" side to distinguish -- both
/// copies of a pair are equally well-formed and identical, so which one
/// survives doesn't matter content-wise; this keeps the first (lowest
/// idInBook) occurrence and drops the rest.
///
/// `reference` (text + url) on hadithunlocked-sourced books is derived
/// from the RAW item's own `ref`/`number` field at import time, not from
/// `idInBook` -- see `import_hadithunlocked.dart`'s `refNumber` derivation
/// -- so it is left completely untouched here. Only `idInBook` (renumbered
/// sequentially to close the gaps left by removed rows) and `id`
/// (`bookId * 1000000 + idInBook`, matching the existing convention) are
/// rewritten.
///
/// Usage: dart run tool/fix_lulu_marjan_duplicates.dart
void main() {
  const path = 'db/by_book/hadithunlocked/lulu-marjan.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  String norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final seen = <String>{};
  final kept = <Map<String, dynamic>>[];
  var dropped = 0;
  for (final h in hadiths) {
    final key = norm(h['arabic'] as String);
    if (seen.contains(key)) {
      dropped++;
      continue;
    }
    seen.add(key);
    kept.add(h);
  }

  final bookId = kept.first['bookId'] as int;
  for (var i = 0; i < kept.length; i++) {
    final idInBook = i + 1;
    kept[i]['idInBook'] = idInBook;
    kept[i]['id'] = bookId * 1000000 + idInBook;
  }

  data['hadiths'] = kept;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$path: ${hadiths.length} -> ${kept.length} rows ($dropped exact duplicates dropped)',
  );
}
