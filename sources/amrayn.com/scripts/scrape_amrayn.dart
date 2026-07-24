import 'dart:convert';
import 'dart:io';

/// STAGE: verification/second-source-gathering tool -- long-running (tens of
/// thousands of rate-limited requests), run standalone, independent of the
/// rebuild/build/report cycle. Its output is not currently consumed by
/// `rebuild_from_fawaz.dart`, `build_unified_editions.dart`, or any other
/// script in this repo -- it exists purely to accumulate an independent
/// second (or, for 3 books, *only*) source of Arabic/English/chapter/grade
/// data to manually or semi-automatically diff against what's already in
/// `db/by_book/` and `db/unified/`, the same role amrayn already served for
/// the fawaz-rebuild cross-checks documented in NUMBERING_CORRUPTION_AUDIT.md
/// (e.g. confirming Tirmidhi 2735 and the Ibn Majah cluster by direct content
/// comparison). Re-run any time to resume/extend the scrape; safe to run
/// concurrently with unrelated pipeline scripts since it never touches
/// `db/by_book/` or `db/unified/`.
///
/// INPUT: none from this repo -- fetches live HTML from amrayn.com.
///
/// OUTPUT: `db/scrape_cache/amrayn/{outKey}.jsonl` (one line per hadith,
/// append-only, resumable) and `db/scrape_cache/amrayn/about/{outKey}.json`
/// (one-shot per book, not re-fetched once cached). `db/scrape_cache/` is the
/// live, gitignored working copy a run reads/appends to while in progress —
/// see `sources/amrayn.com/runs/` (sibling of this script, one level up) for
/// dated, git-tracked archival snapshots taken at meaningful checkpoints, and
/// `sources/README.md` for the full per-source archive convention used across
/// every scrape source in this repo (not just amrayn.com).
///
/// Scrapes amrayn.com's full hadith catalog for cross-comparison against our
/// own by_book data. amrayn covers 15 of our books (all but mishkat_almasabih,
/// bulugh_almaram, hisn_almuslim, and shahwaliullah40/dehlawi) using the same
/// paired-Arabic/English structure with real chapter/sub-chapter breakdowns
/// and grading, matching sunnah.com's own citation numbering. For riyad_assalihin,
/// aladab_almufrad and shamail_muhammadiyah it's our *only* independent source
/// (no fawazahmed0/hadith-api coverage); for the rest it's a second opinion to
/// diff against the fawaz-direct rebuild.
///
/// Captures everything available per hadith page without executing JS: the
/// server-rendered text (Arabic, English, chapter, grade) plus every field in
/// the page's embedded React data payload (isnad chain, notes, postscript,
/// tags, cross-collection reference links, raw grade flag, etc). Also scrapes
/// each book's /about page (book + author info, combined on one page on this
/// site -- there is no separate author page).
///
/// Respects robots.txt's `Crawl-delay: 5` for `User-agent: *` (amrayn.com/hadith
/// itself is not disallowed) -- do not lower this without re-checking robots.txt.
///
/// Designed to survive lost internet / a killed process / a machine restart
/// with zero manual cleanup -- recovery is always just re-running the same
/// command:
/// - Output is append-only JSONL per book, keyed by idInBook. Every write is
///   flushed to disk immediately (not just at end-of-book), so a hard kill
///   loses at most the one in-flight record, never previously-written ones.
/// - On startup each book's file is rescanned; only rows that parsed as valid
///   JSON *and* have no `error` key count as done. Transient-failure rows
///   (network blip, timeout) are retried automatically on the next run rather
///   than being permanently skipped.
/// - Each hadith fetch gets up to 3 attempts with backoff before being logged
///   as an error, so a few-second internet hiccup doesn't even need a restart.
/// - One book failing outright doesn't stop the others in the same run.
/// - A book whose real citations aren't a flat `1..count` sequence (letter
///   variants, e.g. Muslim's `8a`/`8b`/`8d`/`8e`) sets `citationDiscovery:
///   true` on its [BookConfig]; [discoverCitations] crawls that book's
///   chapter-listing pages once (cached to `{outKey}.citations.json`
///   thereafter) to build the real fetch list instead of guessing integers.
/// - If [maxConsecutiveErrors] fetches in a row fail for any reason, the
///   process stops itself (`exit(3)`) rather than grinding through the rest
///   of the book logging the same failure -- surfaces for a human decision
///   instead of running unattended into a wall.
///
/// List order below is priority order (earlier = scraped first).
///
/// Usage: dart run tool/scrape_amrayn.dart [bookKey ...]   (default: all)

