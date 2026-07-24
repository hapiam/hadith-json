# amrayn.com — scrape archive

Everything gathered from amrayn.com so this source never has to be
re-scraped from scratch: the scrapers themselves, every dated snapshot of
what they produced, the raw HTML samples used to reverse-engineer the
site's citation scheme, and the gap-checking scripts used to verify
completeness. See the parent [`sources/README.md`](../README.md) for the
archive convention this folder follows (shared by every scrape source in
this repo).

## Why amrayn.com

amrayn.com pairs Arabic/English text with real chapter/sub-chapter
breakdowns and grading, using the same citation numbering as sunnah.com.
It covers 15 of our 18 books (all but `mishkat_almasabih`,
`bulugh_almaram`, `hisn_almuslim`, and `shahwaliullah40`/`dehlawi`):

- **Sole independent source** for `riyad_assalihin`, `aladab_almufrad`,
  and `shamail_muhammadiyah` — no fawazahmed0/hadith-api coverage exists
  for these three.
- **Second-opinion cross-check** for the 6 fawaz-rebuilt books
  (Bukhari/Muslim/Abu Dawud/Tirmidhi/Nasa'i/Ibn Majah) plus
  `malik`/`nawawi40`/`qudsi40`/`darimi` — used to confirm specific
  numbering questions by direct content comparison (see
  `NUMBERING_CORRUPTION_AUDIT.md` in the repo root for concrete examples,
  e.g. Tirmidhi 2735 and the Ibn Majah cluster).
- **Bonus books** beyond the core 18, scraped opportunistically once the
  tooling existed: `nasai_kubra_bonus`, `mustadrak_alhakim_bonus`.

The scrape's own output is **not** currently consumed by
`rebuild_from_fawaz.dart` or `build_unified_editions.dart` — it exists to
accumulate an independent dataset to manually or semi-automatically diff
against `db/by_book/`, not to feed the pipeline directly.

## Layout

```
amrayn.com/
  scripts/              every tool ever run against this source
  runs/<date>_<label>/  dated, git-tracked snapshots of scrape_cache/amrayn
  discovery-notes/      raw HTML/text samples used to figure out the
                         citation-discovery scheme (see below)
```

## The two scrapers

### `scripts/scrape_amrayn.dart` — the main scraper

Covers every book except Malik (see below). Captures the server-rendered
text (Arabic, English, chapter, grade) plus every field in each page's
embedded React data payload (isnad chain, notes, postscript, tags,
cross-collection reference links, raw grade flag), and each book's
`/about` page once (book + author info live on one combined page on this
site).

Designed to survive a killed process or lost internet with zero manual
cleanup — recovery is always just re-running the same command:

- Output is append-only JSONL per book, keyed by `idInBook`; every write
  is flushed immediately, so a hard kill loses at most one in-flight
  record.
- On startup, only rows that parsed as valid JSON *and* carry no `error`
  key count as already done — transient failures (network blip, timeout)
  retry automatically instead of being permanently skipped.
- Each fetch gets up to 3 attempts with backoff before being logged as an
  error; `maxConsecutiveErrors` failures in a row stops the whole run
  (`exit(3)`) rather than grinding through the rest of a book on a dead
  connection.
- Respects `robots.txt`'s `Crawl-delay: 5`.

Usage: `dart run scripts/scrape_amrayn.dart [bookKey ...]` (default: all).

#### The citation-discovery problem

Most books' hadith are addressable by a flat `1..count` integer sequence
(`/bukhari:1`, `/bukhari:2`, ...). A few aren't — most notably **Sahih
Muslim**, which uses letter-suffixed variants (`muslim:8a`, `8b`, `8d`,
`8e`, with no `8c`) that only ever appear as real `href`s on that hadith's
own chapter-listing page, never as something you can derive by
incrementing an integer.

`discoverCitations` handles this: for any `BookConfig` flagged
`citationDiscovery: true`, it crawls that book's chapter → sub-chapter
(`ch-N`) pages once to build the real fetch list, caching the result to
`{outKey}.citations.json` so the discovery crawl itself never re-runs.
**Two-level discovery was required, not one**, because a chapter's own
base page only server-renders its first ~28 sub-chapter links — anything
past that only shows up by also fetching that chapter's `/ch-2`, `/ch-3`,
... pages directly. The raw HTML samples in `discovery-notes/` (`s59.html`
through `s86.html`, each paired with a `.txt` extract) are exactly the
pages pulled while reverse-engineering this — kept as a record of *why*
the two-level crawl is necessary, in case the site's markup ever changes
and this needs re-deriving.

### `scripts/scrape_amrayn_malik.dart` — Muwatta Imam Malik

Malik gets its own script because amrayn.com's URL scheme for this one
book is genuinely different: individual hadith live at
`/malik/{chapter}/{hadithInChapter}` (chapter-local numbering, matching
how the Muwatta is traditionally cited — "Book X, Hadith Y"), confirmed
directly against the live site (`/malik:1` through `/malik:175` all 404;
`/malik/1/1` through `/malik/1/31` all resolve). It reuses every
HTML-parsing helper from `scrape_amrayn.dart` (they only need an HTML
string, not a URL) — only URL construction and the
`idInBook <-> chapter/local-number` mapping are new.

No separate chapter-count discovery step is needed: hadith are fetched at
local number 1, 2, 3... per chapter until a genuine HTTP 404 (the pages
are fully server-rendered, so a 404 reliably means "past the last hadith
in this chapter"). Output lands in the same `malik.jsonl` the main script
would have used, with two extra fields: `malikChapterNum`/
`malikLocalHadithNum`.

Usage: `dart run scripts/scrape_amrayn_malik.dart`.

## Gap-checking / status scripts

Every scrape run needs a way to answer "is this book actually done, and if
not, what's still missing" — these one-off scripts were written for that,
one per question that came up during the campaign. All of them read
directly from the live `db/scrape_cache/amrayn/` working copy (some
hardcode that path), so they only work run from a checkout where that
cache still exists (or against a `runs/<date>/` snapshot, path-adjusted).

| Script | What it checks |
|---|---|
| `check_all_scrapes.dart` | Status table across every book: done rows (deduped by `idInBook`, no `error` key) vs. the scraper's configured expected count, plus how many of the missing are logged 404s (likely a citation-scheme gap, not a real failure). |
| `check_scrape_gaps.dart` | Mirrors the scraper's own "done" logic for one book: a line without an `error` key counts as done, regardless of stale error lines from earlier failed attempts on the same `idInBook`. |
| `check_vs_citations.dart` | Definitive completion check for a citation-discovery book: every citation in the discovered list must have a successful row in the jsonl, keyed by the citation string. |
| `check_mustadrak_gaps.dart` | Same done-logic as `check_scrape_gaps.dart`, applied to the two bonus books (`nasai_kubra_bonus`/`mustadrak_alhakim_bonus`), whose expected totals are the max `idInBook` seen since amrayn numbers them sequentially with no independently-known target count. |
| `check_muslim_scrape.dart` | Definitive Sahih Muslim audit: done rows vs. the scraper's own expected 7190, holes, unresolved errors, duplicates, and a content sanity check (non-empty Arabic+English on sampled rows). |
| `check_muslim_v2.dart` | Cross-checks `muslim.citations.json` (the discovered citation list) against the jsonl directly. |
| `check_malik_v2.dart` / `check_malik_v3.dart` | Successive completeness/sanity passes over `malik.jsonl` while the dedicated Malik scraper was being built and verified. |
| `bukhari_gaps.dart` | Bukhari-specific hole finder. |
| `muslim_coverage.dart` / `amrayn_status.dart` | Ad-hoc coverage summaries used mid-campaign. |
| `gaps_for.dart` | Generic version of the above — pass a book key and its expected total, get its gap list. |

## Known limitations / things to check before relying on a re-scrape

- Crawl-delay is 5s per request — a full re-scrape of a large book
  (Bukhari, Muslim) takes hours, by design, not something to rush.
- The citation-discovery cache (`{outKey}.citations.json`) is only as
  good as the crawl that built it; if amrayn.com ever restructures its
  chapter/sub-chapter pages, delete the cache file to force
  rediscovery rather than trusting a stale list.
- `scrape_amrayn_malik.dart`'s per-chapter 404-terminated loop assumes the
  site keeps serving genuine 404s past a chapter's last hadith rather than,
  say, a soft-404 200 page — worth a spot check if a future run comes back
  suspiciously short.
