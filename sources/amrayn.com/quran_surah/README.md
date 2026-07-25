# amrayn.com Surah-info scrape — archive

A separate, smaller scrape effort from the hadith-citation one archived in
this same `sources/amrayn.com/` folder (see `../README.md`) — this one
pulls **Quran Surah background/tafsir-summary text** (name, period of
revelation, theme, historical background, etc.) from
`amrayn.com/quran/info/{surahNumber}`, feeding the data behind
`SurahAboutPage` in the `hapi_app_v2` app repo
(`lib/quran/surah_about_page.dart`) — same "About" page format as the
Hadith book About page (see task history for "Build Surah About page by
scraping amrayn.com"). Archived here — moved out of `hapi_app_v2` itself,
which is app code only, not scraper/tooling — so the raw pages and the
extraction logic don't have to be re-derived if the app's Surah-about
content ever needs regenerating or extending to other surahs.

## Layout

```
quran_surah/
  raw_pages/   surah{N}.txt — raw scraped page text for surahs 30-58
  scripts/     the extraction/generation tooling
  generated/   an intermediate generator OUTPUT, kept for reference only
```

## How the data got from amrayn.com into the app

1. **Fetch**: each `raw_pages/surah{N}.txt` is the plain-text content of
   `amrayn.com/quran/info/{N}` (30 through 58 — this batch's range; other
   surahs' data came from an earlier pass not preserved this way, see
   `hapi_app_v2/lib/quran/surah_about_data_1.dart` through `_4.dart`'s own
   history/comments, in the app repo, for what covers what).
2. **Extract fields**: `scripts/test_extract6.dart` — regex-based field
   pullers (`extractStringField`/`extractRawField`/
   `extractStringArrayField`) for the structured metadata amrayn embeds
   per surah page (revelation place/order, ruku/hizb count, manzil, juz
   info, intro).
3. **Extract prose sections**: `scripts/build_surah_data.ps1` — per-surah,
   *explicitly hand-identified* ordered section-heading lists (`Name`,
   `Period of Revelation`, `Historical Background`, `Theme and Subject
   Matter`, etc. — these vary surah to surah, which is why they're listed
   out per surah rather than parsed generically) used to slice each raw
   page's prose into `SurahAboutSection(title, body)` entries.
4. **Emit Dart**: `scripts/build_dart.ps1` — assembles the extracted
   fields + sections into `SurahAbout(...)` Dart object literals, one per
   surah, in the shape `hapi_app_v2/lib/quran/surah_about_data_*.dart`
   expects. `scripts/entries.dart` is a saved snapshot of that generated
   output — also see `generated/surah_about_data_2_generated.dart`, an
   earlier full-file generation pass kept for reference.
5. **Result**: the reviewed/cleaned-up final version of this data lives
   in the app repo proper at `hapi_app_v2/lib/quran/surah_about_data_2.dart`
   — treat that as canonical, not anything in this archive.

## Re-running this

Both `.ps1` scripts hardcode the path they were originally run from (a
now-deleted session scratch directory) — update the `$dir` variable at
the top of each to point at this folder's `raw_pages/` before attempting
to re-run either one. `test_extract6.dart`'s field-extraction regexes are
path-independent and can be reused directly.

## Relationship to the Hadith-citation amrayn scraper

This is a **separate scrape target on the same site** — different URL
pattern (`/quran/info/{N}` vs. the hadith citation scraper's
`/{book}:{n}` or `/{book}/{chapter}/{n}`), different content shape, no
shared code with `../scripts/scrape_amrayn.dart`. See `../README.md` for
that effort.
