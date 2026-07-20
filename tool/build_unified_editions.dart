import 'dart:convert';
import 'dart:io';

/// STAGE: repeatable build step -- the last thing you run after any upstream
/// data change (a `rebuild_from_fawaz.dart` run, a manual spine edit, a new
/// fawaz edition drop, an amrayn/al-hadees.com re-scrape). Safe to re-run at
/// any time; it always wipes and fully regenerates `db/unified/` rather than
/// patching it incrementally, so there's no stale-merge risk.
///
/// INPUTS (per book, see the `books` list below for which files each
/// `BookDef` points at):
/// - `db/by_book/{the_9_books|forties|other_books}/{book}.json` -- the
///   "spine": structure, Arabic, English narrator/text, chapters, grade,
///   reference. For the 10 books already migrated onto fawaz's own numbering
///   (bukhari/muslim/abudawud/tirmidhi/nasai/ibnmajah/malik/nawawi40/qudsi40/
///   shahwaliullah40), this file **is** `rebuild_from_fawaz.dart`'s output,
///   not the original AhmedBaset data -- this script doesn't know or care
///   which; it just reads whatever's currently checked in as the spine.
/// - `db/editions/files/{lang}-{book}.min.json` -- fawaz's cached per-
///   language editions, joined onto the spine by `_joinFawazLanguage` below
///   (non-English translations + multi-grader grades; English text itself
///   always comes from the spine, never from here).
/// - `db/by_locale/id/by_book/...` -- sagad's Indonesian drafts, used only
///   for books fawaz has no `ind-*` edition for.
///
/// OUTPUTS: `db/unified/catalog.json` (+ `.min.json`), one `files/{lang}-
/// {book}.json` (+ `.min.json`) edition per language x book, `by_book/
/// {bookKey}.json` (+ `.min.json`) master files with every language's
/// translation on each hadith, `REPORT.md` (build provenance + fawaz<->spine
/// match rates), `MATRIX.md` (language x book coverage), and zipped mirror
/// artifacts under `hapiam_mirror_hadith/` for the CDN backup mirror.
/// `DATA_QUALITY_REPORT.md` is a *separate* output, written by
/// `gen_data_quality_report.dart` from this script's `by_book/` output, not
/// by this script itself.
///
/// WHY it matters that `_joinFawazLanguage` joins by `hadithnumber` against
/// the spine's own `idInBook`: for the 10 fawaz-rebuilt books that join is
/// correct *by construction* (idInBook was set directly from fawaz's own
/// hadithnumber upstream), but for the remaining 8 books it still depends on
/// the spine's `idInBook` actually lining up with fawaz's sequential
/// numbering -- see README's "Why this repo was rebuilt around content-
/// matching" section for the Bukhari idInBook=7277 case that proved a naive
/// version of this same assumption false at scale.
///
/// Usage: dart run tool/build_unified_editions.dart [repoRoot]
void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args[0] : '.');
  final builder = UnifiedBuilder(root);
  builder.run();
}

/// Static per-book config: where its spine file lives, its display title,
/// and (if it has one) the fawaz edition key + sunnah.com URL slug used to
/// look up translations/grades and reconstruct citations. `fawazBook == null`
/// means this book has no fawaz coverage at all (riyadussalihin, mishkat,
/// adab, shamail, bulugh, hisn -- see README's "no cached independent
/// canonical source" books) so it only ever gets the spine's own languages.
class BookDef {
  BookDef({
    required this.bookId,
    required this.bookKey,
    required this.spineRelative,
    required this.englishTitle,
    this.fawazBook,
    this.sunnahSlug,
  });

  final int bookId;
  final String bookKey;
  final String spineRelative;
  final String englishTitle;
  final String? fawazBook;
  final String? sunnahSlug;
}

class LangInfo {
  const LangInfo(this.code, this.iso, this.name, this.prefix);
  final String code; // catalog language field for file id, e.g. eng
  final String iso; // short ISO-ish: en, ur, ar
  final String name;
  final String prefix; // fawaz filename prefix
}

/// Per-(language, book) join outcome, surfaced in `REPORT.md`'s match-rate
/// table. `matchedByHadithNumber` (matched on fawaz's own sequential
/// number) is the trustworthy majority; `matchedByArabicNumberOnly`
/// (fell back to matching on `arabicnumber` instead) is a weaker signal
/// worth watching if it's ever a large share of `fawazTotal`.
/// `unmatchedFawaz` rows are silently skipped, never force-appended.
class MatchStat {
  MatchStat(this.editionName);
  final String editionName;
  int fawazTotal = 0;
  int matchedByHadithNumber = 0;
  int matchedByArabicNumberOnly = 0;
  int unmatchedFawaz = 0;
  int spineTotal = 0;
  int spineCovered = 0;
}

class UnifiedBuilder {
  UnifiedBuilder(this.root);

  final Directory root;
  late final Directory unifiedDir;
  late final Directory filesDir;
  late final Directory byBookDir;

  final reportLines = <String>[];
  final discarded = <String>[];
  final matchStats = <MatchStat>[];
  final catalogEditions = <Map<String, dynamic>>[];

  /// Chapter names, once per book (language-keyed `names` maps), written to
  /// `catalog.json` instead of being duplicated into every language edition
  /// file. See each book's own `by_book` spine for the source shape:
  /// `{id, parentId, names: {ar, en, ur, ...}, needsTranslation?: [...]}`.
  final catalogBookChapters = <String, List<Map<String, dynamic>>>{};

  static const fawazLangs = <LangInfo>[
    LangInfo('ben', 'bn', 'Bengali', 'ben'),
    LangInfo('eng', 'en', 'English', 'eng'),
    LangInfo('fra', 'fr', 'French', 'fra'),
    LangInfo('ind', 'id', 'Indonesian', 'ind'),
    LangInfo('rus', 'ru', 'Russian', 'rus'),
    LangInfo('tam', 'ta', 'Tamil', 'tam'),
    LangInfo('tur', 'tr', 'Turkish', 'tur'),
    LangInfo('urd', 'ur', 'Urdu', 'urd'),
  ];

