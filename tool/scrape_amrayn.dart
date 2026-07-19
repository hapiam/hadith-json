import 'dart:convert';
import 'dart:io';

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
/// Output is append-only JSONL per book, keyed by idInBook, so the scrape is
/// resumable after interruption -- re-running skips ids already present in the
/// output file. List order below is priority order (earlier = scraped first).
///
/// Usage: dart run tool/scrape_amrayn.dart [bookKey ...]   (default: all)

class BookConfig {
  final String urlKey;
  final String outKey;
  final int count;
  const BookConfig(this.urlKey, this.outKey, this.count);
}

const books = [
  // Phase-3 books with no other independent source -- highest priority.
  BookConfig('riyadussaliheen', 'riyad_assalihin', 1896),
  BookConfig('adab', 'aladab_almufrad', 1322),
  BookConfig('shamail', 'shamail_muhammadiyah', 398),
  // The 6 AhmedBaset-spine books already rebuilt from fawaz -- scrape as a
  // second, independent source to cross-check the rebuild against.
  BookConfig('bukhari', 'bukhari', 7076),
  BookConfig('muslim', 'muslim', 7190),
  BookConfig('nasai', 'nasai', 5758),
  BookConfig('abudawood', 'abudawud', 5274),
  BookConfig('tirmidhi', 'tirmidhi', 3956),
  BookConfig('ibnmajah', 'ibnmajah', 4340),
  // Phase-2 books, also fawaz-rebuilt -- same cross-check purpose.
  BookConfig('malik', 'malik', 1973),
  BookConfig('nawawi', 'nawawi40', 42),
  BookConfig('qudsi', 'qudsi40', 40),
  // Already independently rebuilt this session from mhashim6 -- lower priority,
  // still useful as a second opinion.
  BookConfig('darimi', 'darimi', 3546),
  // Not part of our current 18-book catalog -- amrayn-only bonus collections,
  // scraped last in case they're worth adding later.
  BookConfig('nasaikubra', 'nasai_kubra_bonus', 11949),
  BookConfig('hakim', 'mustadrak_alhakim_bonus', 8803),
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
    await scrapeAbout(client, book, aboutDir);
    await scrapeBook(client, book, outDir);
  }
  client.close(force: true);
  print('All done.');
}

Future<void> scrapeAbout(HttpClient client, BookConfig book, Directory aboutDir) async {
  final outFile = File('${aboutDir.path}/${book.outKey}.json');
  if (outFile.existsSync()) {
    print('${book.outKey}: about page already cached.');
    return;
  }
  final url = 'https://amrayn.com/${book.urlKey}/about';
  try {
    final html = await fetchHtml(client, url);
    final record = parseAboutPage(html, book);
    outFile.writeAsStringSync(const JsonEncoder.withIndent('\t').convert(record));
    print('${book.outKey}: about page saved.');
  } catch (e) {
    stderr.writeln('${book.outKey} about ERROR: $e');
  }
  await Future.delayed(delayBetweenRequests);
}

Future<void> scrapeBook(HttpClient client, BookConfig book, Directory outDir) async {
  final outFile = File('${outDir.path}/${book.outKey}.jsonl');
  final done = <int>{};
  if (outFile.existsSync()) {
    for (final line in outFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        done.add(obj['idInBook'] as int);
      } catch (_) {}
    }
  }
  print('${book.outKey}: ${done.length}/${book.count} already done, resuming.');

  final sink = outFile.openWrite(mode: FileMode.append);
  int okCount = 0, errCount = 0;
  for (var n = 1; n <= book.count; n++) {
    if (done.contains(n)) continue;
    final url = 'https://amrayn.com/${book.urlKey}:$n';
    Map<String, dynamic> record;
    try {
      final html = await fetchHtml(client, url);
      record = parseHadith(html, book, n);
      okCount++;
    } catch (e) {
      record = {'idInBook': n, 'error': e.toString()};
      errCount++;
      stderr.writeln('${book.outKey} $n ERROR: $e');
    }
    sink.writeln(jsonEncode(record));
    if (n % 25 == 0 || n == book.count) {
      print('${book.outKey}: $n/${book.count} (ok=$okCount err=$errCount)');
    }
    await Future.delayed(delayBetweenRequests);
  }
  await sink.flush();
  await sink.close();
  print('${book.outKey}: finished. ok=$okCount err=$errCount');
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
  final bytes = await resp.fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
  return utf8.decode(bytes, allowMalformed: true);
}

// ---- Server-rendered HTML fields (reliable, always present) ----

