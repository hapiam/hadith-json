# hadith-json (hapi merge)

A comprehensive JSON database of hadiths across Arabic and multiple translation languages, based on [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) **`main`**, with enrichments from community forks — rebuilt around **content-verified numbering** rather than trusting any single source's row order.

Scraped primarily from [Sunnah.com](https://sunnah.com/), with targeted replacements where that source was incomplete (see below).

## Canonical data: `db/unified/`

**Preferred layout for new consumers.** Rebuild with:

```bash
dart run tool/build_unified_editions.dart
```

### Layout

| Path | Purpose |
|------|---------|
| `db/unified/catalog.json` | Index of every language × book edition |
| `db/unified/files/{lang}-{book}.json` (+ `.min.json`) | One complete edition per language × book |
| `db/unified/by_book/{bookKey}.json` (+ `.min.json`) | Master files with all `translations` on each hadith |
| `db/unified/REPORT.md` | Build provenance, discarded duplicates, fawaz↔spine match rates |
| `db/unified/MATRIX.md` | Language × book coverage matrix |
| `db/unified/DATA_QUALITY_REPORT.md` | Every extra/appended, untranslated, or fuzzy-matched hadith, named individually with a reason |
| `hapiam_mirror_hadith/{editionId}.min.json.zip` | Local, gitignored staging output for a third, independent archival mirror at `hapiam/mirror/hadith` — **not** currently wired into the app's own fetch chain (the app's live hadith downloads go straight against this repo, `hapiam/hadith-json`, pinned to tag `v1.5.0-hapi`, via jsDelivr with a `raw.githubusercontent.com` fallback — see `hapi_app_v2/tool/gen_hadith_unified_catalog.dart`); this exists purely as redundancy against `hapiam/hadith-json` itself becoming unavailable |

### Edition schema

```json
{
  "metadata": {
    "bookId": 1,
    "bookKey": "bukhari",
    "language": "en",
    "arabic": { "title": "...", "author": "..." },
    "translation": { "title": "...", "author": "...", "language": "en" },
    "chapters": [{ "id": 1, "arabic": "...", "english": "..." }]
  },
  "hadiths": [
    {
      "id": 1,
      "idInBook": 1,
      "chapterId": 1,
      "bookId": 1,
      "arabic": "...",
      "translation": { "narrator": "...", "text": "..." },
      "grades": [{ "name": "Darussalam", "grade": "Sahih" }],
      "reference": { "text": "Sahih al-Bukhari 1", "url": "https://sunnah.com/bukhari:1" },
      "untranslated": false,
      "noSourceContent": false,
      "appendedOriginal": false
    }
  ]
}
```

`untranslated` / `noSourceContent` / `appendedOriginal` are honesty flags, not errors to hide: a hadith missing a real English/other-language translation is tagged `untranslated` rather than shown blank or silently dropped; a hadith with no content anywhere (a genuine gap in the underlying source, not our pipeline) is additionally tagged `noSourceContent`; a real hadith whose Arabic text didn't confidently content-match any of the target numbering's slots is appended past the end of the book and tagged `appendedOriginal` rather than forced into the wrong slot or discarded. See `DATA_QUALITY_REPORT.md` for the full, named list of every hadith carrying one of these flags.

## Why this repo was rebuilt around content-matching (not position)

