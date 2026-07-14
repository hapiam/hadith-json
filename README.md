# hadith-json (hapi merge)

A comprehensive JSON database of hadiths across Arabic and multiple translation languages, based on [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) **`main`**, with enrichments from community forks.

Scraped primarily from [Sunnah.com](https://sunnah.com/).

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
      "reference": { "text": "Sahih al-Bukhari 1", "url": "https://sunnah.com/bukhari:1" }
    }
  ]
}
```

Rules used by the builder:

1. **Structural spine** = AhmedBaset `db/by_book` (ids, chapters, Arabic, English narrator/text). Books like Ahmad / Darimi / Hisn are never dropped when fawaz lacks them.
2. **English** prefers AhmedBaset `english.{narrator,text}`; grades/reference from muallimai + fawaz multi-grader `grades[]`.
3. **Other languages** (bn, fr, id, ru, ta, tr, ur) join fawaz rows by `idInBook == hadithnumber` (fallback `arabicnumber`). Unmatched fawaz rows are skipped (no invented ids). Spine rows without a translation keep `translation: null`.
4. **`ara-{book}`** Arabic-only editions (`translation: null`) still carry grades, reference, chapters. Optional **`ara1-{book}`** = undiacritized Arabic (`language: ar-undiacritized`).
5. **Indonesian**: fawaz `ind-*` when available; otherwise sagad `db/by_locale/id` drafts with `translationStatus: "draft"`.

Edition ids use fawaz-style prefixes (`eng-bukhari`, `urd-muslim`, `ara-ahmad`). Catalog `language` uses short codes (`en`, `ur`, `ar`, …).

## Provenance

| Layer | Source | Role |
|-------|--------|------|
| **Spine** | [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) | Structure, Arabic, English narrator/text, chapters |
| **Grades / refs / Hisn** | [muallimai/hadith-json](https://github.com/muallimai/hadith-json) | `grade` + `reference` merged by hadith `id`; Hisn al-Muslim |
| **Multi-language** | [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) | Translations + multi-grader `grades[]` under `db/editions` |
| **Indonesian drafts** | [sagad/hadith-json](https://github.com/sagad/hadith-json) | `db/by_locale/id` for books without fawaz `ind-*` |

## Legacy layouts (kept)

These remain for compatibility; prefer `db/unified/` for new work:

| Path | Notes |
|------|-------|
| `db/by_book/` | Original bilingual AhmedBaset + muallimai enrichments |
| `db/by_chapter/` | Chapter-split bilingual trees |
| `db/by_locale/id/` | Sagad Indonesian drafts (status: draft) |
| `db/editions/` | Raw fawaz whole-edition files (schema-incompatible side store) |

Merge helpers:

- `tool/merge_muallimai_enrichments.dart` — attach grade/reference onto spine
- `tool/fetch_fawaz_editions.ps1` — refresh `db/editions`
- `tool/build_unified_editions.dart` — regenerate `db/unified/`

## Books

| # | Key | Notes |
|---|-----|-------|
| 1 | bukhari | Full multi-language via fawaz |
| 2 | muslim | Spine↔fawaz `hadithnumber` match ~100%; a few dozen extra fawaz rows skipped |
| 3–7 | nasai, abudawud, tirmidhi, ibnmajah, malik | Grades enriched; multi-lang where fawaz has them |
| 8 | ahmad | Spine-only (+ sagad ID draft). Chapters 8–30 still missing upstream |
| 9 | darimi | Spine ara/eng (+ ID when sagad matches) |
| 10–12 | nawawi40, qudsi40, shahwaliullah40 | Forties; fawaz keys nawawi/qudsi/dehlawi |
| 13–17 | riyadussalihin, mishkat, adab, shamail, bulugh | Spine + sagad ID drafts |
| 18 | hisn | From muallimai; ara + eng |

## Known limitations

- **Sunan ad-Darimi English/Indonesian**: AhmedBaset spine English texts and sagad ID texts are currently empty for Darimi; unified still emits `eng-darimi` (blank translations) + `ara-darimi` for structure.
- **Musnad Ahmad chapters 8–30** missing from Sunnah.com (unchanged).
- Some language editions have `translation: null` on a subset of spine rows when fawaz lacks that `hadithnumber` (see `translationCount` in catalog + `REPORT.md`).
- Indonesian sagad entries remain **draft** quality.
- Raw `db/editions` schemas stay separate; do not field-merge them by hand — use the unified builder.

## Attribution & license

Upstream data remains attributed to [Ahmed Abdelbaset / AhmedBaset](https://github.com/AhmedBaset/hadith-json) and contributors; enrichments from [muallimai](https://github.com/muallimai/hadith-json), [sagad](https://github.com/sagad/hadith-json), and [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api). Follow upstream licensing when redistributing.

---

*May Allah accept this work and make it beneficial. Ameen.*