final _titleRe = RegExp(r'co-hadith__title-text-head">([^<]*)</h2>');
final _gradeRe = RegExp(r'co-hadith__grade ([a-zA-Z-]+)">([^<]*)</span>');
final _chapterRe = RegExp(
  r'pa-hadith__chapter" id="ch-(\d+)"[\s\S]*?class="arabic">\(<span class="pa-hadith__chapter-title-container-contents-arabic-numb">\d+</span>\) [–-] <!-- -->([\s\S]*?)</div><div>\(<!-- -->\d+<!-- -->\) [–-] <!-- -->([\s\S]*?)</div></div><a[^>]*class="pa-hadith__chapter-link" href="/([a-z]+)/(\d+)/ch-\d+"',
);
final _englishRe = RegExp(r'<p class="co-hadith__english-text">([\s\S]*?)</p></div>');
final _arabicRe = RegExp(r'<p class="co-hadith__arabic-text arabic">([\s\S]*?)</p></div>');
final _domIdRe = RegExp(r'"co-hadith" id="h(\d+)-(\d+)"');
final _boldRe = RegExp(r'<b>([\s\S]*?)</b>');

Map<String, dynamic> parseHadith(String html, BookConfig book, int n) {
  final flat = html.replaceAll('\r', '').replaceAll('\n', '');

  final titleMatch = _titleRe.firstMatch(flat);
  if (titleMatch == null) {
    throw Exception('title not found (page may be 404 or layout changed)');
  }
  final title = unescapeHtml(titleMatch.group(1)!.trim());

  final grades = _gradeRe
      .allMatches(flat)
      .map((m) => {'class': m.group(1), 'text': unescapeHtml(m.group(2)!.trim())})
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
  if (englishMatch == null || arabicMatch == null) {
    throw Exception('english/arabic text block not found');
  }
  final englishHtml = englishMatch.group(1)!;
  final arabicHtml = arabicMatch.group(1)!;

  // Checked directly against live pages (riyadussaliheen, adab, bukhari):
  // amrayn does not embed inline <a>/<span>/<em> markup for narrator names,
  // Quran quotes, or cross-references inside the hadith body -- it's plain
  // text with only <br/> line breaks. The one formatting signal that *does*
  // exist is an inconsistently-placed <b>...</b> wrapper (usually a trailing
  // "[Al-Bukhari and Muslim]"-style source note, but not always present and
  // not always last) -- captured here as its own list rather than assumed
  // to be a fixed trailing segment.
  final boldSegments = _boldRe
      .allMatches(englishHtml)
      .map((m) => cleanInlineHtml(m.group(1)!))
      .where((s) => s.isNotEmpty)
      .toList();

  final englishRaw = cleanInlineHtml(englishHtml);
  final narratorSplit = splitNarratorBody(englishRaw);

  final domIdMatch = _domIdRe.firstMatch(flat);
  final amraynSectionNum = domIdMatch != null ? int.tryParse(domIdMatch.group(1)!) : null;
  final amraynId = domIdMatch != null ? int.tryParse(domIdMatch.group(2)!) : null;

  final extra = extractEmbeddedFields(flat, n);

  return {
    'idInBook': n,
    'title': title,
    'chapter': chapter,
    'grades': grades,
    'englishRaw': englishRaw,
    'narrator': narratorSplit.$1,
    'body': narratorSplit.$2,
    'boldSegments': boldSegments,
    'arabic': cleanInlineHtml(arabicHtml),
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
(String?, String) splitNarratorBody(String text) {
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
  final scoped = flat.substring(anchor.start, (anchor.start + 4000).clamp(0, flat.length));

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
    'postscriptArabic': parseRawToken(extractRawField(scoped, 'postscriptArabic')),
    'hasExplanationAvailable': parseRawToken(extractRawField(scoped, 'hasExplanationAvailable')),
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
  return itemRe.allMatches(m.group(1)!).map((im) => unescapeJsonEscapes(im.group(1)!)).toList();
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
  final stripped = raw.replaceFirst(RegExp(r'^\\*"'), '').replaceFirst(RegExp(r'\\*"$'), '');
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
final _aboutBodyRe = RegExp(r'pa-article__post-contents-body">([\s\S]*?)footer__contents');

Map<String, dynamic> parseAboutPage(String html, BookConfig book) {
  final flat = html.replaceAll('\r', '').replaceAll('\n', '');
  final titleMatch = _aboutTitleRe.firstMatch(flat);
  final bodyMatch = _aboutBodyRe.firstMatch(flat);
  return {
    'urlKey': book.urlKey,
    'outKey': book.outKey,
    'pageTitle': titleMatch != null ? unescapeHtml(titleMatch.group(1)!.trim()) : null,
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
  return out.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
}
