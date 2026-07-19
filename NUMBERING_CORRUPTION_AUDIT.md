# Hadith Numbering/Chapter Corruption Audit

Started 2026-07-19, prompted by a real user-reported symptom in the app (Sahih
Muslim's chapter picker briefly showing hadith #1/#2/#3 when jumping into
chapter 5, before correcting to the real chapter 5 content at hadith 1161).
That specific bug is fixed (see "Fixed so far" below). This document is the
systematic follow-up: how many *other* places carry the same class of bug,
and what's the actual mechanism, so we're not just patching symptoms one
user report at a time.

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
| Sahih al-Bukhari | 7,563 | 1 |
| Sahih Muslim | 7,563 | 3 (+3 already fixed) |
| Sunan Abi Dawud | 5,274 | 0 |
| Jami at-Tirmidhi | 3,956 | 20 |
| Sunan an-Nasa'i | 5,758 | 13 |
| Sunan Ibn Majah | 4,341 | 25 |
| Sunan ad-Darimi | 3,367 | 7 |

Total: **69 outliers still unresolved**, plus the 3 in Sahih Muslim already
fixed this session (idInBook 1/2/3, mistagged `chapterId: 5` instead of `0`
— see git history).

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

Likely also explains Tirmidhi's 20 and Bukhari's 1 outlier — not
individually verified yet, but same shape (isolated single hadith, scattered
across a wide `idInBook` range, no visible common cause besides "matching
missed one side of a lettered pair").

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

### Pattern C — Nasa'i's chapter-35 cluster

All 13 of Sunan an-Nasa'i's outliers are tagged `chapterId: 35` ("The Book
of Oaths and Vows"), spanning a *wide* `idInBook` range (1520 to 5316 —
these aren't clustered together, they're scattered across most of the
book). Checked 3 of them directly: all are about land leasing/cultivation
contracts (Musaqah/Muzara'ah-type content — "Whoever has land, let him
cultivate it..."), which has nothing to do with oaths or vows. A single
wrong chapter value recurring this consistently across such a wide spread
smells like a **mechanical bug** in whatever step assigned `chapterId` for
Nasa'i specifically — e.g. an off-by-one or fallback-default in a
chapter-lookup table, rather than 13 independent content-matching misses.
Not yet root-caused; whatever script did this is, like Pattern A's, not
present in the repo to inspect.

## Fixed so far (this session)

- Sahih Muslim idInBook 1, 2, 3: retagged `chapterId` 5 → 0. Verified
  correct (idInBook=3's real content — "Whoever lies upon me
  intentionally..." — is confirmed Introduction content on sunnah.com).
  Rebuilt via `build_unified_editions.dart`; not yet re-uploaded to the
  mirror.
- Addenda physical ordering (all 6 books, 265 addenda total) — separate
  issue, already covered in the earlier session summary, not part of this
  audit.

## NOT fixed — explicitly holding per your instruction

None of the 69 remaining outliers above have been touched. Fixing Pattern A
requires per-entry sunnah.com verification (find the real base+letter,
confirm no collision, apply the same `isAddendum`/`sortKey` treatment
already proven safe for Bukhari's 16). Fixing Pattern B risks the same
"looks obvious but isn't" trap Muslim's 374 just demonstrated. Pattern C
needs its mechanism actually found before a fix can be trusted at all.

## Open questions / next steps

1. **Recover or reconstruct the missing script(s).** Neither the
   collision-resolution logic downstream of `arabic_match.dart` nor
   whatever produced Nasa'i's chapter-35 cluster exists in this repo. If
   they can't be found in an earlier session's history, the honest fix is
   to write new, *collision-aware* versions rather than guess at the old
   ones' exact behavior.
2. **Extend the outlier scan to Ahmad and Darimi's Arabic-only data** more
   thoroughly (Darimi done above; Ahmad wasn't scanned — it went through a
   completely different rebuild path, full al-hadees.com re-scrape, so may
   not share this failure mode at all, but hasn't been checked).
3. **Verify all 32 Pattern-B entries individually** before assuming
   "retag to 0" is even the right fix for any of them (Muslim's 374 already
   disproved the naive "chapterId 0 must be right" assumption once).
4. **Verify Bukhari's 1 and Tirmidhi's 20 Pattern-A candidates** against
   sunnah.com the same way Muslim's 3772/374 were confirmed.
5. Decide fix order/priority once the above is done — this doc's job was to
   find and characterize the corruption, not resolve it yet.
