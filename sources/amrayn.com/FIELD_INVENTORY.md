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

## `bookName`/`bookNameArabic` — now captured going forward

**Scraper updated** (`scrape_amrayn.dart`'s `extractEmbeddedFields`) to
extract `bookName`/`bookNameArabic` alongside the fields it already
captures — a top-level "Book of X" grouping distinct from (and coarser
than) the `chapter` sub-chapter field we already capture. Example,
live-verified on `bukhari:1`: `chapter` gives the fine-grained "How the
Divine Revelation started..." sub-chapter, while
`bookName`/`bookNameArabic` give the coarse "Revelation" / "كتاب بدء
الوحى" — this is Bukhari's well-known ~97-book division (Book 1:
Revelation, Book 2: Belief, ...), which our own `db/unified/` chapter
schema does not currently distinguish from sub-chapters at all.

**Only English + Arabic exist — checked, not assumed.** amrayn.com is an
English-only site: `<html lang="en">`, no `hreflang` alternates, no
locale switcher found on either fetched page. Arabic is per-hadith
embedded content (like `arabic`/`chainArabic`/`notesArabic`), not a
separate site locale. So `bookName`/`bookNameArabic` is the complete set
of languages this field will ever have here — there's no third-language
version being missed.

**Not yet re-scraped.** This only takes effect on hadith fetched *after*
this code change — the 61,540 hadith already sitting in
`sources/amrayn.com/runs/2026-07-24_full-catalog/` don't have
`bookName`/`bookNameArabic` yet. Re-running the full scrape to backfill
it is a ~61,540-request, multi-day operation at the site's own 5-second
crawl-delay (robots.txt) — not run as part of this investigation; needs
its own explicit go-ahead.

## `gradeFlag` decoded — it's a real bitwise-OR bitmask

Verified by cross-checking every distinct `gradeFlag` value seen against
the `grades[].class` combination it always co-occurs with, across the
full 61,390-hadith corpus that carries `grades[]` (39 distinct flag
values observed):

- **Single-grade hadith get a pure power-of-2 flag.** `class:"sahih"` →
  `1` (bit 0), `"hasan"` → `2` (bit 1), `"daeef"` → `4` (bit 2),
  `"moudu"` → `8` (bit 3), `"hasansahih"` → `16` (bit 4), `"munkar"` →
  `32` (bit 5), `"shadhdh"` → `64` (bit 6), and so on up through at least
  bit 30 (`daeef` again, a different bit — see below).
- **Multi-grade hadith get the bitwise OR of their component grades.**
  Verified directly: `gradeFlag=257` (`0b100000001` = bit 8 + bit 0)
  co-occurs only with `class` combination `maqtu+sahih`; `gradeFlag=8196`
  (bit 13 + bit 2) only with `daeef+marfu`; `gradeFlag=2359297` (bit 21 +
  bit 18 + bit 0) only with the three-grade combination
  `daeef+sahih+sahih` — the two different bits both decoding to `class:
  "sahih"` is itself confirmation this is a real OR, not a coincidence.
- **The same coarse `class` string maps to *multiple* different bits**
  (e.g. `"sahih"` alone was seen at bit 0, bit 9, bit 21, bit 25, and bit
  26). `class` is a coarse display bucket; `gradeFlag`'s bit is more
  granular — almost certainly one bit per (grading authority, verdict)
  pair internal to amrayn's backend (e.g. Darussalam's "Sahih (Authentic)"
  vs. Al-Albani's "Sahih (Authentic) [Al-Albani]" vs. an isnad-only
  "Sahih ul-Isnaad (Authentic Chain)" all show `class:"sahih"` but are
  textually distinct grades and get distinct bits).
- **What's NOT decoded**: which specific authority each individual bit
  belongs to. That mapping isn't recoverable from `class`+`text` alone
  when two different authorities produce identical text (e.g. two sources
  both saying plain "Sahih (Authentic)" with no bracketed name) — would
  need amrayn's own internal enum or UI (e.g. a tooltip) to fully resolve,
  and hasn't been pursued since nothing currently needs it.

**Full `grades[].class` value set found** (21 distinct values across the
corpus): `daeef`, `daeefjiddan`, `gharib`, `hasan`, `hasansahih`,
`hasanulisnaad`, `lighairih`, `maqtu`, `marfu`, `mauquf`, `moudu`,
`munkar`, `munqati`, `mursal`, `mutawatir`, `nochainfoundalalbani`,
`qudsi`, `sahih`, `sahihlighirih`, `shadhdh`, `unknown` — a real
traditional hadith-grading taxonomy (authentic/good/weak/fabricated/
mursal/mawquf/etc.), not amrayn-invented categories.

## Not yet done

- Broader live-page sampling of `special`/`trending`/`popular` (2 samples
  isn't enough to say whether these are ever true anywhere on the site).
- Decide whether `bookName`/`bookNameArabic` (top-level Book grouping)
  is worth carrying into `db/unified/`'s schema, and whether/when to run
  the multi-day re-scrape needed to backfill it for already-scraped
  hadith.
- Decide whether `grades[]` (rich multi-authority grading) and `links[]`
  (cross-collection citation graph) become new fields in `db/unified/`'s
  schema — not decided yet, deliberately.
