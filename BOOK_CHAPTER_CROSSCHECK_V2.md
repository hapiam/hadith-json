# amrayn vs. canonical book/chapter assignment -- content-matched, v2

Supersedes `BOOK_CHAPTER_CROSSCHECK.md`'s citation-string method (only covered the un-lettered majority of each book, and never included Tirmidhi/Ibn Majah at all). This version matches by Arabic text content (`arabic_match.dart`), so it covers every amrayn citation regardless of lettering, uniformly across all 6 fawaz-rebuilt books. Malik excluded -- see `MALIK_BOOK_JOIN.md` for its own separately-verified relationship.

| Book | Compared | Matched (same book) | Mismatched | Amrayn citations with no fawaz match | Fawaz rows with no canonical idInBook |
|---|---:|---:|---:|---:|---:|
| bukhari | 6791 | 6294 | 497 | 0 | 0 |
| muslim | 8850 | 8579 | 271 | 41 | 0 |
| nasai | 5662 | 5630 | 32 | 66 | 0 |
| abudawud | 5273 | 5219 | 54 | 1 | 0 |
| tirmidhi | 3896 | 3804 | 92 | 55 | 0 |
| ibnmajah | 4325 | 4324 | 1 | 3 | 0 |

## bukhari

- compared: 6791, matched: 6294, mismatched: 497 (7.3%)

### Mismatch samples

- citation=294: amrayn book=5 (Bathing (Ghusl)), canonical chapterId=6 (Menstrual Periods)
- citation=2291: amrayn book=39 (Kafalah), canonical chapterId=38 (Transferance of a Debt from One Person to Another (Al-Hawaala))
- citation=2351: amrayn book=41 (Agriculture), canonical chapterId=42 (Distribution of Water)
- citation=2352: amrayn book=41 (Agriculture), canonical chapterId=42 (Distribution of Water)
- citation=4474: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4475: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4476: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4477: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4478: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4479: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4480: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4481: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4482: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4483: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))
- citation=4484: amrayn book=64 (Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)), canonical chapterId=65 (Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh)))

## muslim

- compared: 8850, matched: 8579, mismatched: 271 (3.1%)

### Mismatch samples

- citation=80b: amrayn book=1 (The Book of Faith), canonical chapterId=26 (The Book of Vows)
- citation=112b: amrayn book=46 (The Book of Destiny), canonical chapterId=1 (The Book of Faith)
- citation=157c: amrayn book=12 (The Book of Zakat), canonical chapterId=6 (The Book of Prayer - Travellers)
- citation=157e: amrayn book=47 (The Book of Knowledge), canonical chapterId=15 (The Book of Pilgrimage)
- citation=157f: amrayn book=47 (The Book of Knowledge), canonical chapterId=39 (The Book of Greetings)
- citation=157g: amrayn book=47 (The Book of Knowledge), canonical chapterId=39 (The Book of Greetings)
- citation=157i: amrayn book=54 (The Book of Tribulations and Portents of the Last Hour), canonical chapterId=46 (The Book of Destiny)
- citation=157j: amrayn book=54 (The Book of Tribulations and Portents of the Last Hour), canonical chapterId=46 (The Book of Destiny)
- citation=157k: amrayn book=54 (The Book of Tribulations and Portents of the Last Hour), canonical chapterId=46 (The Book of Destiny)
- citation=267d: amrayn book=36 (The Book of Drinks), canonical chapterId=2 (The Book of Purification)
- citation=520: amrayn book=4 (The Book of Prayers), canonical chapterId=5 (The Book of Mosques and Places of Prayer)
- citation=520a: amrayn book=4 (The Book of Prayers), canonical chapterId=5 (The Book of Mosques and Places of Prayer)
- citation=520b: amrayn book=4 (The Book of Prayers), canonical chapterId=5 (The Book of Mosques and Places of Prayer)
- citation=521: amrayn book=4 (The Book of Prayers), canonical chapterId=5 (The Book of Mosques and Places of Prayer)
- citation=521a: amrayn book=4 (The Book of Prayers), canonical chapterId=5 (The Book of Mosques and Places of Prayer)

