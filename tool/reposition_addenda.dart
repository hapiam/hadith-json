// STAGE: one-shot data-repair script, not part of the regular build loop.
// INPUT/OUTPUT: reads and rewrites in place whichever `db/by_book/
// the_9_books/*.json` file(s) are passed as args (or, with no args, every
// *.json directly under that directory) -- it's a targeted mutation of
// spine data, not a derived/generated artifact, so unlike db/unified/ its
// changes are meant to be committed.
//
// Gives every `appendedOriginal` (isAddendum) hadith a `sortKey` that places
// it immediately after the matched sibling its own old citation belongs
// next to (e.g. Bukhari 690b -> right after 690), instead of being
// tail-appended past the book's canonical count.
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
//
// TODO: as of the fawaz rebuild (see NUMBERING_CORRUPTION_AUDIT.md /
// README's "Why this repo was rebuilt around content-matching"),
// `rebuild_from_fawaz.dart` deliberately drops `isAddendum`/`sortKey`
// entirely for the 6 books it produces (fawaz's own sequential numbering
// has no gaps to work around) -- and as of this writing, none of the 9
// files under `db/by_book/the_9_books/` (checked directly: bukhari, muslim,
// nasai, abudawud, tirmidhi, ibnmajah, malik, darimi, ahmed all have zero
// `"appendedOriginal"` occurrences) currently have any addenda left for
// this script to act on at all. Running it today against every file in
// that directory is a full no-op (each file hits the early `if
// (repositioned == 0 && introCount == 0 && unparsed == 0) return;` and
// isn't even rewritten). This script is only still meaningful if a future
// book gets content-matched (not fawaz-rebuilt) and produces new
// `appendedOriginal` entries the old way -- otherwise it's dead weight
// against the current dataset and a candidate for removal or an explicit
// "superseded" note pointing here from the README.

import 'dart:convert';
import 'dart:io';

final _introRe = RegExp(r'Introduction\s+(\d+)\s*$');
final _numLetterRe = RegExp(r'(\d+)\s*([a-z])?(?:\s*,\s*[a-z])*\s*$');

void main(List<String> args) {
  final files = args.isNotEmpty
      ? args.map((a) => File(a)).toList()
      : Directory('db/by_book/the_9_books')
            .listSync()
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.json') && !f.path.endsWith('.min.json'),
            )
            .toList();

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

    // Introduction-section addenda cite as "Introduction N", not a book
    // hadith number at all -- there's no numbered sibling to slot next to,
    // so these sort before every real hadith (large negative offset) but
    // still in their own internal N order relative to each other.
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
      // first addendum slot, 'c' the second, etc. `base + 0.01 * rank`
      // keeps every lettered variant sorting strictly between `base` and
      // `base + 1` -- close enough to look "attached" in a hadith list
      // without colliding with any real idInBook. The `used` set + `while`
      // loop handles the rare case where two different addenda both parse
      // to the same nominal rank (e.g. a duplicate letter in the source
      // citation text) by bumping the second one to the next free slot
      // instead of overwriting the first's sortKey.
      var rank = letter.codeUnitAt(0) - 'a'.codeUnitAt(0) - 1;
      if (rank < 0) rank = 0;
      final used = letterSlotUsed.putIfAbsent('$base', () => {});
      while (used.contains(rank)) {
        rank++;
      }
      used.add(rank);
      sortKey = base + 0.01 * (rank + 1);
    } else {
      // No letter suffix at all (a bare cross-reference stub, e.g. "narrated
      // similarly") -- park it just past the midpoint (`base + 0.5`) rather
      // than in the `0.01`-`0.09`-ish lettered-variant band, so a real
      // lettered sibling and a same-base unlettered addendum never collide
      // even though they share the same integer `base`.
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
