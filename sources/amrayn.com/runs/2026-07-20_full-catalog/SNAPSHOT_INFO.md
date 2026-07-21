# Run: 2026-07-20 full-catalog scrape

Campaign started 2026-07-20, targeting all 15 amrayn.com-covered books (see
`../../scripts/scrape_amrayn.dart`'s own `books` list) via one continuous
sequential process plus, from 2026-07-21 onward, additional parallel
processes for the books further back in the queue (see the parent
`sources/README.md` for why/how — this repo runs scrapes as a live working
copy in `db/scrape_cache/amrayn/`, gitignored, with dated snapshots like this
one committed here at meaningful checkpoints).

**This snapshot was taken 2026-07-21, while the campaign was still actively
running** (several books not yet complete — `.jsonl` files here reflect
whatever had been fetched at snapshot time, not necessarily each book's final
state). Re-run the snapshot copy once the whole campaign wraps up and replace
these files with the final version before removing this notice.

## Status at snapshot time (ok/target, gap notes)

| Book | ok | target | Notes |
|---|---|---|---|
| riyad_assalihin | 1896 | 1896 | Complete |
| aladab_almufrad | 1322 | 1322 | Complete |
| shamail_muhammadiyah | 394 | 398 | 4 permanent 404s (confirmed via retry, not transient) |
| bukhari | 6791 | 7076 | 285 permanent 404s (confirmed via full retry pass) |
| muslim | in progress | 7190 | main sequential process still running |
| nasai, abudawud, tirmidhi, ibnmajah, darimi, nasai_kubra_bonus, mustadrak_alhakim_bonus | in progress | — | parallel processes started 2026-07-21 |
| nawawi40 | 42 | 42 | Complete |
| qudsi40 | 40 | 40 | Complete |
| malik | **0** | 1973 | **Every entry 404s** — this book uses a different URL scheme (`/malik/{chapter}/{hadithInChapter}`, not the flat `/malik:N` every other book uses). Scraping paused; needs a dedicated per-chapter routine, not a retry. See `../../README.md`. |