class BookConfig {
  final String urlKey;
  final String outKey;
  final int count;
  // True when the book's real per-hadith URLs aren't a flat `1..count`
  // sequence -- e.g. Muslim uses letter-suffixed variants (`muslim:8a`,
  // `muslim:8b`, `muslim:8d`, `muslim:8e`, with no `8c`) that only appear as
  // real hrefs on that hadith's chapter-listing page, never as a citation you
  // can derive by incrementing an integer. When true, [discoverCitations] is
  // used to build the real fetch list instead of `1..count`.
  final bool citationDiscovery;
  const BookConfig(
    this.urlKey,
    this.outKey,
    this.count, {
    this.citationDiscovery = false,
  });
}

const books = [
  // citationDiscovery is set on every book whose flat 1..count sweep left
  // gaps: the flat sweep can neither reach letter-suffixed citations
  // (muslim:8a) nor distinguish "number doesn't exist in amrayn's edition"
  // from "failure". Discovery enumerates the site's actual citation list, so
  // a completed discovery-mode run == 100% of what amrayn really has.
  // Books already at 100% from the flat sweep keep the cheap flat mode.
  //
  // Phase-3 books with no other independent source -- highest priority.
  BookConfig('riyadussaliheen', 'riyad_assalihin', 1896),
  BookConfig('adab', 'aladab_almufrad', 1322),
  BookConfig('shamail', 'shamail_muhammadiyah', 398, citationDiscovery: true),
  // The 6 AhmedBaset-spine books already rebuilt from fawaz -- scrape as a
  // second, independent source to cross-check the rebuild against.
  BookConfig('bukhari', 'bukhari', 7076, citationDiscovery: true),
  // Confirmed via live probe: amrayn's real Muslim citations include letter
  // variants (8a/8b/8d/8e, skipping 8c) not derivable by incrementing an
  // int -- this is why a plain 1..7190 sweep only ever reached ~40%.
  BookConfig('muslim', 'muslim', 7190, citationDiscovery: true),
  BookConfig('nasai', 'nasai', 5758, citationDiscovery: true),
  BookConfig('abudawood', 'abudawud', 5274),
  BookConfig('tirmidhi', 'tirmidhi', 3956, citationDiscovery: true),
  BookConfig('ibnmajah', 'ibnmajah', 4340, citationDiscovery: true),
  // Phase-2 books, also fawaz-rebuilt -- same cross-check purpose.
  BookConfig('malik', 'malik', 1973),
  BookConfig('nawawi', 'nawawi40', 42),
  BookConfig('qudsi', 'qudsi40', 40),
  // Already independently rebuilt this session from mhashim6 -- lower priority,
  // still useful as a second opinion.
  BookConfig('darimi', 'darimi', 3546),
  // Not part of our current 18-book catalog -- amrayn-only bonus collections,
  // scraped last in case they're worth adding later.
  BookConfig('nasaikubra', 'nasai_kubra_bonus', 11949, citationDiscovery: true),
  BookConfig('hakim', 'mustadrak_alhakim_bonus', 8803, citationDiscovery: true),
];

/// amrayn.com's robots.txt states `Crawl-delay: 5` for `User-agent: *` -- this
/// is the site's own stated rate limit for automated access, not a value we
/// should shrink below out of convenience, especially at full-catalog scale
/// (tens of thousands of requests). Kept at exactly that floor.
const delayBetweenRequests = Duration(seconds: 5);

Future<void> main(List<String> args) async {
  final wanted = args.isEmpty
      ? books
      : books.where((b) => args.contains(b.outKey)).toList();
  if (wanted.isEmpty) {
    stderr.writeln('No matching book keys in $args');
    exit(1);
  }

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
  final outDir = Directory('db/scrape_cache/amrayn');
  outDir.createSync(recursive: true);
  final aboutDir = Directory('db/scrape_cache/amrayn/about');
  aboutDir.createSync(recursive: true);

  for (final book in wanted) {
    try {
      await scrapeAbout(client, book, aboutDir);
      await scrapeBook(client, book, outDir);
    } catch (e) {
      // A failure here means something escaped the per-request try/catch
      // inside scrapeBook (e.g. disk full, file-handle error) -- log and
      // move on to the next book rather than losing the rest of the run.
      // Re-running the command later will resume this book correctly.
      stderr.writeln(
        '${book.outKey}: book-level failure, skipping for now: $e',
      );
    }
  }
  client.close(force: true);
  print('All done.');
}

