# Hadith Numbering/Chapter Corruption Audit

Started 2026-07-19, prompted by a real user-reported symptom in the app (Sahih
Muslim's chapter picker briefly showing hadith #1/#2/#3 when jumping into
chapter 5, before correcting to the real chapter 5 content at hadith 1161).
This document is the record of that investigation, including a wrong turn:
the first fixes (below, "Fixed so far") only chased `chapterId` mistags one
outlier at a time. Direct verification against sunnah.com eventually
uncovered a much larger issue — the English translation field was unreliable
at scale for all 6 of the AhmedBaset-spine-derived books, not just the
outliers, and the citation/reference field was built from the wrong
numbering scheme entirely. See "RESOLUTION" below for how this was actually
fixed.

## RESOLUTION (2026-07-19) — rebuilt bukhari/muslim/abudawud/tirmidhi/nasai/ibnmajah directly from fawaz

**Root cause**: for these 6 books, only the *Arabic* field was ever
re-matched onto fawaz's canonical numbering by content
(`tool/arabic_match.dart`). English stayed sourced from the old AhmedBaset
spine's own `english` field — never cross-checked against fawaz, and
unreliable at an unknown but large scale (confirmed instances of English
text paired with a completely unrelated hadith's Arabic). Separately, the
citation/reference field was built by naively concatenating the book name
with `idInBook` ("Sahih Muslim 374") — but `idInBook` (fawaz's `hadithnumber`,
sequential/gapless) is a *different* numbering scheme from sunnah.com's own
citation numbering (fawaz's `arabicnumber`, decimal suffix = letter, e.g.
`1618.02` = "1618b"). Conflating the two is what made early verification in
this doc unreliable too — comparing content against
`sunnah.com/{book}:{idInBook}` was frequently checking the wrong page.

**Fix**: `tool/rebuild_from_fawaz.dart` rebuilds `db/by_book/the_9_books/
{book}.json` for these 6 books directly from the cached fawaz edition
(`db/editions/files/ara-/eng-{book}.min.json`) — one paired, internally
consistent source, no cross-source joins:
- `idInBook` = fawaz `hadithnumber`; `chapterId` = fawaz `reference.book`;
  `arabic`/`english` = fawaz's own paired text; `reference` reconstructed
  from `arabicnumber` (real sunnah.com citation, letter suffix computed
  from the decimal).
- `isAddendum`/`sortKey` dropped entirely for these 6 books — fawaz's
  sequential numbering already gives every lettered variant its own
  natural slot, so the old "tail-appended arbitrary number" workaround is
  unnecessary.
- fawaz itself has a known gap: some hadith carry `reference.book=0` *and*
  `hadith=0` together as its own "couldn't determine the chapter"
  placeholder (distinct from a real book-0 Introduction, which always has
  a real in-book hadith number). Trusting that as chapterId 0 would
  mislabel real content as front matter, so it's tagged `chapterUnknown`
  instead. A same-session-proven technique (nearest-resolved-neighbor
  agreement, run in reverse from the isolated-outlier scan) recovered most
  of these automatically; the tiny remainder was hand-verified against
  sunnah.com directly.
- The isolated-outlier scan (re-run against the *by_book* source, not the
  stale unified output) still catches genuine residual fawaz errors —
  found and fixed 3 in Tirmidhi (fawaz's own `reference.book` provably
  wrong per sunnah.com) — and correctly leaves alone a handful of cases
  that look like outliers but are fawaz-confirmed-real (a lettered
  citation sibling legitimately living in a different book than its base
  number, e.g. Sahih Muslim 151c vs 151a/151b).

**Verified clean**: 0 isolated outliers in bukhari/abudawud/tirmidhi/nasai
after fixes (Muslim and Ibn Majah's 2 each are confirmed-real, not bugs);
0 Arabic mismatches against fawaz (all 6, by construction); every chapter
name backfilled and correct in bukhari/muslim/abudawud/tirmidhi/ibnmajah
(nasai has 1 unmatched — its catalog previously had a synthetic `35.2` id
that doesn't exist in fawaz's own numbering, now uses fawaz's real `35`
Agriculture id instead). Remaining honest gaps, all tagged rather than
silently blank/wrong: Muslim 9 genuinely-unresolved chapters (no fawaz
citation number at all for those hadith) + Nasa'i 82 (the pre-existing,
upstream-in-fawaz-too "Agriculture" content gap already known from this
audit). `tool/build_unified_editions.dart` and
`tool/gen_data_quality_report.dart` re-run clean against the rebuilt data.

**Phase 2 (same day, follow-up round)**: malik, nawawi40, qudsi40,
shahwaliullah40 rebuilt the same way. `tool/rebuild_from_fawaz.dart`
generalized to handle their different `id` numbering (a single incrementing
counter across the whole old spine, `globalOffset + idInBook`, auto-detected
from the existing data rather than hardcoded) and citation conventions:
Malik cites by book/in-book-hadith path (`sunnah.com/malik/{book}/{hadith}`,
no separate citation number — verified directly), the three "forties" cite
as "Hadith N, {title}" and use a single flat chapter (fawaz section 1) since
they have no real subdivisions.

Malik: fawaz's own edition caps at 1,858 hadith (independently corroborates
this repo's earlier README finding, "Muwatta Malik: 1,858, not 1,942"); the
127 additional real hadith in the old spine beyond that (idInBook
1859-1985) have no fawaz coverage at all and were carried forward
**unchanged** rather than dropped — Malik's spine was never subject to this
session's content-matching bug in the first place (its Arabic was
"unchanged" per this repo's README, so its Arabic/English pairing was never
re-shuffled the way the 6 main books' was). Verified: 1,985 total hadith
(1,858 rebuilt + 127 preserved, matching the pre-existing count exactly),
0/61 chapters missing an Arabic name, 0 genuine isolated-outlier bugs (16
flagged by the scan all turned out to be pre-existing blank/`noSourceContent`
entries with nothing to mis-categorize, not real errors), spot-checked
citations resolve correctly on sunnah.com.

The three forties (42/40/40 hadith): fawaz coverage is 1:1 with the
existing counts, no gaps, no outliers possible (single chapter each).

Musnad Ahmad's hadith text (Arabic/Urdu, from the al-hadees.com scrape) was
never part of this pipeline and is untouched. Darimi likewise untouched.
Riyad as-Salihin, Mishkat al-Masabih, Al-Adab al-Mufrad, Ash-Shama'il
al-Muhammadiyyah, Bulugh al-Maram, and Hisn al-Muslim have no cached
independent canonical source at all (per this plan's original inventory) —
still open, needs its own research pass before any rebuild can start there.

## Musnad Ahmad — companion/chapter duplicate-id merge (separate issue, same day)

Unrelated to the fawaz work above: user-reported bugs in `bookChapters.ahmad`
(87 duplicate-name catalog entries, e.g. Ali ibn Abi Talib split across ids
1004/1005 with idInBook 1294 wrongly routed to the spurious 1005 mid-run —
see conversation history for the full root-cause writeup, including the
"Karam"/"Hadyth" generic-fallback-label discovery).

Classified the 80 genuine-person duplicate-name groups (7 more were
generic-label collisions like "Karam"/"Hadyth", not handled here) by how
their two-or-three ids' `idInBook` ranges relate:

- **11 adjacent-range groups** (e.g. Abu Darda: id 2201 range 27479-27513
  immediately followed by id 2202's 27514-27558, zero gap) — almost
  certainly one continuous physical section arbitrarily split into two
  catalog entries. Merged into the earliest id.
- **4 tiny-stray groups** (a large contiguous block + a 1-3-hadith orphan
  elsewhere, e.g. Ali 1004 n=818 + 1005 n=1, Abu Hurairah 1030 n=3865 +
  1031 n=1, Abu Sa'eed al-Khudri 1032 n=955 + 1033 n=1) — the stray almost
  certainly belongs with the dominant block. Merged, absorbing into the
  larger id.
- **65 groups left untouched** — both sides have substantial, physically
  separate hadith counts (not a small-stray pattern) sharing an identical
  translated name. Many of these names are tribal/group labels ("Abd
  al-Qays" is a tribe, not a person) or visibly garbled transliterations
  ("Sahar Abd Y", "Jadaywb ibn Mwsy") rather than clean personal names —
  strong evidence these are genuinely separate physical sections that
  happen to share an incomplete/generic label from the original
  Urdu-label-extraction step, not duplicate ids of the same person.
  Blindly merging these risks misattributing real hadith to the wrong
  narrator, which is worse than leaving the duplicate label alone. Fixing
  this properly requires going back to the raw 1,203 Urdu labels and
  re-deriving cleaner names per physically-contiguous block — not
  attempted here; flagged as follow-up requiring its own research pass.

Executed via a one-off script (not committed as a tool — this was a data
correction, not a repeatable pipeline step): 15 groups merged, 227 hadith
reassigned, 15 redundant catalog entries removed (1,229 → 1,214 chapters),
total hadith count unchanged (27,648). Verified: idInBook 1294 (the
originally-reported bug) now correctly resolves to Ali's main chapter (id
1004); all 15 merged names confirmed no longer duplicated in the catalog.

**Not done in this pass** (left as follow-up, in priority order):
1. The 65 ambiguous duplicate-name groups above — needs real research per
   name, not mechanical merging.
2. The 32 garbled/generic-label chapters ("Karam" x3, "Hadyth", "Ahadyth",
   etc.) — needs the raw Urdu-label re-extraction described above; these
   were already characterized in detail but not fixed.
3. Catalog ordering — 34 companion sub-chapters across 10 parent groups
   still sit out of chronological order relative to their hadith's actual
   position in the book; re-deriving order from data (sort each parent's
   children by min `idInBook`) is cheap but wasn't run this pass since
   the underlying duplicate/garbled-name issues above should be resolved
   first.
4. The 42 hadith tagged directly to a top-level group id with no companion
   sub-chapter (the source of the 27,648 vs 27,606-in-chapter-list
   discrepancy) — still uncategorized.

## Method

Every `chapterId`-assignment in the 6 books that went through the
content-verified rebuild (`f6f8b9d`, task history: "Content-match X spine
onto fawaz canonical numbering") was checked for **isolated outliers**: a
hadith whose own `chapterId` disagrees with *both* its immediate neighbors
in `idInBook` order, while those two neighbors agree with each other. That's
a strong, low-false-positive signal — a hadith sitting in the *middle* of an
otherwise-contiguous chapter run, but tagged as belonging to some other
chapter entirely. Addenda (`isAddendum: true`) were excluded from the scan
(they're allowed to sit out of numeric sequence by design).

Script: `tool/audit scans (ad-hoc, not yet committed — see "Next steps")`,
run against `db/unified/files/{eng,ara}-{book}.json` for bukhari, muslim,
abudawud, tirmidhi, nasai, ibnmajah, and darimi.

## Results

| Book | Canonical hadith | Outliers found |
|---|---:|---:|
| Sahih al-Bukhari | 7,563 | 0 (1 fixed) |
| Sahih Muslim | 7,563 | 3 (+3 already fixed) |
| Sunan Abi Dawud | 5,274 | 0 |
| Jami at-Tirmidhi | 3,956 | 20 |
| Sunan an-Nasa'i | 5,758 | 0 (13 fixed, +82 more found and fixed — see Pattern C) |
| Sunan Ibn Majah | 4,341 | 25 |
| Sunan ad-Darimi | 3,367 | 7 |

Total: **55 outliers still unresolved**, plus 99 already fixed this session
(Muslim idInBook 1/2/3, mistagged `chapterId: 5` instead of `0`; Bukhari
idInBook 5056, mistagged `chapterId: 65` instead of `66`; Nasa'i's 13
isolated outliers plus 82 more hadith that the isolated-outlier scan itself
couldn't catch — see Pattern C and "Fixed so far" below, and git history).

## Three distinct patterns, not one bug

### Pattern A — real lettered citation, never flagged as an addendum

Confirmed directly against sunnah.com for 2 of Sahih Muslim's 3 remaining
outliers:

- `idInBook=3772` (tagged `chapterId: 43`, "The Book of Virtues" — that part
  is *correct*): real citation is **"Sahih Muslim 2303b"**, a lettered
  sibling of the hadith already sitting at `idInBook=2303`. It should have
  gone through the same treatment `690b`-style Bukhari addenda got (
  `isAddendum: true`, `sortKey` ≈ 2303.01, sorts right after 2303) but
  instead got assigned an arbitrary standalone number (3772) with no
  addendum flag at all.
- `idInBook=374`: real citation is **"Sahih Muslim 374a"**, under "The Book
  of Menstruation" (`chapterId: 3`) — not the Introduction (`chapterId: 0`,
  where our data has it) and not `chapterId: 1` either (its immediate
  `idInBook` neighbors 373/375 are chapterId 1, which is *also* wrong —
  neighbor-agreement is a good outlier detector but not proof of the
  correct answer).
- `idInBook=4153` — not yet individually verified against sunnah.com, but
  matches the same shape (chapterId 54 vs. neighbors' chapterId 23).

**Working theory**: the content-matching pass (`tool/arabic_match.dart`,
`matchToCanonical`) has no collision detection — nothing stops two distinct
old-spine entries from both fuzzy-matching to the *same* canonical index
(exactly what you'd expect for a base hadith and its lettered sibling,
which share most of their text). Whatever downstream step consumed
`matchToCanonical`'s output and decided "this one gets the canonical slot,
that one becomes a `690b`-style addendum" evidently handled that collision
correctly *most* of the time (Bukhari's 16, Muslim's other ~103 addenda) but
missed a handful of cases per book. **I could not find the actual script
that ran this** — `arabic_match.dart` is a pure library (`library;`, no
`main()`), the commit that used it (`f6f8b9d`) doesn't include the caller,
and it's not present anywhere in git history as a since-deleted file. It was
almost certainly a one-off local script from an earlier session that was
never committed. This is itself worth noting: **the exact tool that produced
the current spine data is not reproducible from this repo alone.**

Suspected to also explain Tirmidhi's 20 outliers — not individually
verified yet, but same shape (isolated single hadith, scattered across a
wide `idInBook` range). **Bukhari's own 1 outlier turned out NOT to be this
pattern**: verified against sunnah.com (idInBook=5056, "Sahih al-Bukhari
5056", no letter suffix at all — In-book reference "Book 66, Hadith 81"),
it was simply mistagged `chapterId: 65` instead of `66`, sitting isolated
in the middle of an otherwise-contiguous chapter-66 run (5051-5055,
5057-5061). No lettered-citation collision involved — just a plain
one-off chapter-tag slip. Fixed (see "Fixed so far" below). This is a
useful reminder that "isolated outlier" is one detection method covering
at least two different underlying causes, not one.

### Pattern B — Introduction-region chapter scatter

Ibn Majah (25 outliers) and Darimi (7 outliers): every single one has
`chapterId: 0` (Introduction) as its neighbor value, meaning these are all
individual hadith sitting *inside* what should be a contiguous Introduction
block, each mistagged with some other real chapter's ID (1, 4, 5, 6, 8, 9,
11, 12, 21, 31, 35, 36, 37... — no obvious single wrong value, unlike
Pattern C below). This is the exact same shape as Sahih Muslim's now-fixed
idInBook 1/2/3 bug. Given Pattern A's finding that even a "confirmed"
Introduction entry (Muslim's 374) can actually belong to neither its tagged
chapter *nor* its neighbor's chapter, I'd bet at least some of these 32
entries are Pattern A in disguise (a lettered/mismatched citation that
happens to fall in the Introduction's numeric range) rather than a pure
chapter-tag error — **not yet individually verified**.

### Pattern C — Nasa'i's missing "35.2" chapter (ROOT-CAUSED AND FIXED)

Turned out to be **two separate bugs**, not one, both now fixed and
verified — the isolated-outlier scan's "13" badly undercounted the real
damage here.

**Bug C1 — an entire chapter got silently swallowed by its two neighbors.**
`db/unified/catalog.json`'s `bookChapters.nasai` defines chapter
**"35.2 — The Book of Agriculture"**, but before this fix **zero** hadith
in the whole book actually used that `chapterId` — the chapter existed in
the catalog metadata with nothing tagged under it. Cross-checked against
sunnah.com's real book list: Book 35 "Oaths and Vows" is 3761–3856, Book
"35b" (their own label) "Agriculture" is **3857–3938** (82 hadith), Book 36
"Kind Treatment of Women" is 3939–3965. Our data had 3761–3856 correctly
tagged `35`, but then kept tagging `35` through 3897 (41 of Agriculture's
82 hadith) before jumping straight to `36` for 3898–3938 (the other 41) —
splitting the missing chapter's content roughly in half between its two
neighbors, at a cut point (3898) that doesn't correspond to any real book
boundary. Because each mistagged half was internally *contiguous*, the
isolated-outlier scan (which only flags a single hadith sitting *alone* in
the wrong chapter) couldn't see most of it — only the individual outliers
in Bug C2 below were ever within its reach. **Fixed**: retagged idInBook
3857–3938 (82 hadith, confirmed both endpoints against sunnah.com) to
`chapterId: 35.2`, the catalog entry that was sitting unused.

**Bug C2 — 13 genuinely isolated single-hadith mistags**, unrelated to
Bug C1 (none fall inside 3857–3938): idInBook 1520, 3192, 3205, 3238, 3943,
4136, 4477, 4633, 4658, 4674, 4934, 5056, 5316 — all individually verified
against sunnah.com, and in every case the real chapter matched exactly what
the immediate neighbors already showed (no Muslim-374-style surprises).
All were tagged either `chapterId: 14` (one entry) or `chapterId: 35`
(the rest) regardless of where they actually belonged (17, 25, 26, 36, 38,
44, 46, 48 — see git history for the full idInBook→chapterId mapping).
**Fixed**: retagged all 13 to their verified correct chapterId.

Re-ran the isolated-outlier scan after both fixes: **0 outliers remain in
Nasa'i.** Root cause for Bug C1 is now well-understood (a missing chapter
boundary during whatever pass assigned Nasa'i's `chapterId`s); Bug C2's
individual misses are still presumed Pattern-A-like (a step further
upstream matching content to the wrong slot), but the *exact* script that
did either is still not present in this repo to inspect — same caveat as
Pattern A.

## Fixed so far (this session)

- Sahih Muslim idInBook 1, 2, 3: retagged `chapterId` 5 → 0. Verified
  correct (idInBook=3's real content — "Whoever lies upon me
  intentionally..." — is confirmed Introduction content on sunnah.com).
  Rebuilt via `build_unified_editions.dart`; not yet re-uploaded to the
  mirror.
- Sahih al-Bukhari idInBook 5056: retagged `chapterId` 65 → 66. Verified
  correct against sunnah.com ("Sahih al-Bukhari 5056", Book 66 "Virtues of
  the Qur'an", chapter "To weep while reciting the Qur'an", in-book
  reference "Book 66, Hadith 81"). Rebuilt via `build_unified_editions.dart`
  and `gen_data_quality_report.dart`; not yet pushed/tagged/re-deployed.
- Addenda physical ordering (all 6 books, 265 addenda total) — separate
  issue, already covered in the earlier session summary, not part of this
  audit.
- Sunan an-Nasa'i, Bug C1: idInBook 3857–3938 (82 hadith) retagged
  `chapterId` 35/36 → 35.2 ("The Book of Agriculture", previously an
  unused catalog entry). Both endpoints verified against sunnah.com.
- Sunan an-Nasa'i, Bug C2: 13 isolated outliers (idInBook 1520, 3192, 3205,
  3238, 3943, 4136, 4477, 4633, 4658, 4674, 4934, 5056, 5316) individually
  verified against sunnah.com and retagged to their real chapterId.
  Isolated-outlier scan confirms **0 remaining outliers in Nasa'i**.
- All Nasa'i fixes rebuilt via `build_unified_editions.dart` and
  `gen_data_quality_report.dart`; not yet pushed/tagged/re-deployed.

## NOT fixed — explicitly holding per your instruction

None of the 55 remaining outliers above (Tirmidhi's 20, Ibn Majah's 25,
Darimi's 7, Muslim's remaining 3) have been touched. Fixing Pattern A
requires per-entry sunnah.com verification (find the real base+letter,
confirm no collision, apply the same `isAddendum`/`sortKey` treatment
already proven safe for Bukhari's 16). Fixing Pattern B risks the same
"looks obvious but isn't" trap Muslim's 374 just demonstrated. Nasa'i
(Pattern C) is now fully resolved — see above.

## Open questions / next steps

1. **Recover or reconstruct the missing script(s).** The collision-
   resolution logic downstream of `arabic_match.dart` (Pattern A/Bug C2)
   still isn't in this repo — Nasa'i's Bug C1 (the missing "35.2" chapter)
   is now root-caused in outcome (a chapter boundary got dropped somewhere
   in whatever assigned `chapterId`s), but the actual script that produced
   it is equally unrecoverable. If they can't be found in an earlier
   session's history, the honest fix is
   to write new, *collision-aware* versions rather than guess at the old
   ones' exact behavior.
2. **Extend the outlier scan to Ahmad and Darimi's Arabic-only data** more
   thoroughly (Darimi done above; Ahmad wasn't scanned — it went through a
   completely different rebuild path, full al-hadees.com re-scrape, so may
   not share this failure mode at all, but hasn't been checked).
2b. **DONE — checked every book for Nasa'i's Bug C1 pattern** (a catalog
   chapter entry with zero hadith actually tagged to it — cheaper and more
   direct than the isolated-outlier scan, which missed most of Bug C1
   entirely). Diffed `bookChapters.{book}`'s ids against the distinct
   `chapterId`s actually used, for all 7 books in this audit: Bukhari (97
   chapters), Muslim (57), Abi Dawud (43), Tirmidhi (49), Nasa'i (52, now
   0 after the fix), Ibn Majah (38), Darimi (24) — **zero unused chapters
   in every book.** Bug C1 was a Nasa'i-only one-off, not a repeating
   pattern; Tirmidhi/Ibn Majah/Darimi's remaining outliers are genuinely
   just isolated single-hadith mistags (Pattern A/B), not another hidden
   swallowed chapter.
3. **Verify all 32 Pattern-B entries individually** before assuming
   "retag to 0" is even the right fix for any of them (Muslim's 374 already
   disproved the naive "chapterId 0 must be right" assumption once).
4. **Verify Tirmidhi's 20 Pattern-A candidates** against sunnah.com the same
   way Muslim's 3772/374 were confirmed (Bukhari's own 1 outlier is now
   fixed — see "Fixed so far" — but turned out to be a plain chapter-tag
   slip, not this pattern, so don't assume Tirmidhi's 20 will all be
   Pattern A either).
5. Decide fix order/priority once the above is done — this doc's job was to
   find and characterize the corruption, not resolve it yet.

## CRITICAL — new finding, 2026-07-19: this is not just a chapterId bug

While starting individual verification of the remaining 55 (per open
question 3/4 above), discovered a **much more serious class of corruption**
that the isolated-outlier scan cannot see at all, because it only compares
`chapterId` values — it never checks whether a hadith's own `arabic` text
actually matches its own `translation`, or whether either matches its
`reference`/citation.

**Confirmed with direct sunnah.com verification (not guessed):**

- **Muslim idInBook=374**: our `arabic` field is
  "إِنَّ الإِيمَانَ لَيَأْرِزُ إِلَى الْمَدِينَةِ..." — that is **Sahih
  Muslim 147** ("The Book of Faith"), a totally different, much earlier
  hadith. It has nothing to do with "374a" (Book of Menstruation, Ibn
  'Abbas eating after using the privy) — the real 374a's actual Arabic and
  English are both completely different from what's sitting in our data at
  idInBook=374. The earlier "Pattern A" note in this doc (assuming 374's
  real identity is "374a") was **wrong** — it never checked the Arabic
  against the citation, only assumed the citation itself was trustworthy.
- **Muslim idInBook=3772**: `arabic` is about a jointly-owned slave being
  freed by one owner ("فِي الْمَمْلُوكِ بَيْنَ الرَّجُلَيْنِ..." —
  manumission/liability ruling), but `translation` is "There would be such
  a vast distance between the sides of my Cistern..." (Hadith of the
  Cistern) — the translation matches real 2303b correctly, but the Arabic
  paired with it is for some entirely different hadith.
- **Muslim idInBook=4153**: `arabic` matches real **Sahih Muslim 1618d**
  ("The Book of the Rules of Inheritance" — al-Bara' b. 'Azib on the last
  Qur'an verse/surah revealed), but `translation` is "I heard my brother
  say that Jabir had stated: Be on your guard against them" — unrelated to
  the Arabic entirely.
- **Tirmidhi idInBook=1237**: `arabic` is about a prohibition on selling
  animal-for-animal on credit; `translation` is about Khul' divorce and a
  menstruating wife's Iddah — unrelated.
- **Tirmidhi idInBook=1308**: `arabic` is "the rich man's procrastination
  [in repaying debt] is injustice"; `translation` is about one portion of
  food being sufficient for two/four/eight people — unrelated.
- **Nasa'i idInBook=1520** — one of Bug C2's **13 entries already "fixed
  and verified" earlier this session** — `arabic` is the Prophet praying
  Istisqa (rain prayer), 2 rak'ahs facing the qibla (matches its
  neighbors' shared topic exactly); `translation` is "Whoever missed three
  Jumu'ahs out of negligence, Allah will place a seal over his heart" —
  completely unrelated. **The earlier fix only checked that the citation
  number's chapter matched neighbors — it never checked that the Arabic
  and translation actually agree with each other or with that citation.**
  This means Bug C2's "verified" fixes may still be pairing the right
  `chapterId` with wrong hadith text.

**Separately, also found: missing content, not just wrong content.** All
**82 of 82** entries in the idInBook 3857–3938 range (Nasa'i's "Bug C1"
Agriculture chapter, already retagged to `chapterId: 35.2` this session)
have **completely empty `arabic` and `translation` fields** — confirmed via
`git diff` that this predates the chapterId fix (only `chapterId` lines
changed; the fix did not touch/blank content). 4 more scattered entries
(idInBook 125, 1368, 1369, 1372) are blank too — 86 blank-Arabic entries
total in Nasa'i alone, not yet checked in other books. The Agriculture
chapter's *tagging* is now correct, but the chapter is still functionally
empty in the app.

**Implication**: the isolated-outlier scan (chapterId-only) undercounts the
real damage in two distinct ways — (1) it can't detect a hadith whose
content is simply wrong/mismatched even when its `chapterId` happens to
look consistent with neighbors, and (2) it can't detect blank/missing
content at all. Mechanically retagging `chapterId` for the remaining 55
outliers (or trusting the 95 Nasa'i entries already "fixed") is **not
sufficient** — every entry needs its `arabic`/`translation`/`reference`
triple cross-checked against sunnah.com, not just its chapter tag.
**Paused here pending direction — this needs a different, much larger-scope
remediation plan than "retag chapterId for N outliers.".**

## On-device range-gap log (2026-07-20)

The app now has a live diagnostic (`computeHadithChapterRangeInfo` in
`hapi_app_v2/lib/hadith/hadith_chapter_range_info.dart`) that walks every
leaf chapter's hadith numbers in reading order and `debugPrint`s a
`[HadithRangeGap]` line the first time it finds a place where one hadith
number doesn't hand off cleanly to the next (`ends at N -> starts at M`,
or `internally splits: ends at N, resumes at M`, always with `(expected
N+1)`), deduped per session. The user ran the app and pasted a full session's
worth of these lines. Findings below, categorized.

### Sahih Muslim

- **384 / 388** (ch1 "Faith" holes, landing under ch43 "Virtues" / ch16
  "Marriage" respectively): **disputed — reopened, not resolved.** Earlier
  this session I called this "not a bug" on the strength of sunnah.com's own
  page content (both the chapter it files 384/388 under and their topical
  subject matter matching "Virtues"/"Marriage" rather than "Faith"). Pushed
  on directly: that only proves sunnah.com's own editorial choice, not that
  it's more correct than amrayn.com's, which apparently keeps both hadith
  in their numeric neighborhood (i.e. doesn't interleave them). Sahih
  Muslim has multiple widely-used, mutually-disagreeing numbering/chapter-
  boundary schemes across different print editions — two independent
  digitization projects disagreeing here is itself evidence of real
  ambiguity, not proof either one is wrong. Topical content-matching is
  suggestive of compiler intent but doesn't settle it (a compiler can place
  a topically-adjacent hadith for reasons unrelated to subject-matter
  tagging — isnad grouping, cross-reference, etc.). **Needs**: a third
  independent source (ideally a scholarly reference on Sahih Muslim's
  actual chapter boundaries, not just another hadith website), or ruling
  out that this is the same class of bug as the 5112/5113 and Tirmidhi 2735
  findings below — a `reference.book` mistag in fawaz's own data — which
  was never actually checked for 384/388 specifically.
- **5112–5115** (ch35 "Sacrifices" hole, stray piece landing under ch36
  "Drinks"): **already fixed in this repo** (`manualOverrides` in
  `tool/rebuild_from_fawaz.dart`, commit `4ecc35b`, tag `v1.11.3-hapi`) —
  but the log shows the *full* 4-wide hole with 5112/5113 present nowhere
  at all, which is the pre-fix shape (post-fix would only leave a 2-wide
  5114–5115 hole). **The device that produced this log has a stale,
  pre-fix install of Sahih Muslim** — app-side action (delete/re-download
  the book), not a data bug. Flagging here only so a future "why is this
  still broken" report isn't mistaken for a regression.
- **4968–4971** and **5885–5886**: **fixed** (`manualOverrides` in
  `tool/rebuild_from_fawaz.dart`). Turned out to need no external source at
  all — sunnah.com wasn't even reachable directly (403s a plain `curl`) but
  wasn't necessary either, since fawaz's own raw data already answers it:
  all 6 idInBook carry fawaz's `reference.book=0, hadith=0` "couldn't
  determine the chapter" placeholder, i.e. the *same already-documented*
  fawaz-upstream limitation as 5112/5113, not a new phenomenon. The
  automated neighbor-inference pass in `rebuild_from_fawaz.dart` correctly
  refused to guess for these (each one's two resolved neighbors disagree —
  4967=book 33 vs 4972=book 34; 5884=book 40 vs 5887=book 41), but direct
  content comparison against *one specific* neighbor settles it with more
  than a coin-flip's confidence:
  - 4968–4971: word-for-word the same report as neighbor 4967 (book 33,
    "the Prophet ﷺ forbade returning to family at night after a long
    absence without warning") via different chains — more citation variants
    of hadith 715 that fawaz's numbering never assigned a letter-suffix to.
    4968 even opens "بِهَذَا الإِسْنَادِ" ("with this chain"), referring
    back to 4967's own chain. Book 34 (Hunting/Slaughter) shares no topic
    or chain with any of the four.
  - 5885–5886: same narrator-chain opening ("عَنْ إِبْرَاهِيمَ بْنِ
    مَيْسَرَةَ") and topic (reciting Umayya ibn Abi as-Salt's poetry to the
    Prophet ﷺ) as neighbor 5887 (book 41) — 5887 even says explicitly
    "بِمِثْلِ حَدِيثِ إِبْرَاهِيمَ بْنِ مَيْسَرَةَ" ("similar to Ibrahim ibn
    Maisarah's report"), naming the same narrator. Book 40 (incense/
    fragrance, neighbor 5884) shares nothing with either.

  Rebuilt, verified in both `db/by_book/the_9_books/muslim.json` and the
  propagated `db/unified/files/ara-muslim.min.json` (4968-4971 → chapterId
  33, 5885-5886 → chapterId 41). `gen_data_quality_report.dart` re-run
  clean; `git diff` confirms only Muslim's own output changed (a few bytes
  in zip sizes), no other book touched. Not yet tagged/pushed.
- **5384**: genuinely unrecoverable, left as-is. Same `reference.book=0/
  hadith=0` placeholder, but unlike the six above, fawaz's own `text` field
  is *empty* here (both Arabic and English) — there's no content to match
  against anything, so this stays `chapterId: null` / `noSourceContent`,
  same treatment as the Nasa'i Agriculture gap below.

### Sunan an-Nasa'i

- **3857–3938** (ch35 "Agriculture" → ch36 "Kind Treatment of Women"): **not
  a new bug** — this is the already-documented upstream fawaz gap (blank
  `ara-nasai`/`eng-nasai` for this exact range, see "RESOLUTION" section
  above). No pipeline fix needed; the outstanding work is app-side
  (`noSourceContent` tagging so the reader shows "not available" instead of
  a silent hole — not yet done).

### Jami` at-Tirmidhi

- **2735** (stray single hadith under ch38 "Description of Paradise"; ch42
  "Seeking Permission" ends at 2734, ch43 "Manners" starts at 2736): new,
  but well-isolated and likely a simple `reference.book` mistag — 2735's
  real reading-order position sits between chapters 42 and 43 (2736 = ch43's
  real start), the same shape as the Muslim 5112/5113 fix. Needs a
  sunnah.com check on hadith 2735's real citation, then a
  `manualOverrides` entry in `tool/rebuild_from_fawaz.dart` once confirmed.

### Sunan Ibn Majah

Chapters 10 "Divorce," 11 "Expiation," 15 "Charity," 16 "Pawning," 19
"Manumission" (idInBook roughly 2089–2529) show hadith numbers jumping
non-monotonically across the cluster (ch10 walks 2089 → 2435 → 2464 → 2476 →
2477, then hands to ch11 which starts back down at 2090). Unlike the other
findings above, this isn't a clean missing-range or single-hadith mistag —
either the catalog's chapter *order* doesn't match Ibn Majah's physical
reading order for this stretch, or several individual hadith are mistagged,
and I can't tell which without re-deriving it from fawaz's own
`reference.book`/section data for Ibn Majah specifically. **Needs its own
investigation pass**, scoped to idInBook ~2089–2529 and catalog chapters
10/11/15/16/19.

### Musnad Ahmad ibn Hanbal

~90 findings, all falling under the already-known, already-scoped companion/
chapter-catalog problem (see the "Musnad Ahmad — a second, separate
problem in the companion/chapter layer" section of the working plan from
earlier this session — not reproduced here). Confirmed patterns present in
this log:
- "Karam (RA)" reused as a fake person across unrelated anonymous-narrator
  clusters (chapterIds 1309, 1432, 1917 all show this) — it's a garbled
  reading of كِرَام ("Kiram," an honorific), not a name.
- Duplicate companions split across two catalog ids breaking an otherwise-
  contiguous run (Anas ibn Malik 1034/1035, Ibn Abbas 1073/1074, and
  several more visible in this log).
- Garbled/generic labels ("Hadyth (RA)," "Ahadyth (RA)," "Hadith of an
  Unnamed Companion") appearing as many distinct catalog ids from the
  Urdu-label-extraction step failing.
- Catalog order not matching physical book position for large stretches
  (e.g. chapterId 1608 handing off to 1764, then to 1642 — nowhere near
  each other in the book).

This log is a much more complete enumeration of affected companion ids than
anything sampled before — worth using directly as the starting census for
the dedicated fix pass (merge duplicates, re-derive order from actual
`idInBook` position, honest "unnamed narrator" labels instead of
label-string grouping) rather than fixing any of these individually here.

### Summary / next actions

1. **Muslim 384/388 — reopened, disputed.** Needs a third independent
   source, or a check for whether it's actually the same class of bug as
   #2/#3 below (a `reference.book` mistag never actually checked for these
   two).
2. Muslim 4968–4971, 5885–5886 — **fixed**, see above (5384 stays
   genuinely unrecoverable — blank source content). Not yet tagged/pushed.
3. Tirmidhi 2735 — sunnah.com verification, likely a one-line
   `manualOverrides` fix once confirmed.
4. Ibn Majah 2089–2529 cluster — needs its own investigation (order vs.
   mistag, undetermined).
5. Musnad Ahmad — feed this log's companion-id list into the existing
   planned fix pass; not a new problem.
6. Muslim 5112/5113 — **directly confirmed fixed and live**, not just
   inferred from the commit/tag existing: fetched `ara-muslim.min.json` at
   `v1.11.3-hapi` from both `raw.githubusercontent.com` and the app's
   primary `cdn.jsdelivr.net` URL, both show `chapterId: 35` for idInBook
   5112 and 5113. The stale result in this log is confirmed device-side
   (the test device's installed copy of Sahih Muslim predates the fix);
   no repo-side action, but the fix only reaches an already-installed book
   via delete + re-download, and only if the app build itself was refreshed
   past the point the local catalog's `sourceTag` was bumped to
   `v1.11.3-hapi`.
7. Nasa'i 3857–3938 — unchanged, already understood, no repo-side action.
