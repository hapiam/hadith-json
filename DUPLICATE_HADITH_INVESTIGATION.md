# Duplicate hadith rows: discovery, why it sat unfixed, and the current cleanup

Status as of 2026-07-29: **investigation and classification complete for all 30
books; fix code not yet written.** This document is the full narrative —
written up per explicit request, because this bug was found once before
(2026-07-24, `FAWAZ_INTERNAL_DUPLICATION.md`) and not acted on, and the user
wanted that failure mode on the record alongside the fix.

## TL;DR

958 duplicate rows exist across 21 of 30 books. They are **not one bug** —
three unrelated mechanisms produced them, and only two are actually wrong:

| Category | Books | Rows | Verdict |
|---|---|---|---|
| 1. Scraper-retry duplication | Bukhari, Muslim, Tabarani | ~713 | **Bug — fix by dropping the placeholder duplicate** |
| 2. Our own numbering-overlap bug | Malik, Lu'lu' wal-Marjan | ~146 | **Bug — fix by overlap-aware append, not blind concatenation** |
| 3. Legitimate classical repetition | Nasai-Kubra, Ahmad, ~14 others | ~99 | **Not a bug — leave untouched** |

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

**Fix approach**: for each duplicate pair, drop the placeholder/incomplete
side and keep the resolved side; where both sides are fully resolved but
differ slightly in transcription quality, keep whichever has fewer OCR/typo
artifacts (manual or heuristic per-pair, not a blind rule). Not yet
implemented.

## Category 2 — numbering-overlap bug in our own merge script (Malik, Lu'lu' wal-Marjan)

This is **our bug, not the source data's** — confirmed by pattern, not
assumption, before writing this section (per "do all checks you need before
starting").

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

### Lu'lu' wal-Marjan

21 rows show a near-uniform `idInBook` offset pattern (+126/+127) between
duplicate pairs, and — stronger evidence than Malik had at the same stage —
the two rows in each pair share the **same source `url`/`path`**, meaning
the scrape genuinely fetched the identical source page twice: once landing
at a sensible low citation number, once dumped into a high "tail" range
(1699/1837/1854-ish). This is the same class of bug as Malik (overlap-unaware
append) but with even more direct evidence (shared source URL, not just
content similarity). Full `text.ar`-level verification (the same rigor
Tabarani got) has **not yet been done** for this book — flagged as
remaining work before writing the fix.

**Fix approach for both books**: before appending any "beyond max" row,
diacritic-normalize and content-match it against the existing 1..max range;
only append if no match is found. Not "row-by-row delete" (which would risk
deleting the wrong side of a pair) — an overlap check gate on the append
step itself, consistent with how `arabic_match.dart` already does
content-matching elsewhere in this pipeline. Not yet implemented for either
book.

## Category 3 — legitimate classical repetition (leave untouched)

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

**Fixed in `hapi_app_v2`, uncommitted, awaiting device test**:
- Position-counting convention (`_hadithChapterPositions()` in
  `reader_page.dart`) changed to count every row including addenda, matching
  sunnah.com's own "Book N, Hadith X" numbering exactly (verified directly:
  Bukhari 774→168, 774b→169, 775→170).
- Addendum badge dead-code bug (showed an internal row id instead of the
  citation position).

**Investigated and classified, fix code not yet written**:
- Category 1 (Bukhari/Muslim/Tabarani scraper-retry duplicates).
- Category 2 (Malik/Lu'lu' wal-Marjan numbering-overlap bug).

**Not yet started**:
- Lu'lu' wal-Marjan's `text.ar`-level verification (Tabarani-equivalent
  rigor).
- Writing and running the actual dedup/overlap-check fix for Categories 1–2.
- Re-running `build_unified_editions.dart`, publishing a new tag, updating
  `hapi_app_v2`'s catalog once the above lands.

## Source-quality notes this investigation adds

These extend the "Known sources" table in `sources/README.md` and the
per-book notes in `README.md`:

- **fawazahmed0/hadith-api**: internally self-duplicates in Bukhari (401
  confirmed instances), Muslim (93), Nasai (15), Abu Dawud (4), Tirmidhi
  (92), Ibn Majah (5), Malik (109) — see `FAWAZ_INTERNAL_DUPLICATION.md` for
  the full per-book breakdown. Caused by upstream scraper retries, not
  anything in this repo's own pipeline for those rows specifically — but
  this repo's `rebuild_from_fawaz.dart` did not filter them out, so they
  passed straight through into `db/unified/`.
- **hadithunlocked.com**: Tabarani specifically has ~338 duplicate rows from
  the same retry pattern (already partially documented in `tool/
  import_hadithunlocked.dart`'s doc comment re: "340 duplicate numbers" in
  the raw `item.number` field — now confirmed at the content level, not
  just the numbering level).
- **This repo's own `rebuild_from_fawaz.dart`-family scripts**: the Malik
  and Lu'lu' wal-Marjan "append beyond max" logic has no overlap check
  against existing content — a defect in our code, not in any upstream
  source. Any future book handled with a similar "append what didn't match"
  pattern should get the overlap check from the start, not retrofitted
  after the fact.
