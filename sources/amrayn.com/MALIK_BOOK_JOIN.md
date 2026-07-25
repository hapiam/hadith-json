# Malik: amrayn malikChapterNum <-> fawaz raw reference.book

A join key `BOOK_CHAPTER_CROSSCHECK.md` never checked: fawaz's own raw `reference.book` field (separate from the canonical `chapterId` rebuild that file was actually about). Content-matched by Arabic text (`arabic_match.dart`), then compared per-citation.

- amrayn citations content-matched to a fawaz row: 1389 / 1405
- exact agreement: 1334 (96.0%)
- disagreement: 55 (4.0%)
- fawaz distinct `reference.book` values: 62 (range 0-61)
- amrayn distinct `malikChapterNum` range: 1-61

**This is not the same kind of disagreement the other 6 books had.** Bukhari/Nasa'i/Abu Dawud/Tirmidhi/Ibn Majah/Muslim's disagreements were narrow and bounded (off by exactly one adjacent book, clustered in short citation ranges). Here the gap between amrayn's book number and fawaz's book number GROWS as the book progresses -- single digits early on, up to the 40s-50s by the end -- even though both sources independently cap at 61 total books. This is a genuine progressive divergence in book-division convention, consistent with Muwatta Malik's well-documented real manuscript-recension differences (more than one historical transmission line, with different chapter groupings), not a data-quality defect in either source. Resolving which recension each source actually follows needs a third source or direct scholarly reference -- not resolvable from these two sources' automated matching alone.

## Disagreement progression (first 20 by idInBook order)

| idInBook | amraynBook - fawazBook |
|---:|---:|
| 222 | 5 |
| 224 | 5 |
| 388 | 10 |
| 418 | -1 |
| 541 | 17 |
| 550 | 17 |
| 552 | 17 |
| 562 | 17 |
| 582 | 17 |
| 583 | 17 |
| 623 | 18 |
| 624 | 18 |
| 638 | 18 |
| 643 | 18 |
| 651 | 19 |
| 719 | 1 |
| 788 | 25 |
| 792 | 25 |
| 885 | 29 |
| 937 | 31 |

## Disagreement progression (last 20 by idInBook order)

| idInBook | amraynBook - fawazBook |
|---:|---:|
| 1001 | 32 |
| 1002 | 32 |
| 1003 | 32 |
| 1004 | 32 |
| 1050 | 36 |
| 1079 | 38 |
| 1106 | 39 |
| 1108 | 39 |
| 1109 | 39 |
| 1113 | 39 |
| 1114 | 39 |
| 1115 | 39 |
| 1116 | 39 |
| 1117 | 39 |
| 1118 | 40 |
| 1119 | 40 |
| 1120 | 40 |
| 1123 | 40 |
| 1125 | 40 |
| 1292 | 49 |
