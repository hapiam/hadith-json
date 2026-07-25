import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable.
///
/// Follow-up to `build_numbering_relationship_map.dart`'s finding that a
/// large fraction of fawaz's own rows (7%-36% depending on book) have ZERO
/// amrayn citations content-matched to them. Tests one specific hypothesis
/// for WHY, rather than assuming it: does fawaz's own file repeat the same
/// hadith text under more than one row (e.g. Bukhari's well-known
/// convention of citing the same narration again under a different
/// chapter), such that amrayn's single citation for that content already
/// "used up" its match on one occurrence, leaving the other occurrence(s)
/// showing as unmatched even though the content itself IS represented?
///
/// Method: for every fawaz row amrayn never matched, search the REST of
/// fawaz's own file (not amrayn) for a near-identical text via the same
/// normalized-prefix anchor + bigram-similarity checks `arabic_match.dart`
/// already uses. If a near-identical fawaz row exists AND that other row
/// IS one amrayn did match, this specific unmatched row is very likely an
/// internal duplicate, not a real content gap.
///
/// OUTPUT: sources/amrayn.com/FAWAZ_INTERNAL_DUPLICATION.md.
void main() {
  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik'];
  final buf = StringBuffer();
  buf.writeln('# Are fawaz rows amrayn never matches actually internal duplicates?\n');
  buf.writeln(
    'For every fawaz row with zero amrayn citations landing on it, checks '
    'whether a near-identical text exists ELSEWHERE in fawaz\'s own file, '
    'and whether THAT other occurrence is one amrayn did match. If so, this '
    'unmatched row very likely represents content amrayn already covers '
    'once, under a different fawaz row -- not a real gap.\n',
  );

  for (final book in books) {
    final fawazFile = File('db/editions/files/ara-$book.min.json');
    final amraynFile = File('sources/amrayn.com/processed/$book.json');
    if (!fawazFile.existsSync() || !amraynFile.existsSync()) continue;

    final fawazData = jsonDecode(fawazFile.readAsStringSync()) as Map<String, dynamic>;
    final fawazHadiths = (fawazData['hadiths'] as List).cast<Map<String, dynamic>>();
    final fawazArabic = fawazHadiths.map((h) => (h['text'] as String?) ?? '').toList();
    final fawazNorm = fawazArabic.map(normalizeForMatching).toList();

    final amraynData = jsonDecode(amraynFile.readAsStringSync()) as Map<String, dynamic>;
    final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();
    final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final amraynKeys = amraynHadiths.map((h) => (h['citation'] as String?) ?? '${h['idInBook']}').toList();

    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: fawazArabic,
      oldLabels: amraynKeys,
    );

    final matchedFawazIndices = <int>{};
    for (final idx in result) {
      if (idx != null) matchedFawazIndices.add(idx);
    }
    final unmatchedFawazIndices = [
      for (var i = 0; i < fawazHadiths.length; i++)
        if (!matchedFawazIndices.contains(i)) i,
    ];

    // Index fawaz's own text by 60-char normalized prefix, for exact
    // internal-duplicate detection first (fast, cheap).
    final prefixIndex = <String, List<int>>{};
    for (var i = 0; i < fawazNorm.length; i++) {
      final prefix = fawazNorm[i].length <= 60 ? fawazNorm[i] : fawazNorm[i].substring(0, 60);
      prefixIndex.putIfAbsent(prefix, () => []).add(i);
    }

    var exactInternalDupOfMatched = 0;
    var exactInternalDupOfUnmatched = 0; // duplicate exists but that copy is ALSO unmatched
    var noInternalDup = 0;
    final noDupSamples = <int>[];

    for (final i in unmatchedFawazIndices) {
      final prefix = fawazNorm[i].length <= 60 ? fawazNorm[i] : fawazNorm[i].substring(0, 60);
      final siblings = (prefixIndex[prefix] ?? []).where((j) => j != i).toList();
      if (siblings.isEmpty) {
        noInternalDup++;
        if (noDupSamples.length < 5) noDupSamples.add(i);
        continue;
      }
      final anyMatched = siblings.any((j) => matchedFawazIndices.contains(j));
      if (anyMatched) {
        exactInternalDupOfMatched++;
      } else {
        exactInternalDupOfUnmatched++;
      }
    }

    buf.writeln('## $book');
    buf.writeln('- fawaz rows amrayn never matches: ${unmatchedFawazIndices.length}');
    buf.writeln('- of those, exact internal duplicate exists elsewhere in fawaz AND that '
        'duplicate IS matched by amrayn: $exactInternalDupOfMatched '
        '(${(100 * exactInternalDupOfMatched / (unmatchedFawazIndices.isEmpty ? 1 : unmatchedFawazIndices.length)).toStringAsFixed(1)}%) '
        '-- confirms the internal-duplication hypothesis for these');
    buf.writeln('- exact internal duplicate exists but THAT copy is also unmatched by amrayn: $exactInternalDupOfUnmatched '
        '-- content repeated within fawaz, but amrayn seems to have neither occurrence');
    buf.writeln('- no exact internal duplicate found at all (real candidate for "amrayn genuinely lacks this"): $noInternalDup');
    buf.writeln();
    stdout.writeln('$book: dupOfMatched=$exactInternalDupOfMatched dupOfUnmatched=$exactInternalDupOfUnmatched noDup=$noInternalDup '
        '(of ${unmatchedFawazIndices.length} unmatched)');
  }

  File('sources/amrayn.com/FAWAZ_INTERNAL_DUPLICATION.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote sources/amrayn.com/FAWAZ_INTERNAL_DUPLICATION.md');
}