The original builder joined every non-English translation (Bengali, French, Indonesian, Russian, Tamil, Turkish, Urdu — English was always sourced from the spine's own `english` field, never through this path) onto the Arabic spine by comparing **fawaz's `hadithnumber` directly against the spine's `idInBook` position** — i.e. "fawaz row 1000 must be the same hadith as spine's 1000th row." That assumption is false whenever the spine itself doesn't advance one-for-one with the citation numbering it claims in its own `reference.text` — which happens constantly, because classical hadith collections routinely group multiple citation numbers (repeated or lightly-varied narrations of the same report) under one consolidated physical entry.

This was caught by direct text comparison, not inference: Bukhari's spine entry at `idInBook=7277` (the very last entry) carries `reference.text: "Sahih al-Bukhari 7563"` — its *own* citation number is 7563 — while the old positional join was attaching it fawaz row **7277's** translation, which is a completely different, unrelated hadith. The drift is cumulative and grows across the book (checked at `idInBook` 100/1000/3000/5000/6000/7000/7277 — text diverged from 1000 onward), meaning a large fraction of every non-English Bukhari/Muslim/Abi Dawud/Tirmidhi/Nasa'i/Ibn Majah translation was silently paired with the wrong Arabic hadith, growing worse toward the end of each book.

**The fix**: for each of those 6 books, every existing spine entry was re-matched onto fawaz's own numbering (1..N, which is also the "total entries including repetitions" count these books are conventionally cited by) **by Arabic content**, using `tool/arabic_match.dart` — never by row position. Once every book's Arabic content is placed at the index that matches its real citation number, `idInBook == hadithnumber` holds by construction, and the existing positional join in `_joinFawazLanguage` becomes correct for every language at once, without needing a code change there.

### The matching algorithm (`tool/arabic_match.dart`)

Layered, in order of confidence: exact 60-character normalized-prefix anchor → word-overlap Dice coefficient (≥0.5) → plain containment → space-insensitive containment (transcription gaps) → honorific/Qur'an-citation-stripped comparison → character-bigram Dice similarity (≥0.85, small spelling variants) → sliding fuzzy-substring window (short fragments merged into a longer neighbor). Anchor matches are the trustworthy majority; anything that only clears a fuzzy layer is listed individually in `DATA_QUALITY_REPORT.md` for a human glance, not silently accepted.

### Verified match rates (this rebuild)

| Book | Old spine → fawaz canonical match | Final count | vs. commonly-cited target |
|---|---|---|---|
| Bukhari | 99.78% (7,261/7,277) | 7,579 | 7,563 (+16 appended, individually listed) |
| Muslim | 98.58% (7,353/7,459) | 7,669 | 7,563 (+106 appended — Muslim uses far more parallel-isnad citation variants than Bukhari) |
| Abi Dawud | 99.92% (5,272/5,276) | 5,278 | 5,274 (+4 appended) |
| Tirmidhi | 97.90% (3,968/4,053) | 4,041 | 3,956 (+85 appended) |
| Nasa'i | 99.12% (5,717/5,768) | 5,809 | 5,758 (+51 appended) |
| Ibn Majah | 99.93% (4,342/4,345) | 4,344 | 4,341 (+3 appended) |
| Darimi | 100% (mhashim6/hadith-islamware swap) | 3,367 | 3,367 (exact) |
| Malik | fawaz-aligned count independently verified across 6 languages | 1,985 Arabic / 1,858 with any translation | 1,858 is the real, source-backed number (see below); 127 Arabic-only entries beyond that are tagged `untranslated`, not dropped |
| Ahmad | al-hadees.com full scrape + 15 numbering gaps individually researched | 27,648 | see Musnad Ahmad section below — 28,199 is not a verifiable target |

Every "extra" (appended) entry above is real old-spine content whose text simply didn't confidently match any of the target numbering's slots (usually a bare cross-reference stub like "narrated similarly, same chain" too short to content-match) — never a fabricated or duplicated record. `DATA_QUALITY_REPORT.md` names every single one, plus every `untranslated`/`noSourceContent` entry, plus every fuzzy (non-anchor) match, so nothing in the above table is opaque.

### Verification discipline

Every rebuild in this round was audited against `git show HEAD:db/unified/catalog.json` as a known-good baseline — diffing every edition's `hadithCount` before/after to confirm changes were isolated to the intended book(s) and nothing else regressed. This is a repeatable check, not a one-time spot-check:

```bash
dart run tool/build_unified_editions.dart
# then diff current db/unified/catalog.json's editions[].hadithCount
# against `git show HEAD:db/unified/catalog.json` — anything that moved
# outside the book(s) you touched is a regression.
```

## Musnad Ahmad ibn Hanbal: all scraped fields, not just Arabic + grade

The al-hadees.com scrape captured more than what originally made it into `ahmed.json`: `classification` (the isnad type — marfu'/mawquf/maqtu', i.e. raised to the Prophet / stopped at a Companion / cut off at a Follower) and `conclusion` (the scholar's own authentication statement, e.g. "its chain is sound") were both present in the raw scrape (`27,632` records) but silently dropped before reaching the final data. Both are now carried through the full pipeline — verified present on 12,536 and 27,599 hadiths respectively out of 27,648. `statusReference` (who issued the `grade`) is also now sourced from the real scraped field rather than hardcoded, though it happens to be uniformly "Darussalam" across every record. Section-level chapter names also now carry the real scraped Urdu group name (`groupUrdu`) instead of an empty placeholder, matching the convention already used for companion-level chapters.

## Musnad Ahmad ibn Hanbal: 27,648, and why not 28,199

Ahmad's original AhmedBaset spine had only 1,374 hadith (Sunnah.com itself is only **4% complete** for this book — verified directly on `sunnah.com/ahmad`, which is likely why the original spine stopped so early). It was replaced entirely with a full scrape of al-hadees.com (27,632 raw records), plus 15 individually-researched numbering gaps cross-checked against islamweb.net's independent text (13 confirmed-recoverable, 1 strong candidate, 1 confirmed genuine gap with nothing to recover) — see `MUSNAD_AHMAD_GAPS.md` in the app repo's `tool/quran_hadith_pipeline/` for the full per-gap research trail. Final count: **27,648**.

Sunnah.com's own about page states Musnad Ahmad "consists of 28199 ahadith organized by 1277 narrators" — this is the figure commonly repeated across secondary Islamic sites and was initially treated as the target. On investigation, al-hadees.com's own maximum citation number is exactly **27,647** (verified directly against the raw scrape), and this number is independently corroborated by other secondary sources describing "approximately 27,647 ahadith with repetitions in the standard recension edited and expanded by [Ahmad's son] Abdullah." No complete, freely-accessible digitization of citations 27,648–28,199 was found (sunnah.com's own content, the likely origin of the 28,199 figure, doesn't go anywhere near that far). Rather than fabricate placeholder entries to hit a round number, **27,648 is treated as the real, defensible target** for this edition; 28,199 is documented here as an unverifiable secondary figure, not silently dropped from the record.

## Muwatta Malik: 1,858, not 1,942

A commonly-cited total for Muwatta Malik (Yahya al-Laythi recension) is 1,942. fawaz's own translation files for Malik — Bengali, English, French, Indonesian, Turkish, Urdu — independently and consistently cap at **1,858** matched rows across every language, a hard content ceiling in fawaz's digitization rather than a counting artifact. 1,858 is treated as the real, source-backed target. The Arabic-only spine (1,985 entries) has 127 entries beyond that ceiling with no matching translation in any of the 6 languages — real Arabic content, tagged `untranslated` rather than removed (see `DATA_QUALITY_REPORT.md`).

## Sunan ad-Darimi: 3,367, exact match

Rebuilt by content-matching the old AhmedBaset spine (3,406 entries) onto mhashim6/hadith-islamware's Arabic-only scaffold (3,367 rows, verified duplicate-free) using the same `arabic_match.dart` algorithm — 100% of old-spine entries matched. 146 of the 3,367 canonical slots had no old-spine match at all (no English ever existed for these in the prior data either) and are tagged `untranslated`.

## Provenance

| Layer | Source | Role |
|-------|--------|------|
| **Spine** | [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) | Structure, Arabic, English narrator/text, chapters (Ahmad and Darimi's spines have since been replaced — see above) |
| **Grades / refs / Hisn** | [muallimai/hadith-json](https://github.com/muallimai/hadith-json) | `grade` + `reference` merged by hadith `id`; Hisn al-Muslim |
| **Multi-language** | [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) | Translations + multi-grader `grades[]` under `db/editions`; also the canonical numbering target for Bukhari/Muslim/Abi Dawud/Tirmidhi/Nasa'i/Ibn Majah |
| **Ahmad Arabic** | al-hadees.com (full scrape) | Replaces AhmedBaset's 1,374-hadith stub entirely |
| **Darimi Arabic** | [mhashim6/Open-Hadith-Data](https://github.com/mhashim6/Open-Hadith-Data) (mirrors ceefour/hadith-islamware) | Replaces AhmedBaset's spine as the canonical Arabic scaffold |
| **Indonesian drafts** | [sagad/hadith-json](https://github.com/sagad/hadith-json) | `db/by_locale/id` for books without fawaz `ind-*` |

## Two-level chapters (Ahmad only, so far)

Ahmad's chapters carry a `parentId` linking a companion/Sahabah sub-section (`subjectUrdu`, currently Urdu-only placeholder labels, 1,214 sub-chapters) to its top-level Musnad group (`groupArabic`, 15–20 sections) — threaded through `build_unified_editions.dart`'s chapter-copying logic. No other book has this two-level structure yet; carrying it forward to the remaining 8 books, and building real Arabic/English companion titles, is tracked as future work (see the app repo's task list).

## Legacy layouts (kept)

These remain for compatibility; prefer `db/unified/` for new work:

| Path | Notes |
|------|-------|
| `db/by_book/` | Original bilingual AhmedBaset + muallimai enrichments. Ahmad and Darimi's files here have been fully replaced (see above); the other 7 still reflect the original spine plus this round's content-matched rebuild. |
| `db/by_chapter/` | Chapter-split bilingual trees |
| `db/by_locale/id/` | Sagad Indonesian drafts (status: draft). Ahmad's old-numbering draft file was renamed `.OLD_1374_numbering.json.bak` rather than deleted, to prevent it from silently mismatching against the new 27,648-hadith numbering via a leftover `idInBook` join — it predates the Arabic replacement and needs re-matching before reuse (tracked as future work). |
| `db/editions/` | Raw fawaz whole-edition files (schema-incompatible side store) — also the canonical-numbering source for the content-match rebuild above. |

Merge helpers:

- `tool/merge_muallimai_enrichments.dart` — attach grade/reference onto spine
- `tool/fetch_fawaz_editions.ps1` — refresh `db/editions`
- `tool/arabic_match.dart` — content-based cross-source Arabic matching (never by position/sequence number)
- `tool/reposition_addenda.dart` — moves an `isAddendum` hadith's `sortKey` to sit right after the canonically-numbered sibling it's a variant of (e.g. old citation "690b" → `690.01`), instead of trailing the whole book
- `tool/transliterate_ahmad_companions.dart` — builds Arabic/transliterated companion (Sahabah) names for Ahmad's sub-chapters from the scraped Urdu labels
- `tool/gen_data_quality_report.dart` — regenerates `db/unified/DATA_QUALITY_REPORT.md` from `db/unified/by_book/*.json`
- `tool/build_unified_editions.dart` — regenerate `db/unified/`

## Books

| # | Key | Notes |
|---|-----|-------|
| 1 | bukhari | Content-matched onto fawaz's 7,563 canonical numbering (99.78% match); full multi-language |
| 2 | muslim | Content-matched onto fawaz's 7,563 canonical numbering (98.58% match); full multi-language |
| 3–6 | nasai, abudawud, tirmidhi, ibnmajah | Content-matched onto fawaz canonical numbering (97.9–99.93% match); multi-lang where fawaz has them |
| 7 | malik | Arabic spine unchanged (1,985); translation ceiling independently verified at 1,858 across 6 languages |
| 8 | ahmad | Full al-hadees.com scrape (27,648) replacing the old 1,374-hadith stub; 15 numbering gaps individually researched |
| 9 | darimi | Arabic spine replaced via content-match onto mhashim6/hadith-islamware (3,367, exact) |
| 10–12 | nawawi40, qudsi40, shahwaliullah40 | Forties; fawaz keys nawawi/qudsi/dehlawi |
| 13–17 | riyadussalihin, mishkat, adab, shamail, bulugh | Spine + sagad ID drafts |
| 18 | hisn | From muallimai; ara + eng |

## Known limitations

- **Muslim's Introduction section** (83 entries, `chapterId: 0`) sits outside fawaz's numbered scheme entirely and is preserved by appending past the main 7,563, not discarded.
- **Malik's 127 Arabic-only entries** (idInBook 1859–1985) have no translation in any of fawaz's 6 languages — tagged `untranslated`, real content.
- **Musnad Ahmad's #24424 gap** is a confirmed genuine gap in al-hadees.com's own numbering (islamweb's independent text also has nothing there) — nothing to recover, left as a numbering skip.
- **Musnad Ahmad currently has only Arabic + Urdu** (27,648/27,648 entries have no English/Indonesian translation). It did have both under the old 1,374-hadith AhmedBaset numbering, but those translations were removed rather than kept attached to citations that no longer match — the old English/Indonesian files were joined by position against a spine that's since been fully replaced by the al-hadees.com scrape, so re-attaching them requires the same content-matching treatment the 6 fawaz-derived books got, not yet done for Ahmad. Tracked as future work.
- **Sunan ad-Darimi has Arabic only** — no English, Indonesian, or any other language exists for any of its 3,367 entries in any upstream source used here (AhmedBaset's own English field was empty for Darimi before this rebuild too; the Arabic-scaffold replacement didn't change that).
- Some language editions have `translation: null` on a subset of rows when fawaz lacks that citation (see `translationCount` in catalog + `REPORT.md`); the exact list, plus every addendum and no-English-translation entry across all 18 books, is in `DATA_QUALITY_REPORT.md`.
- Indonesian sagad entries remain **draft** quality.
- Raw `db/editions` schemas stay separate; do not field-merge them by hand — use the unified builder.

## Attribution & license

Upstream data remains attributed to [Ahmed Abdelbaset / AhmedBaset](https://github.com/AhmedBaset/hadith-json) and contributors; enrichments from [muallimai](https://github.com/muallimai/hadith-json), [sagad](https://github.com/sagad/hadith-json), [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api), [mhashim6/Open-Hadith-Data](https://github.com/mhashim6/Open-Hadith-Data), and al-hadees.com. Follow upstream licensing when redistributing.

---

*May Allah accept this work and make it beneficial. Ameen.*
