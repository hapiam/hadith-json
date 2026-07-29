import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, run AFTER `rebuild_from_fawaz.dart`,
/// idempotent (a re-run against an already-fixed file finds no more
/// mismatched runs).
///
/// Found 2026-07-29 while investigating chapter table-of-contents red flags
/// the user reported for Muslim: `idInBook` 384 (citation "151c") and 388
/// ("154b") are both `noSourceContent: true` -- fawaz's own file has no
/// Arabic or English text at all for these two lettered-variant citations
/// -- and both got assigned a `chapterId` matching NEITHER neighbor (384
/// landed in chapter 43 "Virtues", 388 in chapter 16 "Marriage", when both
/// sit between chapter-1 "Faith" neighbors on both sides).
/// `rebuild_from_fawaz.dart`'s neighbor-inference chapterId assignment
/// presumably can't do its usual content-based check on a completely empty
/// row, and fell back to something else here.
///
/// A first version of this script hardcoded just those two rows, found via
/// a simple prev/next comparison. The user then reported a THIRD case
/// (idInBook 5114-5115, both citing empty "977c"/"977d") that the simple
/// scan missed entirely: two ADJACENT wrongly-chaptered rows validate each
/// other in a pure prev/next check (5114's `next` is 5115, which shares its
/// own wrong `chapterId` 36, so neither looks anomalous in isolation) even
/// though BOTH disagree with the real surrounding context (chapterId 35 on
/// both sides of the pair). This script now finds every such case
/// automatically instead of relying on a hardcoded, one-off-discovered
/// list: it groups consecutive `noSourceContent` rows sharing one
/// `chapterId` into a run, then checks the row immediately before AND
/// after that whole run (not just one neighbor) -- a run is only "wrong"
/// when both surrounding rows agree with each other on a DIFFERENT
/// chapterId than the run itself, which is a decisive, low-risk signal
/// (matches `rebuild_from_fawaz.dart`'s own established neighbor-inference
/// convention used everywhere else in this pipeline).
///
/// idInBook 5384 (also `noSourceContent`, `chapterId: null`) is correctly
/// never flagged by this logic -- it's a different, already-documented,
/// deliberate situation (a genuine content gap with nothing to infer a
/// chapter from at all, not a wrong assignment) -- see
/// `rebuild_from_fawaz.dart`'s own doc comment on it.
///
/// This is unrelated to Muslim's separate, deeper, deferred numbering
/// problem (fawaz's own `hadithnumber` not reliably tracking sunnah.com's
/// real citations -- see DUPLICATE_HADITH_INVESTIGATION.md's "Category
/// 1b") -- only `chapterId` is touched here, nothing about `reference` or
/// numbering, so this fix carries none of that broader risk.
///
/// Usage: dart run tool/fix_muslim_empty_row_chapterid.dart
void main() {
  const path = 'db/by_book/the_9_books/muslim.json';

  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths =
      (data['hadiths'] as List)
          .map((h) => Map<String, dynamic>.from(h as Map))
          .toList()
        ..sort(
          (a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int),
        );

  var fixed = 0;
  var i = 0;
  while (i < hadiths.length) {
    if (hadiths[i]['noSourceContent'] != true) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < hadiths.length &&
        hadiths[j + 1]['noSourceContent'] == true &&
        hadiths[j + 1]['chapterId'] == hadiths[i]['chapterId']) {
      j++;
    }
    final before = i > 0 ? hadiths[i - 1]['chapterId'] : null;
    final after = j + 1 < hadiths.length ? hadiths[j + 1]['chapterId'] : null;
    if (before != null &&
        after != null &&
        before == after &&
        hadiths[i]['chapterId'] != before) {
      for (var k = i; k <= j; k++) {
        stdout.writeln(
          '  idInBook ${hadiths[k]['idInBook']}: chapterId '
          '${hadiths[k]['chapterId']} -> $before (${hadiths[k]['reference']['text']})',
        );
        hadiths[k]['chapterId'] = before;
        fixed++;
      }
    }
    i = j + 1;
  }

  data['hadiths'] = hadiths;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('$path: $fixed row(s) corrected.');
}
