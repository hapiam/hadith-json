# Duplicate hadith rows: discovery, why it sat unfixed, and the current cleanup

Status as of 2026-07-29: **fixed and published for Bukhari, Muslim, Malik,
Lu'lu' wal-Marjan, and Tabarani** (partially for Tabarani — see Category 1).
This document is the full narrative — written up per explicit request,
because this bug was found once before (2026-07-24,
`FAWAZ_INTERNAL_DUPLICATION.md`) and not acted on, and the user wanted that
failure mode on the record alongside the fix.

## TL;DR

Fixed, verified isolated to the intended books (`db/unified/catalog.json`
`hadithCount` diffed against the pre-fix baseline — exactly bukhari, muslim,
malik, lulu-marjan, tabarani changed, nothing else moved), and republished:

| Category | Books | Rows dropped | Verdict |
|---|---|---|---|
| 1. Scraper-retry duplication | Bukhari, Muslim, Tabarani | Bukhari 303, Muslim 68, Tabarani 38 (of 210 groups — see below) | **Fixed** (Tabarani partial — 187 groups need per-pair human judgment, not auto-resolved) |
| 2. Our own numbering-overlap bug | Malik | 125 | **Fixed** |
| 3. Source-site duplication | Lu'lu' wal-Marjan | 69 | **Fixed** |
| 4. Legitimate classical repetition | Nasai-Kubra, Ahmad, ~14 others | 0 (left untouched) | **Not a bug — no action taken** |

Fix scripts: `tool/fix_fawaz_internal_duplicates.dart` (Bukhari/Muslim),
`tool/fix_malik_duplicates.dart`, `tool/fix_lulu_marjan_duplicates.dart`,
`tool/fix_tabarani_duplicates.dart`. All idempotent (safe to re-run). The
other 19 books with small legitimate-repetition tails (Category 4) were
deliberately left untouched — confirmed by the `catalog.json` `hadithCount`
diff that their counts didn't shift, but they have **not** been re-scanned
with diacritic normalization the way Malik/Lu'lu' were, so a residual
undercount in that category (already believed to be legitimate, not a bug)
can't be ruled out without doing that pass too.

Separately, and already fixed/published (tag `v1.15.0-hapi`): a *different*
duplication bug where lettered citation variants (e.g. "402b") showed
**identical English translation text** to their base citation, caused by
`rebuild_from_fawaz.dart` truncating a fractional `hadithnumber` field. See
`sources/README.md` and the "RESOLUTION" section of
`NUMBERING_CORRUPTION_AUDIT.md`. That fix is unrelated to the row-level
duplicates described here — it was a translation-*pairing* bug, not a
duplicate-*row* bug — but it's the reason this investigation started.

## How this was found

1. **2026-07-28, user report**: Bukhari #402/#690/#1228/#1390 showed
   identical English translation text across rows that should be distinct
   lettered variants. Traced to the fractional-`hadithnumber`-truncation bug
   in `rebuild_from_fawaz.dart` (map-key collision, last-write-wins). Fixed,
   re-published as `v1.15.0-hapi`.
2. **User pushed back** on the fix being declared complete: pointed out that
   sunnah.com's own "Book N, Hadith X" numbering for Bukhari 774 is "168,
   169, 170" — sequential, nothing skipped — while our own position-counting
   convention (excluding addenda from the count) produced "172" for the same
   row. Two separate problems surfaced from this:
   - Our position-counting convention doesn't match sunnah.com's (app-side
     fix, `hapi_app_v2/lib/reading/reader/reader_page.dart`, see below).
   - Some citation numbers that sunnah.com lists once, our data has as
     **exact-duplicate rows** — a genuine data problem, not a counting
     convention mismatch.
