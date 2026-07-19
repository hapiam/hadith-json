import 'dart:convert';
import 'dart:io';

/// Scrapes amrayn.com for the 3 Phase-3 books it has independent coverage of
/// (Riyad as-Saliheen, Al-Adab Al-Mufrad, Shama'il al-Muhammadiya) -- these
/// have no fawazahmed0/hadith-api coverage, so this is their only available
/// paired-Arabic/English canonical source with real chapter/sub-chapter
/// structure and grading, matching sunnah.com's own citation numbering.
///
/// Respects robots.txt's `Crawl-delay: 5` for `User-agent: *` (amrayn.com/hadith
/// itself is not disallowed). Output is append-only JSONL per book, keyed by
/// idInBook, so the scrape is resumable after interruption -- re-running skips
/// ids already present in the output file.
///
/// Usage: dart run tool/scrape_amrayn.dart [bookKey ...]   (default: all 3)

class BookConfig {
  final String urlKey;
  final String outKey;
  final int count;
  const BookConfig(this.urlKey, this.outKey, this.count);
}

const books = [
  BookConfig('riyadussaliheen', 'riyad_assalihin', 1896),
  BookConfig('adab', 'aladab_almufrad', 1322),
  BookConfig('shamail', 'shamail_muhammadiyah', 398),
];

const delayBetweenRequests = Duration(seconds: 6);

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

  for (final book in wanted) {
    await scrapeBook(client, book, outDir);
  }
  client.close(force: true);
  print('All done.');
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

final _titleRe = RegExp(r'co-hadith__title-text-head">([^<]*)</h2>');
final _gradeRe = RegExp(r'co-hadith__grade ([a-zA-Z-]+)">([^<]*)</span>');
final _chapterRe = RegExp(
  r'pa-hadith__chapter" id="ch-(\d+)"[\s\S]*?class="arabic">\(<span class="pa-hadith__chapter-title-container-contents-arabic-numb">\d+</span>\) [–-] <!-- -->([\s\S]*?)</div><div>\(<!-- -->\d+<!-- -->\) [–-] <!-- -->([\s\S]*?)</div></div><a[^>]*class="pa-hadith__chapter-link" href="/([a-z]+)/(\d+)/ch-\d+"',
);
final _englishRe = RegExp(r'<p class="co-hadith__english-text">([\s\S]*?)</p></div>');
final _arabicRe = RegExp(r'<p class="co-hadith__arabic-text arabic">([\s\S]*?)</p></div>');

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

  return {
    'idInBook': n,
    'title': title,
    'chapter': chapter,
    'grades': grades,
    'englishRaw': cleanInlineHtml(englishHtml),
    'arabic': cleanInlineHtml(arabicHtml),
  };
}

/// Strips inline tags (keeping <br/> as \n, dropping <b>/</b> wrappers but
/// keeping their text) and decodes HTML entities.
String cleanInlineHtml(String s) {
  var out = s.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  out = out.replaceAll(RegExp(r'</?b>'), '');
  out = out.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  out = out.replaceAll(RegExp(r'<[^>]+>'), '');
  return unescapeHtml(out).trim();
}

String unescapeHtml(String s) {
  return s
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
