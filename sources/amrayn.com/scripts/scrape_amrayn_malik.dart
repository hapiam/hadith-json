import 'dart:convert';
import 'dart:io';

import 'scrape_amrayn.dart' as core;

/// STAGE: dedicated scraper for Muwatta Imam Malik. amrayn.com's URL scheme
/// for this one book differs from every other book `scrape_amrayn.dart`
/// covers: individual hadith live at `/malik/{chapter}/{hadithInChapter}`
/// (chapter-local numbering -- matching how the Muwatta is traditionally
/// cited, "Book X, Hadith Y"), not the flat `/malik:N` scheme every other
/// amrayn.com book uses. Confirmed directly against the live site: `/malik:1`
/// through `/malik:175` all 404, while `/malik/1/1` through `/malik/1/31`
/// (chapter 1's 31 hadith) all resolve fine.
///
/// Reuses every HTML-parsing helper from `scrape_amrayn.dart` (they only
/// need an HTML string, not a URL scheme) -- only the URL construction and
/// the idInBook <-> chapter/local-number mapping are new here.
///
/// INPUT: none from this repo -- fetches live HTML from amrayn.com. Per
/// chapter, hadith are fetched at local number 1, 2, 3... until a genuine
/// HTTP 404 (confirmed: `/malik/{ch}/{n}` pages are fully server-rendered,
/// so a 404 reliably means "past the last hadith in this chapter" -- no
/// separate chapter-count discovery step needed; an earlier attempt at that
/// via the chapter-landing page's "N ahādīth" badge failed because that
/// badge is client-side-rendered and absent from the raw HTML this script
/// actually receives).
///
/// OUTPUT: the same file the main script would have used for this book --
/// `db/scrape_cache/amrayn/malik.jsonl` -- so this is a drop-in continuation
/// of that book's entry, not a separate data island. Records carry two extra
/// fields beyond the usual shape: `malikChapterNum`/`malikLocalHadithNum`.
///
/// Respects the same `Crawl-delay: 5` as the main script for every request.
///
/// Usage: dart run sources/amrayn.com/scripts/scrape_amrayn_malik.dart
const _urlKey = 'malik';
const _outKey = 'malik';
const _totalCount = 1973; // must match BookConfig('malik', ...) in scrape_amrayn.dart
const _chapterCount = 61;
// Safety valve only -- no real chapter should ever need this many local
// hadith numbers; stops a genuinely broken chapter from looping forever.
const _maxLocalPerChapter = 150;

Future<void> main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
  final outDir = Directory('db/scrape_cache/amrayn');
  outDir.createSync(recursive: true);
  final outFile = File('${outDir.path}/$_outKey.jsonl');

  // Resume support: a previously-written record carries the chapter/local
  // position it came from, so "already done" is keyed by (chapter, local),
  // not by idInBook -- idInBook itself is only assigned once, in the single
  // forward pass below, so it can't be recovered standalone from a partial
  // prior run without replaying the same chapter-by-chapter walk anyway.
  final done = <String>{};
  if (outFile.existsSync()) {
    for (final line in outFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        if (obj.containsKey('error')) continue;
        if (obj['malikChapterNum'] == null) continue; // stale non-malik-scheme row from an earlier failed attempt
        done.add('${obj['malikChapterNum']}/${obj['malikLocalHadithNum']}');
      } catch (_) {}
    }
  }
  print('malik: ${done.length} entries already done, resuming.');

  final book = core.BookConfig(_urlKey, _outKey, _totalCount);
  final sink = outFile.openWrite(mode: FileMode.append);
  var idInBook = 0;
  var okCount = 0, errCount = 0;
  for (var ch = 1; ch <= _chapterCount; ch++) {
    for (var localN = 1; localN <= _maxLocalPerChapter; localN++) {
      idInBook++;
      final key = '$ch/$localN';
      if (done.contains(key)) continue;
      final url = 'https://amrayn.com/$_urlKey/$ch/$localN';
      Map<String, dynamic> record;
      try {
        final html = await core.fetchHtmlWithRetry(client, url);
        record = core.parseHadith(html, book, idInBook);
        record['malikChapterNum'] = ch;
        record['malikLocalHadithNum'] = localN;
        okCount++;
      } catch (e) {
        final is404 = e.toString().contains('HTTP 404');
        if (is404) {
          // Past the last hadith in this chapter -- not a real error, just
          // the natural end-of-chapter signal. Don't record it, don't count
          // it, and this idInBook slot is unused (the next chapter's first
          // hadith reuses it).
          idInBook--;
          break;
        }
        record = {
          'idInBook': idInBook,
          'malikChapterNum': ch,
          'malikLocalHadithNum': localN,
          'error': e.toString(),
        };
        errCount++;
        stderr.writeln('malik ch$ch/$localN (idInBook=$idInBook) ERROR: $e');
        sink.writeln(jsonEncode(record));
        await sink.flush();
        await Future.delayed(core.delayBetweenRequests);
        continue;
      }
      sink.writeln(jsonEncode(record));
      await sink.flush();
      if (okCount % 25 == 0) {
        print('malik: ch$ch/$localN, idInBook=$idInBook (ok=$okCount err=$errCount)');
      }
      await Future.delayed(core.delayBetweenRequests);
    }
  }
  await sink.close();
  print('malik: finished. ok=$okCount err=$errCount, final idInBook=$idInBook (expected ~$_totalCount)');
  client.close(force: true);
}
