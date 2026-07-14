# Fawazahmed0 editions mapping (`db/editions`)

Additive mirror of [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) whole-edition JSON, for offline multi-language translations. **Does not merge into** `db/by_book`, `db/by_chapter`, or `db/by_locale`.

CDN (still authoritative for per-hadith / section shards):

`https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/`

## Schema: incompatible - coexist only

| | Fawaz editions | AhmedBaset / hapi bilingual |
|--|----------------|-----------------------------|
| Layout | Whole-edition files + optional CDN shards | Per-book / per-chapter trees |
| Identity | `hadithnumber`, `arabicnumber`, optional `reference` | `id`, `idInBook`, `chapterId`, `bookId` |
| Arabic | Single `text` string | `arabic` string |
| Translation | Single `text` string (narrator often inline) | `english: { narrator, text }` |
| Grades | `grades: [{ name, grade }]` (multi-grader) | Optional single `grade` string (muallimai) |
| Sections | Edition `metadata` + section maps | Chapter files under `by_chapter` |

**Do not field-merge** these shapes. Keep both layouts side by side.

## Book key mapping (fawaz to hapi `src/books.ts`)

Where collections overlap:

| Fawaz book key | hapi id | hapi route / path |
|----------------|---------|-------------------|
| `bukhari` | 1 | `bukhari` |
| `muslim` | 2 | `muslim` |
| `nasai` | 3 | `nasai` |
| `abudawud` | 4 | `abudawud` |
| `tirmidhi` | 5 | `tirmidhi` |
| `ibnmajah` | 6 | `ibnmajah` |
| `malik` | 7 | `malik` |
| `nawawi` | 10 | `nawawi40` |
| `qudsi` | 11 | `qudsi40` |
| `dehlawi` | 12 | `shahwaliullah40` |

### Present in hapi, missing from fawaz

- **ahmad** (8) - Musnad Ahmad
- **darimi** (9) - Sunan ad-Darimi
- **riyad_assalihin** (13), **mishkat** (14), **adab** (15), **shamail** (16), **bulugh** (17)
- **hisn_almuslim** (18) - Hisn al-Muslim (muallimai port)

## Languages in fawaz (9)

Arabic, Bengali, English, French, Indonesian, Russian, Tamil, Turkish, Urdu.

Edition file names look like `{lang}-{book}.min.json` (e.g. `eng-bukhari`, `ara-bukhari1` for undiacritized Arabic). Not every book has every language.

## ID alignment notes

- For many Kutub as-Sitta hadiths, `hadithnumber` / `arabicnumber` often align with sunnah.com numbering and hapi `idInBook` (e.g. Bukhari Arabic #1 matches).
- **Do not assume perfect 1:1** across all books - Muslim numbering especially can differ between editions and schemes.
- Fawaz English is one `text` string; AhmedBaset splits narrator vs text.
- Grades: keep fawaz multi-grader `grades[]` and hapi optional `grade` separately; never overwrite one with the other.

## What is ported here vs CDN-only

**Ported under `db/editions/`:**

- `editions.json`, `editions.min.json`, `info.json`
- Whole-edition minified files: `files/{name}.min.json` (~74 editions)

**Not ported** (use CDN):

- Per-hadith shards: `editions/{name}/{n}.json`
- Section shards

Refresh: `tool/fetch_fawaz_editions.ps1`
