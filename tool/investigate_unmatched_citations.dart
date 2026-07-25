import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable. Companion to
/// `content_match_amrayn_vs_known.dart`: for every amrayn citation that
/// tool couldn't find in fawaz's raw data, dump full context (Arabic text,
/// chapter, grade, whether it's a lettered variant, whether an IDENTICAL or
/// near-identical Arabic text exists elsewhere in amrayn's OWN dataset for
/// this book) so a human can actually read and categorize them, not just
/// see a bare citation list.
///
/// OUTPUT: sources/amrayn.com/UNMATCHED_DETAIL.md.
void main(List<String> args) {
  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik'];
  final buf = StringBuffer();
  buf.writeln('# Full detail on every amrayn citation NOT found in fawaz\n');

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

    final stats = MatchStats();
    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: fawazArabic,
      oldLabels: amraynKeys,
      stats: stats,
    );

    // Build a normalized-text -> list-of-citations index over amrayn's OWN
    // dataset, to detect "this exact text also appears under a different
    // amrayn citation" (duplicate/lettered-variant pattern) independent of
    // fawaz entirely.
    final ownTextIndex = <String, List<String>>{};
    for (var i = 0; i < amraynHadiths.length; i++) {
      final norm = normalizeForMatching(amraynArabic[i]);
      final key = norm.length <= 60 ? norm : norm.substring(0, 60);
      ownTextIndex.putIfAbsent(key, () => []).add(amraynKeys[i]);
    }

    buf.writeln('## $book\n');
    var n = 0;
    for (var i = 0; i < amraynHadiths.length; i++) {
      if (result[i] != null) continue;
      n++;
      final h = amraynHadiths[i];
      final citation = amraynKeys[i];
      final arabic = amraynArabic[i];
      final norm = normalizeForMatching(arabic);
      final key = norm.length <= 60 ? norm : norm.substring(0, 60);
      final siblings = (ownTextIndex[key] ?? []).where((c) => c != citation).toList();
      final isLettered = RegExp(r'[a-z]$').hasMatch(citation);
      final chapterEn = ((h['chapter'] as Map?)?['englishTitle'] as String?) ?? '?';

      buf.writeln('### $citation ${isLettered ? "(lettered)" : ""}');
      buf.writeln('- chapter: $chapterEn');
      buf.writeln('- arabic length: ${arabic.length} chars');
      buf.writeln('- duplicate-within-amrayn siblings: ${siblings.isEmpty ? "none" : siblings.join(", ")}');
      buf.writeln('- text: ${arabic.length > 300 ? arabic.substring(0, 300) + "..." : arabic}');
      buf.writeln();
    }
    stdout.writeln('$book: $n unmatched entries dumped');
  }

  File('sources/amrayn.com/UNMATCHED_DETAIL.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote sources/amrayn.com/UNMATCHED_DETAIL.md');
}
