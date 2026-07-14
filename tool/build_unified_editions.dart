import 'dart:convert';
import 'dart:io';

/// Build canonical `db/unified/` editions from AhmedBaset spine + fawaz + sagad.
/// Re-runnable: wipes and regenerates `db/unified/`.
///
/// Usage: dart run tool/build_unified_editions.dart [repoRoot]
void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args[0] : '.');
  final builder = UnifiedBuilder(root);
  builder.run();
}

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
    reportLines.add('- AhmedBaset spine: `db/by_book` (structure, arabic, english narrator/text, chapters)');
    reportLines.add('- muallimai: grade + reference already merged into spine');
    reportLines.add('- fawazahmed0: `db/editions/files/{lang}-{book}.min.json` (non-English translations + multi-grader grades)');
    reportLines.add('- sagad: `db/by_locale/id/by_book` Indonesian drafts for books without fawaz `ind-*`');
    reportLines.add('');

    _scanDiscardedDuplicates();

    for (final book in books) {
      stdout.writeln('Building ${book.bookKey}...');
      _buildBook(book);
    }

    _writeCatalog();
    _writeReport();
    _writeMatrix();

    final elapsed = DateTime.now().difference(started);
    stdout.writeln(
      'Done: ${catalogEditions.length} editions in ${elapsed.inSeconds}s → ${unifiedDir.path}',
    );
  }

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
      reportLines.add('No duplicate language variants discarded (only ara-*1 handled separately).');
    } else {
      for (final d in discarded) {
        reportLines.add('- $d');
      }
    }
    reportLines.add('');
  }

  void _buildBook(BookDef book) {
    final spinePath = p(root.path, 'db', 'by_book', book.spineRelative);
    final spineFile = File(spinePath);
    if (!spineFile.existsSync()) {
      reportLines.add('WARN: missing spine ${book.spineRelative}');
      return;
    }

    final spine = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final chapters = (spine['chapters'] as List<dynamic>? ?? const [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
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
        'translations': <String, dynamic>{
          if (enTrans != null) 'en': enTrans,
        },
        'grades': grades,
        'reference': reference,
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
    final hasFawazInd = book.fawazBook != null &&
        File(p(root.path, 'db', 'editions', 'files', 'ind-${book.fawazBook}.min.json'))
            .existsSync();
    if (!hasFawazInd) {
      _absorbSagadIndonesian(book, byId, masters, sources);
    }

    // Write master by_book file.
    final masterOut = {
      'metadata': {
        'bookId': book.bookId,
        'bookKey': book.bookKey,
        'arabic': meta['arabic'],
        'english': meta['english'],
        'chapters': chapters
            .map((c) => {
                  'id': c['id'],
                  'arabic': c['arabic'],
                  'english': c['english'],
                })
            .toList(),
        'sources': sources.toList()..sort(),
      },
      'hadiths': masters,
    };
    _writeJson(File(p(byBookDir.path, '${book.bookKey}.json')), masterOut);
    _writeMinJson(File(p(byBookDir.path, '${book.bookKey}.min.json')), masterOut);

    // Always emit Arabic + English views for every spine book (even if English
    // text is empty upstream — e.g. some Darimi rows).
    _emitArabicEdition(book, meta, chapters, masters, sources, undiacritized: false);
    if (book.fawazBook != null &&
        File(p(root.path, 'db', 'editions', 'files', 'ara-${book.fawazBook}1.min.json'))
            .existsSync()) {
      _emitArabicEdition(book, meta, chapters, masters, sources, undiacritized: true);
    }

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
      forceEmit: true,
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
          translations[lang.iso] = {
            'narrator': '',
            'text': text,
          };
          sources.add('fawaz');
        }
      }

      // Always merge grades when present on this language file.
      _mergeGrades(row, h['grades']);
      if (viaArabicOnly) {
        // tracked in stats only
      }
    }

    stat.spineCovered = covered.length;
    matchStats.add(stat);
    sources.add('fawaz');
  }

  void _joinUndiacritizedArabic(
    BookDef book,
    Map<num, Map<String, dynamic>> byIdInBook,
    Set<String> sources,
  ) {
    final f = File(
      p(root.path, 'db', 'editions', 'files', 'ara-${book.fawazBook}1.min.json'),
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

  void _absorbSagadIndonesian(
    BookDef book,
    Map<int, Map<String, dynamic>> byId,
    List<Map<String, dynamic>> masters,
    Set<String> sources,
  ) {
    final localePath = p(root.path, 'db', 'by_locale', 'id', 'by_book', book.spineRelative);
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
        'chapters': chapters
            .map((c) => {
                  'id': c['id'],
                  'arabic': c['arabic'],
                  'english': c['english'],
                })
            .toList(),
      },
      'hadiths': hadiths,
    };
    _writeEditionFiles(editionId, out);
    catalogEditions.add({
      'id': editionId,
      'bookKey': book.bookKey,
      'bookId': book.bookId,
      'language': langIso,
      'languageName': langName,
      'name': '${book.englishTitle} ($langName)',
      'hadithCount': hadiths.length,
      'features': features,
      'path': 'files/$editionId.json',
      'sources': sources.toList()..sort(),
    });
  }

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
      hadiths.add({
        'id': row['id'],
        'idInBook': row['idInBook'],
        'chapterId': row['chapterId'],
        'bookId': row['bookId'],
        'arabic': row['arabic'],
        'translation': translation,
        'grades': row['grades'],
        'reference': row['reference'],
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
        'chapters': chapters
            .map((c) => {
                  'id': c['id'],
                  'arabic': c['arabic'],
                  'english': c['english'],
                })
            .toList(),
      },
      'hadiths': hadiths,
    };
    _writeEditionFiles(editionId, out);
    catalogEditions.add({
      'id': editionId,
      'bookKey': book.bookKey,
      'bookId': book.bookId,
      'language': langIso,
      'languageName': langName,
      'name': '${book.englishTitle} ($langName)',
      'hadithCount': hadiths.length,
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
      'schemaVersion': 1,
      'editions': catalogEditions,
    };
    _writeJson(File(p(unifiedDir.path, 'catalog.json')), catalog);
    _writeMinJson(File(p(unifiedDir.path, 'catalog.min.json')), catalog);
  }

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
    final muslimStats =
        matchStats.where((s) => s.editionName.contains('muslim')).toList();
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

    File(p(unifiedDir.path, 'REPORT.md')).writeAsStringSync(
      '${reportLines.join('\n')}\n',
    );
  }

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
      present.putIfAbsent(e['bookKey'] as String, () => {}).add(e['language'] as String);
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
          .map((g) => {
                'name': (g['name'] ?? 'unknown').toString(),
                'grade': (g['grade'] ?? '').toString(),
              })
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
      if (list.any((e) => e['grade'].toString().toLowerCase() == g.toLowerCase() &&
          e['name'].toString().toLowerCase() == name.toLowerCase())) {
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

  Map<String, dynamic>? _normalizeReference(
    dynamic ref, {
    required BookDef book,
    required num? idInBook,
  }) {
    if (ref is Map) {
      final text = ref['text']?.toString();
      final url = ref['url']?.toString();
      if ((text != null && text.isNotEmpty) || (url != null && url.isNotEmpty)) {
        return {
          if (text != null) 'text': text,
          if (url != null) 'url': url,
        };
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

  String p(String a, [String? b, String? c, String? d, String? e, String? f, String? g]) {
    final parts = [a, b, c, d, e, f, g].whereType<String>().toList();
    return parts.join(Platform.pathSeparator);
  }
}
