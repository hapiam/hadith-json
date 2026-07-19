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

Malik/Nawawi40/Qudsi40/Shahwaliullah40 have the same architecture (fawaz
coverage exists) but were **not** rebuilt this round — same risk profile,
flagged as follow-up. Musnad Ahmad and Darimi were never part of this
pipeline (separate, already-validated rebuilds) and are untouched.

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
