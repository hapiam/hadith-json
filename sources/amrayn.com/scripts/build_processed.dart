/// STAGE: post-processing tool — turns the raw, append-only, mixed success/
/// error `scrape_amrayn.dart`/`scrape_amrayn_malik.dart` output into ONE
/// clean, deduplicated, properly-ordered JSON file per book: the "scrape
/// 1.0" results the user asked to maintain going forward — re-run this any
/// time the raw scrape gains new data, load the output straight into the
/// app, or diff it against `db/by_book/` for comparison.
///
/// INPUT: raw `{book}.jsonl` files under [sourceDir] — defaults to the
/// latest committed `runs/` snapshot (reproducible or that. Point it at
/// `db/scrape_cache/amrayn` instead to build from the live, gitignored
/// working copy while a scrape is actively running.
///
/// OUTPUT: `sources/amrayn.com/processed/{outKey}.json` — one JSON file per
/// book, shaped `{book, aboutAmrayn, hadithCount, hadiths: [...]}`.
/// `hadiths` keeps EVERY field the raw scrape captured, verbatim, even ones
/// the app never consumes (isnad chain, notes, postscript, tags,
/// cross-collection links, raw grade flag, etc.) — nothing is trimmed here.
///
/// Cleaning rules:
/// - Rows carrying an `error` key (failed fetch, or a stale flat-`/book:N`
///   attempt against a book that turned out to need citation discovery —
///   see [BookConfig.citationDiscovery] in `scrape_amrayn.dart`, and Malik's
///   own old-URL-scheme 404s) are dropped entirely.
/// - Remaining rows are deduplicated by identity — `citation` if present,
///   else `idInBook` — keeping the LAST successful write for that identity
///   (append-only log semantics: a later write is a correction/retry, never
///   older data winning over newer).
///
/// Ordering rules (this is the actual "proper chapter/hadith # order" the
/// raw jsonl does NOT have — it's written in fetch order, not book order):
/// - Malik: `(malikChapterNum, malikLocalHadithNum)` — its real citation
///   structure ("Book X, Hadith Y"); `idInBook` there is just this
///   scraper's own running counter, not a meaningful sort key.
/// - Every other book: `(idInBook, citation-letter-suffix)` — reduces to
///   plain `idInBook` ascending for the vast majority of rows (no lettered
///   citation), and threads lettered variants (`8`, `8a`, `8b`, `8d`...)
///   in immediately after their base number for the few that have them
///   (only Muslim has this in bulk; a handful of other citation-discovery
///   books have a few stray lettered rows too).
///
/// Usage: `dart run sources/amrayn.com/scripts/build_processed.dart [bookKey ...]`
/// (default: every book found under [sourceDir]).
library;

import 'dart:convert';
import 'dart:io';

const String sourceDir = 'sources/amrayn.com/runs/2026-07-24_full-catalog';
const String outDir = 'sources/amrayn.com/processed';

const List<String> allBooks = [
  'riyad_assalihin',
  'aladab_almufrad',
  'shamail_muhammadiyah',
  'bukhari',
  'muslim',
  'nasai',
  'abudawud',
  'tirmidhi',
  'ibnmajah',
  'malik',
  'nawawi40',
  'qudsi40',
  'darimi',
  'nasai_kubra_bonus',
  'mustadrak_alhakim_bonus',
];

void main(List<String> args) {
  final targets = args.isEmpty ? allBooks : args;
  Directory(outDir).createSync(recursive: true);
  for (final book in targets) {
    _process(book);
  }
}

void _process(String book) {
  final inFile = File('$sourceDir/$book.jsonl');
  if (!inFile.existsSync()) {
    stdout.writeln('$book: no $book.jsonl in $sourceDir, skipping');
    return;
  }

  final byKey = <String, Map<String, dynamic>>{};
  var errorRows = 0;
  var corruptLines = 0;
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(inFile.readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final Map<String, dynamic> row;
    try {
      row = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      corruptLines++;
      continue;
    }
    if (row.containsKey('error')) {
      errorRows++;
      continue;
    }
    final key = (row['citation'] as String?) ?? '${row['idInBook']}';
    byKey[key] = row; // last successful write for this identity wins
  }

  final records = byKey.values.toList();
  if (book == 'malik') {
    records.sort((a, b) {
      final ac = a['malikChapterNum'] as int? ?? 0;
      final bc = b['malikChapterNum'] as int? ?? 0;
      if (ac != bc) return ac.compareTo(bc);
      final al = a['malikLocalHadithNum'] as int? ?? 0;
      final bl = b['malikLocalHadithNum'] as int? ?? 0;
      return al.compareTo(bl);
    });
  } else {
    records.sort((a, b) {
      final ai = a['idInBook'] as int? ?? 0;
      final bi = b['idInBook'] as int? ?? 0;
      if (ai != bi) return ai.compareTo(bi);
      final asuf = _letterSuffix(a['citation'] as String?, ai);
      final bsuf = _letterSuffix(b['citation'] as String?, bi);
      return asuf.compareTo(bsuf);
    });
  }

  Map<String, dynamic>? about;
  final aboutFile = File('$sourceDir/about/$book.json');
  if (aboutFile.existsSync()) {
    about = jsonDecode(aboutFile.readAsStringSync()) as Map<String, dynamic>;
  }

  final outFile = File('$outDir/$book.json');
  final buf = StringBuffer();
  buf.write('{\n');
  buf.write('  "book": ${jsonEncode(book)},\n');
  buf.write('  "aboutAmrayn": ${about == null ? 'null' : jsonEncode(about)},\n');
  buf.write('  "hadithCount": ${records.length},\n');
  buf.write('  "hadiths": [\n');
  for (var i = 0; i < records.length; i++) {
    buf.write('    ');
    buf.write(jsonEncode(records[i]));
    buf.write(i < records.length - 1 ? ',\n' : '\n');
  }
  buf.write('  ]\n');
  buf.write('}\n');
  outFile.writeAsStringSync(buf.toString());

  stdout.writeln(
    '$book: ${records.length} hadiths written '
    '(dropped $errorRows error rows, $corruptLines corrupt lines) '
    '-> ${outFile.path}',
  );
}

/// The letter suffix after the numeric `idInBook` in a citation string
/// (e.g. `"8a"` with `idInBook` 8 -> `"a"`), or `''` when there's no
/// citation field at all (the common case: citation == idInBook, no letter
/// suffix ever existed for this hadith).
String _letterSuffix(String? citation, int idInBook) {
  if (citation == null) return '';
  final prefix = '$idInBook';
  return citation.startsWith(prefix)
      ? citation.substring(prefix.length)
      : citation;
}