3. **User asked**: "why did we not catch this when diffing different
   versions we download?" This led to finding `sources/amrayn.com/
   FAWAZ_INTERNAL_DUPLICATION.md` — a report from an **earlier session
   (2026-07-24)** that already discovered this exact pattern (e.g. Bukhari:
   401 of fawaz's "amrayn never matches" rows are exact duplicates of a row
   amrayn *does* match) while investigating amrayn cross-match rates. That
   report used the finding only to explain *why* amrayn's match percentage
   looked lower than expected — it was never converted into a dedup fix.
   **This is the direct answer to "why didn't we catch this": we did catch
   it, once, four days earlier, and didn't act on it** because the
   investigation at the time was scoped to a different question (match-rate
   explanation) rather than data-quality remediation.
4. **User asked to scan all 30 books**, not just the originally-reported
   ones. A whole-file duplicate scan (exact-text + Arabic-content match)
   found 958 duplicate rows across 21 books.
5. **User asked for root-cause classification before any fix** ("keep
   investigating before we make changes" / "do all checks you need before
   starting"). That classification is Categories 1–3 below.

## Category 1 — scraper-retry duplication (Bukhari, Muslim, Tabarani)

Adjacent-row pairs with **exact-identical Arabic matn**, where one side of
the pair carries an unresolved/placeholder marker (missing chapter/citation
metadata) and the other is fully resolved. Consistent with a scraper having
retried a request and both the failed-partial and successful attempt landing
in the output.

- Bukhari: 305 rows (subset of the fractional-numbering-related rows fixed
  in `v1.15.0-hapi`'s pipeline pass, but the *row-duplication* itself is a
  separate defect from the translation-pairing bug that release fixed).
- Muslim: 70 rows.
- Tabarani (hadithunlocked.com source): ~338 rows. `tool/
  import_hadithunlocked.dart`'s own doc comment already flags Tabarani as
  having "340 duplicate numbers" in hadithunlocked's raw `item.number` field
  — this is that same defect, confirmed at the content level.

**Translation-quality check (user's explicit ask)**: the user's working
hypothesis was "one variant probably has better data, fixing typos in the
other" — investigated directly against Tabarani's raw `text.ar` (matn) and
English fields (not just `chain.ar`/isnad, which I initially and incorrectly
checked first). Finding: real quality variance exists between the two
copies of a pair, but **no consistent direction** — sometimes the
later-numbered copy is cleaner, sometimes the earlier one is. The fix
therefore needs a per-pair "keep the better text" comparison, not a
blanket "keep first" or "keep last" rule.

**Fix, implemented** (`tool/fix_fawaz_internal_duplicates.dart` for
Bukhari/Muslim, `tool/fix_tabarani_duplicates.dart` for Tabarani):
re-reads fawaz's raw per-language edition to recover the placeholder
signal the spine itself doesn't preserve (`rebuild_from_fawaz.dart`
regenerates its own `reference.text`/`url` from `idInBook`, overwriting
fawaz's original `reference.book`/`hadith`), groups spine rows by
diacritic-normalized Arabic text, and for each group: drops the
placeholder side if exactly one exists; if every member is a placeholder
(content-identical, no chapter info on either side to prefer — found in
Muslim only, 44 groups), keeps the lowest `idInBook`; if every member is
resolved with the *same* real reference (a genuine fawaz double-count,
confirmed for Bukhari `idInBook` 272/273, both citing sunnah.com Book 5
Hadith 25), keeps the lowest. Anything else — resolved members disagreeing
on their real reference, meaning the text match might be two genuinely
different classical citations rather than a bug — is left untouched and
printed for manual review, never auto-resolved.

Results: **Bukhari 7589 → 7286 (303 dropped, 1 group/2 rows left for
review)**, **Muslim 7563 → 7495 (68 dropped, 2 groups/4 rows left for
review)**. A false-positive risk surfaced and was closed during
implementation: Muslim's Introduction section (`chapterId: 0`, ~90 rows)
has **empty-string Arabic** for every entry — normalizing to the same `""`
key collapsed all of them into one spurious 99-member "duplicate" group.
The reference-mismatch fallback correctly refused to auto-drop any of them
(each has a distinct real `book:0` reference number), but the script was
additionally hardened to skip any normalized key under 15 characters from
grouping entirely, so this class of false positive can't reach the
auto-drop paths on a future run even if the mismatch-fallback weren't
there.

Tabarani (`tool/fix_tabarani_duplicates.dart`) is **only partially
fixed**: of 210 duplicate-Arabic groups, only 23 also had byte-identical
English translation — those were dropped (38 rows). The remaining 187
groups have matching Arabic but genuinely different English between
copies (confirmed earlier: no consistent "which side is better" pattern),
so no automated rule picked a winner — both rows are still present,
listed pair-by-pair with full English text in
`TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md` for a future manual pass.
Tabarani: 10640 → 10602 (38 dropped).

## Category 2 — numbering-overlap bug in our own merge script (Malik only)

This is **our bug, not the source data's** — confirmed by pattern, not
assumption, before writing this section (per "do all checks you need before
starting"). (Lu'lu' wal-Marjan was originally grouped here too on the
strength of an early exact-string scan; re-verified below in Category 3 and
moved out — its cause turned out to be different.)

### Malik

`db/by_book/the_9_books/malik.json` appends 140 rows past fawaz's own
maximum (`fawazMax = 1858`, read directly from `db/editions/files/
ara-malik.min.json`) as "new" content beyond fawaz's coverage. Checking
those 140 appended rows against fawaz's own 1..1858 range:

- **Exact-string match**: 62 of 140 (44%) are duplicates.
- **Diacritic/whitespace-normalized match** (`s.replace(/[ً-ٰٟ]/g,'').replace(/\s+/g,' ').trim()`):
  **125 of 140 (89%)** are duplicates.

The gap between those two numbers is itself informative: it means the two
source digitizations of Malik use different tashkeel/diacritic markup for
the *same* underlying text, which plain string equality doesn't see through.

Spot-checked one normalized-only match to rule out the normalization being
too aggressive (i.e. accidentally collapsing two genuinely different hadith
onto each other): appended row `idInBook 1861` vs. fawaz-covered row
`idInBook 1734` —

```
1861: وَحَدَّثَنِي عَنْ مَالِكٍ، عَنْ صَفْوَانَ بْنِ سُلَيْمٍ، أَنَّهُ بَلَغَهُ أَنَّ النَّبِيَّ صلى الله عليه وسلم قَالَ ‏"‏ أَنَا وَكَافِلُ الْيَتِيمِ...
1734: وَحَدَّثَنِي عَنْ مَالِكٍ، عَنْ صَفْوَانَ بْنِ سُلَيْمٍ، أَنَّهُ بَلَغَهُ أَنَّ النَّبِيَّ صلى الله عليه وسلم قَالَ ‏ "‏ أَنَا وَكَافِلُ الْيَتِيمِ...
```

Identical content; the only difference is one stray invisible Arabic
presentation-form mark next to an already-present quote character — exactly
the kind of noise diacritic normalization is supposed to see through, not a
false positive. **This confirms 125/140 is the real count, not 62/140.**

Practical implication: `README.md`'s current "Malik: 1,858, not 1,942" /
"127 Arabic-only entries beyond that ceiling, untranslated" framing is
substantially wrong. That framing assumed the appended tail was genuinely
new content fawaz simply hadn't translated. In fact **only about 15 of the
140 appended rows are actually new** — the other 125 are the same hadith
fawaz already has, re-added under a new `idInBook` because the merge script
appended by *position* (past `fawazMax`) instead of checking whether the
content already existed somewhere in 1..1858.

**Fix, implemented** (`tool/fix_malik_duplicates.dart`): drops any tail row
(`idInBook` > 1858) whose diacritic-normalized Arabic matches something
already in 1..1858; the 15 genuinely new tail rows are left exactly as
they were. Deliberately does **not** renumber `idInBook`/`id` on the
survivors — this file's `id` field is a legacy sequential value inherited
from the original AhmedBaset spine for most of its range (used as
`merge_muallimai_enrichments.dart`'s join key against muallimai's
grade/reference data, only switching to a clean `bookId * 1000000 +
idInBook` formula in the last few rows) — renumbering risked quietly
breaking that join if this file is ever re-merged from muallimai's source
again. Result: **1998 → 1873 rows (125 dropped)**, tail now `idInBook`
1888, 1889, 1986–1998 (gaps where duplicates were removed, by design).

## Category 3 — source-site duplication (Lu'lu' wal-Marjan)

**This one is not our pipeline's fault, and not a scraper-retry artifact
either — it was re-investigated from scratch and turns out to be a third,
distinct mechanism.** Lu'lu' wal-Marjan has no fawaz overlay at all (it's
sourced entirely from hadithunlocked.com, sequential `idInBook` 1..1907, no
"append past max" step in its pipeline the way Malik has) — so the
Category-2 "our merge script" explanation could never have applied to it in
the first place. The original classification (grouped with Malik as
"same bug class... even more direct evidence") was wrong and is corrected
here.

A whole-book normalized-Arabic scan (`db/by_book/hadithunlocked/
lulu-marjan.json`, same `s.replace(/[diacritics]/g,'').replace(/\s+/g,'
').trim()` normalization used for Malik) found **59 duplicate groups, 69
excess rows, 128 total rows involved** — not the 21 rows originally
estimated from an early exact-string-only pass. Every group's members share
the same `reference.url` (same hadithunlocked.com page), and are close
together in `idInBook` (e.g. 4 & 5, 39 & 40) rather than split into a
"main body vs. appended tail" pattern the way Malik's are.

Traced one pair (idInBook 4 & 5, `bukhari:1291`, path `lulu-marjan/0/1`) all
the way to **hadithunlocked.com's own live page**
(`https://hadithunlocked.com/lulu-marjan/0/1`, fetched directly): the
duplicate is visible on the rendered page itself, as items **"(4)
bukhari:1291"** and **"(539) bukhari:1291"**, word-for-word identical Arabic
and English, both fully-formed (not one placeholder + one resolved). Spot-
checked 6 more pairs (39/40, 89/90, 97/98, 158/159, 989/990, 1860/1861,
1466/1467) at the raw-JSON level (`sources/hadithunlocked.com/
original_source/hadith/hadithunlocked_lulu-marjan.json`) — all 7 pairs
checked are exact-identical `text.ar` and `text.en`, all same `source.ref`
citation, all same `path`. No pattern distinguishes which side is "the
retry" (unlike Category 1, where one side reliably carries a placeholder
marker) — both copies of a pair are equally well-formed, just genuinely
present twice on hadithunlocked.com's own page.

