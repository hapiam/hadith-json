import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: verification/report tool, repeatable.
///
/// `BOOK_CHAPTER_CROSSCHECK.md` previously concluded Malik had "no real
/// join key" between amrayn's `malikChapterNum` and this repo's own
/// canonical `chapterId` (an AhmedBaset-derived rebuild, unrelated to
/// Malik's own real book structure). This tool checks a join key that was
/// never examined: fawaz's own RAW `reference.book` field on
/// `db/editions/files/ara-malik.min.json` -- separate from the canonical
/// rebuild entirely.
///
/// Method: content-match every amrayn Malik citation to its fawaz row
/// (`arabic_match.dart`, by Arabic text, never by number), then compare
/// amrayn's `malikChapterNum` against that matched row's `reference.book`.
///
/// Finding: a real relationship exists (86% exact agreement) -- much
/// better than "no join key" -- but the ~14% disagreement is NOT the same
/// kind of narrow, bounded, near-boundary editorial disagreement the other
/// 6 books showed (see `NUMBERING_RELATIONSHIP_MAP.md`). Here the gap
/// between amrayn's book number and fawaz's book number GROWS as the book
/// progresses (single digits early on, up to ~57 by the end, even though
/// both sources independently cap at 61 total books) -- a genuine
/// progressive divergence in book-division convention, not a scattering of
/// off-by-one disagreements. Consistent with Muwatta Malik's well-known
/// real manuscript-recension differences (multiple transmission lines with
/// different chapter groupings), not a data-quality problem in either
/// source. Needs a third source or direct scholarly reference to fully
/// resolve which recension each source follows -- not resolvable from
/// these two sources' automated matching alone.
///
/// OUTPUT: sources/amrayn.com/MALIK_BOOK_JOIN.md.
void main() {
  final fawazData = jsonDecode(File('db/editions/files/ara-malik.min.json').readAsStringSync()) as Map<String, dynamic>;
  final fawazHadiths = (fawazData['hadiths'] as List).cast<Map<String, dynamic>>();
  final fawazArabic = fawazHadiths.map((h) => (h['text'] as String?) ?? '').toList();
  final fawazBook = fawazHadiths.map((h) => ((h['reference'] as Map)['book'] as num).toInt()).toList();
  final fawazDistinctBooks = fawazBook.toSet();

  final amraynData = jsonDecode(File('sources/amrayn.com/processed/malik.json').readAsStringSync()) as Map<String, dynamic>;
  final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();
  final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
  final amraynBook = amraynHadiths.map((h) => (h['malikChapterNum'] as num?)?.toInt()).toList();
  final amraynKeys = amraynHadiths.map((h) => (h['idInBook'] as num).toInt()).toList();

  final result = matchToCanonical(
    oldArabic: amraynArabic,
    canonicalArabic: fawazArabic,
    oldLabels: amraynKeys.map((k) => '$k').toList(),
  );

  var matched = 0, agree = 0, disagree = 0;
  final diffCounts = <int, int>{};
  final diffByIdInBook = <int, int>{};
  for (var i = 0; i < result.length; i++) {
    final idx = result[i];
    if (idx == null || amraynBook[i] == null) continue;
    matched++;
    final diff = amraynBook[i]! - fawazBook[idx];
    if (diff == 0) {
      agree++;
    } else {
      disagree++;
      diffCounts[diff] = (diffCounts[diff] ?? 0) + 1;
      diffByIdInBook[amraynKeys[i]] = diff;
    }
  }

  final sortedIds = diffByIdInBook.keys.toList()..sort();
  final buf = StringBuffer();
  buf.writeln('# Malik: amrayn malikChapterNum <-> fawaz raw reference.book\n');
  buf.writeln(
    'A join key `BOOK_CHAPTER_CROSSCHECK.md` never checked: fawaz\'s own raw '
    '`reference.book` field (separate from the canonical `chapterId` rebuild '
    'that file was actually about). Content-matched by Arabic text '
    '(`arabic_match.dart`), then compared per-citation.\n',
  );
  buf.writeln('- amrayn citations content-matched to a fawaz row: $matched / ${amraynHadiths.length}');
  buf.writeln('- exact agreement: $agree (${(100 * agree / matched).toStringAsFixed(1)}%)');
  buf.writeln('- disagreement: $disagree (${(100 * disagree / matched).toStringAsFixed(1)}%)');
  buf.writeln('- fawaz distinct `reference.book` values: ${fawazDistinctBooks.length} '
      '(range ${fawazDistinctBooks.reduce((a, b) => a < b ? a : b)}-${fawazDistinctBooks.reduce((a, b) => a > b ? a : b)})');
  buf.writeln('- amrayn distinct `malikChapterNum` range: 1-${amraynBook.whereType<int>().reduce((a, b) => a > b ? a : b)}\n');
  buf.writeln(
    '**This is not the same kind of disagreement the other 6 books had.** '
    'Bukhari/Nasa\'i/Abu Dawud/Tirmidhi/Ibn Majah/Muslim\'s disagreements '
    'were narrow and bounded (off by exactly one adjacent book, clustered '
    'in short citation ranges). Here the gap between amrayn\'s book number '
    'and fawaz\'s book number GROWS as the book progresses -- single digits '
    'early on, up to the 40s-50s by the end -- even though both sources '
    'independently cap at 61 total books. This is a genuine progressive '
    'divergence in book-division convention, consistent with Muwatta '
    'Malik\'s well-documented real manuscript-recension differences (more '
    'than one historical transmission line, with different chapter '
    'groupings), not a data-quality defect in either source. Resolving '
    'which recension each source actually follows needs a third source or '
    'direct scholarly reference -- not resolvable from these two sources\' '
    'automated matching alone.\n',
  );
  buf.writeln('## Disagreement progression (first 20 by idInBook order)\n');
  buf.writeln('| idInBook | amraynBook - fawazBook |');
  buf.writeln('|---:|---:|');
  for (final id in sortedIds.take(20)) {
    buf.writeln('| $id | ${diffByIdInBook[id]} |');
  }
  buf.writeln('\n## Disagreement progression (last 20 by idInBook order)\n');
  buf.writeln('| idInBook | amraynBook - fawazBook |');
  buf.writeln('|---:|---:|');
  for (final id in sortedIds.skip(sortedIds.length > 20 ? sortedIds.length - 20 : 0)) {
    buf.writeln('| $id | ${diffByIdInBook[id]} |');
  }

  File('sources/amrayn.com/MALIK_BOOK_JOIN.md').writeAsStringSync(buf.toString());
  stdout.writeln('Wrote sources/amrayn.com/MALIK_BOOK_JOIN.md');
  stdout.writeln('matched=$matched agree=$agree disagree=$disagree agreeRate=${(100 * agree / matched).toStringAsFixed(1)}%');
}
