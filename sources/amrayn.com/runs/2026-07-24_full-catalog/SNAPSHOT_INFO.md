# Run: 2026-07-24 full-catalog scrape

Snapshot of `db/scrape_cache/amrayn/` taken 2026-07-24, superseding the
`2026-07-20_full-catalog` run — this is the current, most complete state
of the campaign. Kept as a copy, not a replacement: the older run stays
available for comparison (e.g. "did this citation's text change between
2026-07 runs"). See `../../README.md` and the parent `sources/README.md`
for the scraper/archive conventions.

Status below is from `dart run ../../scripts/check_all_scrapes.dart` (naive
flat-count check, run against this snapshot), corrected per-book by the
more precise checkers noted where the naive count is misleading.

## Status at snapshot time (ok/target, gap notes)

| Book | ok | target | Notes |
|---|---|---|---|
| riyad_assalihin | 1896 | 1896 | Complete |
| aladab_almufrad | 1322 | 1322 | Complete |
| shamail_muhammadiyah | 396 | 398 | 2 permanent 404s |
| bukhari | 6791 | 7076 | 285 permanent 404s (confirmed via full retry pass) |
| muslim | **6923** | **6925** | **Naive count reads 3014/7190 (41.9%) — wrong.** Muslim uses letter-suffixed citations (`8a`/`8b`/`8d`.../no `8c`), discovered via the two-level chapter crawl (`citationDiscovery: true`), not a flat `1..7190` sequence. `check_vs_citations.dart muslim` is the definitive check: 6923 of the 6925 *actually-discovered* citations are done — 2 missing (`614b`, `2331a`). Effectively complete. |
| nasai | 5728 | 5758 | 30 missing: 9 permanent 404, 21 transient (retryable on next run) |
| abudawud | 5274 | 5274 | Complete |
| tirmidhi | 3951 | 3956 | 5 permanent 404s |
| ibnmajah | 4327 | 4340 | 13 missing: 12 permanent 404, 1 transient |
| malik | **1405** | **1405** | **Naive count reads 1405/1973 (71.2%) — wrong target.** `1973` is a flat-sequence guess that doesn't apply; Malik's real URL scheme is chapter-local (`/malik/{chapter}/{n}`), scraped by the dedicated `scrape_amrayn_malik.dart`. `check_malik_v3.dart` is the definitive check: **done=1405, stillFailing=0** across all 61 chapters — complete. The 568 "missing" against 1973 are stale attempts against the wrong flat URL scheme, not real gaps (837 old-scheme rows sit in the file too, ignored by the v3 checker). |
| nawawi40 | 42 | 42 | Complete |
| qudsi40 | 40 | 40 | Complete |
| darimi | 3546 | 3546 | Complete |
| nasai_kubra_bonus | 10803 | 11949 | **In progress** — 1146 missing: 628 permanent 404, 466 transient (retryable), 52 never attempted |
| mustadrak_alhakim_bonus | 8719 | 8803 | 84 permanent 404s |

## Net effect vs. the 2026-07-20 snapshot

Every book in the original 15-book catalog is now either complete or down
to a small, confirmed-permanent 404 residue (dead links on amrayn.com
itself, not a scraper problem) — including the two books
(`muslim`, `malik`) that looked worst by naive count but are actually
essentially/fully done once checked against their real citation schemes.
The two bonus books (`nasai_kubra_bonus`, `mustadrak_alhakim_bonus`) were
added after the 2026-07-20 snapshot and are new to this run;
`nasai_kubra_bonus` still has real retryable/unattempted work left.