**Practical read**: al-Lu'lu' wal-Marjan is itself a compilation of hadith
agreed upon by Bukhari and Muslim — a "combined" reference work — so it's
plausible the underlying print edition or hadithunlocked's own digitization
process lists the same combined entry twice under two different item
numbers on one page. Whatever the ultimate cause upstream, our repo faithfully
imported it — this is not something `import_hadithunlocked.dart` did wrong.

**Fix, implemented** (`tool/fix_lulu_marjan_duplicates.dart`): same
operational fix as Category 1's decisive cases (drop one of each
exact-duplicate pair, keep the lowest `idInBook`) even though the root
cause is different. Unlike Malik, this book's `id` field cleanly follows
`bookId * 1000000 + idInBook` throughout (it's hadithunlocked-imported, no
muallimai join), so survivors *were* renumbered sequentially and `id`
recomputed to match — `reference` (text + url) was left untouched since
it's derived from the raw item's own `ref`/`number` field at import time,
not from `idInBook`. Result: **1907 → 1838 rows (69 dropped)**, `idInBook`
now a clean gapless 1..1838.

## Category 4 — legitimate classical repetition (leave untouched)

- **Nasai al-Kubra**: 33 rows. All in different chapters, no offset
  pattern, no shared-source-URL pattern. Matches its documented nature as
  "the full uncurated collection" (as opposed to the curated Sunan an-Nasai)
  — classical hadith collections legitimately record the same report
  multiple times under different chapter headings when it's relevant to
  more than one topic.