## nasai

- compared: 5662, matched: 5630, mismatched: 32 (0.6%)

### Mismatch samples

- citation=325: amrayn book=1 (The Book of Purification), canonical chapterId=2 (The Book of Water)
- citation=1433: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1434: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1435: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1436: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1437: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1438: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1439: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1440: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1441: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1442: amrayn book=14 (The Book of Jumu'ah (Friday Prayer)), canonical chapterId=15 (The Book of Shortening the Prayer When Traveling)
- citation=1556: amrayn book=18 (The Book of the Fear Prayer), canonical chapterId=19 (The Book of the Prayer for the Two 'Eids)
- citation=3857: amrayn book=35 (The Book of Agriculture), canonical chapterId=22 (The Book of Fasting)
- citation=3858: amrayn book=35 (The Book of Agriculture), canonical chapterId=51 (The Book of Drinks)
- citation=3861: amrayn book=35 (The Book of Agriculture), canonical chapterId=24 (The Book of Hajj)

## abudawud

- compared: 5273, matched: 5219, mismatched: 54 (1.0%)

### Mismatch samples

- citation=3969: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3970: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3971: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3972: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3973: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3974: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3975: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3976: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3977: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3978: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3979: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3980: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3981: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3982: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))
- citation=3983: amrayn book=31 (The Book of Manumission of Slaves), canonical chapterId=32 (Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at))

## tirmidhi

- compared: 3896, matched: 3804, mismatched: 92 (2.4%)

### Mismatch samples

- citation=734: amrayn book=8 (The Book on Fasting), canonical chapterId=2 (The Book on Salat (Prayer))
- citation=1365: amrayn book=15 (The Chapters On Judgements From The Messenger of Allah), canonical chapterId=33 (Chapters On Al-Fitan)
- citation=1491: amrayn book=18 (The Book on Hunting), canonical chapterId=21 (The Book on Military Expeditions)
- citation=1492: amrayn book=18 (The Book on Hunting), canonical chapterId=21 (The Book on Military Expeditions)
- citation=1516: amrayn book=19 (The Book on Sacrifices), canonical chapterId=2 (The Book on Salat (Prayer))
- citation=1599: amrayn book=21 (The Book on Military Expeditions), canonical chapterId=40 (The Book on Faith)
- citation=1617: amrayn book=21 (The Book on Military Expeditions), canonical chapterId=1 (The Book on Purification)
- citation=1637: amrayn book=22 (The Book on Virtues of Jihad), canonical chapterId=47 (Chapters on Tafsir)
- citation=1711: amrayn book=23 (The Book on Jihad), canonical chapterId=15 (The Chapters On Judgements From The Messenger of Allah)
- citation=1820: amrayn book=25 (The Book on Food), canonical chapterId=24 (The Book on Clothing)
- citation=2037: amrayn book=28 (Chapters on Medicine), canonical chapterId=2 (The Book on Salat (Prayer))
- citation=2042: amrayn book=28 (Chapters on Medicine), canonical chapterId=25 (The Book on Food)
- citation=2043: amrayn book=28 (Chapters on Medicine), canonical chapterId=40 (The Book on Faith)
- citation=2044: amrayn book=28 (Chapters on Medicine), canonical chapterId=7 (The Book on Zakat)
- citation=2049: amrayn book=28 (Chapters on Medicine), canonical chapterId=22 (The Book on Virtues of Jihad)

## ibnmajah

- compared: 4325, matched: 4324, mismatched: 1 (0.0%)

### Mismatch samples

- citation=2490: amrayn book=16 (The Chapters on Pawning), canonical chapterId=15 (The Chapters on Charity)