Future<void> scrapeAbout(
  HttpClient client,
  BookConfig book,
  Directory aboutDir,
) async {
  final outFile = File('${aboutDir.path}/${book.outKey}.json');
  if (outFile.existsSync()) {
    print('${book.outKey}: about page already cached.');
    return;
  }
  final url = 'https://amrayn.com/${book.urlKey}/about';
  try {
    final html = await fetchHtmlWithRetry(client, url);
    final record = parseAboutPage(html, book);
    outFile.writeAsStringSync(
      const JsonEncoder.withIndent('\t').convert(record),
    );
    print('${book.outKey}: about page saved.');
  } catch (e) {
    stderr.writeln('${book.outKey} about ERROR: $e');
  }
  await Future.delayed(delayBetweenRequests);
}

/// Consecutive-error safety valve: if this many fetches in a row fail (any
/// error -- 404, timeout, layout change...), something is systemically wrong
/// (site block, dead citation scheme, structural change) and grinding through
/// the rest of the book would just log thousands more identical failures.
/// Stops this book's process and surfaces it for a human decision rather than
/// continuing silently -- a successful fetch resets the counter to 0.
const maxConsecutiveErrors = 10;

Future<void> scrapeBook(
  HttpClient client,
  BookConfig book,
  Directory outDir,
) async {
  final citations = book.citationDiscovery
      ? await discoverCitations(client, book, outDir)
      : List.generate(book.count, (i) => '${i + 1}');

  final outFile = File('${outDir.path}/${book.outKey}.jsonl');
  // Only rows that parsed cleanly *and* succeeded count as done -- a row
  // written after exhausting retries (see fetchHtmlWithRetry) carries an
  // `error` key and is deliberately left out, so it gets retried on the very
  // next run instead of being silently skipped forever. A truncated final
  // line (process killed mid-write, extremely unlikely now that every write
  // is flushed) fails jsonDecode and is likewise just treated as not-done.
  // Keyed by the `citation` string (not the numeric idInBook, which is not
  // unique for letter-suffixed books) -- old rows from before this field
  // existed fall back to their idInBook so prior progress isn't lost.
  final done = <String>{};
  if (outFile.existsSync()) {
    for (final line in outFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        if (obj.containsKey('error')) continue;
        final citation =
            obj['citation'] as String? ?? (obj['idInBook'] as int?)?.toString();
        if (citation != null) done.add(citation);
      } catch (_) {}
    }
  }
  print(
    '${book.outKey}: ${done.length}/${citations.length} already done, resuming.',
  );

  final sink = outFile.openWrite(mode: FileMode.append);
  int okCount = 0, errCount = 0, consecutiveErrors = 0;
  for (var i = 0; i < citations.length; i++) {
    final citation = citations[i];
    if (done.contains(citation)) continue;
    final url = 'https://amrayn.com/${book.urlKey}:$citation';
    Map<String, dynamic> record;
    try {
      final html = await fetchHtmlWithRetry(client, url);
      record = parseHadith(html, book, citation);
      okCount++;
      consecutiveErrors = 0;
    } catch (e) {
      record = {
        'idInBook': leadingInt(citation),
        'citation': citation,
        'error': e.toString(),
      };
      errCount++;
      consecutiveErrors++;
      stderr.writeln('${book.outKey} $citation ERROR: $e');
    }
    sink.writeln(jsonEncode(record));
    // Flush every write, not just at end-of-book: a killed process or crash
    // should lose at most the one record currently in flight.
    await sink.flush();
    if ((i + 1) % 25 == 0 || i == citations.length - 1) {
      print(
        '${book.outKey}: ${i + 1}/${citations.length} (ok=$okCount err=$errCount)',
      );
    }
    if (consecutiveErrors >= maxConsecutiveErrors) {
      await sink.close();
      stderr.writeln(
        '${book.outKey}: STOPPING -- $consecutiveErrors consecutive errors '
        '(last: "$citation" -> ${record['error']}). This needs a human look '
        '(site block, layout change, or a citation-scheme gap this script '
        "doesn't know about yet) -- not continuing automatically.",
      );
      exit(3);
    }
    await Future.delayed(delayBetweenRequests);
  }
  await sink.close();
  print('${book.outKey}: finished. ok=$okCount err=$errCount');
}

