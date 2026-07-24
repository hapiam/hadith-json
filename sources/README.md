# External data sources: scripts + raw scrape archives

This directory is the durable, git-tracked archive of every external website
this repo has scraped (or scrapes going forward): the exact script used, and
the raw data it produced, kept in chronological order per source so any run
can be re-examined or re-processed later without re-hitting the live site.

## Convention

```
sources/
  <hostname>/                 e.g. amrayn.com
    scripts/                  every scraper script ever used against this
                               source, always written in Dart
    runs/
      <YYYY-MM-DD>_<label>/    one dated folder per distinct scrape campaign
        *.jsonl                raw output, one line per record
        about/*.json           any per-book/per-edition metadata scraped
        scrape.log             the run's own console log, if it kept one
        SNAPSHOT_INFO.md        what this run covered, when, and its final
                                 (or as-of-snapshot) completion status
```

- **One folder per source hostname** — every website ever scraped gets its
  own top-level folder here, so "what did we get from where" is always a
  single `ls sources/` away.
- **Scripts live with their source, not in the shared `tool/` directory.**
  `tool/` is for pipeline scripts that operate on already-merged data
  (`build_unified_editions.dart`, `rebuild_from_fawaz.dart`, etc); anything
  that fetches live HTML/JSON from an external site belongs under
  `sources/<hostname>/scripts/` instead.
- **Runs are dated and named, never overwritten.** A new scrape campaign
  against the same source gets a new `runs/<date>_<label>/` folder rather
  than clobbering the previous one, so old runs stay available for
  comparison (e.g. "did this citation's text change between our 2026-07 and
  a future re-scrape").
- **The live working copy stays outside `sources/`, gitignored.** A scraper
  actively appends to its own working directory (for amrayn.com, that's
  `db/scrape_cache/amrayn/` — see that script's own doc comment) so its
  built-in resume/retry logic can tell "already done" from "not yet
  attempted" without racing against a snapshot copy. Periodically, and
  always once a campaign finishes, that working copy gets snapshotted
  (copied, not moved) into a dated `sources/<hostname>/runs/` folder and
  committed — that snapshot is the durable, reprocessable archive; the
  gitignored working copy is disposable.

## Known sources

| Source | Scripts preserved? | Data preserved? | Used for |
|---|---|---|---|
| **amrayn.com** | ✅ `sources/amrayn.com/scripts/` (main + Malik-specific scrapers, plus every gap-checking script written during the campaign) | ✅ `sources/amrayn.com/runs/` (latest: `2026-07-24_full-catalog`) | Sole independent source for `riyad_assalihin`/`aladab_almufrad`/`shamail_muhammadiyah`; second-opinion cross-check for the 6 fawaz-rebuilt books + malik/nawawi40/qudsi40/darimi; also `nasai_kubra_bonus`/`mustadrak_alhakim_bonus` beyond the core 18. See **[`sources/amrayn.com/README.md`](amrayn.com/README.md)** for the full methodology (two-level citation discovery, the Malik URL-scheme fix, every checker script) and `sources/amrayn.com/runs/*/SNAPSHOT_INFO.md` for per-run status. |
| **fawazahmed0/hadith-api** | ⚠️ `tool/fetch_fawaz_editions.ps1` (PowerShell, predates this convention — not a scrape, fetches a published API/CDN, left in `tool/` rather than migrated here) | ✅ locally cached, used directly by `tool/rebuild_from_fawaz.dart` | Canonical Arabic+English+numbering source for Bukhari/Muslim/Abu Dawud/Tirmidhi/Nasa'i/Ibn Majah (see main `README.md`) |
| **mhashim6/Open-Hadith-Data** (GitHub) | ➖ not applicable — a raw file pull from a public GitHub repo, not a scrape | ✅ merged into `db/by_book/the_9_books/darimi.json` | Darimi's canonical Arabic scaffold |
| **al-hadees.com** | ❌ **not preserved** — the original scraping script was written and run in an earlier chat session's scratch space, not saved into this repo, and no longer exists | ✅ merged result only, in `db/by_book/the_9_books/ahmed.json` (27,632 raw records → 27,648 final, see main `README.md`'s Musnad Ahmad section) | Musnad Ahmad's full rebuild, replacing the old 1,374-hadith AhmedBaset stub |

The last two rows are a known gap this convention is meant to prevent going
forward: if either of those books ever needs re-scraping or a raw-record
audit, the script would have to be rewritten from scratch since it wasn't
archived. Every scrape from this point on should land under `sources/` so
that never happens again.
