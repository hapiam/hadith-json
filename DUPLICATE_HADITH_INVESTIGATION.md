# Duplicate hadith rows: discovery, why it sat unfixed, and the current cleanup

Status as of 2026-07-29 (final): **fixed and published for Bukhari, Malik,
Lu'lu' wal-Marjan, and Tabarani** (partially for Tabarani). **Muslim's
duplicate-row fix was reverted** after being found wrong — see "The
2026-07-29 correction" below. This document is the full narrative, written
up per explicit request, including the parts that went wrong the first
time — the user asked for that on the record alongside the fix, and it
happened twice in one day (once for the whole 4-day-old investigation
gap, once for this same day's first attempt at Bukhari/Muslim).

## TL;DR

| Category | Books | Rows dropped | Verdict |
|---|---|---|---|
| 1. Compound citations (sunnah.com's own convention) | Bukhari | 303 rows merged into 289 compound-citation entries | **Fixed correctly** (see correction below) |
| 1b. Same phenomenon, unresolved | Muslim | 0 (reverted) | **Deferred** — fawaz's own numbering doesn't reliably track sunnah.com's real citations for this book; needs separate investigation |
| 1c. Site-level duplication (not a citation convention) | Tabarani | 38 rows (of 210 groups) | **Fixed, partial** — 187 groups need per-pair human judgment |
| 2. Our own numbering-overlap bug | Malik | 125 | **Fixed** |
| 3. Source-site duplication | Lu'lu' wal-Marjan | 69 | **Fixed** |
| 4. Legitimate classical repetition | Nasai-Kubra, Ahmad, ~14 others | 0 (left untouched) | **Not a bug — no action taken** |

Fix scripts: `tool/fix_bukhari_compound_citations.dart`,
`tool/fix_malik_duplicates.dart`, `tool/fix_lulu_marjan_duplicates.dart`,
`tool/fix_tabarani_duplicates.dart`. All idempotent. `tool/
fix_fawaz_internal_duplicates.dart` (the first, wrong Bukhari/Muslim
attempt) is **retired** — kept in git history for the record, not deleted,
but no longer run; Bukhari is now handled by
`fix_bukhari_compound_citations.dart` instead, and Muslim isn't handled by
either script right now.

Separately, and already fixed/published (tag `v1.15.0-hapi`): a *different*
duplication bug where lettered citation variants (e.g. "402b") showed
identical English translation text to their base citation, caused by
`rebuild_from_fawaz.dart` truncating a fractional `hadithnumber` field. See
`sources/README.md` and the "RESOLUTION" section of
`NUMBERING_CORRUPTION_AUDIT.md`. Unrelated to everything below except that
it's the reason this investigation started.

## How this was found

1. **2026-07-28, user report**: Bukhari #402/#690/#1228/#1390 showed
   identical English translation text across rows that should be distinct
   lettered variants. Traced to the fractional-`hadithnumber`-truncation bug
   in `rebuild_from_fawaz.dart`. Fixed, published as `v1.15.0-hapi`.
2. **User pushed back**: sunnah.com's own "Book N, Hadith X" numbering for
   Bukhari 774 is "168, 169, 170" — sequential — while our position-counting
   convention (excluding addenda) produced "172". Two separate problems:
   position-counting convention mismatch (app-side fix, see below), and
   some citation numbers sunnah.com lists once, our data had as
   **exact-duplicate rows**.
3. **User asked why this wasn't caught earlier.** Found
   `sources/amrayn.com/FAWAZ_INTERNAL_DUPLICATION.md`, a report from an
   earlier session (2026-07-24) that found the same pattern via a different
   method (amrayn cross-matching) but only used it to explain match-rate
   statistics, never converted into a fix.
4. **User asked to scan all 30 books.** A whole-file duplicate scan found
   958 duplicate rows across 21 books, classified into what were originally
   thought to be 3 root causes.
5. **First fix attempt** (`tool/fix_fawaz_internal_duplicates.dart`):
   for Bukhari/Muslim, treated fawaz's own `reference: {book:0, hadith:0}`
   placeholder marker on one side of a duplicate-text pair as "this row is
   scraper garbage, drop it, keep the resolved side." Verified narrowly (a
   diacritic-normalization false-positive check on Muslim's empty-Arabic
   Introduction section) but **not verified against sunnah.com itself**.
   Published as `v1.16.0-hapi`.
6. **User tested on device and immediately caught two problems**: citation
   number 273 (dropped by the fix) had simply vanished — no row, no
   explanation, just a jump from 272 to 274 in the reader and large
   red-flagged "gap" ranges across the chapter table of contents. And the
   book's headline hadith count (7260) no longer matched the traditionally-
   cited 7563, with no clear story for why. The user supplied a direct
   sunnah.com screenshot: `sunnah.com/bukhari:272`'s own "Reference:" field
   reads **"Sahih al-Bukhari 272, 273"** — both numbers, one page, one
   hadith. Not a duplicate to delete. A real, sunnah.com-documented compound
   citation.

## The 2026-07-29 correction

This is the important part to get right, because the first fix was
confidently shipped and still wrong.

**What went wrong**: `fix_fawaz_internal_duplicates.dart` inferred "is this
row a duplicate to discard" purely from fawaz's own internal
`reference.book`/`hadith` field (resolved vs. `{0,0}` placeholder) — never
from sunnah.com's own page. That field's `{0,0}` value means "fawaz's
parser didn't resolve a citation for this row," which is NOT the same as
"this row shouldn't exist." For Bukhari, it very often means "fawaz's
parser only recovered one of a hadith's multiple legitimate citation
numbers." Deleting the placeholder side didn't just remove a duplicate row
— it destroyed a real citation number (273) that sunnah.com itself cites,
with no record left anywhere in the data that it had ever existed.

**Re-verification, this time against sunnah.com directly**: sampled 11
groups across the whole book (both the "one placeholder + one resolved"
sub-pattern and the rarer "both resolved, same reference" sub-pattern that
covered the original 272/273 example), spread across different chapters
and group sizes (2-member and 3-member groups). **11/11 confirmed genuine
sunnah.com compound citations** — every single sampled group's real
sunnah.com page title lists exactly the same citation numbers as the
group's `idInBook` members, e.g.:

- `sunnah.com/bukhari:299` → title "Sahih al-Bukhari **299, 300, 301**"
- `sunnah.com/bukhari:1122` → "**1121, 1122**"
- `sunnah.com/bukhari:2303` → "**2302, 2303**"
- (8 more, same pattern, not reproduced here — see the fix script's own
  commit for the full sample list)

The 7 groups originally left untouched (differing real references between
members) were also spot-checked: `sunnah.com/bukhari:1707` is a single,
standalone citation, confirming those are genuinely separate pages/hadith
that happen to share similar text — correctly left alone both times.

**The Muslim side of the same fix turned out to be a different, deeper
problem, not the same one**: checking Muslim samples the same way revealed
that fawaz's `hadithnumber` for Muslim does not reliably track sunnah.com's
real numbering AT ALL, independent of duplication. Two direct content
checks: `idInBook` 2045/2046 (raw Arabic/English about Ibn 'Abbas
testifying regarding a Khutbah before Eid prayer, exhorting women to give
charity — squarely an Eid-prayer topic, consistent with its actual
neighbors 2040-2050) resolve on sunnah.com to `muslim:2045a`/`2046a`,
which are two **completely unrelated** hadith in "The Book of Drinks."
Same finding for `idInBook` 2093/2094 (our content: eclipse prayer;
sunnah.com's real 2094: "Clothes and Adornment"). This means Muslim's
`reference.text: "Sahih Muslim {idInBook}"` (self-generated by
`rebuild_from_fawaz.dart` from `idInBook` alone) is unreliable for
potentially large stretches of the book — a pre-existing problem from the
original fawaz rebuild (commit `bde48ba`), not something introduced or
fixable by this duplicate-row investigation. **Decision: fully revert
Muslim's duplicate-row changes** (restored to the pre-`v1.16.0-hapi`
7,563-row state) rather than ship a fix built on ground truth that's
already known to be unreliable. Muslim's real-numbering-alignment problem
is tracked as separate future work, out of scope here.

**Malik/Lu'lu'/Tabarani were also re-checked** against this same lesson
(don't trust an internal field, verify the real source) before trusting
them further:
- **Malik**: `sunnah.com/malik/51/5` (the real page for the content at
  `idInBook` 1734/1861) shows a single, non-compound reference — confirms
  the duplicate really was our own pipeline's redundant re-add, not a
  citation convention. Fix stands.
- **Tabarani**: an early spot-check made the same class of mistake this
  correction is about — it verified a pair that the actual fix script
  never touched (looked up by raw source `id`, not by the spine's grouping
  key), found two DIFFERENT isnad chains sharing a reused generic English
  translation, and briefly worried the whole Tabarani fix might be
  measuring the wrong thing. Redone properly, matching the actual script's
  grouping (the spine's `arabic` field, which is chain **and** matn
  concatenated, not matn alone): the real dropped pairs have byte-identical
  chain AND matn AND English. Checked one directly on hadithunlocked.com's
  live page (`tabarani:4498a`/`4498b`) — genuinely the same chain and text
  listed twice on one page, no compound-citation framing at all (unlike
  sunnah.com's explicit "Reference: X, Y"). Fix stands; the earlier "38
  dropped" count was already correct, the *methodology validating it* was
  briefly wrong and then fixed.
- **Lu'lu' wal-Marjan**: originally verified via a live hadithunlocked.com
  page fetch (not an internal field), the correct methodology from the
  start. Fix stands unchanged.

## Category 1 — Bukhari: compound citations, fixed by merging (not deleting)

`tool/fix_bukhari_compound_citations.dart` replaces the retired
`fix_fawaz_internal_duplicates.dart` for Bukhari. For each of 289 confirmed
compound-citation groups (295 groups originally found, 6 left alone as
differing-reference/likely-genuine-repetition — see the correction above):

- Merge into **one** surviving row (the lowest `idInBook` — sunnah.com
  always lists the lowest number first in its own "Reference:" field, and
  any number in the group resolves to the same page).
- Rewrite that row's `reference.text` to the **true compound form**
  matching sunnah.com exactly, e.g. `"Sahih al-Bukhari 272, 273"` — the
  dropped numbers are not lost, they live in this string permanently.
- Leave `idInBook`/`id` **exactly as they were** on every surviving row —
  deliberately NOT renumbered. A first version of this script DID renumber
  sequentially to close the resulting gaps (fixing a confusing reader jump
  and red-flagged chapter table-of-contents "gaps" — see below), but the
  user caught a worse problem it created: every citation number after a
  merge would silently drift lower by one, compounding across the book, so
  the very last hadith would no longer read "7563" — the number this book
  is actually known by. 273 is a REAL number in sunnah.com's own
  continuous 1..7563 sequence (confirmed directly: bukhari:298, then the
  299/300/301 compound, then 302 — nothing skipped in the true numbering);
  it just doesn't get its own row anymore since 272's row already carries
  its content. Freezing `idInBook` at its true original value is what
  keeps every later citation anchored to sunnah.com's real numbering all
  the way to 7563, at the cost of `idInBook` no longer being gapless — see
  the app-side fix below for how the reader UI now treats that gap as
  expected instead of an error, which turned out to be the right layer to
  fix this at, not the numbering.

Result: **Bukhari 7589 → 7286 rows** (303 rows folded into 289 merged
entries), 6 groups left untouched as likely genuine repetition under
distinct real citations. `idInBook` unchanged on every surviving row; the
main citation range's own true max is still exactly **7563** (verified:
`idInBook` 7563 exists, is not one of the 26 already-existing tail-appended
lettered-variant rows, and is the highest non-appended `idInBook` in the
book).

## Category 1b — Muslim: deferred (see correction above)

Reverted to the pre-fix 7,563-row state. Not fixed this pass — fawaz's own
numbering needs to be independently verified against sunnah.com (or a
reliable alternative) before any duplicate-row decision can be trusted for
this book. This affects more than just the duplicate-row question: any
future work trusting Muslim's `reference.text` for *any* row should treat
it as unverified.

## Category 1c — Tabarani: site-level duplication (hadithunlocked.com)

Different from Bukhari's pattern — no compound-citation framing exists on
hadithunlocked.com (checked directly). Of 210 duplicate-Arabic (chain+matn)
groups, 23 also have byte-identical English — genuinely the same content
listed twice on the same page (e.g. `tabarani:4498a`/`4498b`, verified
live). Those 38 rows were dropped, keeping the lowest `idInBook` per group.
The remaining 187 groups have matching chain+matn but **different English
translations** with no consistent quality direction (per the user's
explicit request to investigate rather than assume "immaterial") — left
untouched, listed pair-by-pair in `TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md`
for a future manual pass. Result: **10640 → 10602 rows** (38 dropped).

## Category 2 — numbering-overlap bug in our own merge script (Malik only)

`db/by_book/the_9_books/malik.json` appends 140 rows past fawaz's own
maximum (`fawazMax = 1858`) as "new" content beyond fawaz's coverage.
Diacritic-normalized comparison against fawaz's own 1..1858 range found
**125 of 140 (89%)** are duplicates — not 62/140 (44%) from exact-string
matching alone, which missed matches differing only by invisible
formatting marks (spot-checked: `idInBook` 1861 vs 1734, identical content,
differing by one stray Arabic presentation-form character). Verified
against sunnah.com directly (see correction above) — single, non-compound
reference, confirming this is genuinely our own pipeline's redundant
re-add, not a citation convention.

`README.md`'s old "Malik: 127 untranslated entries beyond 1,858" claim was
substantially wrong — only ~15 of the 140 appended rows are actually new
content, corrected in `README.md`.

**Fix, implemented** (`tool/fix_malik_duplicates.dart`): drops any tail row
whose diacritic-normalized Arabic matches something already in 1..1858.
Deliberately does **not** renumber `idInBook`/`id` — this file's `id` is a
legacy join-key for `merge_muallimai_enrichments.dart` over most of its
range, unlike Bukhari's fully-synthetic `id`. Result: **1998 → 1873 rows**
(125 dropped), tail now `idInBook` 1888, 1889, 1986-1998 (gaps by design).

## Category 3 — source-site duplication (Lu'lu' wal-Marjan)

Not our pipeline's fault, not a scraper-retry artifact — a third, distinct
mechanism. Lu'lu' wal-Marjan has no fawaz overlay/append step at all, so
Category 2's explanation could never have applied to it. Traced to
**hadithunlocked.com's own live page**: the same content is genuinely
listed twice under two different item numbers on one page (e.g. "(4)
bukhari:1291" and "(539) bukhari:1291", word-for-word identical), no
compound-citation framing. Whole-book normalized-Arabic scan found 59
duplicate groups, 69 excess rows.

**Fix, implemented** (`tool/fix_lulu_marjan_duplicates.dart`): drops one of
each exact-duplicate pair, keeps the lowest `idInBook`, renumbers
`idInBook`/`id` sequentially (safe here — this book's `id` is a clean
`bookId * 1000000 + idInBook` formula with no legacy join-key dependency,
unlike Malik). `reference` left untouched (derived from the raw item's own
field at import time, not from `idInBook`). Result: **1907 → 1838 rows**
(69 dropped), `idInBook` gapless 1..1838.

## Category 4 — legitimate classical repetition (leave untouched)

- **Nasai al-Kubra**: 33 rows, different chapters, no offset/URL pattern —
  matches its documented nature as the full uncurated collection.
- **Musnad Ahmad**: 19 rows, same-musnad multi-chain pattern.
- **~14 other books**: 1-13 row tails each, no defect pattern.

No action taken. Not re-scanned with diacritic normalization the way
Malik/Lu'lu' were — a residual undercount can't be fully ruled out without
that pass, tracked as future work.

## App-side changes (`hapi_app_v2`)

Bukhari's merged rows need the reader to show the TRUE compound citation
(e.g. "272, 273"), not just the row's own `hadithNumberInBook` (e.g. "272"
alone would silently lose "273"). Changes, all in the app repo:

- **`lib/reading/reader/reader_page.dart`**: generalized the addendum-only
  `_addendumShortLabel` into `_citationShortLabel`, which prefers
  `Hadith.originalReference`'s trailing number(s) over the plain
  `hadithNumberInBook` whenever they actually differ — covers both addenda
  (e.g. "774b") and merged compound citations (e.g. "272, 273") with one
  mechanism. Used by both the reader row's own citation badge and the
  Copy/Share header line. Each number in a multi-number citation renders on
  its own line (a single shrunk-to-fit line was still unreadable once
  there were 2-3 numbers), the badge grows to fit them, and the row is
  tinted amber (the same color an addendum already uses) whenever more
  than one number is shown.
- **`lib/reading/reading_user_db.dart`**: `ReadingUserDb.getHadith` now
  falls back to scanning compound-citation rows (`original_reference LIKE
  '%,%'`) for a whole-number-token match when a direct
  `hadith_number_in_book` lookup misses — so searching/jumping to a
  now-merged citation number (e.g. typing "273") still finds the right row
  instead of reporting "not found."
- **`lib/reading/search/hadith_jump_to_bar.dart`**: the Chapter #
  auto-fill and the Go button's fast path both now resolve the typed
  number to the target row's *real* `hadithNumberInBook` first (via the
  fallback above), instead of using the raw typed number for downstream
  lookups that assume it matches a row exactly.
- **`lib/hadith/hadith_chapter_range_info.dart`**: since `idInBook` is now
  deliberately left with gaps at every merge point (see Category 1 above),
  the chapter table-of-contents' own gap-anomaly detector needed to stop
  treating those as data holes. `computeHadithChapterRangeInfo` now bridges
  any gap that's fully named in the compound citation on the row
  immediately before it (e.g. row 272's own `originalReference`, "Sahih
  al-Bukhari 272, 273", explains a gap of just "273") into one continuous
  range before either building the displayed range list or running the
  red-flag check — so a chapter reads as a clean "248-293" instead of
  splitting into "248-272, 274-293" with both boundary numbers flagged red.

Position-counting convention (`_hadithChapterPositions()`, counts every row
including addenda, matching sunnah.com's own numbering) and the addendum
badge dead-code fix from earlier the same day are unaffected by this
correction and remain as they were.

## Source-quality notes this investigation adds

- **fawazahmed0/hadith-api**: internally self-duplicates in Bukhari,
  Muslim, Nasai, Abu Dawud, Tirmidhi, Ibn Majah, Malik — see
  `FAWAZ_INTERNAL_DUPLICATION.md` for the original per-book breakdown.
  For Bukhari, verified directly against sunnah.com: these are
  overwhelmingly genuine **compound citations** (one real page, multiple
  numbers), not scraper garbage — fawaz's own `{book:0,hadith:0}`
  placeholder marker means "parser didn't resolve this row's citation," not
  "this row is invalid." **This is a correction to how earlier notes in
  this repo characterized that marker.** Nasai/Abu Dawud/Tirmidhi/Ibn
  Majah/Malik's own internal-duplicate counts from `FAWAZ_INTERNAL_
  DUPLICATION.md` have NOT been re-verified against sunnah.com with this
  same rigor — treat them as unverified, likely-but-not-confirmed
  compound-citation candidates, not confirmed bugs, until checked.
- **fawazahmed0/hadith-api, Muslim specifically**: `hadithnumber` does not
  reliably track sunnah.com's real citation numbering — confirmed via two
  direct content mismatches (see correction above). This is a bigger,
  separate problem from anything else in this document, discovered as a
  byproduct of the duplicate-row investigation, affecting the trustworthiness
  of `reference.text` for potentially any row in the book, not just the
  duplicate ones.
- **hadithunlocked.com**: two separate defects, confirmed by direct live-page
  checks (not by trusting either site's internal metadata alone): Tabarani
  has ~210 duplicate-content groups from what looks like a scraper-retry
  pattern (already partially flagged in `import_hadithunlocked.dart`'s own
  doc comment); Lu'lu' wal-Marjan has 69 duplicate rows genuinely present on
  the site's own rendered page, a distinct defect from Tabarani's.
- **This repo's own `rebuild_from_fawaz.dart`-family scripts**: (1) Malik's
  "append beyond max" logic has no overlap check against existing content —
  our own bug. (2) The FIRST duplicate-row fix attempt for Bukhari/Muslim
  (`fix_fawaz_internal_duplicates.dart`, retired) trusted an internal
  reference field over the real source — a methodology mistake worth
  remembering for any future "is this a duplicate" question in this
  pipeline: **verify against the real, authoritative source page directly,
  every time, before deleting anything** — not just once as a spot-check,
  and not by inferring correctness from a field this same pipeline
  generated.