/// Extracts the leading integer from a citation like `"172"` or `"8a"` -- used
/// as the (non-unique, for letter-suffixed books) `idInBook` field, kept for
/// sort order and backward compatibility with rows written before citation
/// discovery existed.
int leadingInt(String citation) =>
    int.parse(RegExp(r'^\d+').firstMatch(citation)!.group(0)!);

/// Discovers the book's real per-hadith citation strings by crawling its
/// chapter-listing pages (`/{urlKey}/1`, `/{urlKey}/2`, ...) AND each
/// chapter's sub-chapter pages (`/{urlKey}/{ch}/ch-N`), harvesting every
/// `/{urlKey}:CITATION` href found on them, instead of assuming `1..count`
/// is a valid, complete sequence. The sub-chapter level is essential:
/// verified live (muslim chapter 1), a chapter's base page only
/// server-renders its FIRST sub-chapter's hadith links -- the rest of the
/// chapter's hadith are only linked from the individual `ch-*` pages, so a
/// single-level crawl silently finds only ~a quarter of the book. Cached to
/// `db/scrape_cache/amrayn/{outKey}.citations.json` after the first run --
/// the chapter structure doesn't change, so this never needs re-discovery.
Future<List<String>> discoverCitations(
  HttpClient client,
  BookConfig book,
  Directory outDir,
) async {
  final cacheFile = File('${outDir.path}/${book.outKey}.citations.json');
  if (cacheFile.existsSync()) {
    final citations = (jsonDecode(cacheFile.readAsStringSync()) as List)
        .cast<String>();
    print(
      '${book.outKey}: using cached citation list (${citations.length}).',
    );
    return citations;
  }

  print('${book.outKey}: discovering citations from chapter pages...');
  final mainHtml = await fetchHtmlWithRetry(
    client,
    'https://amrayn.com/${book.urlKey}',
  );
  await Future.delayed(delayBetweenRequests);
  final chapterRe = RegExp('href="/${book.urlKey}/(\\d+)"');
  final chapterNums = chapterRe
      .allMatches(mainHtml)
      .map((m) => int.parse(m.group(1)!))
      .toSet()
      .toList()
    ..sort();
  if (chapterNums.isEmpty) {
    throw Exception(
      'no chapter links found on /${book.urlKey} -- layout may have changed',
    );
  }

  final citationRe = RegExp('href="/${book.urlKey}:([0-9]+[a-z]?)"');
  final citations = <String>{};
  for (var ci = 0; ci < chapterNums.length; ci++) {
    final ch = chapterNums[ci];
    final html = await fetchHtmlWithRetry(
      client,
      'https://amrayn.com/${book.urlKey}/$ch',
    );
    citations.addAll(citationRe.allMatches(html).map((m) => m.group(1)!));
    await Future.delayed(delayBetweenRequests);

    // Second level: WALK this chapter's sub-chapter pages (`ch-1`, `ch-1b`,
    // `ch-2`, ...) with natural-404 termination, mirroring the dedicated
    // Malik script's chapter walk. The base page's own `ch-*` hrefs can't be
    // used as the list: only the first ~10 sub-chapters are server-rendered
    // there (the rest are client-side), which is exactly the truncation that
    // made the first Muslim discovery find 1,692 of the book. Sub-chapter
    // base numbers are contiguous, with occasional letter variants
    // (`ch-1b`, `ch-1c`) between them; a couple of consecutive missing base
    // numbers means past-the-end.
    var subCount = 0;
    var missesInARow = 0;
    for (var n = 1; n <= 500 && missesInARow < 3; n++) {
      final found = await _harvestSubPage(
        client,
        book,
        ch,
        'ch-$n',
        citationRe,
        citations,
      );
      if (!found) {
        missesInARow++;
        continue;
      }
      missesInARow = 0;
      subCount++;
      // Letter variants: `ch-{n}b`, `ch-{n}c`, ... (the bare `ch-{n}` is the
      // implicit "a"); stop at the first missing letter.
      for (var l = 'b'.codeUnitAt(0); l <= 'z'.codeUnitAt(0); l++) {
        final okL = await _harvestSubPage(
          client,
          book,
          ch,
          'ch-$n${String.fromCharCode(l)}',
          citationRe,
          citations,
        );
        if (!okL) break;
        subCount++;
      }
    }
    print(
      '${book.outKey}: chapter ${ci + 1}/${chapterNums.length} (#$ch, '
      '$subCount sub-chapters) -> ${citations.length} citations so far',
    );
  }

  final sorted = citations.toList()
    ..sort((a, b) {
      final cmp = leadingInt(a).compareTo(leadingInt(b));
      return cmp != 0 ? cmp : a.compareTo(b);
    });
  cacheFile.writeAsStringSync(
    const JsonEncoder.withIndent('\t').convert(sorted),
  );
  print('${book.outKey}: discovered ${sorted.length} citations, cached.');
  return sorted;
}

