# Book-mismatch pairs (v2 cross-check) re-classified by LCS ratio

For every amrayn/canonical book-assignment "mismatch" from `BOOK_CHAPTER_CROSSCHECK_V2.md`, computes the longest-common-substring ratio (same method as `FUZZY_MATCH_ANALYSIS.md`) between the amrayn text and the fawaz text the matcher paired it with. High ratio = same report, so the book disagreement is real. Low ratio = the matcher paired two DIFFERENT hadiths, so the "mismatch" is a matcher artifact, not a real book-boundary finding.

## bukhari
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 497
- ambiguous (0.3-0.6): 0
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 0 (0.0% of this book's reported mismatches)

## muslim
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 242
- ambiguous (0.3-0.6): 28
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 1 (0.4% of this book's reported mismatches)

### False-match samples (muslim)

citation=2979 lcsRatio=0.23
  AMRAYN (book=54): حَدَّثَنِي أَبُو الطَّاهِرِ، أَحْمَدُ بْنُ عَمْرِو بْنِ سَرْحٍ أَخْبَرَنَا ابْنُ وَهْبٍ، أَخْبَرَنِي أَبُو هَانِئٍ سَمِعَ أَبَا عَبْدِ الرَّحْمَنِ الْ
  FAWAZ #4075 (chapterId=22): حَدَّثَنِي أَبُو الطَّاهِرِ، أَحْمَدُ بْنُ عَمْرِو بْنِ سَرْحٍ أَخْبَرَنَا ابْنُ وَهْبٍ، أَخْبَرَنِي أَبُو هَانِئٍ الْخَوْلاَنِيُّ أَنَّهُ سَمِعَ عُلَ


## nasai
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 15
- ambiguous (0.3-0.6): 13
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 4 (12.5% of this book's reported mismatches)

### False-match samples (nasai)

citation=3861 lcsRatio=0.27
  AMRAYN (book=35): أَخْبَرَنَا مُحَمَّدُ بْنُ حَاتِمٍ، قَالَ أَنْبَأَنَا حِبَّانُ، قَالَ أَنْبَأَنَا عَبْدُ اللَّهِ، عَنِ ابْنِ جُرَيْجٍ، قِرَاءَةً قَالَ قُلْتُ لِعَطَاء
  FAWAZ #3031 (chapterId=24): أَخْبَرَنَا مُحَمَّدُ بْنُ حَاتِمٍ، قَالَ أَنْبَأَنَا حِبَّانُ، قَالَ أَنْبَأَنَا عَبْدُ اللَّهِ، عَنْ إِبْرَاهِيمَ بْنِ عُقْبَةَ، أَنَّ كُرَيْبًا، قَ

citation=3863 lcsRatio=0.27
  AMRAYN (book=35): أَخْبَرَنَا مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ الْمُبَارَكِ، قَالَ حَدَّثَنَا يَحْيَى، - وَهُوَ ابْنُ آدَمَ - قَالَ حَدَّثَنَا مُفَضَّلٌ، - وَهُوَ ابْ
  FAWAZ #5167 (chapterId=48): أَخْبَرَنَا مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ الْمُبَارَكِ، قَالَ حَدَّثَنَا يَحْيَى، - وَهُوَ ابْنُ آدَمَ - قَالَ حَدَّثَنَا زُهَيْرٌ، عَنْ أَبِي إِ

citation=3898 lcsRatio=0.22
  AMRAYN (book=35): أَخْبَرَنَا مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ الْمُبَارَكِ، قَالَ حَدَّثَنَا حُجَيْنُ بْنُ الْمُثَنَّى، قَالَ حَدَّثَنَا اللَّيْثُ، عَنْ رَبِيعَةَ بْ
  FAWAZ #1966 (chapterId=21): أَخْبَرَنَا مُحَمَّدُ بْنُ عَبْدِ اللَّهِ بْنِ الْمُبَارَكِ، قَالَ حَدَّثَنَا حُجَيْنُ بْنُ الْمُثَنَّى، قَالَ حَدَّثَنَا اللَّيْثُ، عَنْ عُقَيْلٍ، عَ

citation=3906 lcsRatio=0.29
  AMRAYN (book=35): أَخْبَرَنَا أَحْمَدُ بْنُ مُحَمَّدِ بْنِ الْمُغِيرَةِ، قَالَ حَدَّثَنَا عُثْمَانُ بْنُ سَعِيدٍ، عَنْ شُعَيْبٍ، قَالَ الزُّهْرِيُّ كَانَ ابْنُ الْمُسَي
  FAWAZ #164 (chapterId=1): أَخْبَرَنَا أَحْمَدُ بْنُ مُحَمَّدِ بْنِ الْمُغِيرَةِ، قَالَ حَدَّثَنَا عُثْمَانُ بْنُ سَعِيدٍ، عَنْ شُعَيْبٍ، عَنِ الزُّهْرِيِّ، قَالَ أَخْبَرَنِي عَ


## abudawud
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 54
- ambiguous (0.3-0.6): 0
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 0 (0.0% of this book's reported mismatches)

## tirmidhi
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 28
- ambiguous (0.3-0.6): 29
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 35 (38.0% of this book's reported mismatches)

### False-match samples (tirmidhi)

citation=734 lcsRatio=0.00
  AMRAYN (book=8): 
  FAWAZ #391 (chapterId=2): 

citation=1365 lcsRatio=0.24
  AMRAYN (book=15): حَدَّثَنَا عَبْدُ اللَّهِ بْنُ مُعَاوِيَةَ الْجُمَحِيُّ الْبَصْرِيُّ، حَدَّثَنَا حَمَّادُ بْنُ سَلَمَةَ، عَنْ قَتَادَةَ، عَنِ الْحَسَنِ، عَنْ سَمُرَةَ
  FAWAZ #2163 (chapterId=33): حَدَّثَنَا عَبْدُ اللَّهِ بْنُ مُعَاوِيَةَ الْجُمَحِيُّ الْبَصْرِيُّ، حَدَّثَنَا حَمَّادُ بْنُ سَلَمَةَ، عَنْ أَبِي الزُّبَيْرِ، عَنْ جَابِرٍ، قَالَ ن

citation=1491 lcsRatio=0.22
  AMRAYN (book=18): حَدَّثَنَا هَنَّادٌ، حَدَّثَنَا أَبُو الأَحْوَصِ، عَنْ سَعِيدِ بْنِ مَسْرُوقٍ، عَنْ عَبَايَةَ بْنِ رِفَاعَةَ بْنِ رَافِعِ بْنِ خَدِيجٍ، عَنْ أَبِيهِ، 
  FAWAZ #1600 (chapterId=21): حَدَّثَنَا هَنَّادٌ، حَدَّثَنَا أَبُو الأَحْوَصِ، عَنْ سَعِيدِ بْنِ مَسْرُوقٍ، عَنْ عَبَايَةَ بْنِ رِفَاعَةَ، عَنْ أَبِيهِ، عَنْ جَدِّهِ، رَافِعِ بْنِ

citation=1492 lcsRatio=0.23
  AMRAYN (book=18): حَدَّثَنَا هَنَّادٌ، حَدَّثَنَا أَبُو الأَحْوَصِ، عَنْ سَعِيدِ بْنِ مَسْرُوقٍ، عَنْ عَبَايَةَ بْنِ رِفَاعَةَ بْنِ رَافِعٍ، عَنْ أَبِيهِ، عَنْ جَدِّهِ،
  FAWAZ #1600 (chapterId=21): حَدَّثَنَا هَنَّادٌ، حَدَّثَنَا أَبُو الأَحْوَصِ، عَنْ سَعِيدِ بْنِ مَسْرُوقٍ، عَنْ عَبَايَةَ بْنِ رِفَاعَةَ، عَنْ أَبِيهِ، عَنْ جَدِّهِ، رَافِعِ بْنِ

citation=1516 lcsRatio=0.00
  AMRAYN (book=19): 
  FAWAZ #391 (chapterId=2): 

citation=1599 lcsRatio=0.28
  AMRAYN (book=21): حَدَّثَنَا قُتَيْبَةُ، حَدَّثَنَا عَبَّادُ بْنُ عَبَّادٍ الْمُهَلَّبِيُّ، عَنْ أَبِي جَمْرَةَ، عَنِ ابْنِ عَبَّاسٍ، أَنَّ النَّبِيَّ ﷺ قَالَ لِوَفْدِ 
  FAWAZ #2611 (chapterId=40): حَدَّثَنَا قُتَيْبَةُ، حَدَّثَنَا عَبَّادُ بْنُ عَبَّادٍ الْمُهَلَّبِيُّ، عَنْ أَبِي جَمْرَةَ، عَنِ ابْنِ عَبَّاسٍ، قَالَ قَدِمَ وَفْدُ عَبْدِ الْقَيْ

citation=1617 lcsRatio=0.12
  AMRAYN (book=21): حَدَّثَنَا مُحَمَّدُ بْنُ بَشَّارٍ، حَدَّثَنَا عَبْدُ الرَّحْمَنِ بْنُ مَهْدِيٍّ، عَنْ سُفْيَانَ، عَنْ عَلْقَمَةَ بْنِ مَرْثَدٍ، عَنْ سُلَيْمَانَ بْنِ
  FAWAZ #61 (chapterId=1): حَدَّثَنَا مُحَمَّدُ بْنُ بَشَّارٍ، حَدَّثَنَا عَبْدُ الرَّحْمَنِ بْنُ مَهْدِيٍّ، عَنْ سُفْيَانَ، عَنْ عَلْقَمَةَ بْنِ مَرْثَدٍ، عَنْ سُلَيْمَانَ بْنِ

citation=1637 lcsRatio=0.11
  AMRAYN (book=22): حَدَّثَنَا أَحْمَدُ بْنُ مَنِيعٍ، حَدَّثَنَا يَزِيدُ بْنُ هَارُونَ، أَخْبَرَنَا مُحَمَّدُ بْنُ إِسْحَاقَ، عَنْ عَبْدِ اللَّهِ بْنِ عَبْدِ الرَّحْمَنِ 
  FAWAZ #3045 (chapterId=47): حَدَّثَنَا أَحْمَدُ بْنُ مَنِيعٍ، حَدَّثَنَا يَزِيدُ بْنُ هَارُونَ، أَخْبَرَنَا مُحَمَّدُ بْنُ إِسْحَاقَ، عَنْ أَبِي الزِّنَادِ، عَنِ الأَعْرَجِ، عَنْ

citation=1711 lcsRatio=0.27
  AMRAYN (book=23): حَدَّثَنَا مُحَمَّدُ بْنُ الْوَزِيرِ الْوَاسِطِيُّ، حَدَّثَنَا إِسْحَاقُ بْنُ يُوسُفَ الأَزْرَقُ، عَنْ سُفْيَانَ، عَنْ عُبَيْدِ اللَّهِ بْنِ عُمَرَ، ع
  FAWAZ #1361 (chapterId=15): حَدَّثَنَا مُحَمَّدُ بْنُ وَزِيرٍ الْوَاسِطِيُّ، حَدَّثَنَا إِسْحَاقُ بْنُ يُوسُفَ الأَزْرَقُ، عَنْ سُفْيَانَ، عَنْ عُبَيْدِ اللَّهِ بْنِ عُمَرَ، عَنْ

citation=2037 lcsRatio=0.00
  AMRAYN (book=28): 
  FAWAZ #391 (chapterId=2): 


## ibnmajah
- real book-boundary mismatch (LCS ratio >=0.6, same report, different book): 0
- ambiguous (0.3-0.6): 1
- matcher false-positive (LCS ratio <0.3, NOT the same hadith at all): 0 (0.0% of this book's reported mismatches)

## TOTAL across all 6 books
- real book-boundary mismatch: 836
- ambiguous: 71
- matcher false-positive: 40
