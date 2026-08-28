import 'dart:convert';
import 'dart:io';

/// STAGE: one-time patch, applying the 2026-08-28 small-tier AI-fabrication
/// audit's verified corrections (ibnrajab50, ibnkhuzaymah, lulu-marjan,
/// muslim, bazzar — the 5 books with under 100 `isAiTranslated: true` rows
/// each; the other 8 hadithunlocked books, some 70-90% AI-translated, were
/// NOT in scope for this pass).
///
/// Every row here went through two independent LLM reviewers reading the
/// Arabic directly, then two more independent skeptics verifying the
/// PROPOSED correction against the Arabic before it's applied here — same
/// discipline as `fix_bayhaqi_14109_translation.dart`, just batched. Not
/// every AI-tagged row in these 5 books needed a fix: only rows a reviewer
/// flagged and a verifier confirmed are listed in `_fixes` below.
///
/// One `lulu-marjan` row (id 20001539, "Highest Companion") was
/// deliberately EXCLUDED from this batch — the audit found the English is
/// correct against the well-attested standard wording of that hadith; the
/// STORED ARABIC is the one with the gap (a pre-existing hadithunlocked.com
/// transcription quirk, confirmed against its own site), so nothing here
/// should touch it.
///
/// Usage: dart run tool/fix_small_tier_audit_2026_08_28.dart <path-to-all_fixes.json>
void main(List<String> args) {
  final fixes = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final fixesByBook = <String, List<Map<String, dynamic>>>{};
  for (final f in fixes) {
    fixesByBook.putIfAbsent(f['book'] as String, () => []).add(f);
  }

  var totalFixed = 0;
  fixesByBook.forEach((book, fixes) {
    final path = 'db/by_book/hadithunlocked/$book.json';
    final file = File(path);
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = (data['hadiths'] as List)
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();

    var bookFixed = 0;
    for (final fix in fixes) {
      final id = fix['id'];
      final row = hadiths.firstWhere(
        (h) => h['id'] == id,
        orElse: () => throw StateError('$book: id $id not found'),
      );
      final english = Map<String, dynamic>.from(row['english'] as Map);
      final oldNarrator = english['narrator'];
      final oldText = english['text'];
      english['narrator'] = fix['correctedNarrator'];
      english['text'] = fix['correctedText'];
      row['english'] = english;
      row.remove('isAiTranslated');
      bookFixed++;
      totalFixed++;
      stdout.writeln('--- $book id=$id (idInBook=${fix['idInBook']}) ---');
      if (oldNarrator != fix['correctedNarrator']) {
        stdout.writeln('  narrator (old): $oldNarrator');
        stdout.writeln('  narrator (new): ${fix['correctedNarrator']}');
      }
      if (oldText != fix['correctedText']) {
        stdout.writeln('  text changed (old ${(oldText as String).length} chars -> new ${(fix['correctedText'] as String).length} chars)');
      }
    }

    data['hadiths'] = hadiths;
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln('$path: corrected $bookFixed row(s).');
  });

  stdout.writeln('\nTotal: corrected $totalFixed row(s) across ${fixesByBook.length} book(s).');
}