/// Fetches one sub-chapter page during [discoverCitations]' walk and adds
/// its hadith citations to [citations]. Returns false on a genuine 404
/// (the walk's past-the-end signal). A persistent non-404 failure (network
/// outage outlasting fetchHtmlWithRetry's attempts) is rethrown rather than
/// silently treated as end-of-chapter -- truncating discovery there would
/// bake an incomplete citation list into the cache.
Future<bool> _harvestSubPage(
  HttpClient client,
  BookConfig book,
  int chapter,
  String sub,
  RegExp citationRe,
  Set<String> citations,
) async {
  try {
    final html = await fetchHtmlWithRetry(
      client,
      'https://amrayn.com/${book.urlKey}/$chapter/$sub',
    );
    citations.addAll(citationRe.allMatches(html).map((m) => m.group(1)!));
    await Future.delayed(delayBetweenRequests);
    return true;
  } catch (e) {
    if (e.toString().contains('HTTP 404')) {
      await Future.delayed(delayBetweenRequests);
      return false;
    }
    rethrow;
  }
}

/// Up to 3 attempts with backoff (5s, 10s) before giving up -- absorbs brief
/// internet drops/timeouts without needing a full restart. A real 404 (page
/// genuinely doesn't exist) is not worth retrying, so it fails fast.
Future<String> fetchHtmlWithRetry(
  HttpClient client,
  String url, {
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fetchHtml(client, url);
    } catch (e) {
      lastError = e;
      if (e.toString().contains('HTTP 404')) break;
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: 5 * attempt));
      }
    }
  }
  throw lastError!;
}

Future<String> fetchHtml(HttpClient client, String url) async {
  final req = await client.getUrl(Uri.parse(url));
  req.headers.set(
    'User-Agent',
    'Mozilla/5.0 (compatible; hapi-hadith-research/1.0; contact: htezcane@gmail.com)',
  );
  final resp = await req.close();
  if (resp.statusCode != 200) {
    // Drain the body so the connection can be reused/closed cleanly.
    await resp.drain<void>();
    throw Exception('HTTP ${resp.statusCode}');
  }
  final bytes = await resp.fold<List<int>>(
    <int>[],
    (acc, chunk) => acc..addAll(chunk),
  );
  return utf8.decode(bytes, allowMalformed: true);
}

// ---- Server-rendered HTML fields (reliable, always present) ----

// Most books wrap this in <h2>, but shamail_muhammadiyah's page layout uses
// <h1> for the same element -- matched via a class-tag-neutral `[^<]*<` so
// this doesn't care which heading level a given book happens to use.
final _titleRe = RegExp(r'co-hadith__title-text-head">([^<]*)<');
final _gradeRe = RegExp(r'co-hadith__grade ([a-zA-Z-]+)">([^<]*)</span>');
final _chapterRe = RegExp(
  r'pa-hadith__chapter" id="ch-(\d+)"[\s\S]*?class="arabic">\(<span class="pa-hadith__chapter-title-container-contents-arabic-numb">\d+</span>\) [–-] <!-- -->([\s\S]*?)</div><div>\(<!-- -->\d+<!-- -->\) [–-] <!-- -->([\s\S]*?)</div></div><a[^>]*class="pa-hadith__chapter-link" href="/([a-z]+)/(\d+)/ch-\d+"',
);
final _englishRe = RegExp(
  r'<p class="co-hadith__english-text">([\s\S]*?)</p></div>',
);
final _arabicRe = RegExp(
  r'<p class="co-hadith__arabic-text arabic">([\s\S]*?)</p></div>',
);
final _domIdRe = RegExp(r'"co-hadith" id="h(\d+)-(\d+)"');
final _boldRe = RegExp(r'<b>([\s\S]*?)</b>');

