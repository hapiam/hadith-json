import 'dart:io';

/// Fixes a regression introduced by `fix_muslim_small_tier_2026_08_28.dart`:
/// that script's line-scan matched EVERY `"text":` line inside a hadith
/// record's bounds, which is both `english.text` (intended) AND
/// `reference.text` (a short citation like "Sahih Muslim 179a" — NOT
/// intended), overwriting both with the corrected hadith text. Confirmed via
/// `git show 72a5b20^:...` that these 3 records' `reference.text` was a
/// plain citation before that patch ran.
///
/// This restores just `reference.text` for the 3 affected records, using a
/// narrower match: only the FIRST `"text":` line found strictly after that
/// record's own `"reference": {` line, so it cannot accidentally touch
/// `english.text` again.
///
/// Usage: dart run tool/fix_muslim_reference_regression_2026_08_28.dart
void main() {
  const path = 'db/by_book/hadithunlocked/muslim.json';
  final lines = File(path).readAsStringSync().split('\r\n');

  final corrections = {
    2000942: 'Sahih Muslim 419a',
    2000446: 'Sahih Muslim 179a',
    2005506: 'Sahih Muslim 2118',
  };

  for (final entry in corrections.entries) {
    final idLine = '\t\t\t"id": ${entry.key},';
    final idIndex = lines.indexOf(idLine);
    if (idIndex == -1) throw StateError('could not find $idLine');

    var refIndex = -1;
    for (var i = idIndex + 1; i < lines.length; i++) {
      if (lines[i].startsWith('\t\t\t"id": ')) break; // next record, stop
      if (lines[i].contains('"reference": {')) {
        refIndex = i;
        break;
      }
    }
    if (refIndex == -1) throw StateError('no reference block for ${entry.key}');

    var textIndex = -1;
    for (var i = refIndex + 1; i < lines.length; i++) {
      if (lines[i].contains('"text":')) {
        textIndex = i;
        break;
      }
    }
    if (textIndex == -1) throw StateError('no text line in reference block for ${entry.key}');

    final old = lines[textIndex];
    final indent = old.substring(0, old.indexOf('"text"'));
    lines[textIndex] = '$indent"text": "${entry.value}",';
    stdout.writeln('id=${entry.key}: restored reference.text');
    stdout.writeln('  old: ${old.trim()}');
    stdout.writeln('  new: ${lines[textIndex].trim()}');
  }

  File(path).writeAsStringSync(lines.join('\r\n'));
  stdout.writeln('\n$path: corrected ${corrections.length} reference.text field(s).');
}