- **Musnad Ahmad**: 19 rows. Same narrator/Companion musnad section, very
  short isnad-continuation text — consistent with Ahmad's own structure
  (multiple chains for one report grouped under one Companion's musnad).
- **~14 other books**: 1–13 row "tails" each, no pattern indicating a
  pipeline defect.

No action planned for this category.

## What's fixed already vs. what's still open

**Fixed and published** (`v1.15.0-hapi`):
- Fractional-`hadithnumber` translation-pairing collision
  (`rebuild_from_fawaz.dart`), see `NUMBERING_CORRUPTION_AUDIT.md`.

**Fixed this pass, `build_unified_editions.dart` re-run, isolation verified,
pending tag/publish** (next section below):
- Category 1: Bukhari (303 dropped), Muslim (68 dropped) — fully resolved
  bar 3 groups of legitimately-ambiguous same-text-different-real-citation
  rows, left for human review. Tabarani (38 dropped) — partially resolved,
  187 groups need per-pair translation-quality judgment, tracked in
  `TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md`.
- Category 2: Malik (125 dropped).
- Category 3: Lu'lu' wal-Marjan (69 dropped).
- `db/unified/catalog.json` hadithCount diffed against the pre-fix git
  baseline: exactly bukhari/muslim/malik/lulu-marjan/tabarani changed, every
  other edition (including all Category 4 books) unchanged.

**Fixed in `hapi_app_v2`, uncommitted, awaiting device test**:
- Position-counting convention (`_hadithChapterPositions()` in
  `reader_page.dart`) changed to count every row including addenda, matching
  sunnah.com's own "Book N, Hadith X" numbering exactly (verified directly:
  Bukhari 774→168, 774b→169, 775→170).