  static final books = <BookDef>[
    BookDef(
      bookId: 1,
      bookKey: 'bukhari',
      spineRelative: 'the_9_books/bukhari.json',
      englishTitle: 'Sahih al-Bukhari',
      fawazBook: 'bukhari',
      sunnahSlug: 'bukhari',
    ),
    BookDef(
      bookId: 2,
      bookKey: 'muslim',
      spineRelative: 'the_9_books/muslim.json',
      englishTitle: 'Sahih Muslim',
      fawazBook: 'muslim',
      sunnahSlug: 'muslim',
    ),
    BookDef(
      bookId: 3,
      bookKey: 'nasai',
      spineRelative: 'the_9_books/nasai.json',
      englishTitle: "Sunan an-Nasa'i",
      fawazBook: 'nasai',
      sunnahSlug: 'nasai',
    ),
    BookDef(
      bookId: 4,
      bookKey: 'abudawud',
      spineRelative: 'the_9_books/abudawud.json',
      englishTitle: 'Sunan Abi Dawud',
      fawazBook: 'abudawud',
      sunnahSlug: 'abudawud',
    ),
    BookDef(
      bookId: 5,
      bookKey: 'tirmidhi',
      spineRelative: 'the_9_books/tirmidhi.json',
      englishTitle: "Jami' at-Tirmidhi",
      fawazBook: 'tirmidhi',
      sunnahSlug: 'tirmidhi',
    ),
    BookDef(
      bookId: 6,
      bookKey: 'ibnmajah',
      spineRelative: 'the_9_books/ibnmajah.json',
      englishTitle: 'Sunan Ibn Majah',
      fawazBook: 'ibnmajah',
      sunnahSlug: 'ibnmajah',
    ),
    BookDef(
      bookId: 7,
      bookKey: 'malik',
      spineRelative: 'the_9_books/malik.json',
      englishTitle: 'Muwatta Malik',
      fawazBook: 'malik',
      sunnahSlug: 'malik',
    ),
    BookDef(
      bookId: 8,
      bookKey: 'ahmad',
      spineRelative: 'the_9_books/ahmed.json',
      englishTitle: 'Musnad Ahmad',
      // Set so _joinFawazLanguage() picks up db/editions/files/urd-ahmad
      // .min.json (built from the al-hadees.com scrape's own Urdu
      // translation, keyed to this book's new idInBook numbering -- see
      // MUSNAD_AHMAD_MIGRATION.md). No other fawazLangs file exists for
      // 'ahmad' so every other language here is a no-op (file-not-found,
      // gracefully skipped) until re-attached via arabic_match.dart.
      fawazBook: 'ahmad',
      sunnahSlug: 'ahmad',
    ),
    BookDef(
      bookId: 9,
      bookKey: 'darimi',
      spineRelative: 'the_9_books/darimi.json',
      englishTitle: 'Sunan ad-Darimi',
      sunnahSlug: 'darimi',
    ),
    BookDef(
      bookId: 10,
      bookKey: 'nawawi40',
      spineRelative: 'forties/nawawi40.json',
      englishTitle: 'Forty Hadith of Nawawi',
      fawazBook: 'nawawi',
      sunnahSlug: 'nawawi40',
    ),
    BookDef(
      bookId: 11,
      bookKey: 'qudsi40',
      spineRelative: 'forties/qudsi40.json',
      englishTitle: 'Forty Hadith Qudsi',
      fawazBook: 'qudsi',
      sunnahSlug: 'qudsi40',
    ),
    BookDef(
      bookId: 12,
      bookKey: 'shahwaliullah40',
      spineRelative: 'forties/shahwaliullah40.json',
      englishTitle: 'Forty Hadith of Shah Waliullah',
      fawazBook: 'dehlawi',
      sunnahSlug: 'shahwaliullah40',
    ),
    BookDef(
      bookId: 13,
      bookKey: 'riyadussalihin',
      spineRelative: 'other_books/riyad_assalihin.json',
      englishTitle: 'Riyad as-Salihin',
      sunnahSlug: 'riyadussalihin',
    ),
    BookDef(
      bookId: 14,
      bookKey: 'mishkat',
      spineRelative: 'other_books/mishkat_almasabih.json',
      englishTitle: 'Mishkat al-Masabih',
      sunnahSlug: 'mishkat',
    ),
    BookDef(
      bookId: 15,
      bookKey: 'adab',
      spineRelative: 'other_books/aladab_almufrad.json',
      englishTitle: 'Al-Adab Al-Mufrad',
      sunnahSlug: 'adab',
    ),
    BookDef(
      bookId: 16,
      bookKey: 'shamail',
      spineRelative: 'other_books/shamail_muhammadiyah.json',
      englishTitle: "Shama'il Muhammadiyah",
      sunnahSlug: 'shamail',
    ),
    BookDef(
      bookId: 17,
      bookKey: 'bulugh',
      spineRelative: 'other_books/bulugh_almaram.json',
      englishTitle: 'Bulugh al-Maram',
      sunnahSlug: 'bulugh',
    ),
    BookDef(
      bookId: 18,
      bookKey: 'hisn',
      spineRelative: 'other_books/hisn_almuslim.json',
      englishTitle: 'Hisn al-Muslim',
      sunnahSlug: 'hisn',
    ),
  ];

  void run() {
    final started = DateTime.now();
    unifiedDir = Directory(p(root.path, 'db', 'unified'));
    filesDir = Directory(p(unifiedDir.path, 'files'));
    byBookDir = Directory(p(unifiedDir.path, 'by_book'));

    if (unifiedDir.existsSync()) {
      unifiedDir.deleteSync(recursive: true);
    }
    filesDir.createSync(recursive: true);
    byBookDir.createSync(recursive: true);

    reportLines.add('# Unified editions build report');
    reportLines.add('');
    reportLines.add('Built: ${started.toUtc().toIso8601String()}');
    reportLines.add('');
    reportLines.add('## Sources');
    reportLines.add(
      '- AhmedBaset spine: `db/by_book` (structure, arabic, english narrator/text, chapters)',
    );
    reportLines.add('- muallimai: grade + reference already merged into spine');
    reportLines.add(
      '- fawazahmed0: `db/editions/files/{lang}-{book}.min.json` (non-English translations + multi-grader grades)',
    );
    reportLines.add(
      '- sagad: `db/by_locale/id/by_book` Indonesian drafts for books without fawaz `ind-*`',
    );
    reportLines.add('');

    _scanDiscardedDuplicates();

    for (final book in books) {
      stdout.writeln('Building ${book.bookKey}...');
      _buildBook(book);
    }

    _writeCatalog();
    _writeReport();
    _writeMatrix();
    _writeMirrorZips();

    final elapsed = DateTime.now().difference(started);
    stdout.writeln(
      'Done: ${catalogEditions.length} editions in ${elapsed.inSeconds}s → ${unifiedDir.path}',
    );
  }

