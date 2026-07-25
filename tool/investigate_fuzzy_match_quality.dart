import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable. Answers a question
/// `content_match_amrayn_vs_known.dart` doesn't: among amrayn<->fawaz pairs
/// that only matched via a FUZZY layer (not the exact 60-char-prefix
/// anchor), how many are real content mismatches vs. just a scribal/
/// transcription difference?
///
/// History: the first version of this script judged "how different" a
/// fuzzy match was using a whole-string bigram score, which gets dragged
/// down by a differing ISNAD chain length even when the actual matn
/// (content) is identical -- verified concretely on Bukhari citation=840,
/// where amrayn's excerpt starts partway through the same hadith fawaz has
/// in full (skips the outer Abdan->Abdullah->Ma'mar->al-Zuhri->Mahmud ibn
/// al-Rabi' chain), scoring only 0.90 on a naive whole-string comparison
/// despite being a correct, complete-content match. That version also
/// missed that amrayn commonly uses the single-glyph ﷺ ligature (U+FDFA)
/// where fawaz spells out the full phrase -- 49,108 occurrences across
/// these 7 books, none of them stripped by `arabic_match.dart`'s own
/// honorific-stripping at the time (now fixed there too).
///
/// This version instead computes the LONGEST COMMON SUBSTRING between the
/// two (normalized, honorific-stripped) texts as a fraction of the SHORTER
/// text's length -- a high ratio means one text is essentially a
/// contiguous excerpt/subset of the other (truncated isnad, appended
/// postscript, etc: still the same underlying report), not a different
/// hadith. Only a LOW ratio (no long shared run of text at all) is real
/// evidence of an actual mismatch.
///
/// OUTPUT: sources/amrayn.com/FUZZY_MATCH_ANALYSIS.md.
void main(List<String> args) {
  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik'];
  final buf = StringBuffer();
  buf.writeln('# Fuzzy-match pairs re-classified by longest-common-substring ratio\n');
  buf.writeln(
    'LCS ratio = length of the longest contiguous shared run of normalized '
    'text, divided by the shorter of the two texts\' own length. High ratio '
    '(>=0.6) means one text is essentially a truncated/excerpted version of '
    'the other (same report, different amount of isnad/postscript captured) '
    '-- not a mismatch. Low ratio is the real signal of a possibly-wrong pairing.\n',
  );

  var totalHigh = 0, totalMid = 0, totalLow = 0;

  for (final book in books) {
    final amraynFile = File('sources/amrayn.com/processed/$book.json');
    final fawazFile = File('db/editions/files/ara-$book.min.json');
    if (!amraynFile.existsSync() || !fawazFile.existsSync()) continue;

    final amraynData = jsonDecode(amraynFile.readAsStringSync()) as Map<String, dynamic>;
    final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();
    final fawazData = jsonDecode(fawazFile.readAsStringSync()) as Map<String, dynamic>;
    final fawazHadiths = (fawazData['hadiths'] as List).cast<Map<String, dynamic>>();
    final fawazArabic = fawazHadiths.map((h) => (h['text'] as String?) ?? '').toList();

    final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final amraynKeys = amraynHadiths.map((h) => (h['citation'] as String?) ?? '${h['idInBook']}').toList();

    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: fawazArabic,
      oldLabels: amraynKeys,
    );

    final canonNorm = fawazArabic.map(normalizeForMatching).toList();
    final prefixIndex = <String, int>{};
    for (var i = 0; i < canonNorm.length; i++) {
      final prefix = canonNorm[i].length <= 60 ? canonNorm[i] : canonNorm[i].substring(0, 60);
      prefixIndex.putIfAbsent(prefix, () => i);
    }

    var high = 0, mid = 0, low = 0;
    final lowSamples = <String>[];

    for (var i = 0; i < amraynHadiths.length; i++) {
      final matchIdx = result[i];
      if (matchIdx == null) continue;
      final oldNorm = normalizeForMatching(amraynArabic[i]);
      final oldPrefix = oldNorm.length <= 60 ? oldNorm : oldNorm.substring(0, 60);
      final isAnchor = prefixIndex[oldPrefix] == matchIdx;
      if (isAnchor) continue;

      final newNorm = canonNorm[matchIdx];
      // Strip honorifics (incl. the ﷺ ligature) before computing LCS -- a
      // scribal-convention substitution (ﷺ vs the spelled-out phrase)
      // otherwise splits one long shared run into two shorter ones and
      // deflates the ratio for what's actually an identical report.
      String stripHon(String s) => s
          .replaceAll(
            RegExp('صلي الله عليه وسلم|رضي الله عنه(ما|ا)?|رحمه الله( تعالي)?|تعالي|عز وجل|ﷺ'),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final oldStripped = stripHon(oldNorm);
      final newStripped = stripHon(newNorm);
      final lcs = _longestCommonSubstringLength(oldStripped, newStripped);
      final shorter = oldStripped.length < newStripped.length ? oldStripped.length : newStripped.length;
      final ratio = shorter == 0 ? 0.0 : lcs / shorter;

      if (ratio >= 0.6) {
        high++;
      } else if (ratio >= 0.3) {
        mid++;
      } else {
        low++;
        if (lowSamples.length < 10) {
          lowSamples.add(
            'citation=${amraynKeys[i]} lcsRatio=${ratio.toStringAsFixed(2)} lcsLen=$lcs\n'
            '  AMRAYN: ${amraynArabic[i].length > 150 ? amraynArabic[i].substring(0, 150) : amraynArabic[i]}\n'
            '  FAWAZ:  ${fawazArabic[matchIdx].length > 150 ? fawazArabic[matchIdx].substring(0, 150) : fawazArabic[matchIdx]}',
          );
        }
      }
    }

    totalHigh += high;
    totalMid += mid;
    totalLow += low;

    buf.writeln('## $book');
    buf.writeln('- high overlap (ratio>=0.6, same report, truncation/excerpt only): $high');
    buf.writeln('- mid overlap (0.3-0.6, partial shared content, needs a look): $mid');
    buf.writeln('- low overlap (<0.3, likely a real mismatch): $low');
    if (lowSamples.isNotEmpty) {
      buf.writeln('\n### Low-overlap samples ($book)\n');
      for (final s in lowSamples) {
        buf.writeln('$s\n');
      }
    }
    buf.writeln();
    stdout.writeln('$book: high=$high mid=$mid low=$low');
  }

  buf.writeln('## TOTAL across all books');
  buf.writeln('- high overlap: $totalHigh');
  buf.writeln('- mid overlap: $totalMid');
  buf.writeln('- low overlap (real mismatch candidates): $totalLow');

  File('sources/amrayn.com/FUZZY_MATCH_ANALYSIS.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote sources/amrayn.com/FUZZY_MATCH_ANALYSIS.md');
  stdout.writeln('TOTAL: high=$totalHigh mid=$totalMid low=$totalLow');
}

/// Classic O(n*m) dynamic-programming longest-common-substring length.
/// Books here are small enough (thousands of chars per pair, not millions)
/// that this is fine to run per fuzzy-matched pair.
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