- Addendum badge dead-code bug (showed an internal row id instead of the
  citation position).

**Not yet started**:
- Tabarani's 187 remaining translation-quality-variance pairs (manual
  review list generated, not resolved).
- The 3 Bukhari/Muslim groups with legitimately differing real citations
  under identical text (may be genuine classical repetition, Category-4
  style — not auto-resolved, needs a human look).
- Publishing a new tag and updating `hapi_app_v2`'s catalog (this section's
  the very next step).

## Source-quality notes this investigation adds

These extend the "Known sources" table in `sources/README.md` and the
per-book notes in `README.md`:

- **fawazahmed0/hadith-api**: internally self-duplicates in Bukhari (401
  confirmed instances via the earlier amrayn cross-check, 303 confirmed and
  fixed via direct raw-reference verification this pass), Muslim (93 /
  68 fixed), Nasai (15), Abu Dawud (4), Tirmidhi (92), Ibn Majah (5), Malik
  (109) — see `FAWAZ_INTERNAL_DUPLICATION.md` for the full per-book
  breakdown from the earlier method. Caused by upstream scraper retries,
  not anything in this repo's own pipeline for those rows specifically —
  this repo's `rebuild_from_fawaz.dart` didn't filter them out, so they
  passed straight through into `db/unified/` until this pass's
  `fix_fawaz_internal_duplicates.dart`. Nasai/Abu Dawud/Tirmidhi/Ibn Majah's
  counts from the earlier method are not yet re-verified or fixed with the
  same rigor — tracked as future work, same pattern expected.
- **hadithunlocked.com**: two *separate* defects, confirmed by different
  methods:
  - Tabarani has ~338 duplicate rows from a scraper-retry pattern (already
    partially documented in `tool/import_hadithunlocked.dart`'s doc comment
    re: "340 duplicate numbers" in the raw `item.number` field — now
    confirmed at the content level, not just the numbering level).
  - Lu'lu' wal-Marjan has 69 duplicate rows that are **not** a scrape
    artifact — confirmed present on hadithunlocked.com's own live page
    (fetched directly, see Category 3 above). This is a genuine upstream
    source-content defect, distinct from Tabarani's retry pattern, even
    though the symptom (duplicate rows in our data) looks the same.
- **This repo's own `rebuild_from_fawaz.dart`-family scripts**: Malik's
  "append beyond max" logic has no overlap check against existing content —
  a defect in our code, not in any upstream source. Any future book handled
  with a similar "append what didn't match" pattern should get the overlap
  check from the start, not retrofitted after the fact. (Lu'lu' wal-Marjan
  does *not* share this defect — it has no "append beyond max" step at all,
  see Category 3.)
