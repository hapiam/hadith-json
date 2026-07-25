import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable.
///
/// `compare_amrayn_vs_canonical_book_v2.dart` reported much higher
/// mismatch rates (6.9%-20.0%) than the old citation-string method
/// (0.2%-7.3%). Spot-checking 5 Bukhari "mismatch" samples in full found
/// several were NOT real book-boundary disagreements at all: the matcher
/// paired the amrayn citation with a completely unrelated fawaz hadith
/// (e.g. citation 222 -- a baby urinating on the Prophet's ﷺ clothes --
/// matched to fawaz #2, "how does revelation come to you", because both
/// happen to share the same isnad opening
/// "AbdAllah ibn Yusuf -> Malik -> Hisham ibn Urwah -> his father ->
/// A'isha", which is a hugely common transmission chain reused verbatim
/// across many different hadiths -- the matcher's fallback layers over-
/// trust a shared isnad prefix even when the actual matn diverges
/// completely).
///
/// This re-applies the same LCS-ratio methodology already used in
/// `investigate_fuzzy_match_quality.dart` to every "mismatched" pair from
/// the v2 comparison specifically, to separate real book-boundary
/// disagreements (high content overlap, different book assignment) from
/// matcher false-positives (low content overlap -- not the same hadith at
/// all, so the "mismatch" is meaningless).
///
/// OUTPUT: sources/amrayn.com/BOOK_MISMATCH_QUALITY.md.
void main() {
  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah'];
  final buf = StringBuffer();
  buf.writeln('# Book-mismatch pairs (v2 cross-check) re-classified by LCS ratio\n');
  buf.writeln(
    'For every amrayn/canonical book-assignment "mismatch" from '
    '`BOOK_CHAPTER_CROSSCHECK_V2.md`, computes the longest-common-substring '
    'ratio (same method as `FUZZY_MATCH_ANALYSIS.md`) between the amrayn '
    'text and the fawaz text the matcher paired it with. High ratio = same '
    'report, so the book disagreement is real. Low ratio = the matcher '
    'paired two DIFFERENT hadiths, so the "mismatch" is a matcher artifact, '
    'not a real book-boundary finding.\n',
  );

  var grandRealMismatch = 0, grandFalseMatch = 0, grandAmbiguous = 0;

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

    var realMismatch = 0, falseMatch = 0, ambiguous = 0;
    final falseMatchSamples = <String>[];

    for (var i = 0; i < amraynHadiths.length; i++) {
      final citation = amraynKeys[i];
      final entry = amraynData[citation] as Map<String, dynamic>?;
      final amraynBook = entry?['book'] as int?;
      if (amraynBook == null) continue;

      final fawazIdx = result[i];
      if (fawazIdx == null) continue;
      final fawazNumber = fawazNumbers[fawazIdx];
      final canonicalChapterId = chapterIdByIdInBook[fawazNumber];
      if (canonicalChapterId == null) continue;
      if (canonicalChapterId == amraynBook) continue; // not a mismatch at all

      String stripHon(String s) => s
          .replaceAll(
            RegExp('صلي الله عليه وسلم|رضي الله عنه(ما|ا)?|رحمه الله( تعالي)?|تعالي|عز وجل|ﷺ'),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final oldStripped = stripHon(normalizeForMatching(amraynArabic[i]));
      final newStripped = stripHon(normalizeForMatching(fawazArabic[fawazIdx]));
      final lcs = _longestCommonSubstringLength(oldStripped, newStripped);
      final shorter = oldStripped.length < newStripped.length ? oldStripped.length : newStripped.length;
      final ratio = shorter == 0 ? 0.0 : lcs / shorter;

      if (ratio >= 0.6) {
        realMismatch++;
      } else if (ratio >= 0.3) {
        ambiguous++;
      } else {
        falseMatch++;
        if (falseMatchSamples.length < 10) {
          falseMatchSamples.add(
            'citation=$citation lcsRatio=${ratio.toStringAsFixed(2)}\n'
            '  AMRAYN (book=$amraynBook): ${amraynArabic[i].length > 150 ? amraynArabic[i].substring(0, 150) : amraynArabic[i]}\n'
            '  FAWAZ #$fawazNumber (chapterId=$canonicalChapterId): ${fawazArabic[fawazIdx].length > 150 ? fawazArabic[fawazIdx].substring(0, 150) : fawazArabic[fawazIdx]}',
          );
        }
      }
    }

    grandRealMismatch += realMismatch;
    grandFalseMatch += falseMatch;
    grandAmbiguous += ambiguous;

    final total = realMismatch + falseMatch + ambiguous;
    buf.writeln('## $book');
    buf.writeln('- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): $realMismatch');
    buf.writeln('- ambiguous (0.3-0.6): $ambiguous');
    buf.writeln('- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): $falseMatch '
        '(${total == 0 ? 0 : (100 * falseMatch / total).toStringAsFixed(1)}% of this book\'s reported mismatches)');
    if (falseMatchSamples.isNotEmpty) {
      buf.writeln('\n### False-match samples ($book)\n');
      for (final s in falseMatchSamples) {
        buf.writeln('$s\n');
      }
    }
    buf.writeln();
    stdout.writeln('$book: realMismatch=$realMismatch ambiguous=$ambiguous falseMatch=$falseMatch');
  }

  buf.writeln('## TOTAL across all 6 books');
  buf.writeln('- real book-boundary mismatch: $grandRealMismatch');
  buf.writeln('- ambiguous: $grandAmbiguous');
  buf.writeln('- matcher false-positive: $grandFalseMatch');

  File('sources/amrayn.com/BOOK_MISMATCH_QUALITY.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote sources/amrayn.com/BOOK_MISMATCH_QUALITY.md');
  stdout.writeln('TOTAL: realMismatch=$grandRealMismatch ambiguous=$grandAmbiguous falseMatch=$grandFalseMatch');
}

int _longestCommonSubstringLength(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var prev = List<int>.filled(b.length + 1, 0);
  var best = 0;
  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      if (a[i - 1] == b[j - 1]) {
        curr[j] = prev[j - 1] + 1;
        if (curr[j] > best) best = curr[j];
      }
    }
    prev = curr;
  }
  return best;
}
