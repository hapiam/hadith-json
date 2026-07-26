import 'dart:convert';
import 'dart:io';

import 'arabic_match.dart';

/// STAGE: one-time spine enrichment, repeatable/idempotent (re-running
/// after a fresh merge is a no-op since matched content stops being
/// "missing").
///
/// `tool/content_match_amrayn_vs_known.dart` found amrayn hadith whose
/// Arabic text doesn't content-match fawaz's raw corpus at all -- genuine
/// gaps, not just citation-numbering noise (see
/// sources/amrayn.com/CONTENT_MATCH_REPORT.md). This tool actually merges
/// that content into the spines, in two distinct ways depending on what's
/// really going on at amrayn's own `idInBook` slot (which is sunnah.com-
/// style canonical numbering, verified directly against amrayn's own
/// `title` field, e.g. "Sahih Muslim 8a" -> `idInBook: 8`):
///
/// 1. **Backfill**: our current spine already has a row at that exact
///    `idInBook` but its `arabic` field is blank (a known, separately
///    documented gap -- see CROSSCHECK_OVERLAP.md's "408 blank-Arabic"
///    finding). amrayn has the real content for the same citation slot;
///    write it in place. No new row, no addendum flag, idInBook unchanged
///    -- this is a pure gap-fill, not new content.
/// 2. **Addendum**: amrayn has content that doesn't correspond to any
///    blank slot -- either genuinely extra material (a lettered narration
///    variant sunnah.com's own numbering keeps distinct, e.g. amrayn has
///    both "8a" and "8b" but our spine's row 8 already has real content
///    for one of them) or content our fawaz-rebuilt numbering simply never
///    had a slot for. Appended as a NEW row with a synthetic `idInBook`
///    beyond the book's current max (never collides with a real citation
///    number), `isAddendum: true`, and `sortKey` set to
///    `<amrayn idInBook> + 0.5` so it displays right after its rightful
///    neighbor instead of at the end of the book -- same pattern already
///    established for repositioned addenda elsewhere in this repo.
///    `chapterId` is inherited from whichever existing spine row has the
///    closest `idInBook` (amrayn's own `chapter` field uses a per-book bab
///    numbering scheme that doesn't correspond to this spine's top-level
///    chapterId scheme at all -- verified directly: amrayn chapterNum=23
///    for Muslim citation 275 is "Wiping over the forehead", not this
///    spine's chapterId=23 "The Book of the Rules of Inheritance").
///
/// Every merged row (both backfilled and addendum) is honestly marked
/// `source: 'amrayn'` -- every other row's absence of this field means
/// "from the primary fawaz/AhmedBaset source" by convention.
///
/// **Malik only**: Muwatta Malik traditionally mixes actual Prophetic
/// hadith with Imam Malik's own legal opinions ("qawl"), and fawaz's raw
/// corpus (which this spine was rebuilt from) appears to have dropped the
/// opinion entries entirely -- verified directly on 2 samples (citations
/// 35 and 433), both are Malik's own rulings with no Prophetic attribution
/// at all. Detected here by a simple textual heuristic (no "ﷺ" / "رَسُولُ
/// اللَّهِ" / "النَّبِيّ" anywhere in the Arabic) and marked
/// `contentType: 'opinion'` so the app can filter/highlight these
/// separately from actual hadith, per explicit user request (2026-07-26)
/// to make this filterable rather than silently mixed in.
///
/// Usage: dart run tool/merge_amrayn_missing_hadith.dart
void main() {
  const books = [
    _BookConfig('muslim', 'db/by_book/the_9_books/muslim.json', 2),
    _BookConfig('nasai', 'db/by_book/the_9_books/nasai.json', 3),
    _BookConfig('abudawud', 'db/by_book/the_9_books/abudawud.json', 4),
    _BookConfig('tirmidhi', 'db/by_book/the_9_books/tirmidhi.json', 5),
    _BookConfig('ibnmajah', 'db/by_book/the_9_books/ibnmajah.json', 6),
    _BookConfig('malik', 'db/by_book/the_9_books/malik.json', 7),
  ];
  final bracketRe = RegExp(r'^(.*?)\s*\[([^\]]+)\]$');

  for (final book in books) {
    final spineFile = File(book.spinePath);
    final spineData = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final spineHadiths = (spineData['hadiths'] as List)
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();

    final spineArabic = spineHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final spineIdInBook = spineHadiths.map((h) => (h['idInBook'] as num).toInt()).toList();
    final byIdInBook = <int, Map<String, dynamic>>{
      for (final h in spineHadiths) (h['idInBook'] as num).toInt(): h,
    };

    final amraynData = jsonDecode(
      File('sources/amrayn.com/processed/${book.bookKey}.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();
    final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final amraynLabels = amraynHadiths.map((h) => '${h['idInBook']}').toList();

    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: spineArabic,
      oldLabels: amraynLabels,
    );

    List<Map<String, String>>? parseGrades(dynamic gradesRaw) {
      if (gradesRaw is! List || gradesRaw.isEmpty) return null;
      final list = <Map<String, String>>[];
      final seen = <String>{};
      for (final g in gradesRaw) {
        if (g is! Map) continue;
        final text = (g['text'] as String?)?.trim();
        if (text == null || text.isEmpty) continue;
        final m = bracketRe.firstMatch(text);
        final name = m != null ? m.group(2)!.trim() : 'Sunnah.com';
        final grade = m != null ? m.group(1)!.trim() : text;
        final key = '${name.toLowerCase()}|${grade.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        list.add({'name': name, 'grade': grade});
      }
      return list.isEmpty ? null : list;
    }

    var backfilled = 0;
    var addenda = 0;
    var maxIdInBook = spineIdInBook.reduce((a, b) => a > b ? a : b);
    final claimedBlankSlots = <int>{};
    final newRows = <Map<String, dynamic>>[];

    for (var i = 0; i < amraynHadiths.length; i++) {
      if (result[i] != null) continue; // already present, real content match
      final h = amraynHadiths[i];
      final arabic = (h['arabic'] as String?)?.trim() ?? '';
      if (arabic.isEmpty) continue;
      final amraynIdInBook = (h['idInBook'] as num).toInt();
      final english = ((h['body'] as String?)?.trim().isNotEmpty ?? false)
          ? (h['body'] as String).trim()
          : ((h['englishRaw'] as String?)?.trim() ?? '');
      final grades = parseGrades(h['grades']);
      final isOpinion = book.bookKey == 'malik' &&
          !arabic.contains('رَسُولُ اللَّهِ') &&
          !arabic.contains('ﷺ') &&
          !arabic.contains('النَّبِيّ');

      final existingRow = byIdInBook[amraynIdInBook];
      final slotIsBlank = existingRow != null &&
          ((existingRow['arabic'] as String?) ?? '').trim().isEmpty;

      if (slotIsBlank && !claimedBlankSlots.contains(amraynIdInBook)) {
        claimedBlankSlots.add(amraynIdInBook);
        existingRow['arabic'] = arabic;
        final englishMap = (existingRow['english'] as Map?)?.cast<String, dynamic>() ?? {};
        if ((englishMap['text'] as String?)?.trim().isEmpty ?? true) {
          englishMap['text'] = english;
        }
        existingRow['english'] = englishMap;
        if (grades != null && existingRow['grade'] == null) {
          existingRow['grade'] = grades;
        }
        existingRow['source'] = 'amrayn';
        if (isOpinion) existingRow['contentType'] = 'opinion';
        backfilled++;
        continue;
      }

      // Addendum: nearest-idInBook neighbor's chapterId.
      int? nearestChapterId;
      var bestDist = 1 << 30;
      for (var j = 0; j < spineIdInBook.length; j++) {
        final d = (spineIdInBook[j] - amraynIdInBook).abs();
        if (d < bestDist) {
          bestDist = d;
          nearestChapterId = spineHadiths[j]['chapterId'] as int?;
        }
      }

      maxIdInBook++;
      newRows.add({
        'id': book.bookId * 1000000 + maxIdInBook,
        'idInBook': maxIdInBook,
        'chapterId': nearestChapterId,
        'bookId': book.bookId,
        'arabic': arabic,
        'english': {'narrator': '', 'text': english},
        if (grades != null) 'grade': grades,
        // The spine's own flag for this is `appendedOriginal`, NOT
        // `isAddendum` -- `build_unified_editions.dart`'s master-row
        // construction reads `h['appendedOriginal']` and RENAMES it to
        // `isAddendum` in the unified output (verified directly: writing
        // `isAddendum` here left every emitted addendum silently showing
        // `isAddendum: false`).
        'appendedOriginal': true,
        'sortKey': amraynIdInBook + 0.5,
        'source': 'amrayn',
        if (isOpinion) 'contentType': 'opinion',
        'reference': {
          'text': isOpinion
              ? 'amrayn $amraynIdInBook (Imam Malik\'s own ruling, not a Prophetic hadith)'
              : 'amrayn $amraynIdInBook',
        },
      });
      addenda++;
    }

    spineHadiths.addAll(newRows);
    spineData['hadiths'] = spineHadiths;
    final meta = (spineData['metadata'] as Map?)?.cast<String, dynamic>();
    if (meta != null) meta['length'] = spineHadiths.length;
    spineFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spineData));
    stdout.writeln(
      '${book.bookKey}: $backfilled blank slots backfilled, $addenda addenda merged '
      '(of ${amraynHadiths.length} amrayn total, ${amraynHadiths.length - backfilled - addenda} already matched)',
    );
  }
}

class _BookConfig {
  const _BookConfig(this.bookKey, this.spinePath, this.bookId);
  final String bookKey;
  final String spinePath;
  final int bookId;
}
