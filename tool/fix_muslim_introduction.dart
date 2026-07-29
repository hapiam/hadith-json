import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine patch, run AFTER `import_hadithunlocked.dart`
/// (Muslim), idempotent (checks for the marker citations before touching
/// anything).
///
/// sunnah.com's real Sahih Muslim Introduction is citations 1, 2, 3, 4a,
/// 4b, 5, 6, 7 (verified directly, 2026-07-29, fetching each page). It is
/// NOT the same thing as hadithunlocked's own "ir"/"i0NN"-numbered items
/// (Imam Muslim's prose muqaddimah, already excluded during import -- see
/// `import_hadithunlocked.dart`'s own doc comment).
///
/// hadithunlocked's raw file DOES separately have plain-numbered items "1"
/// through "7" at the right path (`/muslim/0/2`, `/muslim/0/3`,
/// `/muslim/0/4` -- matching sunnah.com's own bab boundaries exactly), but
/// two problems: (1) the import assigned them the wrong `chapterId` (their
/// section's own sequential chapter id, not `chapterId 1` "Introduction");
/// (2) content-checked directly against sunnah.com, items "1"-"4" matched
/// byte-for-byte, but hadithunlocked's own "5" has a COMPLETELY DIFFERENT
/// narrator chain than sunnah.com's real citation 5 (same matn -- "it is
/// enough of a lie to narrate everything one hears" -- but a different
/// isnad, which hadith science treats as a genuinely different narration,
/// not just a transcription variant), and hadithunlocked has no "4b" at
/// all. Rather than guess which of hadithunlocked's own "5"/"6"/"7" are
/// safe to keep, this script drops ALL of hadithunlocked's mis-chaptered
/// "1"-"7" rows and replaces them with 8 rows transcribed directly from
/// sunnah.com's own live pages (citations 1, 2, 3, 4a, 4b, 5, 6, 7),
/// verified word-for-word against the real source rather than assumed.
///
/// Usage: dart run tool/fix_muslim_introduction.dart
void main() {
  const path = 'db/by_book/hadithunlocked/muslim.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();
  final chapters = (data['chapters'] as List)
      .map((c) => Map<String, dynamic>.from(c as Map))
      .toList();

  final introChapterId = chapters.firstWhere(
    (c) => c['names']['en'] == 'Introduction',
  )['id'] as int;
  final bookId = hadiths.first['bookId'] as int;

  // Drop hadithunlocked's own mis-chaptered "1".."7" (see doc comment).
  const wrongNumbers = {'1', '2', '3', '4', '5', '6', '7'};
  final removed = hadiths
      .where(
        (h) => wrongNumbers.contains(
          (h['reference']['text'] as String).split(' ').last,
        ),
      )
      .toList();
  hadiths.removeWhere(
    (h) => wrongNumbers.contains(
      (h['reference']['text'] as String).split(' ').last,
    ),
  );
  stdout.writeln('Removed ${removed.length} mis-chaptered rows: '
      '${removed.map((h) => h['reference']['text']).join(', ')}');

  // Transcribed directly from sunnah.com/muslim:1 through :7, 2026-07-29 --
  // see this file's own doc comment.
  final introRows = <Map<String, dynamic>>[
    {
      'citation': '1',
      'arabic':
          'وَحَدَّثَنَا أَبُو بَكْرِ بْنُ أَبِي شَيْبَةَ، حَدَّثَنَا غُنْدَرٌ، عَنْ شُعْبَةَ، ح وَحَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، وَابْنُ، بَشَّارٍ قَالاَ حَدَّثَنَا مُحَمَّدُ بْنُ جَعْفَرٍ، حَدَّثَنَا شُعْبَةُ، عَنْ مَنْصُورٍ، عَنْ رِبْعِيِّ بْنِ حِرَاشٍ، أَنَّهُ سَمِعَ عَلِيًّا، - رضى الله عنه - يَخْطُبُ قَالَ قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم ‏"‏ لاَ تَكْذِبُوا عَلَىَّ فَإِنَّهُ مَنْ يَكْذِبْ عَلَىَّ يَلِجِ النَّارَ ‏"‏ ‏.‏',
      'english':
          'Abū Bakr ibn Abī Shaybah narrated to us that Ghundar narrated to us, on authority of Shu’bah; and Muhammad bin ul-Muthannā and Ibn Bashār both narrated to us, they said: Muhammad bin Ja’far narrated to us, Shu’bah narrated to us, on authority of Mansūr, on authority of Rab’iy ibn Hirāsh, that he heard Alī, may Allah be pleased with him, giving a Khutbah and he said that the Messenger of Allah, peace and blessings of Allah upon him, said: ‘Do not lie upon me; indeed whoever lies upon me will enter the Fire’.',
    },
    {
      'citation': '2',
      'arabic':
          'وَحَدَّثَنِي زُهَيْرُ بْنُ حَرْبٍ، حَدَّثَنَا إِسْمَاعِيلُ، - يَعْنِي ابْنَ عُلَيَّةَ - عَنْ عَبْدِ الْعَزِيزِ بْنِ صُهَيْبٍ، عَنْ أَنَسِ بْنِ مَالِكٍ، أَنَّهُ قَالَ إِنَّهُ لَيَمْنَعُنِي أَنْ أُحَدِّثَكُمْ حَدِيثًا كَثِيرًا أَنَّ رَسُولَ اللَّهِ صلى الله عليه وسلم قَالَ ‏"‏ مَنْ تَعَمَّدَ عَلَىَّ كَذِبًا فَلْيَتَبَوَّأْ مَقْعَدَهُ مِنَ النَّارِ ‏"‏ ‏.‏',
      'english':
          'Zuhayr bin Harb narrated to me, Ismā’īl, rather, Ibn Ulayyah narrated to us, on authority of Abd il-Azīz ibn Suhayb, on authority of Anas bin Mālik, that he said: ‘Indeed what prevents me from relating to you a great number of Ḥadīth is that the Messenger of Allah, peace and blessings of Allah upon him, said: ‘Whoever intends to lie upon me, then let him take his seat in the Fire.’',
    },
    {
      'citation': '3',
      'arabic':
          'وَحَدَّثَنَا مُحَمَّدُ بْنُ عُبَيْدٍ الْغُبَرِيُّ، حَدَّثَنَا أَبُو عَوَانَةَ، عَنْ أَبِي حَصِينٍ، عَنْ أَبِي صَالِحٍ، عَنْ أَبِي هُرَيْرَةَ، قَالَ قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم ‏"‏ مَنْ كَذَبَ عَلَىَّ مُتَعَمِّدًا فَلْيَتَبَوَّأْ مَقْعَدَهُ مِنَ النَّارِ ‏"‏ ‏.‏',
      'english':
          'Muhammad bin Ubayd il-Ghubarī narrated to us, Abū Awānah narrated to us, on authority of Abī Hasīn, on authority of Abī Sālih, on authority of Abū Hurayrah, he said, the Messenger of Allah, peace and blessings of Allah upon him, said: ‘Whoever lies upon me intentionally, then let him take his seat in the Fire’.',
    },
    {
      'citation': '4a',
      'arabic':
          'وَحَدَّثَنَا مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ نُمَيْرٍ، حَدَّثَنَا أَبِي، حَدَّثَنَا سَعِيدُ بْنُ عُبَيْدٍ، حَدَّثَنَا عَلِيُّ بْنُ رَبِيعَةَ، قَالَ أَتَيْتُ الْمَسْجِدَ وَالْمُغِيرَةُ أَمِيرُ الْكُوفَةِ قَالَ فَقَالَ الْمُغِيرَةُ سَمِعْتُ رَسُولَ اللَّهِ صلى الله عليه وسلم يَقُولُ ‏"‏ إِنَّ كَذِبًا عَلَىَّ لَيْسَ كَكَذِبٍ عَلَى أَحَدٍ فَمَنْ كَذَبَ عَلَىَّ مُتَعَمِّدًا فَلْيَتَبَوَّأْ مَقْعَدَهُ مِنَ النَّارِ ‏"‏ ‏.‏',
      'english':
          'Muhammad bin Abd Allah ibn Numayr narrated to us, my father narrated to us, Sa’īd bin Ubayd narrated to us, Alī bin Rabī’ah narrated to us, he said: ‘I arrived at the Masjid and al-Mughīrah, the Amīr of al-Kūfah said: ‘I heard the Messenger of Allah, peace and blessings of Allah upon him, saying, ‘Indeed a lie upon me is not like a lie upon anyone else, for whoever lies upon me intentionally, then he shall take his seat in the Fire’.’',
    },
    {
      'citation': '4b',
      'arabic':
          'وَحَدَّثَنِي عَلِيُّ بْنُ حُجْرٍ السَّعْدِيُّ، حَدَّثَنَا عَلِيُّ بْنُ مُسْهِرٍ، أَخْبَرَنَا مُحَمَّدُ بْنُ قَيْسٍ الأَسَدِيُّ، عَنْ عَلِيِّ بْنِ رَبِيعَةَ الأَسَدِيِّ، عَنِ الْمُغِيرَةِ بْنِ شُعْبَةَ، عَنِ النَّبِيِّ صلى الله عليه وسلم بِمِثْلِهِ وَلَمْ يَذْكُرْ ‏"‏ إِنَّ كَذِبًا عَلَىَّ لَيْسَ كَكَذِبٍ عَلَى أَحَدٍ ‏"‏ ‏.‏',
      'english':
          '’Alī bin Hujr as-Sa’dī narrated to us, Alī bin Mushir narrated to us, Muhammad bin Qays il-Asadī informed us, on authority of Alī ibn Rabī’at al-Asadī, on authority of al-Mughīrat ibn Shu’bah, on authority of the Prophet, peace and blessings of Allah upon him a similar narration, however he did not mention the words ‘Indeed a lie upon me is not like a lie upon anyone else’.',
    },
    {
      'citation': '5',
      'arabic':
          'وَحَدَّثَنَا عُبَيْدُ اللَّهِ بْنُ مُعَاذٍ الْعَنْبَرِيُّ، حَدَّثَنَا أَبِي ح، وَحَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، حَدَّثَنَا عَبْدُ الرَّحْمَنِ بْنُ مَهْدِيٍّ، قَالاَ حَدَّثَنَا شُعْبَةُ، عَنْ خُبَيْبِ بْنِ عَبْدِ الرَّحْمَنِ، عَنْ حَفْصِ بْنِ عَاصِمٍ، قَالَ قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم ‏"‏ كَفَى بِالْمَرْءِ كَذِبًا أَنْ يُحَدِّثَ بِكُلِّ مَا سَمِعَ ‏" ‏ ‏.‏',
      'english':
          'Ubayd Allah bin Mu’ādh al-Anbarī narrated to us, my father narrated to us; and Muhammad bin ul-Muthannā narrated to us, Abd ur-Rahman bin Mahdī both narrated to us: Shu’bah narrated to us, on authority of Khubayb bin Abd ir-Rahman, on authority of Hafs bin Āsim, on authority of Abī Hurayrah, he said, the Messenger of Allah, peace and blessings of Allah upon him, said: ‘It is enough of a lie for a man to narrate everything he hears’.',
    },
    {
      'citation': '6',
      'arabic':
          'وَحَدَّثَنِي مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ نُمَيْرٍ، وَزُهَيْرُ بْنُ حَرْبٍ، قَالاَ حَدَّثَنَا عَبْدُ اللَّهِ بْنُ يَزِيدَ، قَالَ حَدَّثَنِي سَعِيدُ بْنُ أَبِي أَيُّوبَ، قَالَ حَدَّثَنِي أَبُو هَانِئٍ، عَنْ أَبِي عُثْمَانَ، مُسْلِمِ بْنِ يَسَارٍ عَنْ أَبِي هُرَيْرَةَ، عَنْ رَسُولِ اللَّهِ صلى الله عليه وسلم أَنَّهُ قَالَ ‏"‏ سَيَكُونُ فِي آخِرِ أُمَّتِي أُنَاسٌ يُحَدِّثُونَكُمْ مَا لَمْ تَسْمَعُوا أَنْتُمْ وَلاَ آبَاؤُكُمْ فَإِيَّاكُمْ وَإِيَّاهُمْ ‏"‏ ‏.‏',
      'english':
          'Muhammad bin Abd Allah bin Numayr and Zuhayr bin Harb narrated to me, they said Abd Allah bin Yazīd narrated to us, he said Sa’īd bin Abī Ayyūb narrated to me, he said Abū Hāni’ narrated to me, on authority of Uthmān Muslim bin Yasār, on authority of Abī Hurayrah, on authority of the Messenger of Allah, peace and blessings of Allah upon him, he said: ‘There will be in the last of my nation a people narrating to you what you nor your fathers heard, so beware of them’.',
    },
    {
      'citation': '7',
      'arabic':
          'وَحَدَّثَنِي حَرْمَلَةُ بْنُ يَحْيَى بْنِ عَبْدِ اللَّهِ بْنِ حَرْمَلَةَ بْنِ عِمْرَانَ التُّجِيبِيُّ، قَالَ حَدَّثَنَا ابْنُ وَهْبٍ، قَالَ حَدَّثَنِي أَبُو شُرَيْحٍ، أَنَّهُ سَمِعَ شَرَاحِيلَ بْنَ يَزِيدَ، يَقُولُ أَخْبَرَنِي مُسْلِمُ بْنُ يَسَارٍ، أَنَّهُ سَمِعَ أَبَا هُرَيْرَةَ، يَقُولُ قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم ‏"‏ يَكُونُ فِي آخِرِ الزَّمَانِ دَجَّالُونَ كَذَّابُونَ يَأْتُونَكُمْ مِنَ الأَحَادِيثِ بِمَا لَمْ تَسْمَعُوا أَنْتُمْ وَلاَ آبَاؤُكُمْ فَإِيَّاكُمْ وَإِيَّاهُمْ لاَ يُضِلُّونَكُمْ وَلاَ يَفْتِنُونَكُمْ ‏"‏ ‏.‏',
      'english':
          'Harmalah bin Yahyā bin Abd Allah bin Harmalah bin Imrān at-Tujībī narrated to me, he said Ibn Wahb narrated to us, he said Abū Shurayh narrated to me that he heard Sharāhīl bin Yazīd saying ‘Muslim bin Yasār informed me that he heard Abā Hurayrah saying, the Messenger of Allah, peace and blessings of Allah upon him, said: ‘There will be in the end of time charlatan liars coming to you with narrations that you nor your fathers heard, so beware of them lest they misguide you and cause you tribulations’.’',
    },
  ];

  final newRows = <Map<String, dynamic>>[
    for (var i = 0; i < introRows.length; i++)
      {
        'chapterId': introChapterId,
        'bookId': bookId,
        'arabic': introRows[i]['arabic'],
        'english': {'narrator': '', 'text': introRows[i]['english']},
        'grade': null,
        'reference': {
          'text': 'Sahih Muslim ${introRows[i]['citation']}',
          'url': 'https://sunnah.com/muslim:${introRows[i]['citation']}',
        },
      },
  ];

  // hadiths (already in idInBook order from import) keep their relative
  // order; the 8 new rows go in front. Renumber the WHOLE result densely
  // from 1 rather than shifting existing rows by `introRows.length` --
  // that naive shift assumes idInBook 1..introRows.length was left empty
  // by the 7-row removal above, but only 7 slots were freed for 8 new
  // rows, so a flat +8 shift leaves a 7-wide hole (idInBook 9-15 never
  // assigned to anything) that `hadith_chapter_range_info.dart`'s gap
  // detector then flags as a false "missing hadith" red flag right at
  // the Introduction/Book-1 boundary (caught 2026-07-29 via that exact
  // detector, run standalone against this spine).
  final result = [...newRows, ...hadiths];
  for (var i = 0; i < result.length; i++) {
    final idInBook = i + 1;
    result[i]['idInBook'] = idInBook;
    result[i]['id'] = bookId * 1000000 + idInBook;
  }
  data['hadiths'] = result;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln(
    '$path: inserted ${newRows.length} verified Introduction rows, '
    'renumbered ${result.length} total rows densely (no shift gap).',
  );
}
