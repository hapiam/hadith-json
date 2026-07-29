import 'dart:convert';
import 'dart:io';

/// STAGE: one-time source-to-spine converter, repeatable/idempotent.
///
/// Converts hadithunlocked.com's raw JSON export
/// (`sources/hadithunlocked.com/original_source/hadith/hadithunlocked_{key}.json`)
/// into a spine file under `db/by_book/hadithunlocked/{key}.json`, in the
/// same shape `build_unified_editions.dart` already reads for every
/// "no-fawaz-coverage" book (modeled on `db/by_book/other_books/riyad_assalihin.json`).
///
/// idInBook: hadithunlocked's own `item.number` is NOT reliably unique or
/// monotonic across every book (verified directly -- tabarani has 340
/// duplicate numbers, suyuti has 17488, ibnrajab50 -- a 50-hadith
/// commentary work where one hadith spans many numbered-the-same
/// commentary items -- has 41 dupes out of 91 total items). So idInBook
/// here is just a sequential counter assigned in natural traversal order
/// (chapters/sections/items are already stored in the book's own reading
/// order), guaranteeing uniqueness universally instead of trusting a
/// source field that only happens to be well-behaved for some books
/// (bayhaqi/ibnhibban/nasai-kubra/ahmad-zuhd were all clean). The source's
/// own citation number is preserved separately in `reference.text` (via
/// `item.ref`, already formatted "book:number") and `reference.url` (via
/// `item.path`, a real working hadithunlocked.com link) so nothing is lost.
///
/// Chapters: hadithunlocked has a 2-level chapter/section structure, and
/// some chapters have items directly on the chapter AND sections
/// underneath (verified: 12 of bayhaqi's 71 chapters, 32 of tabarani's 54,
/// 27 of hakim's 48). The existing spine schema's `parentId` field already
/// supports exactly this 2-level shape (see `riyad_assalihin.json`), so:
/// each source chapter becomes a parentId=null row, each of its sections
/// becomes a parentId=<chapter row id> row, and a hadith's chapterId points
/// at whichever is the most specific enclosing row (the section if inside
/// one, otherwise the chapter itself).
///
/// Text: hadithunlocked self-discloses machine-translated English with a
/// leading "[AI] " or "[Machine] " tag (never silently passed off as
/// human). That tag is stripped from the stored text and recorded instead
/// as a top-level `isAiTranslated: true` sibling field on the hadith row --
/// NOT nested inside `english`, because `build_unified_editions.dart`'s
/// hadith-row-construction loop hardcodes exactly which keys survive out of
/// a spine row's `english` map (only `narrator`/`text`); any nested field
/// would be silently dropped. `classification`/`conclusion` (Musnad Ahmad)
/// already establish top-level-sibling as the surviving pattern for extra
/// per-hadith metadata -- `build_unified_editions.dart` needs a matching
/// line added for `isAiTranslated`.
///
/// Grade: hadithunlocked's `grade`/`grader` fields use "No Grade"/"N/A" as
/// literal placeholder strings for ungraded hadith (verified directly) --
/// filtered out rather than stored as fake grades.
///
/// Usage: dart run tool/import_hadithunlocked.dart
void main() {
  const books = [
    _BookConfig(2, 'muslim', 'Sahih Muslim'),
    _BookConfig(19, 'nasai-kubra', 'al-Sunan al-Kubra, Nasai'),
    _BookConfig(20, 'lulu-marjan', 'al-Lulu wa-al-Marjan (Muttafaq Alayh)'),
    _BookConfig(21, 'ibnrajab50', 'Jami al-Ulum wa-al-Hikam'),
    _BookConfig(22, 'ibnhibban', 'Sahih Ibn Hibban'),
    _BookConfig(23, 'bayhaqi', 'al-Sunan al-Kabir, Bayhaqi'),
    _BookConfig(24, 'tabarani', 'al-Mujam al-Kabir, Tabarani'),
    _BookConfig(25, 'hakim', 'Mustadrak al-Hakim'),
    _BookConfig(26, 'ahmad-zuhd', 'al-Zuhd, Ahmad'),
    _BookConfig(27, 'daraqutni', 'Sunan al-Daraqutni'),
    _BookConfig(28, 'bazzar', 'Musnad al-Bazzar'),
    _BookConfig(29, 'suyuti', 'Jam al-Jawami, Suyuti'),
    _BookConfig(30, 'ibnkhuzaymah', 'Sahih Ibn Khuzaymah'),
  ];

  Directory('db/by_book/hadithunlocked').createSync(recursive: true);

  for (final book in books) {
    final src = jsonDecode(
      File('sources/hadithunlocked.com/original_source/hadith/hadithunlocked_${book.key}.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final bookMeta = src['book'] as Map<String, dynamic>;
    final chapters = <Map<String, dynamic>>[];
    final hadiths = <Map<String, dynamic>>[];
    var nextChapterId = 1;
    var idInBook = 0;
    var aiTagged = 0;
    var withText = 0;
    var withGrade = 0;
    var essaySkipped = 0;
    // Muslim only (verified directly, 2026-07-29): `item.number` values
    // prefixed "i" (e.g. "i001".."i089") or "ir" (e.g. "ir0", "ir1") are
    // NOT narrated hadith at all -- they're fragments of Imam Muslim's own
    // prose muqaddimah (his introductory treatise on hadith methodology,
    // no isnad chain, no narrator). Confirmed by content: "ir3"'s Arabic
    // text opens mid-scholarly-discourse ("وأشْباهُ ما ذَكَرْنا مِن
    // كَلامِ أهْلِ العِلْمِ..."), nothing like a narrated report. sunnah.com's
    // own real Introduction (citations 1-7, genuine narrated hadith) isn't
    // covered by these fragments at all -- see the dedicated
    // `fetch_muslim_introduction.dart` script instead. Excluded here rather
    // than imported as fake hadith rows under a citation format
    // ("Sahih Muslim ir3") that doesn't correspond to anything real.
    final essayNumberRe = RegExp(r'^ir?\d');

    void addHadith(Map<String, dynamic> item, int chapterId) {
      if (essayNumberRe.hasMatch(item['number'] as String)) {
        essaySkipped++;
        return;
      }
      idInBook++;
      final chain = (item['chain'] as Map?)?.cast<String, dynamic>();
      final text = (item['text'] as Map?)?.cast<String, dynamic>();
      final chainAr = (chain?['ar'] as String?)?.trim() ?? '';
      final chainEn = (chain?['en'] as String?)?.trim() ?? '';
      final textAr = (text?['ar'] as String?)?.trim() ?? '';
      var textEn = (text?['en'] as String?)?.trim() ?? '';

      var isAi = false;
      if (textEn.startsWith('[AI]')) {
        isAi = true;
        textEn = textEn.substring(4).trim();
      } else if (textEn.startsWith('[Machine]')) {
        isAi = true;
        textEn = textEn.substring(9).trim();
      }
      if (isAi) aiTagged++;
      if (textEn.isNotEmpty) withText++;

      final grade = (item['grade'] as Map?)?.cast<String, dynamic>();
      final grader = (item['grader'] as Map?)?.cast<String, dynamic>();
      final gradeEn = (grade?['en'] as String?)?.trim() ?? '';
      final graderEn = (grader?['en'] as String?)?.trim() ?? '';
      List<Map<String, String>>? gradeList;
      if (gradeEn.isNotEmpty && gradeEn.toLowerCase() != 'no grade') {
        gradeList = [
          {'name': graderEn.isEmpty || graderEn.toLowerCase() == 'n/a' ? 'Unknown' : graderEn, 'grade': gradeEn},
        ];
        withGrade++;
      }

      final ref = (item['ref'] as String?) ?? '${book.key}:${item['number']}';
      final path = item['path'] as String?;
      final refNumber = ref.contains(':') ? ref.split(':').last : '$idInBook';

      hadiths.add({
        'id': book.bookId * 1000000 + idInBook,
        'idInBook': idInBook,
        'chapterId': chapterId,
        'bookId': book.bookId,
        'arabic': chainAr.isEmpty ? textAr : '$chainAr\n$textAr',
        'english': {'narrator': chainEn, 'text': textEn},
        if (isAi) 'isAiTranslated': true,
        'grade': gradeList,
        'reference': {'text': '${book.shortEnglishTitle} $refNumber', if (path != null) 'url': path},
      });
    }

    String stripAiTag(String s) {
      if (s.startsWith('[AI] ')) return s.substring(5).trim();
      if (s.startsWith('[Machine] ')) return s.substring(10).trim();
      return s;
    }

    for (final chRaw in (src['chapters'] as List)) {
      final ch = (chRaw as Map).cast<String, dynamic>();
      final title = (ch['title'] as Map?)?.cast<String, dynamic>();
      final chapterId = nextChapterId++;
      chapters.add({
        'id': chapterId,
        'bookId': book.bookId,
        'parentId': null,
        'names': {
          'ar': (title?['ar'] as String?) ?? '',
          'en': stripAiTag((title?['en'] as String?) ?? ''),
        },
      });

      final directItems = ch['items'];
      if (directItems is List) {
        for (final itemRaw in directItems) {
          addHadith((itemRaw as Map).cast<String, dynamic>(), chapterId);
        }
      }

      final sections = ch['sections'];
      if (sections is List) {
        for (final secRaw in sections) {
          final sec = (secRaw as Map).cast<String, dynamic>();
          final secTitle = (sec['title'] as Map?)?.cast<String, dynamic>();
          final sectionId = nextChapterId++;
          chapters.add({
            'id': sectionId,
            'bookId': book.bookId,
            'parentId': chapterId,
            'names': {
              'ar': (secTitle?['ar'] as String?) ?? '',
              'en': stripAiTag((secTitle?['en'] as String?) ?? ''),
            },
          });
          final secItems = sec['items'];
          if (secItems is List) {
            for (final itemRaw in secItems) {
              addHadith((itemRaw as Map).cast<String, dynamic>(), sectionId);
            }
          }
        }
      }
    }

    final spine = {
      'id': book.bookId,
      'metadata': {
        'id': book.bookId,
        'length': hadiths.length,
        'arabic': {
          'title': (bookMeta['title'] as Map?)?['ar'] ?? '',
          'author': (bookMeta['author'] as Map?)?['ar'] ?? '',
          'introduction': '',
        },
        'english': {
          'title': (bookMeta['title'] as Map?)?['en'] ?? book.shortEnglishTitle,
          'author': (bookMeta['author'] as Map?)?['en'] ?? '',
          'introduction': '',
        },
      },
      'chapters': chapters,
      'hadiths': hadiths,
    };

    final outPath = 'db/by_book/hadithunlocked/${book.key}.json';
    File(outPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spine));
    stdout.writeln(
      '${book.key}: ${hadiths.length} hadiths, ${chapters.length} chapters, '
      '$withText with English text ($aiTagged AI-tagged), $withGrade with a grade'
      '${essaySkipped > 0 ? ', $essaySkipped non-hadith essay fragments skipped' : ''} -> $outPath',
    );
  }
}

class _BookConfig {
  const _BookConfig(this.bookId, this.key, this.shortEnglishTitle);
  final int bookId;
  final String key;
  final String shortEnglishTitle;
}
