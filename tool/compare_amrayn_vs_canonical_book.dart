import 'dart:convert';
import 'dart:io';

/// STAGE: verification/report tool, repeatable, zero network requests.
///
/// The actual cross-check this whole investigation was for: does amrayn's
/// book/chapter assignment (sources/amrayn.com/{book}_book_lookup.json,
/// resolved 2026-07-25) agree 1:1 with this repo's own canonical
/// book/chapter assignment (db/unified/by_book/{book}.json's chapterId,
/// named via db/unified/catalog.json's bookChapters)?
///
/// Matched by leading integer of the amrayn citation against canonical
/// idInBook -- correct for the un-lettered majority of each book (both
/// sides ultimately number physical narrations in citation order); a
/// lettered citation (e.g. "8a") has no single canonical idInBook to
/// compare against under fawaz's flat Type-1 scheme, so those are
/// reported separately, not silently skipped or wrongly matched.
///
/// Malik is excluded: its canonical numbering is an unrelated flat Arabic-
/// spine index, not comparable to amrayn's malikChapterNum/
/// malikLocalHadithNum without a real join key -- not attempted here.
///
/// OUTPUT: prints a per-book match/mismatch/lettered-skipped count, and
/// every mismatch found, to stdout.
void main() {
  final catalog = jsonDecode(
    File('db/unified/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final bookChapters = catalog['bookChapters'] as Map<String, dynamic>;

  const books = ['bukhari', 'muslim', 'nasai', 'abudawud'];
  for (final book in books) {
    final names = <int, String>{
      for (final c in (bookChapters[book] as List).cast<Map<String, dynamic>>())
        (c['id'] as int): ((c['names'] as Map)['en'] as String? ?? '?'),
    };

    final canonicalData = jsonDecode(
      File('db/unified/by_book/$book.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final canonicalByIdInBook = <int, int>{
      for (final h in (canonicalData['hadiths'] as List).cast<Map<String, dynamic>>())
        if (h['chapterId'] != null) (h['idInBook'] as int): (h['chapterId'] as int),
    };

    final lookup = jsonDecode(
      File('sources/amrayn.com/${book}_book_lookup.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    var matched = 0, mismatched = 0, lettered = 0, noCanonical = 0;
    final mismatches = <String>[];

    for (final entry in lookup.entries) {
      final citation = entry.key;
      final amraynBook = (entry.value as Map)['book'] as int;
      final leadingMatch = RegExp(r'^(\d+)([a-z]?)$').firstMatch(citation);
      if (leadingMatch == null) continue;
      final leadingInt = int.parse(leadingMatch.group(1)!);
      final hasLetter = leadingMatch.group(2)!.isNotEmpty;
      if (hasLetter) {
        lettered++;
        continue;
      }
      final canonicalChapterId = canonicalByIdInBook[leadingInt];
      if (canonicalChapterId == null) {
        noCanonical++;
        continue;
      }
      if (canonicalChapterId == amraynBook) {
        matched++;
      } else {
        mismatched++;
        if (mismatches.length < 15) {
          mismatches.add(
            'citation=$citation: amrayn book=$amraynBook (${names[amraynBook]}), '
            'canonical chapterId=$canonicalChapterId (${names[canonicalChapterId]})',
          );
        }
      }
    }

    print('$book: matched=$matched mismatched=$mismatched '
        'lettered-skipped=$lettered no-canonical-idInBook=$noCanonical');
    for (final m in mismatches) {
      print('  MISMATCH: $m');
    }
  }
}
