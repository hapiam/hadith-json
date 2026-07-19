import 'dart:convert';
import 'dart:io';

/// Rebuilds `db/by_book/the_9_books/{book}.json` directly from the cached
/// fawazahmed0/hadith-api canonical edition (`db/editions/files/ara-{book}.min.json`
/// + `eng-{book}.min.json`), replacing the old AhmedBaset-spine-plus-content-
/// matching pipeline for the 6 books where that pipeline's English/chapterId/
/// reference fields were found to be unreliable (see NUMBERING_CORRUPTION_AUDIT.md).
///
/// fawaz's own `hadithnumber` (sequential, gapless) becomes `idInBook`;
/// `reference.book` becomes `chapterId`; `arabicnumber` (decimal suffix =
/// letter, e.g. `1618.02` = "1618b") is used to reconstruct the real
/// sunnah.com citation instead of naively concatenating the book name with
/// idInBook. Arabic and English come straight from fawaz's own paired
/// record -- no cross-source join.
///
/// Usage: dart run tool/rebuild_from_fawaz.dart <book>
/// book is one of: bukhari muslim abudawud tirmidhi nasai ibnmajah malik
/// nawawi40 qudsi40 shahwaliullah40
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/rebuild_from_fawaz.dart <book>');
    exit(1);
  }
  final book = args.first;

  // fawaz's own edition key, where it differs from our catalog's book key.
  const fawazKey = {
    'nawawi40': 'nawawi',
    'qudsi40': 'qudsi',
    'shahwaliullah40': 'dehlawi',
  };
  final sourceKey = fawazKey[book] ?? book;

  // 'citation' (default): "{title} N[letter]", url "sunnah.com/{urlKey}:N[letter]"
  // (bukhari/muslim/etc., and the flat forties -- arabicnumber is always a
  // plain integer for the forties so the letter-suffix logic is a no-op).
  // 'malik': no text, url is "sunnah.com/{urlKey}/{book}/{hadith}" (Malik's
  // own citation convention -- verified directly against sunnah.com).
  const referenceStyle = {'malik': 'malik'};
  // Forties cite as "Hadith N, {title}" rather than "{title} N".
  const fortyHadithBooks = {'nawawi40', 'qudsi40', 'shahwaliullah40'};

  // Hand-verified against sunnah.com (chapter-boundary hadith the neighbor-
  // inference pass below couldn't resolve on its own -- both neighbors sit
  // in different chapters and there's no way to tell which side this one
  // belongs to without checking the real page). idInBook -> chapterId.
  const manualOverrides = {
    'bukhari': {
      521: 9, // Times of the Prayers
      2384: 42, // Distribution of Water
      2516: 48, // Mortgaging
      2711: 54, // Conditions
      3156: 58, // Jizyah and Mawaada'ah
      4978: 66, // Virtues of the Qur'an
    },
    // These 3 are genuine fawaz reference.book errors (not chapterUnknown
    // placeholders) -- isolated-outlier scan flagged them, sunnah.com
    // confirmed the real book differs from what fawaz's own data claims.
    'tirmidhi': {
      2298: 35, // Chapters On Witnesses (fawaz wrongly said 32, Al-Qadar)
      2795: 43, // Chapters on Manners (fawaz wrongly said 39)
      3723: 49, // Chapters on Virtues (fawaz wrongly said 47)
    },
    // chapterUnknown placeholders (fawaz reference.book=0/hadith=0, arabicnumber
    // null) that neighbor-inference couldn't resolve because the two sides
    // disagree (5111=book 35, 5114=book 36). Confirmed on sunnah.com: these two
    // are actually 1975c/1975d (sunnah.com merges them onto one page), same
    // book-35 "Sacrifices" citation family as neighbor 5111 (1975b) -- fawaz's
    // own arabicnumber parser just failed on this specific pair.
    'muslim': {
      5112: 35, // The Book of Sacrifices (= sunnah.com 1975c)
      5113: 35, // The Book of Sacrifices (= sunnah.com 1975d)
    },
  };

  const bookIdPrefix = {
    'bukhari': 1,
    'muslim': 2,
    'nasai': 3,
    'abudawud': 4,
    'tirmidhi': 5,
    'ibnmajah': 6,
  };
  const englishTitle = {
    'bukhari': 'Sahih al-Bukhari',
    'muslim': 'Sahih Muslim',
    'abudawud': 'Sunan Abi Dawud',
    'tirmidhi': "Jami` at-Tirmidhi",
    'nasai': "Sunan an-Nasa'i",
    'ibnmajah': 'Sunan Ibn Majah',
    'malik': 'Muwatta Malik',
    'nawawi40': '40 Hadith an-Nawawi',
    'qudsi40': '40 Hadith Qudsi',
    'shahwaliullah40': '40 Hadith Shah Waliullah',
  };
  const urlKey = {
    'bukhari': 'bukhari',
    'muslim': 'muslim',
    'abudawud': 'abudawud',
    'tirmidhi': 'tirmidhi',
    'nasai': 'nasai',
    'ibnmajah': 'ibnmajah',
    'malik': 'malik',
    'nawawi40': 'nawawi40',
    'qudsi40': 'qudsi40',
    'shahwaliullah40': 'shahwaliullah40',
  };

  final root = Directory.current.path;
  final araFile = File('$root/db/editions/files/ara-$sourceKey.min.json');
  final engFile = File('$root/db/editions/files/eng-$sourceKey.min.json');
  final existingPath = fortyHadithBooks.contains(book)
      ? '$root/db/by_book/forties/$book.json'
      : '$root/db/by_book/the_9_books/$book.json';
  final existingFile = File(existingPath);

  final ara = jsonDecode(araFile.readAsStringSync()) as Map<String, dynamic>;
  final eng = jsonDecode(engFile.readAsStringSync()) as Map<String, dynamic>;
  final existing = jsonDecode(existingFile.readAsStringSync()) as Map<String, dynamic>;

  // Book-id prefix for the `id = prefix * 1_000_000 + idInBook` scheme (the
  // 6 main books) doesn't apply to malik/the forties -- their existing `id`
  // values are `globalOffset + idInBook` instead (a single incrementing
  // counter across every book in the old spine, not per-book). Detected
  // from the existing data's own first entry rather than hardcoded, so it
  // stays correct even if upstream ordering ever shifts.
  final existingHadiths = (existing['hadiths'] as List).cast<Map<String, dynamic>>();
  final firstExisting = existingHadiths.first;
  final globalIdOffset =
      (firstExisting['id'] as num).toInt() - (firstExisting['idInBook'] as num).toInt();
  final prefix = bookIdPrefix[book];
  final bookIdField = (firstExisting['bookId'] as num).toInt();

  final araHadiths = (ara['hadiths'] as List).cast<Map<String, dynamic>>();
  final engByNum = <int, Map<String, dynamic>>{
    for (final h in (eng['hadiths'] as List).cast<Map<String, dynamic>>())
      (h['hadithnumber'] as num).toInt(): h,
  };

  // Existing chapters list, keyed by (id, english-name-lowercase) so we can
  // backfill Arabic names for chapters whose id+name still line up with
  // fawaz's own numbering. Anything that doesn't match gets a null Arabic
  // name -- flagged for manual follow-up rather than guessed.
  final existingChapters = (existing['chapters'] as List).cast<Map<String, dynamic>>();
  final existingByIdAndName = <String, Map<String, dynamic>>{
    for (final c in existingChapters)
      '${c['id']}|${((c['names'] as Map)['en'] as String).trim().toLowerCase()}': c,
  };

  final sections = ((ara['metadata'] as Map)['sections'] as Map);
  final newChapters = <Map<String, dynamic>>[];
  var unmatchedChapterNames = 0;
  for (final entry in sections.entries) {
    final id = int.parse(entry.key.toString());
    final enName = (entry.value as String).trim();
    if (enName.isEmpty) continue; // section 0 ("Introduction") has no title in some editions
    final key = '$id|${enName.toLowerCase()}';
    final match = existingByIdAndName[key];
    final arName = match != null ? (match['names'] as Map)['ar'] as String? : null;
    if (arName == null) unmatchedChapterNames++;
    newChapters.add({
      'id': id,
      'bookId': bookIdField,
      'parentId': null,
      'names': {
        if (arName != null) 'ar': arName,
        'en': enName,
      },
    });
  }

  String citationSuffix(dynamic arabicnumber) {
    final s = arabicnumber.toString();
    if (!s.contains('.')) return s;
    final parts = s.split('.');
    final base = parts[0];
    final frac = int.parse(parts[1]); // "01" -> 1, "02" -> 2, ...
    final letter = String.fromCharCode('a'.codeUnitAt(0) + frac - 1);
    return '$base$letter';
  }

  final newHadiths = <Map<String, dynamic>>[];
  var missingEnglish = 0;
  var blankContent = 0;
  var chapterUnknown = 0;
  for (final h in araHadiths) {
    final hadithNum = (h['hadithnumber'] as num).toInt();
    final engEntry = engByNum[hadithNum];
    if (engEntry == null) missingEnglish++;

    final refMap = h['reference'] as Map;
    final refBook = (refMap['book'] as num).toInt();
    final refHadith = (refMap['hadith'] as num).toInt();
    // fawaz uses book=0/hadith=0 together as its own "couldn't determine the
    // chapter" placeholder -- distinct from a real book=0 Introduction
    // section (which always has a real, non-zero in-book hadith number).
    // Trusting this placeholder as chapterId 0 would silently mislabel real
    // main-book content as front matter, so it's tagged unknown instead.
    final isUnknownChapter = refBook == 0 && refHadith == 0;
    if (isUnknownChapter) chapterUnknown++;
    final chapterId = isUnknownChapter ? null : refBook;

    final arabicText = h['text'] as String? ?? '';
    final englishText = engEntry?['text'] as String? ?? '';
    final isBlank = arabicText.trim().isEmpty && englishText.trim().isEmpty;
    if (isBlank) blankContent++;

    final citation = citationSuffix(h['arabicnumber']);
    final Map<String, dynamic> reference;
    if (referenceStyle[book] == 'malik') {
      // Malik cites by book/in-book-hadith position, not a bare running
      // number -- verified directly against sunnah.com/malik/{book}/{hadith}.
      // No separate citation text; the old data never had one either.
      reference = {'url': 'https://sunnah.com/${urlKey[book]}/$refBook/$refHadith'};
    } else if (fortyHadithBooks.contains(book)) {
      reference = {
        'text': 'Hadith $citation, ${englishTitle[book]}',
        'url': 'https://sunnah.com/${urlKey[book]}:$citation',
      };
    } else {
      reference = {
        'text': '${englishTitle[book]} $citation',
        'url': 'https://sunnah.com/${urlKey[book]}:$citation',
      };
    }

    newHadiths.add({
      'id': globalIdOffset + hadithNum,
      'idInBook': hadithNum,
      'chapterId': chapterId,
      'bookId': bookIdField,
      'arabic': arabicText,
      'english': {
        'narrator': '',
        'text': englishText,
      },
      if (isUnknownChapter) 'chapterUnknown': true,
      'reference': reference,
      if (isBlank) 'noSourceContent': true,
    });
  }

  // Malik only: fawaz's own edition caps at 1,858 hadith (independently
  // verified across 6 languages, see README's "Muwatta Malik: 1,858, not
  // 1,942" section) -- 127 more real hadith exist in the old spine beyond
  // that with no fawaz coverage at all. Unlike the 6 main books, Malik's
  // spine was never subject to this session's content-matching bug (its
  // Arabic was "unchanged" per README, arabic/english always came from the
  // same original pairing) -- so these are carried forward unchanged rather
  // than dropped, using the same idInBook/id numbering they already have.
  var appendedFromSpine = 0;
  if (book == 'malik') {
    final fawazMaxNum = araHadiths
        .map((h) => (h['hadithnumber'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);
    for (final h in existingHadiths) {
      if ((h['idInBook'] as num).toInt() <= fawazMaxNum) continue;
      newHadiths.add(Map<String, dynamic>.from(h));
      appendedFromSpine++;
    }
  }

  // Second pass: for chapterUnknown entries, infer chapterId from the
  // nearest resolved neighbors on each side (same "isolated outlier"
  // technique used all session, run in reverse) -- if both sides agree,
  // it's a safe inference; if they disagree or one side has no resolved
  // neighbor at all, leave it genuinely unknown rather than guess.
  var inferred = 0;
  for (var i = 0; i < newHadiths.length; i++) {
    if (newHadiths[i]['chapterId'] != null) continue;
    int? prevChapter;
    for (var j = i - 1; j >= 0; j--) {
      if (newHadiths[j]['chapterId'] != null) {
        prevChapter = newHadiths[j]['chapterId'] as int;
        break;
      }
    }
    int? nextChapter;
    for (var j = i + 1; j < newHadiths.length; j++) {
      if (newHadiths[j]['chapterId'] != null) {
        nextChapter = newHadiths[j]['chapterId'] as int;
        break;
      }
    }
    if (prevChapter != null && prevChapter == nextChapter) {
      newHadiths[i]['chapterId'] = prevChapter;
      newHadiths[i]['chapterIdInferred'] = true;
      inferred++;
    }
  }

  // Third pass: hand-verified overrides -- both for chapterUnknown entries
  // still left after inference, and for entries where fawaz's own
  // reference.book was confirmed wrong against sunnah.com directly (the
  // isolated-outlier scan catches these; they're rare but real).
  final overrides = manualOverrides[book] ?? const <int, int>{};
  var overridden = 0;
  for (final h in newHadiths) {
    final idInBook = h['idInBook'] as int;
    final override = overrides[idInBook];
    if (override != null && h['chapterId'] != override) {
      h['chapterId'] = override;
      h.remove('chapterUnknown');
      h.remove('chapterIdInferred');
      overridden++;
    }
  }

  final rebuilt = {
    'id': existing['id'],
    'metadata': {
      'id': existing['id'],
      'length': newHadiths.length,
      'arabic': (existing['metadata'] as Map)['arabic'],
      'english': (existing['metadata'] as Map)['english'],
    },
    'chapters': newChapters,
    'hadiths': newHadiths,
  };

  const encoder = JsonEncoder.withIndent('\t');
  existingFile.writeAsStringSync('${encoder.convert(rebuilt)}\n');

  stdout.writeln('$book: rebuilt ${newHadiths.length} hadith, ${newChapters.length} chapters');
  stdout.writeln('  missing fawaz English entry: $missingEnglish');
  stdout.writeln('  blank arabic+english (tagged noSourceContent): $blankContent');
  stdout.writeln('  chapterId unknown (fawaz book=0/hadith=0 placeholder, tagged chapterUnknown): $chapterUnknown');
  stdout.writeln('    of which inferred from matching neighbors (chapterIdInferred): $inferred');
  stdout.writeln('    fixed via hand-verified override: $overridden');
  stdout.writeln('    still genuinely unresolved (chapterId left null): ${chapterUnknown - inferred - overridden}');
  stdout.writeln('  chapters with no backfilled Arabic name: $unmatchedChapterNames / ${newChapters.length}');
  if (appendedFromSpine > 0) {
    stdout.writeln('  appended unchanged from old spine (beyond fawaz coverage): $appendedFromSpine');
  }
}