  /// Zips every edition's already-minified JSON into `hapiam_mirror_hadith/`
  /// — the exact, ready-to-upload artifact set for the app's CDN mirror
  /// (matches the Quran pipeline's `.min.json.zip` download convention,
  /// instead of shipping plain unzipped `.min.json` like this app used to).
  /// Nothing else in this repo needs to be zipped — only what an end user's
  /// device actually downloads.
  void _writeMirrorZips() {
    final mirrorDir = Directory(p(root.path, 'hapiam_mirror_hadith'));
    if (mirrorDir.existsSync()) {
      mirrorDir.deleteSync(recursive: true);
    }
    mirrorDir.createSync(recursive: true);

    stdout.writeln(
      'Zipping ${catalogEditions.length} editions into hapiam_mirror_hadith/...',
    );
    final zipBytes = <String, int>{};
    for (final e in catalogEditions) {
      final id = e['id'] as String;
      final minJsonFile = File(p(filesDir.path, '$id.min.json'));
      if (!minJsonFile.existsSync()) {
        stderr.writeln('  WARNING: missing $id.min.json, skipping zip');
        continue;
      }
      final zipFile = File(p(mirrorDir.path, '$id.min.json.zip'));
      final result = Process.runSync('powershell', [
        '-NoProfile',
        '-Command',
        'Compress-Archive -Path \'${minJsonFile.path}\' -DestinationPath \'${zipFile.path}\' -Force -CompressionLevel Optimal',
      ]);
      if (result.exitCode != 0) {
        stderr.writeln('  FAILED to zip $id: ${result.stderr}');
        continue;
      }
      zipBytes[id] = zipFile.lengthSync();
    }
    for (final e in catalogEditions) {
      final bytes = zipBytes[e['id']];
      if (bytes != null) e['mirrorZipBytes'] = bytes;
    }
    _writeCatalog(); // re-write now that mirrorZipBytes is populated
    stdout.writeln(
      'Zipped ${zipBytes.length}/${catalogEditions.length} editions.',
    );
  }

  // Runs once up front (not per-book): fawaz's `db/editions/files` sometimes
  // has more than one file for the same language x book (e.g. a numbered
  // variant like `ara-bukhari1` alongside the primary `ara-bukhari`) --
  // scans and records which ones are treated as non-primary duplicates so
  // `REPORT.md` documents *why* a file present on disk never became an
  // edition, instead of it just silently not appearing.
  void _scanDiscardedDuplicates() {
    reportLines.add('## Discarded / non-primary fawaz editions');
    reportLines.add('');
    final editionsDir = Directory(p(root.path, 'db', 'editions', 'files'));
    if (!editionsDir.existsSync()) {
      reportLines.add('No `db/editions/files` found.');
      reportLines.add('');
      return;
    }

    final byBookLang = <String, List<String>>{};
    for (final f in editionsDir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.min.json')) continue;
      final base = name.replaceAll('.min.json', '');
      // Skip undiacritized ara-*1 — emitted separately as ara1-*
      if (RegExp(r'^ara-.+1$').hasMatch(base)) {
        discarded.add('$base (kept as optional ara1-* undiacritized edition)');
        continue;
      }
      final m = RegExp(r'^([a-z]+)-(.+)$').firstMatch(base);
      if (m == null) continue;
      final lang = m.group(1)!;
      final book = m.group(2)!;
      byBookLang.putIfAbsent('$lang|$book', () => []).add(base);
    }

    // Only one primary per lang×book is expected; note any extras with suffixes.
    for (final entry in byBookLang.entries) {
      final names = entry.value..sort();
      if (names.length > 1) {
        final primary = names.firstWhere(
          (n) => !RegExp(r'\d+$').hasMatch(n.split('-').last),
          orElse: () => names.first,
        );
        for (final n in names) {
          if (n != primary) {
            discarded.add('$n (duplicate of $primary)');
          }
        }
      }
    }

    if (discarded.isEmpty) {
      reportLines.add(
        'No duplicate language variants discarded (only ara-*1 handled separately).',
      );
    } else {
      for (final d in discarded) {
        reportLines.add('- $d');
      }
    }
    reportLines.add('');
  }

