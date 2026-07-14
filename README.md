# hadith-json (hapi merge)

A comprehensive JSON database of hadiths in Arabic and English (plus optional Indonesian drafts), based on [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) **`main`**, with carefully ported additions from community forks.

Scraped primarily from [Sunnah.com](https://sunnah.com/).

## Provenance

| Layer | Source | What we took |
|-------|--------|----------------|
| **Base** | [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) `main` | Full bilingual `db/by_book` + `db/by_chapter`, scraper, types. Includes the `id: null` chapter-id fix and latest data corrections. |
| **Grades / references / Hisn** | [muallimai/hadith-json](https://github.com/muallimai/hadith-json) | `grade` + `reference` fields merged **by hadith `id`** without overwriting Arabic/English text from AhmedBaset. Added **Hisn al-Muslim** (`db/by_book/other_books/hisn_almuslim.json`). |
| **Indonesian locale tree** | [sagad/hadith-json](https://github.com/sagad/hadith-json) | Additive `db/by_locale/id/` only. Primary `db/` bilingual files are **not** replaced. |

Git history of this repo starts from AhmedBaset's history for provenance.

### Merge method

Surgical content merge (not a blind git merge of diverged histories):

1. Start from AhmedBaset `main`.
2. Run `tool/merge_muallimai_enrichments.dart` to attach `grade` / `reference` onto matching ids in `db/by_book` and `db/by_chapter`.
3. Copy Hisn al-Muslim JSON from muallimai.
4. Copy `db/by_locale/id` from sagad.

## Books

| # | English | Notes |
|---|---------|-------|
| 1 | Sahih al-Bukhari | |
| 2 | Sahih Muslim | |
| 3 | Sunan Abi Dawud | grades/refs enriched |
| 4 | Jami\` at-Tirmidhi | grades/refs enriched |
| 5 | Sunan an-Nasa'i | grades/refs enriched |
| 6 | Sunan Ibn Majah | grades/refs enriched |
| 7 | Muwatta Malik | |
| 8 | Musnad Ahmad | **chapters 8–30 still missing** (upstream Sunnah.com gap) |
| 9 | Sunan ad-Darimi | |
| 10–17 | Forties + other books | as in AhmedBaset |
| 18 | Hisn al-Muslim | from muallimai |

## Data format (primary bilingual files)

```typescript
interface Hadith {
  id: number;
  idInBook: number;
  chapterId: number;
  bookId: number;
  arabic: string;
  english: {
    narrator: string;
    text: string;
  };
  grade?: string | null;
  reference?: {
    text?: string;
    url?: string;
  };
}
```

Layouts:

- `db/by_book/` — one JSON file per book
- `db/by_chapter/` — one JSON file per chapter
- `db/by_locale/id/` — Indonesian **draft** translations (see below)

## Indonesian locale (`db/by_locale/id`) — DRAFT

Ported from sagad/hadith-json. Structure:

- `db/by_locale/id/by_book/...`
- `db/by_locale/id/by_chapter/...`

Each hadith uses a localized shape with `translation.status`. **All Indonesian entries are `status: "draft"`** — machine / AI-assisted translation from English, **not** editorial-quality. Do not treat as verified for formal publication without human review.

Note: sagad's README describes planned `ar` / `en` locale mirrors; this merge only includes the committed **`id`** tree present in that fork.

## Known limitations

- **Musnad Ahmad chapters 8–30** are missing from Sunnah.com source data. No fork fixed this; the gap remains. Existing Ahmad chapters (1–7, 31) from AhmedBaset are preserved.
- Grades are sparse or null for some books (e.g. Bukhari, Muslim) depending on Sunnah.com source fields in the muallimai scrape.
- Indonesian drafts may include imperfect MT output.

## Fawazahmed0 multi-language editions (`db/editions`)

Additive **side-by-side** port from [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) (CDN tag `@1`). Schemas are **incompatible** with the bilingual AhmedBaset layout — content is **not** field-merged into `db/by_book`, `db/by_chapter`, or `db/by_locale`. Primary bilingual data, muallimai grades/references, Hisn al-Muslim, and the Indonesian locale tree are untouched.

**Ported:**

- Catalog: `db/editions/editions.json`, `editions.min.json`, `info.json`
- Whole-edition minified files: `db/editions/files/{name}.min.json` (~74 editions)
- Mapping notes: `db/editions/MAPPING.md`
- Refresh script: `tool/fetch_fawaz_editions.ps1`

**Not ported:**

- No Ahmad / Darimi (fawaz has no those books); no hapi-only books (Riyad, Mishkat, Adab, Shamail, Bulugh, Hisn)
- No per-hadith or section shards (`editions/{name}/{n}.json`) — use the CDN for those: `https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/`

Languages available in fawaz editions: Arabic, Bengali, English, French, Indonesian, Russian, Tamil, Turkish, Urdu.


## Attribution & license

Upstream data and code remain attributed to [Ahmed Abdelbaset / AhmedBaset](https://github.com/AhmedBaset/hadith-json) and contributors. Additional fields and Hisn from [muallimai](https://github.com/muallimai/hadith-json); Indonesian locale drafts from [sagad](https://github.com/sagad/hadith-json). Follow upstream licensing / attribution expectations when redistributing.

## Contributing

Issues and PRs welcome for data corrections, additional locales (with clear draft/verified labeling), or grade/reference improvements.

---

*May Allah accept this work and make it beneficial. Ameen.*