# amrayn.com raw-scrape field inventory

What amrayn.com's site actually gives us per hadith, verified two ways:
(1) directly reading raw records from
`sources/amrayn.com/runs/2026-07-24_full-catalog/*.jsonl` and counting
field presence across all 15 scraped books/collections, and (2) fetching
two live pages (`amrayn.com/bukhari:1`, `amrayn.com/darimi:1`) and reading
the *entire* embedded JSON payload directly, not just the fields
`scrape_amrayn.dart` already knows to extract — because a scraper can only
ever report what it was told to look for, and the earlier pass here
(before this correction) didn't check for anything it wasn't already
extracting. This file exists so "what does amrayn actually have" can be
answered without re-opening raw JSONL or re-fetching a live page again.

**Correction (this revision):** an earlier version of this file claimed
`boldSegments` is empty on every one of 61,540+ scraped hadith. That was
wrong — a grep pattern bug (checked for a nested-array bracket `[[` when
the real field is a plain string array `["..."]`). Corrected below: it's
populated 99.3% of the time in Riyad as-Salihin.

## Every field on a raw hadith record

```
idInBook, title, chapter{chapterNum,arabicTitle,englishTitle,sectionNum},
grades[{class,text}], englishRaw, narrator, body, boldSegments[],
arabic, amraynSectionNum, amraynId, bookNumber, gradeFlag,
notes, notesArabic, postscript, postscriptArabic,
hasExplanationAvailable, chain, chainArabic,
references[], intlRef, tags[], links[{link,label}]
(+ malikChapterNum, malikLocalHadithNum — Malik only)
```

`narrator`/`body` are just `englishRaw` split at the first line break
when that line reads as an attribution (e.g. "Abu Hurairah reported...");
already used. Everything else below is new information, not yet in our
schema.

**Fields that exist in amrayn's live payload but `scrape_amrayn.dart`
never captures at all** (found by reading the full embedded JSON on a
live page, not just the keys the extractor already knew about):
`bookName`/`bookNameArabic` (a top-level "Book of X" grouping, coarser
than the `chapter` sub-chapter we do capture — see below), and three
boolean flags `special`/`trending`/`popular` per hadith.

## Feature coverage by book/collection

Percentages are `(raw records with the field populated) / (that book's
deduplicated total from COMPARISON_REPORT.md)`, so they're approximate
(numerator is pre-dedup) but accurate to within a fraction of a percent —
good enough to answer "does this book have this feature," not meant as
an exact count. "—" means the field was never seen at all for that book.

| Book / collection | Isnad chain | Structured grading | Cross-collection links | Source-attribution tag¹ | Notes | Has-explanation flag |
|---|---:|---:|---:|---:|---:|---:|
| Bukhari | — | 100% | 0.2% | — | 0.03% | — |
| Muslim | — | 100% | — | — | — | — |
| Abu Dawud | — | 100% | 0.1% | — | — | — |
| Tirmidhi | — | 100% | 2.1% | — | 0.6% | 0.03% |
| Nasa'i | — | ~100% | 0.02% | — | 0.02% | — |
| Ibn Majah | — | 100% | 1.8% | — | 0.16% | — |
| Malik | — | 0.6% | 0.3% | — | — | — |
| Darimi | **99.5%** | 100% | 26.2% | — | — | 0.03% |
| Riyad as-Salihin | — | 100% | 5.3% | **99.3%** | 0.16% | — |
| Adab Mufrad | — | 100% | 0.5% | — | 0.15% | 0.3% |
| Shama'il | — | 2.5% | 0.3% | — | — | — |
| Nawawi's 40 | — | 100% | 95.2% | 2.4% | — | — |
| Qudsi 40 | — | 100% | 32.5% | — | — | — |
| Nasa'i al-Kubra (bonus) | **~100%** | ~100% | 66.4% | — | — | — |
| Mustadrak al-Hakim (bonus) | **99.9%** | 100% | 15.8% | — | — | — |

¹ "Source-attribution tag" is what `boldSegments` actually is (see
below) — not general text highlighting.

**`tags[]` and `postscript`/`postscriptArabic`: 0% on every book, no
exceptions** — confirmed both against the full 61,540+-record corpus and
against the raw live-page payload for two sample hadith. These are real
fields on amrayn's backend schema that are consistently unpopulated for
every hadith checked so far.

## What `boldSegments` (the "text highlight tags" feature) actually is

Corrected finding: sampled the actual bolded text in Riyad as-Salihin and
Nawawi's 40 — it is **not** general in-text highlighting (isnad names,
Quran quotes, keywords). It's a single trailing bracketed source
citation, e.g. `"[Al-Bukhari and Muslim]"`, `"[Muslim]"`,
`"[Al-Bukhari]"`. Riyad as-Salihin and the Forties are both
*compilation* books — they gather hadith originally narrated in Bukhari,
Muslim, and others into a themed collection, so each entry needs to say
which original collection(s) it came from. That's what's bolded. It
doesn't exist in the other 12 books/collections because those are
*primary* collections (Bukhari's own hadith don't need a "this is from
Bukhari" tag) — this isn't a scraper gap, it's a real structural
difference between compilation books and primary books.

## Newly-found, never-captured fields

Found by reading the raw embedded JSON on a live page directly, past
what `scrape_amrayn.dart` already extracts:

- **`bookName` / `bookNameArabic`** — a top-level "Book of X" grouping
  distinct from (and coarser than) the `chapter` sub-chapter field we
  already capture. Example, live-verified on `bukhari:1`: `chapter` gives
  the fine-grained "How the Divine Revelation started..." sub-chapter,
  while `bookName`/`bookNameArabic` give the coarse "Revelation" /
  "كتاب بدء الوحى" — this is Bukhari's well-known ~97-book division
  (Book 1: Revelation, Book 2: Belief, ...), which our own `db/unified/`
  chapter schema does not currently distinguish from sub-chapters at all.
  Worth extending the scraper to capture, if a two-level book/chapter
  structure (already built for Musnad Ahmad, see main `README.md`'s
  "Two-level chapters" section) is wanted for the other books too.
- **`special` / `trending` / `popular`** — three per-hadith booleans.
  Both live samples checked (`bukhari:1`, `darimi:1`) had all three
  `false`, including Bukhari's famous opening "actions are by
  intentions" hadith — so `popular` is likely a site-engagement metric,
  not a religious-significance flag, or is simply unused/unpopulated
  right now like `tags`/`postscript`. Only 2 samples checked; not enough
  to characterize, and not worth a broader live crawl unless there's a
  concrete use for it.

## Not yet done

- Broader live-page sampling of `special`/`trending`/`popular` (2 samples
  isn't enough to say whether these are ever true anywhere on the site).
- Enumerate the full `grades[].class` value set (currently only seen:
  `sahih`, `unknown` — there are almost certainly more, e.g. daif/hasan).
- Decode `gradeFlag`'s bit meaning, if it turns out to matter (e.g. does
  it distinguish which authority issued the grade).
- Decide whether `bookName`/`bookNameArabic` (top-level Book grouping)
  is worth adding to the scraper and, eventually, `db/unified/`'s schema.
- Decide, once the above is answered, whether `grades[]`/`links[]`
  become new fields in `db/unified/`'s schema — not decided yet,
  deliberately.
