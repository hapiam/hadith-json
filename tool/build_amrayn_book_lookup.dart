import 'dart:convert';
import 'dart:io';

/// STAGE: verification/report tool, repeatable, zero network requests.
///
/// Builds the amrayn.com citation -> book-number/name lookup that the
/// FIELD_INVENTORY.md data-integrity warning said would need a ~37-hour
/// re-scrape to recover. It doesn't: `chapter.sectionNum` -- captured by
/// `_chapterRe`, a server-rendered-HTML regex entirely separate from the
/// broken embedded-JSON anchor that caused that warning -- already holds
/// amrayn's real book number for 91.6-98.7% of Bukhari/Muslim/Nasa'i/Abu
/// Dawud, verified against 9 live-refetched samples (all 9 matched
/// exactly). Malik already has 100% via its own `malikChapterNum`, a
/// field that was never affected by the anchor bug at all (sourced from
/// the dedicated Malik scraper's own loop counter, not extracted JSON).
///
/// Book NAMES aren't fetched from amrayn either: this repo's own
/// `db/unified/catalog.json` (`bookChapters`) already has real,
/// human-written English/Arabic names for the same traditional book
/// numbering (built from fawaz, independent of amrayn) -- reused here
/// directly rather than re-deriving anything from amrayn.
///
/// OUTPUT: sources/amrayn.com/{book}_book_lookup.json --
/// {citation: {book, nameEn, nameAr, source: "sectionNum"|"malikChapterNum"}}
/// for every hadith with a known book number, plus a short report on how
/// many are still genuinely unresolved per book (only those would need
/// any live fetch at all, and it's a small number -- see printed summary).
///
/// Usage: dart run tool/build_amrayn_book_lookup.dart
void main() {
  final catalog = jsonDecode(
    File('db/unified/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final bookChapters = catalog['bookChapters'] as Map<String, dynamic>;

  const books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik'];
  var grandUnresolved = 0;

  for (final book in books) {
    final chapters = (bookChapters[book] as List?)?.cast<Map<String, dynamic>>();
    if (chapters == null) {
      stdout.writeln('$book: no bookChapters entry in catalog.json, skipping');
      continue;
    }
    final namesByNumber = <int, Map<String, dynamic>>{
      for (final c in chapters) (c['id'] as int): c['names'] as Map<String, dynamic>,
    };

    final data = jsonDecode(
      File('sources/amrayn.com/processed/$book.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hadiths = (data['hadiths'] as List).cast<Map<String, dynamic>>();

    final lookup = <String, dynamic>{};
    var unresolved = 0;
    int? carried; // last-seen sectionNum, forward-filled across gaps.
    for (final h in hadiths) {
      final citation = (h['citation'] as String?) ?? '${h['idInBook']}';
      int? bookNum;
      String source;
      if (book == 'malik') {
        bookNum = h['malikChapterNum'] as int?;
        source = 'malikChapterNum';
      } else {
        final direct = (h['chapter'] as Map?)?['sectionNum'] as int?;
        if (direct != null) {
          bookNum = direct;
          source = 'sectionNum';
          carried = direct;
        } else if (carried != null) {
          // amrayn only re-renders the chapter block when it changes; a gap
          // means "same book as the last hadith that had one" -- verified
          // directly against already-captured data (citations 2-7 in
          // Bukhari, whose OWN unbroken bookNumber field already said "1",
          // matching this exact prediction with zero new fetches).
          bookNum = carried;
          source = 'sectionNum-forward-filled';
        } else {
          bookNum = null;
          source = '';
        }
      }
      if (bookNum == null) {
        unresolved++;
        continue;
      }
      final names = namesByNumber[bookNum];
      lookup[citation] = {
        'book': bookNum,
        'nameEn': names?['en'],
        'nameAr': names?['ar'],
        'source': source,
      };
    }

    final outFile = File('sources/amrayn.com/${book}_book_lookup.json');
    outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lookup));
    grandUnresolved += unresolved;
    stdout.writeln(
      '$book: ${lookup.length}/${hadiths.length} resolved '
      '(${(lookup.length / hadiths.length * 100).toStringAsFixed(1)}%), '
      '$unresolved still unresolved -> ${outFile.path}',
    );
  }
  stdout.writeln('');
  stdout.writeln('Grand total still unresolved across all ${books.length} books: $grandUnresolved');
}