  // Per-book orchestration: load the spine, join every available fawaz
  // language + grades onto it by idInBook<->hadithnumber, fill Indonesian
  // from sagad where fawaz has none, write the multi-language `by_book`
  // master, then emit one single-language edition file per language that
  // actually has content for this book (always Arabic + English; other
  // languages only if at least one hadith carries them).
  void _buildBook(BookDef book) {
    final spinePath = p(root.path, 'db', 'by_book', book.spineRelative);
    final spineFile = File(spinePath);
    if (!spineFile.existsSync()) {
      reportLines.add('WARN: missing spine ${book.spineRelative}');
      return;
    }

    final spine =
        jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final chapters = (spine['chapters'] as List<dynamic>? ?? const [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    // Chapter names live once in the catalog (language-keyed `names` maps),
    // not duplicated into every edition file below.
    catalogBookChapters[book.bookKey] = chapters;
    final spineHadiths = (spine['hadiths'] as List<dynamic>? ?? const [])
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();
    final meta = Map<String, dynamic>.from(spine['metadata'] as Map? ?? {});

    // Master rows keyed by idInBook for joining; list preserves spine order.
    final masters = <Map<String, dynamic>>[];
    final byIdInBook = <num, Map<String, dynamic>>{};
    final byId = <int, Map<String, dynamic>>{};

    for (final h in spineHadiths) {
      final idInBook = _asNum(h['idInBook']);
      final grades = _gradesFromSpine(h['grade']);
      final reference = _normalizeReference(
        h['reference'],
        book: book,
        idInBook: idInBook,
      );
      final english = h['english'];
      Map<String, dynamic>? enTrans;
      if (english is Map) {
        enTrans = {
          'narrator': (english['narrator'] ?? '').toString(),
          'text': (english['text'] ?? '').toString(),
        };
      }

      final row = <String, dynamic>{
        'id': h['id'],
        'idInBook': h['idInBook'],
        'chapterId': h['chapterId'],
        'bookId': h['bookId'] ?? book.bookId,
        'arabic': (h['arabic'] ?? '').toString(),
        'translations': <String, dynamic>{if (enTrans != null) 'en': enTrans},
        'grades': grades,
        'reference': reference,
        // Real content whose text didn't confidently content-match any
        // canonical citation slot -- kept (not dropped) and excluded from
        // the catalog's headline hadithCount (see DATA_QUALITY_REPORT.md in
        // this repo for the full named list).
        'isAddendum': h['appendedOriginal'] == true,
        // Display-order override for isAddendum rows, set by
        // tool/reposition_addenda.dart from the hadith's own old citation
        // (e.g. "690b" -> 690.01) so it sorts right after the canonically
        // numbered sibling it was originally printed next to, instead of
        // trailing every real hadith in the book. `idInBook` itself is left
        // alone -- it stays each addendum's stable identity for citation.
        // Absent (falls back to idInBook) for every canonically numbered
        // hadith.
        if (h['sortKey'] != null) 'sortKey': h['sortKey'],
        // Optional per-hadith scraped metadata (currently only Musnad Ahmad
        // carries these): isnad classification (marfu'/mawquf/maqtu') and
        // the scholar's own authentication conclusion text.
        if (h['classification'] != null) 'classification': h['classification'],
        if (h['conclusion'] != null) 'conclusion': h['conclusion'],
        // TODO: `rebuild_from_fawaz.dart` sets `noSourceContent: true` on
        // spine rows with genuinely blank Arabic+English (see its
        // `isBlank` handling) and `chapterUnknown: true` on fawaz's
        // "couldn't determine the chapter" placeholder rows -- neither
        // flag is copied through into this unified row, so both are lost
        // by the time `db/unified/by_book/*.json` is written. That means
        // `gen_data_quality_report.dart` (which only reads the unified
        // by_book output) can't see or report on either condition, even
        // though README's edition schema documents `noSourceContent` as
        // part of the intended honesty-flag contract. Propagate both
        // fields here if/when the quality report needs to surface them.
      };
      masters.add(row);
      if (idInBook != null) byIdInBook[idInBook] = row;
      final id = h['id'];
      if (id is int) byId[id] = row;
    }

    final sources = <String>{'ahmedbaset', 'muallimai'};

    // Absorb fawaz grades + non-English translations (and verify eng join).
    if (book.fawazBook != null) {
      _absorbFawazGrades(book, byIdInBook, sources);
      for (final lang in fawazLangs) {
        if (lang.iso == 'en') {
          // English text stays AhmedBaset; still record join stats from eng-* file.
          _joinFawazLanguage(
            book: book,
            lang: lang,
            byIdInBook: byIdInBook,
            absorbTranslation: false,
            sources: sources,
          );
          continue;
        }
        _joinFawazLanguage(
          book: book,
          lang: lang,
          byIdInBook: byIdInBook,
          absorbTranslation: true,
          sources: sources,
        );
      }

      // Optional undiacritized Arabic overlay as separate translation key.
      _joinUndiacritizedArabic(book, byIdInBook, sources);
    }

    // Sagad Indonesian draft for books without fawaz ind coverage.
    final hasFawazInd =
        book.fawazBook != null &&
        File(
          p(
            root.path,
            'db',
            'editions',
            'files',
            'ind-${book.fawazBook}.min.json',
          ),
        ).existsSync();
    if (!hasFawazInd) {
      _absorbSagadIndonesian(book, byId, masters, sources);
    }

    // Write master by_book file. Chapter names live once in catalog.json's
    // `bookChapters[bookKey]` (see `catalogBookChapters` above), not
    // duplicated here.
    final masterOut = {
      'metadata': {
        'bookId': book.bookId,
        'bookKey': book.bookKey,
        'arabic': meta['arabic'],
        'english': meta['english'],
        'sources': sources.toList()..sort(),
      },
      'hadiths': masters,
    };
    _writeJson(File(p(byBookDir.path, '${book.bookKey}.json')), masterOut);
    _writeMinJson(
      File(p(byBookDir.path, '${book.bookKey}.min.json')),
      masterOut,
    );

    // Always emit Arabic + English views for every spine book (even if English
    // text is empty upstream — e.g. some Darimi rows).
    _emitArabicEdition(
      book,
      meta,
      chapters,
      masters,
      sources,
      undiacritized: false,
    );
    if (book.fawazBook != null &&
        File(
          p(
            root.path,
            'db',
            'editions',
            'files',
            'ara-${book.fawazBook}1.min.json',
          ),
        ).existsSync()) {
      _emitArabicEdition(
        book,
        meta,
        chapters,
        masters,
        sources,
        undiacritized: true,
      );
    }

    // Force-emit English for books whose spine actually carries it (all 17
    // AhmedBaset-sourced books) -- but NOT for a book like the new Ahmad
    // scaffold, which has no English source at all yet. Shipping a
    // "Musnad Ahmad (English)" edition with zero actual English text would
    // be actively misleading, worse than not offering the edition.
    final hasAnyEnglish = masters.any((m) {
      final tr = (m['translations'] as Map<String, dynamic>)['en'];
      return tr is Map && (tr['text'] ?? '').toString().trim().isNotEmpty;
    });
    _emitLanguageEdition(
      book: book,
      meta: meta,
      chapters: chapters,
      masters: masters,
      sources: sources,
      langCode: 'eng',
      langIso: 'en',
      langName: 'English',
      preferNarratorSplit: true,
      forceEmit: hasAnyEnglish,
    );

    final presentLangs = <String>{};
    for (final row in masters) {
      final tr = row['translations'] as Map<String, dynamic>;
      presentLangs.addAll(tr.keys.cast<String>());
    }

    for (final lang in fawazLangs) {
      if (lang.iso == 'en') continue;
      if (!presentLangs.contains(lang.iso)) continue;
      _emitLanguageEdition(
        book: book,
        meta: meta,
        chapters: chapters,
        masters: masters,
        sources: sources,
        langCode: lang.code,
        langIso: lang.iso,
        langName: lang.name,
        preferNarratorSplit: false,
      );
    }
  }

  // Grades are graded independently of translation text, so this pulls them
  // from whichever fawaz file is available (eng preferred, ara fallback)
  // without touching any hadith's Arabic/English content -- kept separate
  // from `_joinFawazLanguage` below because grades need to be absorbed even
  // for languages (like English) whose *text* is deliberately not absorbed
  // from fawaz.
  void _absorbFawazGrades(
    BookDef book,
    Map<num, Map<String, dynamic>> byIdInBook,
    Set<String> sources,
  ) {
    // Prefer eng file for grades; fall back to ara.
    final candidates = [
      'eng-${book.fawazBook}.min.json',
      'ara-${book.fawazBook}.min.json',
    ];
    for (final name in candidates) {
      final f = File(p(root.path, 'db', 'editions', 'files', name));
      if (!f.existsSync()) continue;
      final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final hadiths = data['hadiths'] as List<dynamic>? ?? const [];
      var absorbed = 0;
      for (final raw in hadiths) {
        final h = Map<String, dynamic>.from(raw as Map);
        final row = _findSpineRow(byIdInBook, h);
        if (row == null) continue;
        final before = (row['grades'] as List).length;
        _mergeGrades(row, h['grades']);
        if ((row['grades'] as List).length > before) absorbed++;
      }
      if (absorbed > 0) {
        sources.add('fawaz');
        reportLines.add(
          '- ${book.bookKey}: absorbed multi-grader grades from `$name` into $absorbed hadiths',
        );
      }
      break;
    }
  }

  // Joins one fawaz language file onto the spine by matching fawaz's own
  // `hadithnumber` against the spine's `idInBook` (falling back to
  // `arabicnumber` when `hadithnumber` doesn't hit -- tracked separately in
  // `matchedByArabicNumberOnly` since it's a weaker signal). This is a
  // *positional* join by numbering, not a content match -- it only produces
  // correct pairings when the spine's `idInBook` genuinely is the same
  // numbering scheme as fawaz's `hadithnumber`. For the 10 books rebuilt by
  // `rebuild_from_fawaz.dart` that's true by construction; for the remaining
  // 8 it relies on whatever numbering alignment those spines already have.
  // Never invents a row for unmatched fawaz entries -- unmatched fawaz rows
  // are only counted in `stat.unmatchedFawaz`, never appended anywhere.
  void _joinFawazLanguage({
    required BookDef book,
    required LangInfo lang,
    required Map<num, Map<String, dynamic>> byIdInBook,
    required bool absorbTranslation,
    required Set<String> sources,
  }) {
    final fileName = '${lang.prefix}-${book.fawazBook}.min.json';
    final f = File(p(root.path, 'db', 'editions', 'files', fileName));
    if (!f.existsSync()) return;

    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = data['hadiths'] as List<dynamic>? ?? const [];
    final stat = MatchStat(fileName)
      ..fawazTotal = hadiths.length
      ..spineTotal = byIdInBook.length;

    final covered = <num>{};
    for (final raw in hadiths) {
      final h = Map<String, dynamic>.from(raw as Map);
      final hn = _asNum(h['hadithnumber']);
      final an = _asNum(h['arabicnumber']);

      Map<String, dynamic>? row;
      var viaArabicOnly = false;
      if (hn != null && byIdInBook.containsKey(hn)) {
        row = byIdInBook[hn];
        stat.matchedByHadithNumber++;
      } else if (an != null && byIdInBook.containsKey(an)) {
        row = byIdInBook[an];
        stat.matchedByArabicNumberOnly++;
        viaArabicOnly = true;
      }

      if (row == null) {
        stat.unmatchedFawaz++;
        continue;
      }

      final idInBook = _asNum(row['idInBook']);
      if (idInBook != null) covered.add(idInBook);

      if (absorbTranslation) {
        final text = (h['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          final translations = row['translations'] as Map<String, dynamic>;
          translations[lang.iso] = {'narrator': '', 'text': text};
          sources.add('fawaz');
        }
      }

      // Always merge grades when present on this language file.
      _mergeGrades(row, h['grades']);
      // TODO: this if-block is a no-op -- `viaArabicOnly` was already
      // recorded into `stat.matchedByArabicNumberOnly` above (line ~614)
      // and nothing else reads it here. Dead code, safe to delete along
      // with the `var viaArabicOnly = false;` declaration above once
      // confirmed no debugger/breakpoint depends on it.
      if (viaArabicOnly) {
        // tracked in stats only
      }
    }

    stat.spineCovered = covered.length;
    matchStats.add(stat);
    sources.add('fawaz');
  }

  // Optional overlay: fawaz publishes a second, undiacritized (no tashkeel)
  // Arabic edition for some books (`ara-{book}1.min.json`), which this
  // attaches as an extra `translations['ar-undiacritized']` entry rather
  // than replacing the spine's own (diacritized) `arabic` field -- an app
  // reading preference, not a correction, so both must stay available.
  void _joinUndiacritizedArabic(
    BookDef book,
    Map<num, Map<String, dynamic>> byIdInBook,
    Set<String> sources,
  ) {
    final f = File(
      p(
        root.path,
        'db',
        'editions',
        'files',
        'ara-${book.fawazBook}1.min.json',
      ),
    );
    if (!f.existsSync()) return;
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = data['hadiths'] as List<dynamic>? ?? const [];
    var n = 0;
    for (final raw in hadiths) {
      final h = Map<String, dynamic>.from(raw as Map);
      final row = _findSpineRow(byIdInBook, h);
      if (row == null) continue;
      final text = (h['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      (row['translations'] as Map<String, dynamic>)['ar-undiacritized'] = {
        'narrator': '',
        'text': text,
      };
      n++;
    }
    if (n > 0) {
      sources.add('fawaz');
      reportLines.add(
        '- ${book.bookKey}: attached undiacritized Arabic on $n hadiths (ara1)',
      );
    }
  }

  // Fallback-only path: only called by `_buildBook` when fawaz has no
  // `ind-{book}.min.json` at all for this book. Matches sagad's rows by `id`
  // first, `idInBook` second, and explicitly prefers an already-present
  // non-draft fawaz Indonesian translation over sagad's if one somehow
  // exists on the row already -- sagad is the last-resort source, tagged
  // `status: 'draft'` downstream, never silently treated as equal quality.
  void _absorbSagadIndonesian(
    BookDef book,
    Map<int, Map<String, dynamic>> byId,
    List<Map<String, dynamic>> masters,
    Set<String> sources,
  ) {
    final localePath = p(
      root.path,
      'db',
      'by_locale',
      'id',
      'by_book',
      book.spineRelative,
    );
    final f = File(localePath);
    if (!f.existsSync()) {
      reportLines.add('- ${book.bookKey}: no sagad Indonesian by_book file');
      return;
    }

    final byIdInBook = <num, Map<String, dynamic>>{};
    for (final m in masters) {
      final idInBook = _asNum(m['idInBook']);
      if (idInBook != null) byIdInBook[idInBook] = m;
    }

    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = data['hadiths'] as List<dynamic>? ?? const [];
    var matched = 0;
    var unmatched = 0;
    for (final raw in hadiths) {
      final h = Map<String, dynamic>.from(raw as Map);
      final id = h['id'];
      Map<String, dynamic>? row;
      if (id is int) row = byId[id];
      final idInBook = _asNum(h['idInBook']);
      if (row == null && idInBook != null) row = byIdInBook[idInBook];
      if (row == null) {
        unmatched++;
        continue;
      }

      // Prefer fawaz Indonesian when already present.
      final existing = (row['translations'] as Map<String, dynamic>)['id'];
      if (existing is Map &&
          (existing['status'] == null || existing['status'] != 'draft') &&
          (existing['text'] ?? '').toString().trim().isNotEmpty) {
        continue;
      }

      final tr = h['translation'];
      if (tr is! Map) continue;
      final text = (tr['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      (row['translations'] as Map<String, dynamic>)['id'] = {
        'narrator': (tr['narrator'] ?? '').toString(),
        'text': text,
        'status': (tr['status'] ?? 'draft').toString(),
      };
      matched++;
    }
    if (matched > 0) {
      sources.add('sagad');
      reportLines.add(
        '- ${book.bookKey}: Indonesian draft from sagad on $matched hadiths '
        '(unmatched sagad rows: $unmatched; no fawaz ind-* for this book)',
      );
    } else {
      reportLines.add(
        '- ${book.bookKey}: sagad Indonesian present but 0 matches '
        '(sagad rows: ${hadiths.length}, unmatched: $unmatched)',
      );
    }
  }

  // Writes the Arabic-only edition file (`ara-{book}` or, if
  // `undiacritized`, `ara1-{book}`) plus its `catalog.json` entry. Always
  // called once for the diacritized edition per book; called a second time
  // for the undiacritized variant only when fawaz actually published one.
  //
  // TODO: the `chapters` parameter is accepted but never read in this
  // function body -- chapter names are written once into
  // `catalog.json`'s `bookChapters` (see `catalogBookChapters` /
  // `_writeCatalog`), not duplicated per-edition, so this parameter is
  // vestigial. Same applies to `_emitLanguageEdition` below. Safe to drop
  // from both signatures and their call sites once verified nothing else
  // relies on the parameter being present (e.g. arity-sensitive tooling).
  void _emitArabicEdition(
    BookDef book,
    Map<String, dynamic> meta,
    List<Map<String, dynamic>> chapters,
    List<Map<String, dynamic>> masters,
    Set<String> sources, {
    required bool undiacritized,
  }) {
    final langCode = undiacritized ? 'ara1' : 'ara';
    final langIso = undiacritized ? 'ar-undiacritized' : 'ar';
    final langName = undiacritized ? 'Arabic (undiacritized)' : 'Arabic';

    final hadiths = <Map<String, dynamic>>[];
    for (final row in masters) {
      String arabic = (row['arabic'] ?? '').toString();
      if (undiacritized) {
        final tr = row['translations'] as Map<String, dynamic>;
        final und = tr['ar-undiacritized'];
        if (und is Map && (und['text'] ?? '').toString().isNotEmpty) {
          arabic = und['text'].toString();
        } else {
          continue; // only emit rows that have undiacritized text
        }
      }
      hadiths.add({
        'id': row['id'],
        'idInBook': row['idInBook'],
        'chapterId': row['chapterId'],
        'bookId': row['bookId'],
        'arabic': arabic,
        'translation': null,
        'grades': row['grades'],
        'reference': row['reference'],
        'isAddendum': row['isAddendum'] == true,
        if (row['sortKey'] != null) 'sortKey': row['sortKey'],
        if (row['classification'] != null)
          'classification': row['classification'],
        if (row['conclusion'] != null) 'conclusion': row['conclusion'],
      });
    }
    if (hadiths.isEmpty) return;

    final features = <String>['arabic', 'grades', 'reference', 'chapters'];
    final editionId = '$langCode-${book.bookKey}';
    final out = {
      'metadata': {
        'bookId': book.bookId,
        'bookKey': book.bookKey,
        'language': langIso,
        'arabic': meta['arabic'],
        'translation': null,
      },
      'hadiths': hadiths,
    };
    _writeEditionFiles(editionId, out);
    final addendumCount = hadiths.where((h) => h['isAddendum'] == true).length;
    catalogEditions.add({
      'id': editionId,
      'bookKey': book.bookKey,
      'bookId': book.bookId,
      'language': langIso,
      'languageName': langName,
      'name': '${book.englishTitle} ($langName)',
      'hadithCount': hadiths.length - addendumCount,
      if (addendumCount > 0) 'addendumCount': addendumCount,
      'features': features,
      'path': 'files/$editionId.json',
      'sources': sources.toList()..sort(),
    });
  }

  // Writes one translated-language edition file + catalog entry. Skips
  // emitting entirely if not a single hadith in the book has this
  // language's translation, unless `forceEmit` (only ever true for English
  // on spine books -- see `_buildBook`'s "hasAnyEnglish" check -- so every
  // spine-sourced book always ships an English edition, even one that's
  // functionally empty, rather than the app silently having no English
  // edition to fall back to).
  //
  // TODO: `preferNarratorSplit` is accepted (always passed `true` for
  // English, `false` for every other language, see call sites in
  // `_buildBook`) but never actually read anywhere in this function body --
  // dead parameter, same class of issue as the unused `chapters` param
  // noted on `_emitArabicEdition` above. Either wire it up to whatever
  // narrator/text-splitting behavior it was meant to gate, or remove it.
  void _emitLanguageEdition({
    required BookDef book,
    required Map<String, dynamic> meta,
    required List<Map<String, dynamic>> chapters,
    required List<Map<String, dynamic>> masters,
    required Set<String> sources,
    required String langCode,
    required String langIso,
    required String langName,
    required bool preferNarratorSplit,
    bool forceEmit = false,
  }) {
    final hadiths = <Map<String, dynamic>>[];
    var draftCount = 0;
    var withTranslation = 0;
    for (final row in masters) {
      final translations = row['translations'] as Map<String, dynamic>;
      final tr = translations[langIso];

      Map<String, dynamic>? translation;
      if (tr is Map) {
        final text = (tr['text'] ?? '').toString();
        if (text.trim().isNotEmpty) {
          translation = {
            'narrator': (tr['narrator'] ?? '').toString(),
            'text': text,
          };
          if (tr['status'] != null) {
            translation['status'] = tr['status'];
            if (tr['status'] == 'draft') draftCount++;
          }
          withTranslation++;
        } else if (forceEmit && langIso == 'en') {
          // Keep narrator/text keys even when upstream English is blank.
          translation = {
            'narrator': (tr['narrator'] ?? '').toString(),
            'text': text,
          };
        }
      } else if (forceEmit && langIso == 'en') {
        translation = {'narrator': '', 'text': ''};
      }

      // Keep full spinal row count so ids/arabic/grades stay complete even when
      // a language edition is missing a row's translation text.
      // TODO: README's documented edition schema (see "Edition schema"
      // section) shows per-hadith `untranslated` / `noSourceContent` /
      // `appendedOriginal` boolean flags, but this actually emits
      // `isAddendum` (not `appendedOriginal`) and never emits `untranslated`
      // or `noSourceContent` at all -- consumers checking for the
      // README-documented field names against real edition files would find
      // them missing. Either the README needs updating to match reality, or
      // this output needs the missing fields added (`translation == null`
      // already implies "untranslated" but isn't surfaced as its own key).
      hadiths.add({
        'id': row['id'],
        'idInBook': row['idInBook'],
        'chapterId': row['chapterId'],
        'bookId': row['bookId'],
        'arabic': row['arabic'],
        'translation': translation,
        'grades': row['grades'],
        'reference': row['reference'],
        'isAddendum': row['isAddendum'] == true,
        if (row['sortKey'] != null) 'sortKey': row['sortKey'],
        if (row['classification'] != null)
          'classification': row['classification'],
        if (row['conclusion'] != null) 'conclusion': row['conclusion'],
      });
    }
    // Skip emitting a language edition if no hadith has that translation
    // (unless forced — always emit eng for spine books).
    if (withTranslation == 0 && !forceEmit) return;

    final engMeta = meta['english'] is Map
        ? Map<String, dynamic>.from(meta['english'] as Map)
        : <String, dynamic>{'title': book.englishTitle, 'author': ''};

    final features = <String>[
      'arabic',
      'translation',
      'grades',
      'reference',
      'chapters',
    ];
    final editionId = '$langCode-${book.bookKey}';
    final translationMeta = <String, dynamic>{
      'title': engMeta['title'] ?? book.englishTitle,
      'author': engMeta['author'] ?? '',
      'language': langIso,
    };
    if (draftCount > 0) {
      translationMeta['translationStatus'] = 'draft';
    }

    final out = {
      'metadata': {
        'bookId': book.bookId,
        'bookKey': book.bookKey,
        'language': langIso,
        'arabic': meta['arabic'],
        'translation': translationMeta,
        if (draftCount > 0) 'translationStatus': 'draft',
      },
      'hadiths': hadiths,
    };
    _writeEditionFiles(editionId, out);
    final addendumCount = hadiths.where((h) => h['isAddendum'] == true).length;
    catalogEditions.add({
      'id': editionId,
      'bookKey': book.bookKey,
      'bookId': book.bookId,
      'language': langIso,
      'languageName': langName,
      'name': '${book.englishTitle} ($langName)',
      'hadithCount': hadiths.length - addendumCount,
      if (addendumCount > 0) 'addendumCount': addendumCount,
      'translationCount': withTranslation,
      'features': features,
      'path': 'files/$editionId.json',
      'sources': sources.toList()..sort(),
      if (draftCount > 0) 'translationStatus': 'draft',
    });
  }

  void _writeEditionFiles(String editionId, Map<String, dynamic> out) {
    _writeJson(File(p(filesDir.path, '$editionId.json')), out);
    _writeMinJson(File(p(filesDir.path, '$editionId.min.json')), out);
  }

  void _writeCatalog() {
    catalogEditions.sort((a, b) {
      final bid = (a['bookId'] as int).compareTo(b['bookId'] as int);
      if (bid != 0) return bid;
      return (a['id'] as String).compareTo(b['id'] as String);
    });
    final catalog = {
      // v2: chapter names moved here (once per book, language-keyed `names`
      // maps under `bookChapters`) instead of being duplicated inside every
      // edition file's own metadata.
      'schemaVersion': 2,
      'editions': catalogEditions,
      'bookChapters': catalogBookChapters,
    };
    _writeJson(File(p(unifiedDir.path, 'catalog.json')), catalog);
    _writeMinJson(File(p(unifiedDir.path, 'catalog.min.json')), catalog);
  }

  // Writes `db/unified/REPORT.md` from everything accumulated in
  // `reportLines`/`matchStats` over the whole `run()` -- the human-readable
  // build provenance doc referenced throughout the README (fawaz<->spine
  // match rates per edition, discarded duplicate files, per-book absorption
  // notes). Not itself an integrity check -- see
  // `gen_data_quality_report.dart` for the tool that names every individual
  // flagged hadith.
  void _writeReport() {
    reportLines.add('## Fawaz ↔ spine match rates');
    reportLines.add('');
    reportLines.add(
      '| Edition | Fawaz rows | Matched hn | Matched an-only | Unmatched fawaz | Spine covered | Spine total | Coverage |',
    );
    reportLines.add('|---|---:|---:|---:|---:|---:|---:|---:|');
    matchStats.sort((a, b) => a.editionName.compareTo(b.editionName));
    for (final s in matchStats) {
      final cov = s.spineTotal == 0
          ? '0%'
          : '${(100.0 * s.spineCovered / s.spineTotal).toStringAsFixed(2)}%';
      reportLines.add(
        '| ${s.editionName} | ${s.fawazTotal} | ${s.matchedByHadithNumber} | '
        '${s.matchedByArabicNumberOnly} | ${s.unmatchedFawaz} | '
        '${s.spineCovered} | ${s.spineTotal} | $cov |',
      );
    }
    reportLines.add('');

    // Highlight Muslim
    reportLines.add('### Muslim highlight');
    reportLines.add('');
    final muslimStats = matchStats
        .where((s) => s.editionName.contains('muslim'))
        .toList();
    if (muslimStats.isEmpty) {
      reportLines.add('No Muslim fawaz joins recorded.');
    } else {
      for (final s in muslimStats) {
        reportLines.add(
          '- `${s.editionName}`: spine ${s.spineCovered}/${s.spineTotal}; '
          'unmatched fawaz ${s.unmatchedFawaz} (skipped, no invented ids)',
        );
      }
    }
    reportLines.add('');

    reportLines.add('## Catalog summary');
    reportLines.add('');
    reportLines.add('Total unified editions: ${catalogEditions.length}');
    reportLines.add('');

    File(
      p(unifiedDir.path, 'REPORT.md'),
    ).writeAsStringSync('${reportLines.join('\n')}\n');
  }

  // Writes `db/unified/MATRIX.md`, a quick visual check-mark grid of which
  // (book, language) pairs actually got an edition emitted this run -- the
  // fastest way to see at a glance which books are missing a language
  // without reading REPORT.md's more detailed per-edition stats.
  void _writeMatrix() {
    final booksKeys = books.map((b) => b.bookKey).toList();
    final langs = <String>{
      'ar',
      'ar-undiacritized',
      'en',
      'bn',
      'fr',
      'id',
      'ru',
      'ta',
      'tr',
      'ur',
    };
    final present = <String, Set<String>>{};
    for (final e in catalogEditions) {
      present
          .putIfAbsent(e['bookKey'] as String, () => {})
          .add(e['language'] as String);
    }

    final buf = StringBuffer();
    buf.writeln('# Language × book matrix');
    buf.writeln();
    buf.write('| book |');
    final langList = langs.toList()..sort();
    for (final l in langList) {
      buf.write(' $l |');
    }
    buf.writeln();
    buf.write('|---|');
    for (final _ in langList) {
      buf.write('---|');
    }
    buf.writeln();
    for (final b in booksKeys) {
      buf.write('| $b |');
      final set = present[b] ?? {};
      for (final l in langList) {
        buf.write(set.contains(l) ? ' ✓ |' : ' |');
      }
      buf.writeln();
    }
    buf.writeln();
    File(p(unifiedDir.path, 'MATRIX.md')).writeAsStringSync(buf.toString());
  }

  // --- helpers ---

  // Same hadithnumber-then-arabicnumber lookup strategy as
  // `_joinFawazLanguage` above, factored out for the two callers
  // (`_absorbFawazGrades`, `_joinUndiacritizedArabic`) that only need a
  // single row lookup rather than a full pass with match-rate stats.
  Map<String, dynamic>? _findSpineRow(
    Map<num, Map<String, dynamic>> byIdInBook,
    Map<String, dynamic> fawazHadith,
  ) {
    final hn = _asNum(fawazHadith['hadithnumber']);
    if (hn != null && byIdInBook.containsKey(hn)) return byIdInBook[hn];
    final an = _asNum(fawazHadith['arabicnumber']);
    if (an != null && byIdInBook.containsKey(an)) return byIdInBook[an];
    return null;
  }

  List<Map<String, dynamic>> _gradesFromSpine(dynamic grade) {
    if (grade == null) return [];
    if (grade is List) {
      return grade
          .whereType<Map>()
          .map(
            (g) => {
              'name': (g['name'] ?? 'unknown').toString(),
              'grade': (g['grade'] ?? '').toString(),
            },
          )
          .where((g) => (g['grade'] as String).isNotEmpty)
          .toList();
    }
    final s = grade.toString().trim();
    if (s.isEmpty || s == 'null') return [];
    // Prefer Darussalam when the string mentions it.
    final name = s.toLowerCase().contains('darussalam')
        ? 'Darussalam'
        : 'muallimai';
    return [
      {'name': name, 'grade': s},
    ];
  }

  // Grade dedup: a (name, grade-text) pair already present -- case-
  // insensitively -- is skipped rather than duplicated, since the same
  // grader's verdict often shows up in more than one source file (spine +
  // fawaz eng + fawaz ara all sometimes carry "Darussalam: Sahih"). Multiple
  // *different* graders' verdicts for the same hadith are all kept
  // (`grades` is a list, not a single value) -- that's intentional, not a
  // conflict to resolve.
  void _mergeGrades(Map<String, dynamic> row, dynamic incoming) {
    final list = (row['grades'] as List).cast<Map<String, dynamic>>();
    final existing = list
        .map((g) => '${g['name']}|${g['grade']}'.toLowerCase())
        .toSet();

    void addOne(String name, String grade) {
      final g = grade.trim();
      if (g.isEmpty) return;
      final key = '${name.toLowerCase()}|${g.toLowerCase()}';
      if (existing.contains(key)) return;
      // Also skip if identical grade text already present under another name.
      if (list.any(
        (e) =>
            e['grade'].toString().toLowerCase() == g.toLowerCase() &&
            e['name'].toString().toLowerCase() == name.toLowerCase(),
      )) {
        return;
      }
      list.add({'name': name, 'grade': g});
      existing.add(key);
    }

    if (incoming is List) {
      for (final g in incoming) {
        if (g is Map) {
          addOne(
            (g['name'] ?? 'unknown').toString(),
            (g['grade'] ?? '').toString(),
          );
        } else if (g != null) {
          addOne('unknown', g.toString());
        }
      }
    } else if (incoming is String && incoming.trim().isNotEmpty) {
      addOne('Sunnah.com', incoming);
    }
    row['grades'] = list;
  }

  // Prefers the spine's own pre-built `reference` (text + url) untouched
  // when present -- for the fawaz-rebuilt books that's already the correct
  // letter-suffixed sunnah.com citation from `rebuild_from_fawaz.dart`'s
  // `citationSuffix`, not reconstructed here. Only falls through to
  // synthesizing a reference from `idInBook` when the spine has nothing
  // usable at all.
  //
  // TODO: the final fallback (`'${book.englishTitle} $idInBook'`) is exactly
  // the naive "book title + idInBook" concatenation that
  // NUMBERING_CORRUPTION_AUDIT.md identifies as the root cause of the
  // citation/numbering-scheme conflation bug for the 6 main books (idInBook
  // is fawaz's gapless sequential number, NOT sunnah.com's own lettered
  // citation number -- they only agree for un-lettered hadith). It's
  // currently unreachable for any book with a real `reference` on its spine
  // rows, but any future book/spine that reaches this branch with a missing
  // `reference` would silently reproduce the same bug. Consider making this
  // fallback impossible to reach silently (e.g. log a warning) rather than
  // producing a plausible-looking but scheme-conflated citation.
  Map<String, dynamic>? _normalizeReference(
    dynamic ref, {
    required BookDef book,
    required num? idInBook,
  }) {
    if (ref is Map) {
      final text = ref['text']?.toString();
      final url = ref['url']?.toString();
      if ((text != null && text.isNotEmpty) ||
          (url != null && url.isNotEmpty)) {
        return {if (text != null) 'text': text, if (url != null) 'url': url};
      }
      // fawaz-style {book, hadith} without text/url
      if (ref['hadith'] != null && book.sunnahSlug != null) {
        final n = ref['hadith'];
        return {
          'text': '${book.englishTitle} $n',
          'url': 'https://sunnah.com/${book.sunnahSlug}:$n',
        };
      }
    }
    if (idInBook != null && book.sunnahSlug != null) {
      return {
        'text': '${book.englishTitle} $idInBook',
        'url': 'https://sunnah.com/${book.sunnahSlug}:$idInBook',
      };
    }
    return null;
  }

  num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      final asInt = int.tryParse(t);
      if (asInt != null) return asInt;
      return double.tryParse(t);
    }
    return null;
  }

  void _writeJson(File file, Object data) {
    file.writeAsStringSync(
      const JsonEncoder.withIndent('\t').convert(data) + '\n',
    );
  }

  void _writeMinJson(File file, Object data) {
    file.writeAsStringSync(jsonEncode(data));
  }

  String p(
    String a, [
    String? b,
    String? c,
    String? d,
    String? e,
    String? f,
    String? g,
  ]) {
    final parts = [a, b, c, d, e, f, g].whereType<String>().toList();
    return parts.join(Platform.pathSeparator);
  }
}