Map<String, dynamic> parseHadith(String html, BookConfig book, String citation) {
  final n = leadingInt(citation);
  final flat = html.replaceAll('\r', '').replaceAll('\n', '');

  final titleMatch = _titleRe.firstMatch(flat);
  if (titleMatch == null) {
    throw Exception('title not found (page may be 404 or layout changed)');
  }
  final title = unescapeHtml(titleMatch.group(1)!.trim());

  final grades = _gradeRe
      .allMatches(flat)
      .map(
        (m) => {'class': m.group(1), 'text': unescapeHtml(m.group(2)!.trim())},
      )
      .toList();

  final chapterMatch = _chapterRe.firstMatch(flat);
  Map<String, dynamic>? chapter;
  if (chapterMatch != null) {
    chapter = {
      'chapterNum': int.parse(chapterMatch.group(1)!),
      'arabicTitle': unescapeHtml(chapterMatch.group(2)!.trim()),
      'englishTitle': unescapeHtml(chapterMatch.group(3)!.trim()),
      'sectionNum': int.parse(chapterMatch.group(5)!),
    };
  }

  final englishMatch = _englishRe.firstMatch(flat);
  final arabicMatch = _arabicRe.firstMatch(flat);
  // Confirmed directly against a live page (malik ch5/13): some hadith on
  // amrayn genuinely only have one of the two languages, not both -- e.g. an
  // English-only entry with zero Arabic paragraphs anywhere on the page, not
  // a parsing failure. Only a page with *neither* block is a real problem
  // (title matched above, so this isn't a 404 -- more likely a layout this
  // script hasn't seen yet), worth still throwing on so it surfaces instead
  // of silently writing an empty record.
  if (englishMatch == null && arabicMatch == null) {
    throw Exception('neither english nor arabic text block found');
  }
  final englishHtml = englishMatch?.group(1);
  final arabicHtml = arabicMatch?.group(1);

  // Checked directly against live pages (riyadussaliheen, adab, bukhari):
  // amrayn does not embed inline <a>/<span>/<em> markup for narrator names,
  // Quran quotes, or cross-references inside the hadith body -- it's plain
  // text with only <br/> line breaks. The one formatting signal that *does*
  // exist is an inconsistently-placed <b>...</b> wrapper (usually a trailing
  // "[Al-Bukhari and Muslim]"-style source note, but not always present and
  // not always last) -- captured here as its own list rather than assumed
  // to be a fixed trailing segment.
  final boldSegments = englishHtml == null
      ? const <String>[]
      : _boldRe
            .allMatches(englishHtml)
            .map((m) => cleanInlineHtml(m.group(1)!))
            .where((s) => s.isNotEmpty)
            .toList();

  final englishRaw = englishHtml == null ? null : cleanInlineHtml(englishHtml);
  final narratorSplit = englishRaw == null
      ? (null, null)
      : splitNarratorBody(englishRaw);

  final domIdMatch = _domIdRe.firstMatch(flat);
  final amraynSectionNum = domIdMatch != null
      ? int.tryParse(domIdMatch.group(1)!)
      : null;
  final amraynId = domIdMatch != null
      ? int.tryParse(domIdMatch.group(2)!)
      : null;

  final extra = extractEmbeddedFields(flat, n);

  return {
    'idInBook': n,
    'citation': citation,
    'title': title,
    'chapter': chapter,
    'grades': grades,
    'englishRaw': englishRaw,
    'narrator': narratorSplit.$1,
    'body': narratorSplit.$2,
    'boldSegments': boldSegments,
    'arabic': arabicHtml == null ? null : cleanInlineHtml(arabicHtml),
    'amraynSectionNum': amraynSectionNum,
    'amraynId': amraynId,
    ...extra,
  };
}

