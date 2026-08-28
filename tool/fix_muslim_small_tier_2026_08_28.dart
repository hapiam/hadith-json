import 'dart:convert';
import 'dart:io';

/// muslim.json is tab-indented, unlike the other 4 books in the 2026-08-28
/// small-tier audit batch, which are 2-space-indented. Running the same
/// parse-whole-file-and-`JsonEncoder.withIndent`-it-back approach used in
/// `fix_small_tier_audit_2026_08_28.dart` reformats every line of the file
/// to 2-space indent, turning a 3-row fix into a 680,000-line diff that
/// swamps the real change. This does a surgical TEXT-level patch instead:
/// find each row's own `"narrator"`/`"text"` line by scanning for its `"id"`
/// line first (each field's JSON string value is single-line, since
/// newlines inside it are already `\n` escapes, not raw newlines), and
/// replace only that one line — every other byte of the file, including
/// its tab indentation, is untouched.
///
/// Usage: dart run tool/fix_muslim_small_tier_2026_08_28.dart
void main() {
  const path = 'db/by_book/hadithunlocked/muslim.json';
  final allFixes = (jsonDecode(
            File('tool/small_tier_audit_2026_08_28_fixes.json').readAsStringSync(),
          )
          as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((f) => f['book'] == 'muslim')
      .toList();

  // CRLF line terminators, unlike the other 4 books in this batch.
  final lines = File(path).readAsStringSync().split('\r\n');
  var fixedCount = 0;

  for (final fix in allFixes) {
    final idLine = '\t\t\t"id": ${fix['id']},';
    final idIndex = lines.indexOf(idLine);
    if (idIndex == -1) {
      throw StateError('muslim.json: could not find line "$idLine"');
    }
    // Bounded by the NEXT hadith's "id" line (same 3-tab depth) so a
    // narrator/text match can't bleed into a different record.
    var nextIdIndex = lines.length;
    for (var i = idIndex + 1; i < lines.length; i++) {
      if (lines[i].startsWith('\t\t\t"id": ')) {
        nextIdIndex = i;
        break;
      }
    }

    var sawNarrator = false;
    var sawText = false;
    var sawAiFlag = false;
    for (var i = idIndex; i < nextIdIndex; i++) {
      final line = lines[i];
      if (line.contains('"narrator":')) {
        final indent = line.substring(0, line.indexOf('"narrator"'));
        final trailingComma = line.trimRight().endsWith(',') ? ',' : '';
        lines[i] = '$indent"narrator": ${jsonEncode(fix['correctedNarrator'])}$trailingComma';
        sawNarrator = true;
      } else if (line.contains('"text":') && !line.contains('"textArabic"')) {
        final indent = line.substring(0, line.indexOf('"text"'));
        final trailingComma = line.trimRight().endsWith(',') ? ',' : '';
        lines[i] = '$indent"text": ${jsonEncode(fix['correctedText'])}$trailingComma';
        sawText = true;
      } else if (line.contains('"isAiTranslated"')) {
        sawAiFlag = true;
        lines[i] = '__REMOVE_LINE__';
      }
    }
    if (!sawNarrator || !sawText) {
      throw StateError(
        'muslim.json id=${fix['id']}: narrator=$sawNarrator text=$sawText — did not find both fields',
      );
    }
    stdout.writeln(
      'muslim id=${fix['id']}: patched narrator+text'
      '${sawAiFlag ? ', removed isAiTranslated' : ''}',
    );
    fixedCount++;
  }

  final result = lines.where((l) => l != '__REMOVE_LINE__').join('\r\n');
  File(path).writeAsStringSync(result);
  stdout.writeln('\n$path: corrected $fixedCount row(s), formatting preserved.');
}
