# Directory structure, and when/why each part was added

This repo has two distinct eras: the original TypeScript scraper project (2023–2024, AhmedBaset upstream), and the "hapi" fork's data-merge work (starting 2026-07-14). Everything under `db/` traces back to one of those two eras; nothing here was added without a reason tied to a specific problem being solved at the time.

## Era 1 — original AhmedBaset scraper (2023-05-06 onward)

| Path | Added | Why |
|---|---|---|
| `src/`, `types/`, `package.json`, `tsconfig.json`, `biome.json`, `tsup.config.ts`, `pnpm-lock.yaml` | 2023-05-06 (`Setup Project`, `The Main file`) | The original TypeScript scraper itself — `src/helpers/scrapeData.ts` pulled hadith text + chapters from Sunnah.com; `src/helpers/getChapters.ts`/`createDirs.ts`/`createFile.ts` wrote the output into the `db/by_chapter` and `db/by_book` layouts below. This code is what originally produced every book's Arabic + English text and chapter structure. |
| `db/by_chapter/` | 2023-05-06 (`الأربعون النووية`, same day) | Chapter-split bilingual output of the scraper above — one file per chapter, nested under `forties/`, `other_books/`, `the_9_books/`. Kept as a legacy layout; superseded by `db/unified/` for new work. |
| `db/by_book/the_9_books/` | 2023-05-06 (`الكتب التسعة`) | Whole-book bilingual files for the nine canonical collections — the original spine this whole project (and the 2026-07-17 rebuild) is anchored on. |
| `db/by_book/forties/` | 2023-05-06 (`الأربعون النووية` / `كتب الأربعينات`) | The three "Forty Hadith" collections (Nawawi/Qudsi/Shah Waliullah). |
| `db/by_book/other_books/` | 2023-05-06 (`كتب أخرى`) | The remaining five books (Riyad as-Salihin, Mishkat, Adab al-Mufrad, Shamail, Bulugh al-Maram). |
| Grade/reference enrichment, `idInBook` field, per-book/chapter ids | 2023-05 through 2024-04 (`Add idInBook field`, `Add hadiths count`, `fix: id: null when the chapter doesn't have an id`, PR #7, PR #15) | Incremental correctness fixes to the original scraper's output over ~1 year of community contributions — chapter id backfills, hadith counts, MongoDB deploy scaffolding (`Deploy to MONGODB` commits — a separate publishing target for the original project, not used by this fork). |

## Era 2 — the "hapi" fork's multi-source merge (2026-07-14)

Everything below was added in a single day of focused work that turned this from "one scraper's output" into a genuine multi-source merge, immediately followed by the correctness rebuild three days later (Era 3).

| Path | Added | Why |
|---|---|---|
| `db/by_locale/id/` | 2026-07-14, 13:53 (`Merge fork enrichments onto AhmedBaset main for hapi`) | sagad/hadith-json's Indonesian translation drafts, merged in as a same-shaped `by_book`/`by_chapter` tree under a locale prefix — this is the first time a second upstream source was folded in, laying the pattern later sources would follow. |
| `tool/merge_muallimai_enrichments.dart` | 2026-07-14, 13:53 (same commit) | Attaches muallimai/hadith-json's `grade` + `reference` fields onto the AhmedBaset spine by hadith `id` — the first cross-source field merge (as opposed to whole-file replacement). |
| `db/editions/` | 2026-07-14, 14:50 (`Add fawazahmed0 multi-language editions as side-by-side db/editions`) | fawazahmed0/hadith-api's raw per-language-per-book files (`{lang}-{book}.min.json`), added *side-by-side* rather than merged in-place — deliberately kept schema-incompatible with the spine (different field names, own `hadithnumber`/`arabicnumber` numbering) so it could be reconciled properly rather than blindly field-merged. This is the source that made 7 non-English languages possible, and later (Era 3) became the canonical numbering target once its positional join was found to be unreliable. |
| `tool/fetch_fawaz_editions.ps1` | 2026-07-14, 14:50 (same commit) | Refresh script for `db/editions`. |
| `tool/build_unified_editions.dart` | 2026-07-14, 16:20 (`Ship db/unified canonical editions (language x book) as v1.5.0-hapi`) | The real merge engine — joins spine + muallimai + fawaz + sagad into one coherent `db/unified/` output per language×book. This is the file most of Era 3's fixes live in. |
| `db/unified/` (`catalog.json`, `files/`, `by_book/`, `REPORT.md`, `MATRIX.md`) | 2026-07-14, 16:20 onward (six same-day commits through 2026-07-15, 03:20, each captioned "Add unified multi-language editions under db/unified") | Canonical build output — the preferred layout for any new consumer (the app's own `gen_hadith_unified_catalog.dart` reads from here). Six iterative commits that day reflect real debugging/refinement of the join logic, not churn. |

## Era 3 — content-matching correctness rebuild (2026-07-17, today)

Triggered by reconciling this repo's hadith counts against an external reference table and discovering the Era 2 merge engine had a real bug (see README's "Why this repo was rebuilt around content-matching" section for the full technical story).

| Path | Added/changed today | Why |
|---|---|---|
| `tool/arabic_match.dart` | New | Content-based (not positional) Arabic-text matching library — the fix for the positional-join bug. Validated at 99.6%+ on every book it's been run against. |
| `db/by_book/the_9_books/{bukhari,muslim,abudawud,tirmidhi,nasai,ibnmajah,ahmed,darimi}.json` | Rewritten | Six books re-matched onto fawaz's canonical numbering by content; Ahmad's spine fully replaced (al-hadees.com scrape + 15 researched gaps); Darimi's spine replaced (mhashim6/Open-Hadith-Data). Malik untouched (never fawaz-derived to begin with — see README). Old versions preserved as session backups before any rewrite, per this project's "never silently discard real content" discipline. |
| `db/unified/DATA_QUALITY_REPORT.md` | New (via `tool/gen_data_quality_report.dart`) | Every `isAddendum` entry and every hadith with no English translation, across all 18 books (not just the 6 rebuilt this round) — the audit trail for the rebuild above, and a standing reference for the pre-existing gaps too. |
| `hapiam_mirror_hadith/` | New, gitignored | `{editionId}.min.json.zip` for every edition — a local staging output for uploading to `hapiam/mirror/hadith` as a third, independent archival mirror. **Not** the app's live download path (that's this repo directly, via jsDelivr + `raw.githubusercontent.com` — see README's Layout table); this is redundancy, not primary infrastructure, so the zips themselves aren't tracked in this repo's own history. |
| `tool/build_unified_editions.dart` (`isAddendum`/`addendumCount` fields) | Changed | The appended-but-unmatched entries from the rebuild above were initially baked into the headline `hadithCount` undifferentiated from the rest. Fixed so `hadithCount` reflects the real, citable target count and the extras are tracked separately as `addendumCount`, without deleting the underlying content. |
| `README.md` | Rewritten | Documents all of the above — migration rationale, verified match-rate table, and the Ahmad/Malik/Darimi count-reconciliation research, so a future reader doesn't have to reconstruct today's investigation from git blame. |

## Era 4 — doc/report cleanup (2026-07-18)

Era 3 (above) *documented* `DATA_QUALITY_REPORT.md` and a "what the app downloads at runtime" mirror mapping before either was actually true — this pass makes both claims real instead of aspirational.

| Path | Added/changed today | Why |
|---|---|---|
| `tool/gen_data_quality_report.dart` | New | Actually generates `db/unified/DATA_QUALITY_REPORT.md` (Era 3 described this file but never wrote the generator that produces it) — scans all 18 `by_book/*.json` files for `isAddendum` and no-English-translation entries. |
| `db/unified/DATA_QUALITY_REPORT.md` | Regenerated for real | 265 addenda + 31,397 no-English-translation entries, named individually per book. The Ahmad (27,648) and Darimi (3,367) totals dominate the no-English-translation count — both are Arabic-only right now (see README's Known Limitations). |
| `README.md` / `DIRECTORY_STRUCTURE.md` | Corrected | Both previously claimed `hapiam_mirror_hadith/` was "exactly what the app downloads at runtime" — false; the app fetches directly from `hapiam/hadith-json` (this repo) via jsDelivr/raw.githubusercontent, never from `hapiam/mirror`. Reworded to describe it accurately as an unwired archival mirror. Also restored/added Known Limitations bullets for Ahmad (Arabic+Urdu only — English/Indonesian pending re-attachment) and Darimi (Arabic only, no translation exists anywhere upstream), both of which `DATA_QUALITY_REPORT.md`'s real numbers now make impossible to miss. |
| `.gitignore` | Added `hapiam_mirror_hadith/` | It's a local build artifact (zips regenerated from `db/unified/` on demand for mirror upload), not source — doesn't belong in this repo's own history. |

## Current full tree (today)

```
hadith-json-merge/
├── src/, types/                    era 1 — original scraper (2023)
├── db/
│   ├── by_chapter/                 era 1 — legacy chapter-split output
│   ├── by_book/
│   │   ├── the_9_books/            era 1, rewritten era 3 (6 of 9 books)
│   │   ├── forties/                era 1, untouched
│   │   └── other_books/            era 1, untouched
│   ├── by_locale/id/                era 2 — sagad Indonesian drafts
│   ├── editions/                    era 2 — fawaz raw per-language files (75 files)
│   └── unified/                     era 2 canonical output, era 3 corrected
│       ├── catalog.json / .min.json
│       ├── files/                   194 files — per language×book editions
│       ├── by_book/                 36 files — master files, all translations per hadith
│       ├── REPORT.md, MATRIX.md, DATA_QUALITY_REPORT.md
├── tool/
│   ├── build_unified_editions.dart  era 2, extended era 3
│   ├── merge_muallimai_enrichments.dart   era 2
│   ├── fetch_fawaz_editions.ps1     era 2
│   └── arabic_match.dart            era 3 — new
├── hapiam_mirror_hadith/             era 3 — new, 97 zips, uncommitted
└── README.md, DIRECTORY_STRUCTURE.md (this file)
```
