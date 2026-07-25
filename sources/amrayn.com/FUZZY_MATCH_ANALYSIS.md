# Fuzzy-match pairs re-classified by longest-common-substring ratio

LCS ratio = length of the longest contiguous shared run of normalized text, divided by the shorter of the two texts' own length. High ratio (>=0.6) means one text is essentially a truncated/excerpted version of the other (same report, different amount of isnad/postscript captured) -- not a mismatch. Low ratio is the real signal of a possibly-wrong pairing.

## bukhari
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 1055
- mid overlap (0.3-0.6, partial shared content, needs a look): 1
- low overlap (<0.3, likely a real mismatch): 0

## muslim
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 1641
- mid overlap (0.3-0.6, partial shared content, needs a look): 34
- low overlap (<0.3, likely a real mismatch): 2

### Low-overlap samples (muslim)

citation=2766 lcsRatio=0.16 lcsLen=139
  AMRAYN: حَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، وَمُحَمَّدُ بْنُ بَشَّارٍ، - وَاللَّفْظُ لاِبْنِ الْمُثَنَّى - قَالَ حَدَّثَنَا مُعَاذُ بْنُ هِشَامٍ، حَدَّثَنِ
  FAWAZ:  حَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، وَمُحَمَّدُ بْنُ بَشَّارٍ، - وَاللَّفْظُ لاِبْنِ الْمُثَنَّى - قَالَ حَدَّثَنَا مُعَاذُ بْنُ هِشَامٍ، حَدَّثَنِ

citation=2766a lcsRatio=0.16 lcsLen=139
  AMRAYN: حَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، وَمُحَمَّدُ بْنُ بَشَّارٍ، - وَاللَّفْظُ لاِبْنِ الْمُثَنَّى - قَالَ حَدَّثَنَا مُعَاذُ بْنُ هِشَامٍ، حَدَّثَنِ
  FAWAZ:  حَدَّثَنَا مُحَمَّدُ بْنُ الْمُثَنَّى، وَمُحَمَّدُ بْنُ بَشَّارٍ، - وَاللَّفْظُ لاِبْنِ الْمُثَنَّى - قَالَ حَدَّثَنَا مُعَاذُ بْنُ هِشَامٍ، حَدَّثَنِ


## nasai
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 927
- mid overlap (0.3-0.6, partial shared content, needs a look): 8
- low overlap (<0.3, likely a real mismatch): 0

## abudawud
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 361
- mid overlap (0.3-0.6, partial shared content, needs a look): 1
- low overlap (<0.3, likely a real mismatch): 0

## tirmidhi
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 732
- mid overlap (0.3-0.6, partial shared content, needs a look): 82
- low overlap (<0.3, likely a real mismatch): 1

### Low-overlap samples (tirmidhi)

citation=1711 lcsRatio=0.27 lcsLen=148
  AMRAYN: حَدَّثَنَا مُحَمَّدُ بْنُ الْوَزِيرِ الْوَاسِطِيُّ، حَدَّثَنَا إِسْحَاقُ بْنُ يُوسُفَ الأَزْرَقُ، عَنْ سُفْيَانَ، عَنْ عُبَيْدِ اللَّهِ بْنِ عُمَرَ، ع
  FAWAZ:  حَدَّثَنَا مُحَمَّدُ بْنُ وَزِيرٍ الْوَاسِطِيُّ، حَدَّثَنَا إِسْحَاقُ بْنُ يُوسُفَ الأَزْرَقُ، عَنْ سُفْيَانَ، عَنْ عُبَيْدِ اللَّهِ بْنِ عُمَرَ، عَنْ


## ibnmajah
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 683
- mid overlap (0.3-0.6, partial shared content, needs a look): 1
- low overlap (<0.3, likely a real mismatch): 0

## malik
- high overlap (ratio>=0.6, same report, truncation/excerpt only): 285
- mid overlap (0.3-0.6, partial shared content, needs a look): 2
- low overlap (<0.3, likely a real mismatch): 0

## TOTAL across all books
- high overlap: 5684
- mid overlap: 129
- low overlap (real mismatch candidates): 3
