# amrayn.com raw-scrape field inventory

What amrayn.com's site actually gives us per hadith, verified by directly
reading sample records from `sources/amrayn.com/runs/2026-07-24_full-catalog/*.jsonl`
and counting field presence across all 15 scraped books/collections —
not inferred from `build_processed.dart`'s doc comment or guessed from the
schema. `build_processed.dart` keeps every one of these fields verbatim in
`processed/{book}.json` (nothing is trimmed there), but nothing downstream
of that — `db/unified/` — uses any of them yet beyond `arabic`/English
text/`reference`. This file exists so "what does amrayn actually have that
we don't" can be answered without re-opening raw JSONL again.

## Every field on a raw hadith record

```
idInBook, title, chapter{chapterNum,arabicTitle,englishTitle,sectionNum},
grades[{class,text}], englishRaw, narrator, body, boldSegments[],
arabic, amraynSectionNum, amraynId, bookNumber, gradeFlag,
notes, notesArabic, postscript, postscriptArabic,
hasExplanationAvailable, chain, chainArabic,
references[], intlRef, tags[], links[{link,label}]
(+ malikChapterNum, malikLocalHadithNum — Malik only)
```

`narrator`/`body` are just `englishRaw` split at the first line break
when that line reads as an attribution (e.g. "Abu Hurairah reported...");
already used. Everything below is new information, not yet in our schema.

## Per-field presence, counted across all 15 books/collections

| Field | Populated where | Notes |
|---|---:|---|
| `chain` / `chainArabic` | **darimi** (3,527/3,546), **nasai_kubra_bonus** (10,823/10,824), **mustadrak_alhakim_bonus** (8,710/8,719) — **zero everywhere else**, including all "the 9 books" core collections (Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah, Malik, Riyad as-Salihin, Adab Mufrad, Shama'il, the Forties) | Full isnad narrator chain, English (transliterated names, `>`-separated) **and** Arabic. This is the "isnad" the user is asking about — amrayn's site renders it, but only for 3 of the 15 collections we scraped. Whether it exists for the other 12 on the live site (and this scraper just didn't capture it there) vs. genuinely absent needs a live spot-check before concluding either way |
| `grades[]` | Present on nearly every record for 13/15 books (abudawud 5,274/5,274, bukhari 6,791/6,791, ibnmajah 4,328/4,328, muslim 8,898/8,898, nasai 5,753/5,728¹, tirmidhi 3,951/3,951, riyad_assalihin 1,896/1,896, darimi 3,546/3,546, the 2 bonus books, nawawi40/qudsi40 full) — sparse for **malik** (8/1,405) and **shamail_muhammadiyah** (10/397) | Structured `{class, text}`, e.g. `{"class":"sahih","text":"Sahih (Authentic)"}` or `{"class":"unknown","text":"Authentication status unknown"}`. Richer than our own `db/unified/` grade field (which only carries one flat name+grade pair per hadith, from muallimai) — amrayn's `class` value looks like a clean enum worth checking for a full value set |
| `gradeFlag` | Alongside `grades[]`, same coverage pattern | Numeric (e.g. `1`, `512`, `4194304` — looks bit-shifted/power-of-2), null on some records even when `grades[]` is populated (e.g. one muslim sample). Meaning not decoded yet — likely a per-grader-source bitmask, not investigated further |
| `links[]` | Real counts everywhere, heaviest in **nasai_kubra_bonus** (7,174), **mustadrak_alhakim_bonus** (1,379), **darimi** (928); much sparser in the 9 books (ibnmajah 76, tirmidhi 82, riyad_assalihin 101, bukhari 14, others single digits) | Cross-collection citation links, e.g. Nasa'i al-Kubra #1 → `{"link":"/muslim:278a","label":"Sahih Muslim 278a"}`. A real cross-reference graph amrayn maintains between collections — nothing in our own pipeline currently uses this at all |
| `notes` / `notesArabic` | Rare: tirmidhi 24, ibnmajah 7, riyad_assalihin 3, aladab_almufrad 2, bukhari 2, nasai 1 — zero elsewhere | Free-text scholarly notes attached to specific hadith. Low volume but non-zero — worth a manual look at a few samples before deciding if it's worth carrying |
| `hasExplanationAvailable` | `true` on ~6 records total across everything scraped (aladab_almufrad 4, darimi 1, tirmidhi 1) | Near-unused signal in this scrape. Could mean amrayn has a separate "explanation" page we never fetched (this flag says "available," not "fetched") |
| `postscript` / `postscriptArabic` | **Zero** populated anywhere in the entire scrape | Either a dead field on amrayn's site, or requires a page/request path this scraper never exercised. Not confirmed dead — just never observed |
| `tags[]` | **Zero** non-empty anywhere in the entire scrape | Same caveat as `postscript` — never observed populated, not confirmed the site never has them |
| `boldSegments[]` | **Zero** non-empty in every book checked (spot-checked bukhari/muslim/malik/darimi/nasai_kubra_bonus directly; grep across all 15 confirms zero everywhere) | This is `scrape_amrayn.dart`'s attempt at "text highlighting" — extracting `<b>...</b>` spans from the English HTML (see `_boldRe` in the scraper). It never fires on any of the 61,540+ hadith scraped. Either amrayn's English text genuinely never uses inline `<b>` markup (plausible — bold there is usually just the narrator-name wrapper the scraper already handles separately), or the regex/extraction has a bug. **Needs a live-page check before concluding either way** — this is exactly the kind of "feature we might be able to standardize off" the user is asking about, and right now we don't actually know if it exists |

¹ nasai's `grades[]` count (5,753) exceeds its own scrape total in
`COMPARISON_REPORT.md` (5,728) because this count is against the raw
`.jsonl` before `build_processed.dart`'s error-row/dedupe pass.

## What this means, plainly

- **Isnad chains are a real amrayn feature, but a narrow one in what we've
  scraped so far**: only Darimi and the two bonus collections (Nasa'i
  al-Kubra, Mustadrak al-Hakim) carry them. If isnad display is a feature
  worth building, either those 3 collections are the only ones amrayn can
  give it for, or the other 12 need to be checked live to see if the
  scraper simply isn't capturing an isnad section that exists there too.
- **Structured multi-value grading (`grades[]`) is broad and richer than
  what we already store** — worth a closer look at the full set of
  `class` values before deciding whether/how to fold it into
  `db/unified/`'s grade field.
- **Cross-collection `links[]` is untapped** — a real citation graph
  between books that nothing downstream currently reads.
- **`boldSegments`, `tags`, and `postscript` all show up as fields the
  scraper defined but never once populated across 61,540+ records.**
  Before writing these off, at least `boldSegments` deserves a manual
  check against a live amrayn page — "the code looks for this and finds
  nothing" and "this doesn't exist on the site" are different findings,
  and only one of them has actually been confirmed here.

## Not yet done

- Live-page spot-check of `boldSegments`/`tags`/`postscript` on a page the
  scraper marked as having none, to tell "dead field" from "extraction
  bug" apart.
- Live-page check of a Bukhari/Muslim hadith to see whether amrayn
  actually renders an isnad chain for those books that this scrape missed.
- Enumerate the full `grades[].class` value set (currently only seen:
  `sahih`, `unknown` — there are almost certainly more, e.g. daif/hasan).
- Decode `gradeFlag`'s bit meaning, if it turns out to matter (e.g. does
  it distinguish which authority issued the grade).
- Decide, once the above is answered, whether any of this becomes new
  fields in `db/unified/`'s schema — not decided yet, deliberately.
