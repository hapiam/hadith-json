import 'dart:convert';
import 'dart:io';

/// Fixes the FULL scope of the regression `fix_muslim_small_tier_2026_08_28.dart`
/// introduced: its line-scan matched every `"text":`/`"narrator":` line inside
/// a record's bounds, not just `english.narrator`/`english.text`. Beyond the
/// already-fixed `reference.text` (see
/// `fix_muslim_reference_regression_2026_08_28.dart`), it ALSO overwrote every
/// language slot under `translations` (bn/fr/id/ru/ta/tr/ur) with the English
/// fix content, destroying whatever genuine non-English translation had been
/// attached there by `tool/rebuild_muslim_translations.dart`.
///
/// This restores each affected record's ENTIRE `translations` block verbatim
/// from the pre-regression commit (`72a5b20^`), leaving `english.narrator`/
/// `english.text` (already correct) and `reference.text` (already restored)
/// untouched. Uses brace-counting to find each record's `translations` block
/// boundaries in both the original and current file, so no reformatting of
/// anything else in this tab-indented, CRLF file.
///
/// Usage: dart run tool/fix_muslim_translations_regression_2026_08_28.dart
void main() {
  const path = 'db/by_book/hadithunlocked/muslim.json';
  final currentLines = File(path).readAsStringSync().split('\r\n');

  final result = Process.runSync('git', [
    'show',
    '72a5b20^:db/by_book/hadithunlocked/muslim.json',
  ], workingDirectory: '.', stdoutEncoding: null);
  final originalContent = const Utf8Codec().decode(result.stdout as List<int>);
  final originalLines = originalContent.split('\n').map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l).toList();

  const ids = [2000942, 2000446, 2005506];

  for (final id in ids) {
    final origBlock = _translationsBlock(originalLines, id);
    if (origBlock == null) {
      stdout.writeln('id=$id: no translations block in ORIGINAL — nothing to restore, skipping.');
      continue;
    }
    final currBlock = _translationsBlock(currentLines, id);
    if (currBlock == null) {
      throw StateError('id=$id: no translations block found in CURRENT file');
    }

    final replacement = originalLines.sublist(origBlock.start, origBlock.end + 1);
    currentLines.replaceRange(currBlock.start, currBlock.end + 1, replacement);
    stdout.writeln(
      'id=$id: restored translations block '
      '(${currBlock.end - currBlock.start + 1} lines -> ${replacement.length} lines)',
    );
  }

  File(path).writeAsStringSync(currentLines.join('\r\n'));
  stdout.writeln('\n$path: done.');
}

class _Span {
  _Span(this.start, this.end);
  final int start;
  final int end;
}

/// Finds the `"translations": {` ... matching `}` line span for the record
/// whose `"id": <id>,` line appears in [lines], bounded so it can't bleed
/// into a sibling record.
_Span? _translationsBlock(List<String> lines, int id) {
  final idLine = '\t\t\t"id": $id,';
  final idIndex = lines.indexOf(idLine);
  if (idIndex == -1) throw StateError('could not find $idLine');

  var nextIdIndex = lines.length;
  for (var i = idIndex + 1; i < lines.length; i++) {
    if (lines[i].startsWith('\t\t\t"id": ')) {
      nextIdIndex = i;
      break;
    }
  }

  var startIndex = -1;
  for (var i = idIndex + 1; i < nextIdIndex; i++) {
    if (lines[i].contains('"translations": {')) {
      startIndex = i;
      break;
    }
  }
  if (startIndex == -1) return null;

  var depth = 0;
  for (var i = startIndex; i < nextIdIndex; i++) {
    depth += '{'.allMatches(lines[i]).length;
    depth -= '}'.allMatches(lines[i]).length;
    if (depth == 0) return _Span(startIndex, i);
  }
  throw StateError('unbalanced braces scanning translations block from line $startIndex');
}