/// Splits amrayn's English text into (narrator, body) when the first line
/// (up to the first line break) reads as a narrator attribution -- i.e. it
/// ends with a colon, matching the site's own "Narrated X (...):\n<body>"
/// convention. Returns (null, fullText) when no such lead-in is present
/// (some hadith open directly with the report, no separate attribution line).
(String?, String?) splitNarratorBody(String text) {
  final idx = text.indexOf('\n');
  if (idx == -1) return (null, text);
  final firstLine = text.substring(0, idx).trimRight();
  if (firstLine.isNotEmpty && firstLine.endsWith(':')) {
    return (firstLine, text.substring(idx + 1).trimLeft());
  }
  return (null, text);
}

/// Extracts every remaining field from the hadith's own embedded React data
/// payload (present in the raw HTML even without executing JS, though escaped
/// as a JSON string inside a JS string literal at a variable nesting depth).
/// Scoped to a window starting at this hadith's own `hadithNumber` value so
/// common key names (id, links, notes...) that also appear elsewhere on the
/// page (nav menus, breadcrumbs) aren't mistakenly matched.
Map<String, dynamic> extractEmbeddedFields(String flat, int n) {
  final anchorRe = RegExp('\\\\*"hadithNumber\\\\*"\\s*:\\s*\\\\*"$n\\\\*"');
  final anchor = anchorRe.firstMatch(flat);
  if (anchor == null) {
    return {
      'bookNumber': null,
      'gradeFlag': null,
      'notes': null,
      'notesArabic': null,
      'postscript': null,
      'postscriptArabic': null,
      'hasExplanationAvailable': null,
      'chain': null,
      'chainArabic': null,
      'references': const [],
      'intlRef': null,
      'tags': const [],
      'links': const [],
    };
  }
  final scoped = flat.substring(
    anchor.start,
    (anchor.start + 4000).clamp(0, flat.length),
  );

  final linksRe = RegExp('\\\\*"links\\\\*"\\s*:\\s*\\[(.*?)\\]');
  final linkItemRe = RegExp(
    '\\\\*"link\\\\*"\\s*:\\s*\\\\*"(.*?)\\\\*"\\s*,\\s*\\\\*"label\\\\*"\\s*:\\s*\\\\*"(.*?)\\\\*"',
  );
  final linksMatch = linksRe.firstMatch(scoped);
  final links = <Map<String, String>>[];
  if (linksMatch != null) {
    for (final im in linkItemRe.allMatches(linksMatch.group(1)!)) {
      links.add({
        'link': unescapeJsonEscapes(im.group(1)!),
        'label': unescapeJsonEscapes(im.group(2)!),
      });
    }
  }

  return {
    'bookNumber': parseRawToken(extractRawField(scoped, 'bookNumber')),
    'gradeFlag': parseRawToken(extractRawField(scoped, 'gradeFlag')),
    'notes': parseRawToken(extractRawField(scoped, 'notes')),
    'notesArabic': parseRawToken(extractRawField(scoped, 'notesArabic')),
    'postscript': parseRawToken(extractRawField(scoped, 'postscript')),
    'postscriptArabic': parseRawToken(
      extractRawField(scoped, 'postscriptArabic'),
    ),
    'hasExplanationAvailable': parseRawToken(
      extractRawField(scoped, 'hasExplanationAvailable'),
    ),
    'chain': parseRawToken(extractRawField(scoped, 'chain')),
    'chainArabic': parseRawToken(extractRawField(scoped, 'chainArabic')),
    'references': extractStringArrayField(scoped, 'references'),
    'intlRef': parseRawToken(extractRawField(scoped, 'intlRef')),
    'tags': extractStringArrayField(scoped, 'tags'),
    'links': links,
  };
}

/// Matches a JSON-like scalar value (string/null/bool/number) for `key` at
/// variable backslash-escaping depth, tolerant of escaped quotes inside string
/// values (e.g. isnad text containing a quoted phrase).
String? extractRawField(String s, String key) {
  final re = RegExp(
    '\\\\*"$key\\\\*"\\s*:\\s*(null|true|false|-?\\d+(?:\\.\\d+)?|\\\\*"(?:[^"\\\\]|\\\\.)*?\\\\*")',
  );
  return re.firstMatch(s)?.group(1);
}

