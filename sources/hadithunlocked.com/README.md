# hadithunlocked.com integration

12 hadith collections not previously in this repo, imported from
hadithunlocked.com's own JSON export
(`original_source/hadith/hadithunlocked_{key}.json`) via
`tool/import_hadithunlocked.dart` into spine files under
`db/by_book/hadithunlocked/{key}.json`, then folded into
`db/unified/` by `build_unified_editions.dart` like every other book
(bookId 19-30, no fawaz coverage — `fawazBook: null` in every `BookDef`).

## Books added

| bookId | key | Title | English coverage | of which AI-tagged | Grade coverage |
|---|---|---|---|---|---|
| 19 | nasai-kubra | al-Sunan al-Kubra, Nasa'i | 99.7% | 33.9% | 0.06% |
| 20 | lulu-marjan | al-Lulu wa-al-Marjan (Muttafaq Alayh) | 100.0% | 1.2% | 100.00% |
| 21 | ibnrajab50 | Jami al-Ulum wa-al-Hikam | 100.0% | 3.3% | 95.60% |
| 22 | ibnhibban | Sahih Ibn Hibban | 99.5% | 53.1% | 89.30% |
| 23 | bayhaqi | al-Sunan al-Kabir, Bayhaqi | 99.5% | 83.2% | 0.04% |
| 24 | tabarani | al-Mu'jam al-Kabir, Tabarani | 99.8% | 87.0% | 0.12% |
| 25 | hakim | Mustadrak al-Hakim | 99.8% | 82.9% | 52.75% |
| 26 | ahmad-zuhd | al-Zuhd, Ahmad | 99.8% | 94.4% | 0.04% |
| 27 | daraqutni | Sunan al-Daraqutni | 0.0% — Arabic-only edition | n/a | 0.00% |
| 28 | bazzar | Musnad al-Bazzar | 1.0% | 80.4% | 0.00% |
| 29 | suyuti | Jam al-Jawami, Suyuti | 3.1% | 14.1% | 0.20% |
| 30 | ibnkhuzaymah | Sahih Ibn Khuzaymah | 0.7% | 93.8% | 0.00% |

Coverage = share of hadith with any English text at all; the AI-tagged
column is a share *of that text-bearing subset*, not of the whole book.
Numbers taken directly from `tool/import_hadithunlocked.dart`'s own
per-book console output, not eyeballed.

"AI-tagged" = hadithunlocked itself prefixed that hadith's English text
with `[AI]`/`[Machine]`, self-disclosing a machine translation rather than
silently passing it off as scholarly. That tag is stripped from the stored
text and preserved as a top-level `isAiTranslated: true` sibling field on
the hadith row instead (mirrors the existing `classification`/`conclusion`
top-level-sibling pattern from Musnad Ahmad — nesting inside `english`/
`translation` would have been silently dropped, since
`build_unified_editions.dart`'s row-construction loop only ever copies
`narrator`/`text` out of that map).

The 4 lowest-English-coverage books (daraqutni/bazzar/suyuti/ibnkhuzaymah)
were still imported in full rather than deferred or skipped — the pipeline
already handles a "no real translation for any hadith" book cleanly
(`_emitLanguageEdition` just doesn't emit an English file at all when
`withTranslation == 0` and `forceEmit` isn't set, verified: daraqutni's
catalog entry has only an `ar` edition, no empty/fake `en` one). These four
are genuinely Arabic-primary study editions for now; re-visit if a better
English source ever surfaces.

## idInBook

hadithunlocked's own `item.number` field is **not** reliably unique or
monotonic across every book — verified directly against the raw export
before trusting it as a join key (same verify-before-trust norm as every
other join in this repo):

| book | non-monotonic/unparseable | duplicate numbers |
|---|---|---|
| suyuti | 16,730 | 17,488 |
| tabarani | 376 | 340 |
| ibnrajab50 | 41 (of 91 total items) | 41 |
| lulu-marjan | 53 | 3 |
| daraqutni | 38 | 22 |
| hakim | 7 | 7 |
| ibnkhuzaymah | 3 | 0 |
| bayhaqi | 1 | 0 |
| ibnhibban | 2 | 2 |
| bazzar | 1 | 0 |
| nasai-kubra | 0 | 0 |
| ahmad-zuhd | 0 | 0 |

(ibnrajab50 makes sense on inspection: it's a 50-hadith commentary work
where one hadith's discussion spans many items all still labeled with that
hadith's own number.)

So `idInBook` here is a plain sequential counter assigned in the source's
own traversal order (chapters → sections → items, already the book's
natural reading order) — guaranteed unique, at the cost of not matching
hadithunlocked's own display numbering. Nothing is lost: the source's own
citation (`item.ref`, already formatted `book:number`) and a real working
link (`item.path`) are preserved directly in each hadith's own
`reference: {text, url}` field.

## Chapters

hadithunlocked chapters can hold items directly, sections underneath, or
both at once (verified: 12 of bayhaqi's 71 chapters have both, 32 of
tabarani's 54, 27 of hakim's 48). Mapped onto the existing spine schema's
`parentId` field (already a 2-level hierarchy, see
`db/by_book/other_books/riyad_assalihin.json`): each source chapter becomes
a `parentId: null` row, each of its sections becomes a `parentId: <chapter
id>` row, and a hadith's `chapterId` points at whichever is most specific
(the section if inside one, otherwise the chapter itself).

Some section titles are long — a handful legitimately embed a Qur'an
citation as part of the heading text (verified in bayhaqi's own source, not
an import bug) — the app's chapter-nav UI should truncate/expand rather
than assume short titles for these books.

## Grades

`grade`/`grader` use literal placeholder strings ("No Grade"/"N/A") for
ungraded hadith — filtered out rather than stored as fake grades. Where a
grade coverage number above looks bafflingly low (bayhaqi 0.04%, tabarani
0.12%, ahmad-zuhd 0.04%) that's genuinely how sparse hadithunlocked's own
per-hadith grading is for those books, not an import gap — spot-checked
against the raw source directly before writing this table.
