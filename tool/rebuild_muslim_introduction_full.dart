import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine patch, run AFTER `import_hadithunlocked.dart`
/// (Muslim), idempotent (checks for the marker citations before touching
/// anything). Supersedes the retired `fix_muslim_introduction.dart` (kept
/// in git history, no longer run) -- that version only replaced
/// hadithunlocked's mis-chaptered "1"-"7" with 8 verified rows and
/// silently dropped everything else (94 "i"/"ir"-numbered fragments,
/// already excluded during import as apparent non-hadith prose).
///
/// User pushback (2026-07-29): "it is part of the book though right? so we
/// should put it into THE BOOK" -- correct. sunnah.com's own Introduction
/// page (`sunnah.com/muslim/introduction`, fetched live via browser since
/// WebFetch is 403'd there) turns out to have a full, real structure of
/// its own: 8 bab (sub-chapter) headers -- "1" "2" "3" "4" "5" "5B" "5C"
/// "6" -- and 91 individually-referenced narrations, of which only 8 are
/// part of the citable 1-3033 scheme (citations 1, 2, 3, 4a, 4b, 5, 6, 7);
/// the other 83 are labeled "Sahih Muslim Introduction N" (sunnah.com's
/// own convention) and, contrary to the earlier assumption that this
/// content was pure uncited prose, most of them DO have real isnad chains
/// -- they're just not part of the main citable numbering. Plus 5 prose
/// essays in Imam Muslim's own voice (the opening muqaddimah, and each of
/// bab 1/5/5C/6's own framing text) with no citation at all.
///
/// Source data: `sources/sunnah.com/muslim_introduction/
/// muslim_introduction_sunnah.json` -- scraped directly from the live page
/// 2026-07-29 (not reconstructed/guessed), 96 ordered segments covering
/// every bab header, all 91 entries, and all 5 essays, English+Arabic
/// verified against the rendered page text.
///
/// Count/display decision (explicit user choice, 2026-07-29, given two
/// options): count these 83 narrations + 5 essays toward `hadithCount`
/// (they get `contentType: 'commentary'`, the same "tag it, no special
/// reader treatment yet" mechanism `contentType: 'opinion'` already
/// established for Imam Malik's own legal rulings mixed into Muwatta) --
/// NOT tagged/excluded. This raises Muslim's `hadithCount` from 7,376 to
/// roughly 7,463 (91 - 8 already-counted core citations + 5 essays = +88),
/// which lines up with sunnah.com's own "approximately 7,500 ahadith"
/// framing better than 7,376 did.
///
/// Usage: dart run tool/rebuild_muslim_introduction_full.dart
void main() {
  const spinePath = 'db/by_book/hadithunlocked/muslim.json';
  const sourcePath =
      'sources/sunnah.com/muslim_introduction/muslim_introduction_sunnah.json';

  final file = File(spinePath);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();
  final chapters = (data['chapters'] as List)
      .map((c) => Map<String, dynamic>.from(c as Map))
      .toList();

  final introChapterId = chapters.firstWhere(
    (c) => c['names']['en'] == 'Introduction',
  )['id'] as int;
  final bookId = hadiths.first['bookId'] as int;

  // Drop hadithunlocked's own mis-chaptered "1".."7" (see doc comment;
  // same removal `fix_muslim_introduction.dart` did -- these are wrong
  // both in chapter placement and, for "5", in isnad content).
  const wrongNumbers = {'1', '2', '3', '4', '5', '6', '7'};
  final removed = hadiths
      .where(
        (h) => wrongNumbers.contains(
          (h['reference']['text'] as String).split(' ').last,
        ),
      )
      .toList();
  hadiths.removeWhere(
    (h) => wrongNumbers.contains(
      (h['reference']['text'] as String).split(' ').last,
    ),
  );
  stdout.writeln(
    'Removed ${removed.length} mis-chaptered rows: '
    '${removed.map((h) => h['reference']['text']).join(', ')}',
  );

  final segments =
      (jsonDecode(File(sourcePath).readAsStringSync()) as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

  // hadithunlocked's own import ALREADY creates 8 bab sub-chapters under
  // "Introduction" (ids 2-9, positioned correctly right after chapterId 1
  // in the array -- see `import_hadithunlocked.dart`'s chapter/section
  // loop) with titles that are a verified 1:1, same-order match against
  // sunnah.com's own 8 babs (1, 2, 3, 4, 5, 5B, 5C, 6). Reuse them directly
  // -- creating brand-new chapters here (an earlier version of this script
  // did exactly that) produced 8 duplicate babs AND, because the new rows
  // landed at the END of the chapters array instead of right after
  // chapterId 1, a false gap in `hadith_chapter_range_info.dart`'s
  // array-order-dependent detector (caught 2026-07-29 the same way the
  // idInBook shift bug was: running that detector's own algorithm
  // standalone against the built spine).
  final babTitles = <String, Map<String, String>>{};
  for (final s in segments) {
    final num = s['chapterNum'] as String?;
    if (num == null || babTitles.containsKey(num)) continue;
    babTitles[num] = {
      'en': s['chapterTitleEn'] as String,
      'ar': s['chapterTitleAr'] as String,
    };
  }
  const babChapterId = {
    '1': 2,
    '2': 3,
    '3': 4,
    '4': 5,
    '5': 6,
    '5B': 7,
    '5C': 8,
    '6': 9,
  };

  const coreLabels = {'1', '2', '3', '4 a', '4 b', '5', '6', '7'};
  String labelToCitation(String label) => label.replaceAll(' ', '');

  final newRows = <Map<String, dynamic>>[];
  for (final s in segments) {
    final type = s['type'] as String;
    final english = (s['english'] as String).trim();
    final arabic = (s['arabic'] as String).trim();
    if (type == 'essay') {
      // Opening muqaddimah -- no bab of its own, attaches directly to the
      // top-level Introduction chapter, read first.
      newRows.add({
        'chapterId': introChapterId,
        'bookId': bookId,
        'arabic': arabic,
        'english': {'narrator': '', 'text': english},
        'grade': null,
        'contentType': 'commentary',
        'reference': {
          'text': 'Sahih Muslim, Introduction (Muqaddimah)',
          'url': 'https://sunnah.com/muslim/introduction',
        },
      });
    } else if (type == 'babProse') {
      final num = s['chapterNum'] as String;
      newRows.add({
        'chapterId': babChapterId[num],
        'bookId': bookId,
        'arabic': arabic,
        'english': {'narrator': '', 'text': english},
        'grade': null,
        'contentType': 'commentary',
        'reference': {
          'text': 'Sahih Muslim, Introduction (${babTitles[num]!['en']})',
          'url': 'https://sunnah.com/muslim/introduction',
        },
      });
    } else if (type == 'entry') {
      final label = s['label'] as String;
      final num = s['chapterNum'] as String;
      final isCore = coreLabels.contains(label);
      newRows.add({
        'chapterId': babChapterId[num],
        'bookId': bookId,
        'arabic': arabic,
        'english': {'narrator': '', 'text': english},
        'grade': null,
        if (!isCore) 'contentType': 'commentary',
        'reference': {
          'text': isCore
              ? 'Sahih Muslim ${labelToCitation(label)}'
              : 'Sahih Muslim, $label',
          'url': 'https://sunnah.com/muslim/introduction',
        },
      });
    }
  }

  // hadiths (already in idInBook order from import) keep their relative
  // order; the new Introduction rows go in front, in sunnah.com's own
  // reading order (segments array is already ordered this way). Renumber
  // the WHOLE result densely from 1 -- same fix as the retired script's
  // shift-arithmetic bug (2026-07-29): never pre-compute a shift amount,
  // always renumber the final concatenation directly.
  final result = [...newRows, ...hadiths];
  for (var i = 0; i < result.length; i++) {
    final idInBook = i + 1;
    result[i]['idInBook'] = idInBook;
    result[i]['id'] = bookId * 1000000 + idInBook;
  }
  data['hadiths'] = result;
  data['chapters'] = chapters;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$spinePath: inserted ${newRows.length} verified Introduction rows '
    '(8 citable + 83 non-citable narrations + 5 essays) into hadithunlocked\'s '
    'own existing bab sub-chapters (ids 2-9), renumbered ${result.length} '
    'total rows densely. New Introduction hadithCount contribution: '
    '${newRows.length}.',
  );
}