List<String> extractStringArrayField(String s, String key) {
  final re = RegExp('\\\\*"$key\\\\*"\\s*:\\s*\\[(.*?)\\]');
  final m = re.firstMatch(s);
  if (m == null || m.group(1)!.trim().isEmpty) return [];
  final itemRe = RegExp('\\\\*"((?:[^"\\\\]|\\\\.)*?)\\\\*"');
  return itemRe
      .allMatches(m.group(1)!)
      .map((im) => unescapeJsonEscapes(im.group(1)!))
      .toList();
}

/// Converts a raw matched token (from [extractRawField]) into a real Dart
/// value: null/bool/num pass through, quoted strings get their envelope
/// stripped and inner escapes decoded.
dynamic parseRawToken(String? raw) {
  if (raw == null || raw == 'null') return null;
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  final numVal = num.tryParse(raw);
  if (numVal != null) return numVal;
  // Quoted string: strip the (possibly multi-backslash) leading/trailing quote envelope.
  final stripped = raw
      .replaceFirst(RegExp(r'^\\*"'), '')
      .replaceFirst(RegExp(r'\\*"$'), '');
  final unescaped = unescapeJsonEscapes(stripped);
  return unescaped.isEmpty ? null : unescaped;
}

/// Iteratively collapses backslash-escape sequences (`\"`, `\\`, `\n`, `\t`)
/// left over after stripping the outer envelope -- the payload is JSON nested
/// inside a JS string literal, so escaping depth varies by field and context.
String unescapeJsonEscapes(String s) {
  var prev = s;
  for (var i = 0; i < 4; i++) {
    final next = prev
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
    if (next == prev) break;
    prev = next;
  }
  return unescapeHtml(prev);
}

// ---- Book "about" pages (book + author info combined on one page) ----

final _aboutTitleRe = RegExp(r'<title>([^<]*)</title>');
final _aboutBodyRe = RegExp(
  r'pa-article__post-contents-body">([\s\S]*?)footer__contents',
);

Map<String, dynamic> parseAboutPage(String html, BookConfig book) {
  final flat = html.replaceAll('\r', '').replaceAll('\n', '');
  final titleMatch = _aboutTitleRe.firstMatch(flat);
  final bodyMatch = _aboutBodyRe.firstMatch(flat);
  return {
    'urlKey': book.urlKey,
    'outKey': book.outKey,
    'pageTitle': titleMatch != null
        ? unescapeHtml(titleMatch.group(1)!.trim())
        : null,
    'bodyText': bodyMatch != null ? cleanInlineHtml(bodyMatch.group(1)!) : null,
  };
}

// ---- Shared helpers ----

/// Strips inline tags (keeping <br/> as \n, dropping <b>/</b> wrappers but
/// keeping their text) and decodes HTML entities.
String cleanInlineHtml(String s) {
  var out = s.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  out = out.replaceAll(RegExp(r'</?[bp]>'), '\n');
  out = out.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  out = out.replaceAll(RegExp(r'<[^>]+>'), '');
  // A capture window can end mid-tag, leaving a dangling unmatched "<" with no
  // closing ">" -- drop everything from that point on (it's boundary noise).
  final danglingIdx = out.indexOf('<');
  if (danglingIdx != -1) out = out.substring(0, danglingIdx);
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return unescapeHtml(out).trim();
}

final _numericEntityRe = RegExp(r'&#(x?[0-9a-fA-F]+);');

String unescapeHtml(String s) {
  var out = s
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&hellip;', '…')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&nbsp;', ' ');
  // Generic numeric character references (&#8217; / &#x2019;), must run before
  // &amp;/&lt;/&gt; so a literal "&#38;"-style escaped ampersand doesn't get
  // double-unescaped.
  out = out.replaceAllMapped(_numericEntityRe, (m) {
    final code = m.group(1)!;
    final value = code.startsWith('x') || code.startsWith('X')
        ? int.tryParse(code.substring(1), radix: 16)
        : int.tryParse(code);
    return value != null ? String.fromCharCode(value) : m.group(0)!;
  });
  return out
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
