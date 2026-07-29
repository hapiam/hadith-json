import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup, run AFTER `rebuild_from_fawaz.dart`,
/// idempotent (checks the current `chapterId` before touching each row).
///
/// Found 2026-07-29 while investigating chapter table-of-contents red flags
/// the user reported for Muslim: `idInBook` 384 (citation "151c") and 388
/// ("154b") are both `noSourceContent: true` -- fawaz's own file has no
/// Arabic or English text at all for these two lettered-variant citations
/// -- and both got assigned a `chapterId` matching NEITHER neighbor: 384
/// landed in chapter 43 ("The Book of Virtues") and 388 in chapter 16
/// ("The Book of Marriage"), when both sit between chapter-1 ("The Book of
/// Faith") neighbors on both sides (383/385 for 384; 387/389 for 388) in
/// the book's own citation order (151b, [151c], 152, ..., 154a, [154b],
/// 155a). `rebuild_from_fawaz.dart`'s neighbor-inference chapterId
/// assignment presumably can't do its usual content-based check on a
/// completely empty row, and fell back to something else here.
///
/// Whole-book scan confirmed these are the ONLY 2 such rows (out of 203
/// total `noSourceContent` rows) -- a third apparent case, idInBook 5384,
/// is a different, already-correct, already-documented situation
/// (`chapterId: null`, a genuine content gap with nothing to infer from at
/// all -- see `rebuild_from_fawaz.dart`'s own doc comment on it) and is
/// deliberately left untouched here.
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
  const fixes = {384: 1, 388: 1}; // idInBook -> correct chapterId

  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  var fixed = 0;
  for (final h in hadiths) {
    final idInBook = h['idInBook'] as int;
    final correctChapterId = fixes[idInBook];
    if (correctChapterId == null) continue;
    if (h['chapterId'] == correctChapterId) continue; // already fixed
    stdout.writeln(
      '  idInBook $idInBook: chapterId ${h['chapterId']} -> $correctChapterId '
      '(${h['reference']['text']})',
    );
    h['chapterId'] = correctChapterId;
    fixed++;
  }

  data['hadiths'] = hadiths;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('$path: $fixed row(s) corrected.');
}
