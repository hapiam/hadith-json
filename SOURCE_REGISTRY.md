# Source registry — how every hadith source numbers/structures its data, per book

Why this file exists: this repo has repeatedly discovered that hadith
numbering is **not** a universal fact — different sources count the same
book differently (fawaz: flat integers; amrayn/sunnah.com: lettered
grouped citations), and even a source that *looks* like it's using real
citation numbers can secretly be using row position instead and silently
drift from the truth it claims (the original AhmedBaset spine did exactly
this for Bukhari — see `README.md`'s numbering-corruption section). Every
time that gets rediscovered by hand it costs real investigation time.

This file is the "understand it once, never re-derive it" record: for
every source, tracked **per book** (the same source can use a different
scheme for different books — amrayn's own Malik uses chapter/local
numbering while its other books use flat/lettered citations), what type of
numbering it uses, how safely its Arabic can be cross-checked, where it's
cached locally (if at all), and whether it's actually been inspected or is
still a guess.

**Keep this current.** When a new source is added or a book is newly
inspected, update the relevant table row here rather than leaving the
finding only in a chat conversation or a one-off script's output.

## The 4-type checklist

Run through this whenever a source (or a source's coverage of one
particular book) hasn't been classified yet. Needs direct inspection of
real records, not documentation claims — sources have been wrong about
their own data before (fawaz's own README doesn't mention the AhmedBaset
drift bug; that was found by direct text comparison).

**1 — Flat/expanded integer.** Every physical narration gets its own
next sequential number; repeated/near-identical narrations of the same
traditional citation each get a *different* plain integer, nothing
grouped under one shared base number. Fingerprint: `hadithnumber` (or
equivalent) is always numeric, never contains a letter, across the whole
book. *Confirmed example: fawaz's `ara-muslim.min.json` — 7,563 rows,
zero string-typed `hadithnumber` values.*

**2 — Grouped citation with lettered variants.** One number represents a
traditional citation "slot"; repeated/near-identical narrations under
that same citation get letter suffixes (`8`, `8a`, `8b`, `8d`) instead of
new integers — this is the actual traditional printed-book citation
convention. Fingerprint: citation strings/URLs contain trailing letters
(`/muslim:11b`). *Confirmed example: amrayn.com (mirrors sunnah.com).*

**3 — ⚠ Position-claims-citation drift risk.** Not a legitimate "way of
doing it" — a bug pattern to actively screen every source for. The
record's own row position is used as if it were the citation number, but
its own `reference`/citation field disagrees, and the gap grows across
the book. **Check**: pick several records at increasing depth into the
book (early/middle/near-end) and compare row position against what the
record's own reference field claims to be. If they diverge and the
divergence grows, the source's positional order cannot be trusted as a
citation number — even if translations were joined onto it that way
historically. *Confirmed example: the original AhmedBaset spine — Bukhari
row 7277 (the last row) carries `reference.text: "Sahih al-Bukhari
7563"`.*

**4 — ✓ Self-contained Arabic (safe for exact-text matching).** The
Arabic text sits on the very same record as the translation(s) — no join
by number required to compare across languages, so it's immune to
whatever numbering risk (type 1/2/3) that source might otherwise carry.
The opposite is a **split** source: Arabic lives in one file, each
translation in its own separate file, joined only by a shared number —
inherits that source's full numbering risk, since a bad join silently
attaches the wrong Arabic to a translation (this is exactly how the
type-3 bug above corrupted six books' worth of translations in this
repo's own history). Fingerprint: does a translation-language record have
its own `arabic` field, or only `hadithnumber` + `text`?
*Confirmed self-contained: amrayn.com, this repo's own `db/unified/`.
Confirmed split: fawaz (`eng-muslim.min.json`/`fra-muslim.min.json`/
`urd-muslim.min.json` all lack an `arabic` field — join back to
`ara-muslim.min.json` by `hadithnumber` required).*

## Source fingerprints (quick recognition)

| Source | Typical field names | Storage |
|---|---|---|
| fawaz (`fawazahmed0/hadith-api`) | `hadithnumber` (int), `arabicnumber` (string, e.g. `"11.02"` — unexplained secondary numbering, not yet investigated), `text`, `grades`, `reference: {book, hadith}` | Split — separate `{lang}-{book}.min.json` per language, `ara-{book}` is the Arabic-only file |
| amrayn.com | `idInBook` (int), `citation` (string, only present when lettered), `arabic`, `englishRaw`/`narrator`/`body`, `chapter`, `amraynId`, `gradeFlag`, `chain`, `postscript`, `references`, `intlRef`, `tags`, `links` | Self-contained |
| This repo, `db/by_book/` (legacy) | `idInBook`, `chapterId`, `arabic`, `english: {narrator, text}`, `reference: {text, url}` | Self-contained (English only; other languages not present) |
| This repo, `db/unified/by_book/` (canonical) | Same as above, plus `translations: {en, fr, id, ...}` per record | Self-contained, all languages |
| mhashim6/Open-Hadith-Data | Not yet inspected — not cached locally | Unknown |
| muallimai/hadith-json | Not yet inspected — not cached locally (merged via `tool/merge_muallimai_enrichments.dart` historically, raw source not preserved) | Unknown |
| al-hadees.com (Musnad Ahmad scrape) | Not yet inspected against this checklist (scrape itself not preserved as a script — see `sources/README.md`'s known-gaps table) | Unknown |
| sagad/hadith-json | Not yet inspected — Indonesian drafts only, `db/by_locale/id/`, status: draft | Unknown |

## Per-book tables

One table per book. `Status` is honest about what's actually been
checked — "Not yet inspected" means the source is known to cover this
book (per `README.md`'s source table) but nobody has run the checklist
against its real records for this specific book yet.

### Bukhari
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| fawaz | 1 (assumed, not directly checked for this book) | Split | `db/editions/files/ara-bukhari.min.json` (if present) | Not yet inspected | Canonical numbering target per README (99.78% content-match rate) |
| amrayn.com | 2 | Self-contained | `sources/amrayn.com/processed/bukhari.json` | Verified | 10 rows carry a lettered `citation` in the raw scrape |
| Original AhmedBaset spine | 3 ⚠ | Self-contained | superseded, not current | **Confirmed drift bug** | The row-7277-claims-7563 example above is THIS book |

### Muslim
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| fawaz | 1 | Split | `db/editions/files/ara-muslim.min.json` | **Verified** | 7,563 rows, zero lettered `hadithnumber`; row 1 has empty `text` (inherited into canonical's own blank stub — not a bug introduced by this repo) |
| amrayn.com | 2 | Self-contained | `sources/amrayn.com/processed/muslim.json` | **Verified** | 5,979 of 8,898 rows carry a lettered `citation` |

### Malik
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| amrayn.com | Neither 1 nor 2 — its own chapter/local-position scheme (`malikChapterNum`/`malikLocalHadithNum`), no flat citation at all | Self-contained | `sources/amrayn.com/processed/malik.json` | **Verified** | Confirms a single source can use a THIRD, book-specific scheme not covered by types 1/2 — traditional Malik citation is "Book X, Hadith Y", not a flat number |
| fawaz | Unknown for Malik specifically | Split | check `db/editions/files/ara-malik.min.json` | Not yet inspected | README: translations cap at 1,858 across 6 languages regardless of the 1,985-entry Arabic spine — a real content ceiling, not a numbering artifact |

### Darimi
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| mhashim6/Open-Hadith-Data | Unknown | Unknown | Not cached locally | Not yet inspected | Canonical Arabic scaffold for this book (3,367 rows, "verified duplicate-free" per README, but numbering *type* not checked) |
| amrayn.com | 1 (no lettered citations observed, but not confirmed absent) | Self-contained | `sources/amrayn.com/processed/darimi.json` | Partially verified | 3,546 rows found, 3,367 matched onto canonical by `idInBook` fallback (96% of canonical had no parseable citation text — see `COMPARISON_REPORT.md`) |

### Abu Dawud / Tirmidhi / Nasa'i / Ibn Majah
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| fawaz | 1 (assumed by extension from Muslim/Bukhari; not directly checked per-book) | Split | `db/editions/files/ara-{abudawud,tirmidhi,nasai,ibnmajah}.min.json` | Not yet inspected | Canonical numbering target per README (97.9–99.93% content-match rate) |
| amrayn.com | 2 | Self-contained | `sources/amrayn.com/processed/{book}.json` | Verified (citation-discovery confirmed lettered rows exist for all four, in small numbers) | |

### Ahmad
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| al-hadees.com | Unknown | Unknown | Not preserved (script never committed) | Not yet inspected | Replaced AhmedBaset's 1,374-hadith stub with a full 27,648-hadith scrape; amrayn does NOT cover this book at all |

### Nawawi40 / Qudsi40 / Shahwaliullah40 (the Forties)
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| fawaz | 1 | Split | `db/editions/files/ara-{nawawi,qudsi}.min.json` | Not yet inspected | Small, fixed-count books (42/40/~40) — low risk either way |
| amrayn.com | 1 (no lettered citations found) | Self-contained | `sources/amrayn.com/processed/{nawawi40,qudsi40}.json` | Verified for nawawi40/qudsi40 — perfect 42/42 and 40/40 match against canonical | amrayn doesn't cover shahwaliullah40 |

### Riyad as-Salihin / Adab Mufrad / Shama'il
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| amrayn.com | 2 (Adab Mufrad, Shama'il have some lettered citations); 1 for Riyad as-Salihin | Self-contained | `sources/amrayn.com/processed/{riyad_assalihin,aladab_almufrad,shamail_muhammadiyah}.json` | Verified | **Sole independent source for all three** — no fawaz coverage exists. Adab Mufrad/Shama'il comparisons are complicated by real cross-book citations (some Adab Mufrad canonical entries cite Mishkat instead) |

### Mishkat al-Masabih / Bulugh al-Maram / Hisn al-Muslim
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| muallimai/hadith-json | Unknown | Unknown | Not cached locally | Not yet inspected | Hisn al-Muslim's source; amrayn covers NONE of these three books at all |

### Amrayn-only bonus books (nasai_kubra_bonus, mustadrak_alhakim_bonus)
| Source | Type | Storage | Local cache | Status | Notes |
|---|---|---|---|---|---|
| amrayn.com | Not yet classified | Self-contained | `sources/amrayn.com/processed/{book}.json` | Not yet inspected for lettered citations | No canonical counterpart exists for either book yet — see `COMPARISON_REPORT.md` |

## Open questions to resolve as new sources come in

- fawaz's `arabicnumber` field (e.g. `"11.02"`) — looks like a
  book.hadith-style secondary numbering, not yet understood or checked
  against anything.
- mhashim6, muallimai, and al-hadees.com are all still "unknown" for
  every type/storage question — none have a local cache to inspect
  directly yet.
- Whether type-3 drift risk exists anywhere OTHER than the already-fixed
  AhmedBaset spine hasn't been checked — worth running the same
  position-vs-claimed-citation screen against any new source before
  trusting its numbering at all.
