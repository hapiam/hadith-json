# Processed — one clean JSON file per book ("scrape 1.0")

The cleaned, deduplicated, properly-ordered version of each book's raw
scrape — this is what to load into the app or diff against `db/by_book/`,
not the raw `.jsonl` in `../runs/`.

Built by [`../scripts/build_processed.dart`](../scripts/build_processed.dart)
from the latest `../runs/<date>/` snapshot. Re-run that script any time the
raw scrape gains new data (a re-scrape, a resumed discovery pass, etc.) to
regenerate these files — they're meant to be maintained going forward, not
a one-off export.

## Shape

```json
{
  "book": "muslim",
  "aboutAmrayn": { /* book+author metadata amrayn scraped, or null */ },
  "hadithCount": 6923,
  "hadiths": [
    { /* every raw field the scraper captured, verbatim — see
         scrape_amrayn.dart's own doc comment for the full field list
         (isnad chain, notes, postscript, tags, cross-collection links,
         raw grade flag, etc.). Nothing trimmed, even fields the app has
         no current use for. */ }
  ]
}
```

`hadiths` is in proper book order (chapter/hadith #, not scrape-fetch
order) — see `build_processed.dart`'s own doc comment for exactly how each
book's ordering key is derived (plain `idInBook` for most books; Malik's
own `(malikChapterNum, malikLocalHadithNum)`; lettered-citation books like
Muslim thread `8`/`8a`/`8b`/`8d` in immediately after each other).

Only successful, deduplicated records are kept — rows that errored (dead
links, stale flat-URL attempts against a book that needed citation
discovery) are dropped. Per-book counts and known permanent gaps (404s
confirmed real, not a scraper bug) are documented in
`../runs/*/SNAPSHOT_INFO.md`.
