# Malik: amrayn malikChapterNum <-> fawaz raw reference.book

A join key `BOOK_CHAPTER_CROSSCHECK.md` never checked: fawaz's own raw `reference.book` field (separate from the canonical `chapterId` rebuild that file was actually about). Content-matched by Arabic text (`arabic_match.dart`), then compared per-citation.

- amrayn citations content-matched to a fawaz row: 1389 / 1405
- exact agreement: 1194 (86.0%)
- disagreement: 195 (14.0%)
- fawaz distinct `reference.book` values: 62 (range 0-61)
- amrayn distinct `malikChapterNum` range: 1-61

**This is not the same kind of disagreement the other 6 books had.** Bukhari/Nasa'i/Abu Dawud/Tirmidhi/Ibn Majah/Muslim's disagreements were narrow and bounded (off by exactly one adjacent book, clustered in short citation ranges). Here the gap between amrayn's book number and fawaz's book number GROWS as the book progresses -- single digits early on, up to the 40s-50s by the end -- even though both sources independently cap at 61 total books. This is a genuine progressive divergence in book-division convention, consistent with Muwatta Malik's well-documented real manuscript-recension differences (more than one historical transmission line, with different chapter groupings), not a data-quality defect in either source. Resolving which recension each source actually follows needs a third source or direct scholarly reference -- not resolvable from these two sources' automated matching alone.

## Disagreement progression (first 20 by idInBook order)

| idInBook | amraynBook - fawazBook |
|---:|---:|
| 33 | 1 |
| 64 | 1 |
| 67 | 1 |
| 137 | 2 |
| 146 | 1 |
| 156 | 1 |
| 161 | 1 |
| 180 | 2 |
| 197 | 2 |
| 215 | 3 |
| 222 | 5 |
| 224 | 5 |
| 225 | 3 |
| 234 | 3 |
| 242 | 5 |
| 246 | 7 |
| 249 | 5 |
| 250 | 5 |
| 257 | 6 |
| 272 | 6 |

## Disagreement progression (last 20 by idInBook order)

| idInBook | amraynBook - fawazBook |
|---:|---:|
| 1252 | 47 |
| 1253 | 47 |
| 1254 | 1 |
| 1261 | 42 |
| 1264 | 48 |
| 1267 | 47 |
| 1277 | 48 |
| 1280 | 46 |
| 1287 | 48 |
| 1292 | 49 |
| 1294 | 40 |
| 1316 | 36 |
| 1329 | 49 |
| 1342 | 52 |
| 1364 | 25 |
| 1382 | 25 |
| 1389 | 25 |
| 1390 | 3 |
| 1398 | 55 |
| 1401 | 57 |
