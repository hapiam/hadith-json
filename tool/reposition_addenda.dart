// One-shot data-repair script: gives every `appendedOriginal` (isAddendum)
// hadith a `sortKey` that places it immediately after the matched sibling
// its own old citation belongs next to (e.g. Bukhari 690b -> right after
// 690), instead of being tail-appended past the book's canonical count.
// `idInBook` itself is left untouched -- it stays the addendum's stable
// identity (used for citation, potential bookmarking); `sortKey` is purely
// a display-order hint the app's hadith list query sorts by instead.
//
// Also aligns each addendum's `chapterId` to its new neighbor's, since it's
// now presented as sitting right next to it in the same passage.
//
// Run once per by_book source file that has appendedOriginal entries:
//   dart tool/reposition_addenda.dart db/by_book/the_9_books/bukhari.json
// (or with no args, runs against all 9 books under the_9_books/).

import 'dart:convert';
import 'dart:io';

final _introRe = RegExp(r'Introduction\s+(\d+)\s*$');
final _numLetterRe = RegExp(r'(\d+)\s*([a-z])?(?:\s*,\s*[a-z])*\s*$');

void main(List<String> args) {
  final files = args.isNotEmpty
      ? args.map((a) => File(a)).toList()
      : Directory(
          'db/by_book/the_9_books',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.json') && !f.path.endsWith('.min.json')).toList();

  for (final file in files) {
    _processFile(file);
  }
}

void _processFile(File file) {
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List).cast<Map<String, dynamic>>();

  // idInBook -> chapterId, for aligning addenda to their new neighbor.
  final chapterByIdInBook = <num, dynamic>{};
  for (final h in hadiths) {
    if (h['appendedOriginal'] == true) continue;
    final id = h['idInBook'];
    if (id is num) chapterByIdInBook[id] = h['chapterId'];
  }

  // Track how many addenda have already claimed each base, so entries that
  // share a base (multiple plain-number citations, or a repeated letter)
  // still land at distinct, deterministic sortKeys in file order.
  final letterSlotUsed = <String, Set<int>>{};
  final plainSlotCount = <num, int>{};
  var introCount = 0;
  var repositioned = 0;
  var unparsed = 0;

  for (final h in hadiths) {
    if (h['appendedOriginal'] != true) continue;
    final ref = (h['reference']?['text'] as String?) ?? '';

    final introMatch = _introRe.firstMatch(ref);
    if (introMatch != null) {
      final n = int.parse(introMatch.group(1)!);
      h['sortKey'] = -1000000.0 + n;
      introCount++;
      continue;
    }

    final m = _numLetterRe.firstMatch(ref);
    if (m == null) {
      unparsed++;
      stderr.writeln('  ! unparsed reference in ${file.path}: "$ref"');
      continue;
    }
    final base = num.parse(m.group(1)!);
    final letter = m.group(2);

    num sortKey;
    if (letter != null) {
      // 'a' is the matched sibling itself (already at `base`); 'b' is the
      // first addendum slot, 'c' the second, etc.
      var rank = letter.codeUnitAt(0) - 'a'.codeUnitAt(0) - 1;
      if (rank < 0) rank = 0;
      final used = letterSlotUsed.putIfAbsent('$base', () => {});
      while (used.contains(rank)) {
        rank++;
      }
      used.add(rank);
      sortKey = base + 0.01 * (rank + 1);
    } else {
      final slot = plainSlotCount.update(base, (v) => v + 1, ifAbsent: () => 1);
      sortKey = base + 0.5 + 0.001 * slot;
    }
    h['sortKey'] = sortKey;

    final neighborChapter = chapterByIdInBook[base];
    if (neighborChapter != null) {
      h['chapterId'] = neighborChapter;
    }
    repositioned++;
  }

  if (repositioned == 0 && introCount == 0 && unparsed == 0) return;

  file.writeAsStringSync(
    const JsonEncoder.withIndent('\t').convert(data) + '\n',
  );
  print(
    '${file.path}: repositioned=$repositioned intro=$introCount '
    'unparsed=$unparsed',
  );
}
