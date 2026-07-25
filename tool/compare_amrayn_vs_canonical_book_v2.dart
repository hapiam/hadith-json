import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable.
///
/// Replaces `compare_amrayn_vs_canonical_book.dart`'s citation-STRING-based
/// comparison (which only worked for the un-lettered majority of a book,
/// leaving Muslim at 1.4% coverage since 67% of its citations are lettered,
/// and never covered Tirmidhi/Ibn Majah at all) with a CONTENT-based one
/// that works uniformly across every book, lettered citations included.
///
/// Join chain, each step independently verified this session:
/// amrayn citation --[content-match, arabic_match.dart]--> fawaz row
///   --[fawaz's own hadithnumber field]--> canonical idInBook (same value,
///   verified: canonical's idInBook matches its own reference.text's
///   trailing citation number, not raw array position)
///   --> canonical chapterId (the book/chapter assignment already shipped
///   in db/unified/catalog.json's bookChapters, used by the app).
///
/// Malik is excluded: its canonical chapterId is NOT derived from fawaz's
/// numbering the way the other 6 rebuilt books are (see
/// `tool/investigate_malik_book_join.dart` / `MALIK_BOOK_JOIN.md` for its
/// own, separately-verified join key and findings).
///
/// OUTPUT: BOOK_CHAPTER_CROSSCHECK_V2.md at the repo root.
void main() {
  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah'];
  final buf = StringBuffer();
  buf.writeln('# amrayn vs. canonical book/chapter assignment -- content-matched, v2\n');
  buf.writeln(
    'Supersedes `BOOK_CHAPTER_CROSSCHECK.md`\'s citation-string method '
    '(only covered the un-lettered majority of each book, and never '
    'included Tirmidhi/Ibn Majah at all). This version matches by Arabic '
    'text content (`arabic_match.dart`), so it covers every amrayn '
    'citation regardless of lettering, uniformly across all 6 fawaz-'
    'rebuilt books. Malik excluded -- see `MALIK_BOOK_JOIN.md` for its own '
    'separately-verified relationship.\n',
  );
  buf.writeln('| Book | Compared | Matched (same book) | Mismatched | Amrayn citations with no fawaz match | Fawaz rows with no canonical idInBook |');
  buf.writeln('|---|---:|---:|---:|---:|---:|');

  final bookDetails = <String, StringBuffer>{};

  for (final book in books) {
    final fawazData = jsonDecode(File('db/editions/files/ara-$book.min.json').readAsStringSync()) as Map<String, dynamic>;
    final fawazHadiths = (fawazData['hadiths'] as List).cast<Map<String, dynamic>>();
    final fawazArabic = fawazHadiths.map((h) => (h['text'] as String?) ?? '').toList();
    final fawazNumbers = fawazHadiths.map((h) => (h['hadithnumber'] as num).toInt()).toList();

    final canonicalData = jsonDecode(File('db/unified/by_book/$book.json').readAsStringSync()) as Map<String, dynamic>;
    final canonicalHadiths = (canonicalData['hadiths'] as List).cast<Map<String, dynamic>>();
    final chapterIdByIdInBook = <int, int>{
      for (final h in canonicalHadiths)
        if (h['chapterId'] != null) (h['idInBook'] as num).toInt(): (h['chapterId'] as num).toInt(),
    };

    final catalog = jsonDecode(File('db/unified/catalog.json').readAsStringSync()) as Map<String, dynamic>;
    final bookChapters = catalog['bookChapters'] as Map<String, dynamic>;
    final names = <int, String>{
      for (final c in (bookChapters[book] as List).cast<Map<String, dynamic>>())
        (c['id'] as num).toInt(): ((c['names'] as Map)['en'] as String? ?? '?'),
    };

    final amraynData = jsonDecode(File('sources/amrayn.com/${book}_book_lookup.json').readAsStringSync()) as Map<String, dynamic>;
    final amraynArabicData = jsonDecode(File('sources/amrayn.com/processed/$book.json').readAsStringSync()) as Map<String, dynamic>;
    final amraynHadiths = (amraynArabicData['hadiths'] as List).cast<Map<String, dynamic>>();
    final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final amraynKeys = amraynHadiths.map((h) => (h['citation'] as String?) ?? '${h['idInBook']}').toList();

    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: fawazArabic,
      oldLabels: amraynKeys,
    );

    var compared = 0, matched = 0, mismatched = 0, noFawazMatch = 0, noCanonicalIdInBook = 0;
    final mismatchSamples = <String>[];

    for (var i = 0; i < amraynHadiths.length; i++) {
      final citation = amraynKeys[i];
      final entry = amraynData[citation] as Map<String, dynamic>?;
      final amraynBook = entry?['book'] as int?;
      if (amraynBook == null) continue;

      final fawazIdx = result[i];
      if (fawazIdx == null) {
        noFawazMatch++;
        continue;
      }
      final fawazNumber = fawazNumbers[fawazIdx];
      final canonicalChapterId = chapterIdByIdInBook[fawazNumber];
      if (canonicalChapterId == null) {
        noCanonicalIdInBook++;
        continue;
      }

      compared++;
      if (canonicalChapterId == amraynBook) {
        matched++;
      } else {
        mismatched++;
        if (mismatchSamples.length < 15) {
          mismatchSamples.add(
            'citation=$citation: amrayn book=$amraynBook (${names[amraynBook]}), '
            'canonical chapterId=$canonicalChapterId (${names[canonicalChapterId]})',
          );
        }
      }
    }

    buf.writeln('| $book | $compared | $matched | $mismatched | $noFawazMatch | $noCanonicalIdInBook |');

    final detail = StringBuffer();
    detail.writeln('## $book\n');
    detail.writeln('- compared: $compared, matched: $matched, mismatched: $mismatched '
        '(${compared == 0 ? 0 : (100 * mismatched / compared).toStringAsFixed(1)}%)');
    if (mismatchSamples.isNotEmpty) {
      detail.writeln('\n### Mismatch samples\n');
      for (final s in mismatchSamples) {
        detail.writeln('- $s');
      }
    }
    bookDetails[book] = detail;
    stdout.writeln('$book: compared=$compared matched=$matched mismatched=$mismatched '
        'noFawazMatch=$noFawazMatch noCanonicalIdInBook=$noCanonicalIdInBook');
  }

  buf.writeln();
  for (final book in books) {
    buf.writeln(bookDetails[book].toString());
  }

  File('BOOK_CHAPTER_CROSSCHECK_V2.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote BOOK_CHAPTER_CROSSCHECK_V2.md');
}
