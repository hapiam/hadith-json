import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine integrity fix, idempotent (a book with no
/// remaining duplicates is a silent no-op on re-run).
///
/// Root cause (confirmed by direct inspection of fawaz's raw source, not
/// guessed): fawaz's own tirmidhi/nasai/ibnmajah data uses FRACTIONAL
/// `hadithnumber` values (`3604`, `3604.02`, `3604.03`, ... `3604.1` — ten
/// distinct narrations under one citation) as its own version of the
/// sunnah.com a/b/c lettered-split convention. Whatever built these three
/// books' spines from fawaz truncated the fractional part when assigning
/// `idInBook`, silently colliding every variant onto the shared base
/// integer instead of giving each its own identity. Confirmed pre-existing
/// (not introduced by any of this session's own work): present in the
/// c384c49 commit, before any of tonight's amrayn-merge tooling touched
/// these files.
///
/// The existing `reference` field on every colliding row is ALREADY
/// correct — it independently derived the right lettered citation
/// (`Tirmidhi 3604`, `3604b`, `3604c`, ...) from fawaz's fractional
/// numbers, it just never got threaded back into `idInBook` itself. So
/// this fix only touches `idInBook`/`appendedOriginal`/`sortKey` and
/// leaves `reference`, `arabic`, `english`, `grade`, `chapterId`
/// completely untouched.
///
/// For each group of rows sharing one `idInBook` (always found at
/// consecutive array positions, confirmed for all 27+6+2 = 35 groups
/// across the three affected books): the FIRST row (fawaz's base integer
/// entry) keeps its `idInBook` unchanged. Every SUBSEQUENT row (fawaz's
/// `.02`/`.03`/... fractional siblings) gets reassigned a brand-new
/// `idInBook` beyond the book's current max (guaranteed never to collide
/// with a real citation number), `appendedOriginal: true` (the spine's own
/// addendum flag -- NOT `isAddendum`, see `merge_amrayn_missing_hadith.dart`'s
/// doc comment for why that distinction matters), and `sortKey` set to
/// `baseIdInBook + i/10` so it displays immediately after its base sibling
/// and before the next real citation number, matching the same
/// sortKey-positioning convention already used for every other addendum in
/// this repo.
///
/// Usage: dart run tool/fix_duplicate_idinbook.dart
void main() {
  const paths = [
    'db/by_book/the_9_books/tirmidhi.json',
    'db/by_book/the_9_books/nasai.json',
    'db/by_book/the_9_books/ibnmajah.json',
  ];

  for (final path in paths) {
    final file = File(path);
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = (data['hadiths'] as List)
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();

    // Group consecutive rows sharing the same idInBook.
    final groups = <List<int>>[]; // list of row-index groups
    var i = 0;
    while (i < hadiths.length) {
      final id = hadiths[i]['idInBook'];
      var j = i + 1;
      while (j < hadiths.length && hadiths[j]['idInBook'] == id) {
        j++;
      }
      if (j - i > 1) groups.add(List.generate(j - i, (k) => i + k));
      i = j;
    }

    var maxIdInBook = hadiths
        .map((h) => (h['idInBook'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);

    var reassigned = 0;
    for (final group in groups) {
      final baseIdInBook = (hadiths[group[0]]['idInBook'] as num).toInt();
      for (var k = 1; k < group.length; k++) {
        final row = hadiths[group[k]];
        maxIdInBook++;
        row['idInBook'] = maxIdInBook;
        row['appendedOriginal'] = true;
        row['sortKey'] = baseIdInBook + (k / 10);
        reassigned++;
      }
    }

    data['hadiths'] = hadiths;
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln('$path: ${groups.length} duplicate groups fixed, $reassigned rows reassigned to new unique idInBook');
  }
}
