# hadith-json (hapi merge)

A comprehensive JSON database of hadiths based on [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) **`main`**, with grades/references from [muallimai](https://github.com/muallimai/hadith-json), multi-language translations from [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api), and Indonesian drafts from [sagad](https://github.com/sagad/hadith-json).

Scraped primarily from [Sunnah.com](https://sunnah.com/).

## Canonical layout: `db/unified/` (v1.5+)

**This is the recommended consumption path.** One complete option per **(language × book)**, plus master multi-language files.

```
db/unified/
  catalog.json              # all editions + features
  catalog.min.json
  REPORT.md                 # match rates, matrix, notes
  files/{lang}-{book}.json  # e.g. eng-bukhari.json (+ .min.json)
  by_book/{bookKey}.json    # master: arabic + translations{} + grades + reference
```

Rebuild anytime:

```bash
dart run tool/build_unified_editions.dart
```

### Catalog entry

```json
{
  "id": "eng-bukhari",
  "bookKey": "bukhari",
  "bookId": 1,
  "language": "en",
  "languageName": "English",
  "name": "Sahih al-Bukhari (English)",
  "hadithCount": 7277,
  "features": ["arabic", "chapters", "grades", "reference", "translation"],
  "path": "files/eng-bukhari.json",
  "sources": ["ahmedbaset", "fawaz", "muallimai", "sagad"]
}
```

### Edition hadith shape

```json
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
```

- Arabic-only editions (`ara-*`): `translation` is `null`.
- Undiacritized Arabic option: `ara1-{book}` / language `ar-undiacritized`.
- Indonesian drafts (sagad-only books): `translationStatus: "draft"` on metadata/hadith.

### Master `by_book/{bookKey}.json`

Each hadith carries all languages under `translations`:

```json
{
  "arabic": "...",
  "translations": { "en": { "narrator": "...", "text": "..." }, "ur": { "narrator": "", "text": "..." } },
  "grades": [...],
  "reference": { "text": "...", "url": "..." }
}
```

Per-language files are views derived from these masters.

### Merge rules (summary)

1. **Spine** = AhmedBaset `db/by_book` (ids, chapters, Arabic, English narrator/text). Spine-only books (Ahmad, Darimi, Riyad, …) are kept.
2. **English** prefers AhmedBaset `english.{narrator,text}`; grades/reference from muallimai (`grade` → `grades[]`) and fawaz multi-grader `grades[]` when richer.
3. **Other languages** (bn, fr, id, ru, ta, tr, ur) from fawaz `db/editions/files/{lang}-{book}.min.json`, joined by `idInBook == hadithnumber` (fallback `arabicnumber`). Unmatched fawaz rows are skipped and counted in `REPORT.md`.
4. **Indonesian**: fawaz `ind-*` preferred; sagad drafts fill spine-only / gaps and are marked `draft`.
5. **One edition per language per book** (primary fawaz names only; `ara1-*` kept as separate undiacritized option).

### Book keys

| bookKey | bookId | Spine file |
|---------|--------|------------|
| bukhari | 1 | the_9_books/bukhari |
| muslim | 2 | the_9_books/muslim |
| nasai | 3 | the_9_books/nasai |
| abudawud | 4 | the_9_books/abudawud |
| tirmidhi | 5 | the_9_books/tirmidhi |
| ibnmajah | 6 | the_9_books/ibnmajah |
| malik | 7 | the_9_books/malik |
| ahmad | 8 | the_9_books/ahmed |
| darimi | 9 | the_9_books/darimi |
| nawawi | 10 | forties/nawawi40 |
| qudsi | 11 | forties/qudsi40 |
| dehlawi | 12 | forties/shahwaliullah40 |
| riyad | 13 | other_books/riyad_assalihin |
| mishkat | 14 | other_books/mishkat_almasabih |
| adab | 15 | other_books/aladab_almufrad |
| shamail | 16 | other_books/shamail_muhammadiyah |
| bulugh | 17 | other_books/bulugh_almaram |
| hisn | 18 | other_books/hisn_almuslim |

See `db/unified/REPORT.md` for the full language × book matrix and fawaz match rates (especially Muslim).

## Provenance

| Layer | Source | What we took |
|-------|--------|----------------|
| **Base / spine** | [AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) `main` | Full bilingual `db/by_book` + `db/by_chapter`, scraper, types. |
| **Grades / references / Hisn** | [muallimai/hadith-json](https://github.com/muallimai/hadith-json) | `grade` + `reference` merged by hadith `id`; Hisn al-Muslim. |
| **Indonesian locale tree** | [sagad/hadith-json](https://github.com/sagad/hadith-json) | Additive `db/by_locale/id/` (draft). |
| **Multi-language editions** | [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) | `db/editions/` raw mirror + unified merge into `db/unified/`. |

### Legacy merge scripts

1. `tool/merge_muallimai_enrichments.dart` — attach grades/refs onto legacy `db/by_book`.
2. `tool/fetch_fawaz_editions.ps1` — refresh raw fawaz whole-edition files.
3. `tool/build_unified_editions.dart` — build canonical `db/unified/`.

## Legacy paths (still present)

Kept for compatibility; **prefer `db/unified/`**:

- `db/by_book/` — original AhmedBaset bilingual JSON (+ muallimai fields)
- `db/by_chapter/` — per-chapter shards
- `db/by_locale/id/` — sagad Indonesian drafts
- `db/editions/` — raw fawaz mirror (schema-incompatible; see `db/editions/MAPPING.md`)

## Known limitations

- **Musnad Ahmad chapters 8–30** missing upstream (Sunnah.com gap).
- **Muslim numbering**: fawaz has extra rows (~81 unmatched); spine coverage via `hadithnumber` is complete for all 7459 spine hadiths; ~23 extra matches via `arabicnumber`. Details in `db/unified/REPORT.md`.
- **Bukhari / Muslim grades** often empty (Sunnah.com / fawaz) even when `grades[]` is present on the schema.
- **Darimi** sagad Indonesian drafts are mostly empty text — no `ind-darimi` in unified until filled.
- Indonesian sagad entries remain **draft** (machine-assisted).

## Attribution & license

Upstream data and code remain attributed to [Ahmed Abdelbaset / AhmedBaset](https://github.com/AhmedBaset/hadith-json) and contributors. Additional fields and Hisn from [muallimai](https://github.com/muallimai/hadith-json); Indonesian locale drafts from [sagad](https://github.com/sagad/hadith-json); multi-language editions from [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api). Follow upstream licensing / attribution expectations when redistributing.

## Contributing

Issues and PRs welcome for data corrections, locale improvements (with clear draft/verified labeling), or grade/reference improvements.

---

*May Allah accept this work and make it beneficial. Ameen.*
