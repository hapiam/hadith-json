# Translation wording fixes — the "ejaculation" audit (2026-08-03)

User-flagged: the word "ejaculation" appears across the English corpus and
reads wrong in several places. Decision (user-confirmed): **context-aware
fix** — correct only the rows where the word is genuinely wrong against the
row's own Arabic; keep it where it is the accurate fiqh term used by the
published sunnah.com translations. Every kept and fixed row is listed here.

Applied by `tool/fix_ejaculation_wording_2026_08_03.dart` (idempotent,
keyed by `idInBook`, hard-fails on any text mismatch). Spine files under
`db/by_book/` were patched, then `db/unified/` fully regenerated with
`build_unified_editions.dart`. Legacy `db/by_chapter/` and the immutable
fawaz `db/editions/` are deliberately untouched (same policy as every fix
since the 2026-07-17 rebuild: `by_chapter` is a superseded layout, and
`editions/` is source data we never edit).

Every decision below was verified against the row's own Arabic text
directly, not against any pipeline-generated field (per this repo's
standing discipline; see DUPLICATE_HADITH_INVESTIGATION.md and
`tool/fix_bayhaqi_14109_translation.dart`).

## Summary

- 43 spine rows contained "ejaculat*".
- **21 rows KEPT unchanged** — ghusl-rules hadith where the word correctly
  renders أنزل / يُنزل / فضخ الماء / الدفق and matches the published
  translations (softening them would deviate from the official texts for
  no accuracy gain).
- **22 rows FIXED** — five classes below.

## Kept rows (accurate fiqh usage)

| Book / ref | Arabic warrant |
|---|---|
| Bayhaqi 765, 766, 770, 799 | أنزل أو لم يُنزل / فلم يُنزل / نضحت الماء |
| Bayhaqi 774 (word "ejaculate" itself kept; other clauses fixed, see class 5) | فلم يُنزل |
| Ibn Hibban 127, 1169, 1178 ("even if he does not ejaculate" clause), 1185 (main clause) | لم يُنزل / فلا يُنزل |
| Muslim 349 (both spine copies) | الدفق / الماء — official Siddiqui translation |
| Nasa'i 193, 194, 199; Nasa'i al-Kubra 197, 203 | فضخت الماء / الماء من الماء (official + its footnote) |
| Tabarani 21079 | إذا لم يُنزل |
| Bulugh al-Maram 911, 914, 971 | جنابة rendered "ejaculation or sexual impurity" (published wording); وإن لم يُنزل |
| Ibn Majah 505, 606 | فلا يُنزل (official) |
| Muwatta Malik 2/73, 2/74 | يُكسل ولا يُنزل (official Bewley wording) |

## Fixed rows

### Class 1 — archaic English: "ejaculations" = short uttered prayers

The Ka'b b. 'Ujrah muʿaqqibāt hadith. The old Siddiqui translation uses
"ejaculations" in its obsolete sense of "brief exclamatory utterances".
Fixed to "phrases of remembrance (mu'aqqibat)". Deviates deliberately from
the verbatim sunnah.com text; meaning unchanged.

1. Sahih Muslim 596a (hadithunlocked spine, idInBook 1344)
2. Sahih Muslim 596bc (hadithunlocked spine, idInBook 1345)
3. Sahih Muslim 596a (the_9_books spine, idInBook 1349)
4. Sahih Muslim 596 follow-up row (the_9_books spine, idInBook 1350)
5. Tabarani 16373 (borrowed Muslim 596a translation, idInBook 6158)

### Class 2 — madhi mistranslated as "ejaculates" (inverts the ruling)

Madhi (المذي, pre-seminal fluid) requires only washing + wudu; ejaculation
would require ghusl. Calling madhi "ejaculation" makes the stated ruling
look wrong.

6. Tabarani 5589 (idInBook 2425) — يدنو من أهله **فيُمذي** → "emits madhi
   (pre-seminal fluid)".
7. Tabarani 17760 (idInBook 7470) — يلاعب امرأته ويكلمها **فيُمذي** → same fix.
8. Tabarani 17794 (idInBook 7501) — فخرج منه **المذي** → same fix. ALSO the
   reply had an invented ghusl order ("let him perform ghusl, cleanse…")
   not present in the Arabic «فلينضح فرجه وليتوضأ وضوءه للصلاة» → now "let
   him rinse his private part and perform ablution as he would for prayer."

### Class 3 — fabricated or mismatched AI content (full replacement;
`isAiTranslated` cleared, new text is a human-verified translation of the
row's own Arabic)

9. **Mustadrak al-Hakim 7900** (idInBook 7906) — worst find of the audit:
   the English was a borrowed "Water is for Water" Nasa'i translation while
   the row's own Arabic is a different hadith entirely: «تحفة المؤمن الموت»
   → replaced with **"The gift of the believer is death."**
10. Bayhaqi 8051 (idInBook 7417) — English invented "expiation … as well as
    for the ejaculation"; the Arabic says كفّارة الظهار (expiation of
    zihar) with no such clause. Also ينتف شعره = "plucking at his hair",
    not "trimming". Fully retranslated.
11. Bayhaqi 14918 (idInBook 13710) — English invented "What if he
    ejaculates?" for أرأيت إن **عجز واستحمق** ("if he had been incapable or
    had acted foolishly"), said Ibn Umar "went to Umar" when the Arabic has
    Umar going to the Prophet ﷺ, and dropped "at the beginning of her
    waiting period" (في قُبُل عدتها). Fully retranslated.
12. Nasa'i al-Kubra 2943 (idInBook 2867) — said the Prophet's ﷺ head was
    "wet from semen"; the Arabic is رأسه يقطر ماءً نكاحًا من غير احتلام —
    dripping with (ghusl) water due to marital relations, not a wet dream.
    Multiple other garbles in the same row (misattributed speakers,
    واقع = "has intercourse" rendered "ejaculates"). Fully retranslated.

### Class 4 — wrong word for ihtilam / juhd / ifda' / yutm / 'azl / faragh

13. Nasa'i al-Kubra 2978 (idInBook 2901) — جنبًا **من غير احتلام** = junub
    "not from a wet dream", was "without having any ejaculation". Also
    "Abu came to Aisha" → "My father went in to Aisha" (دخل **أبي**), and
    عزمت عليك لما لقيت أبا هريرة → "I adjure you: go and meet Abu
    Hurayrah" (was "I am convinced of what you have encountered…").
14. Ibn Hibban 1178 (idInBook 1120) — ثم **جهدها** = "then exerts himself",
    was "then ejaculates" — the hadith's entire point is that ghusl is due
    even *without* emission (its own next clause says so).
15. Bayhaqi 13919 (idInBook 12793) — **الإفضاء** = intimate conjugal
    contact, was "ejaculation". Also "And He said" (implying Allah) → "And
    he said" (Ibn Abbas is speaking).
16. Bayhaqi 14881 (idInBook 13675) — لا **يُتم** بعد **احتلام** = "no
    orphanhood after puberty", was the meaningless "no completion after
    ejaculation".
17. Bulugh al-Maram 973 (idInBook 133) — ترى في منامها ما يرى الرجل = "a
    woman who sees in her dream what a man sees", was "a woman having
    ejaculation during sleep like a man".
18. Sunan an-Nasa'i 5088 (idInBook 5088) — عزل الماء بغير محله: the broken
    "removing to ejaculate in other than the right place" → "withdrawing
    to spill semen other than in its proper place ('azl)". (Deviates from
    the scraped sunnah.com wording, which was itself broken English.)
19. Nasa'i al-Kubra 9310 (idInBook 9045) — same fix (borrowed 5088 text).
20. Tabarani 4374 (idInBook 1103) — قبل أن **أفرغ** = "before finishing",
    was "before ejaculation". See also class 5.

### Class 5 — adjacent ghusl/wudu confusion in the same reviewed rows

Rendering غُسل/اغتسل as "ablution" (wudu) changes the ruling; fixed while
the rows were under review, each verified against its Arabic.

21. Bayhaqi 774 (idInBook 721) — three clauses: "no obligation … to
    perform ablution" → "no ghusl obligation"; "obligation of performing
    ablution arises" → "ghusl becomes obligatory"; "then he commanded to
    perform ablution" → "then he commanded ghusl" (ثم أمر بالغسل). The
    "water is from water was a concession (رخصة)" clause also repaired.
22. Tabarani 4374 (idInBook 1103) — فاغتسل/أثر الغسل/غسله: "performed
    ablution / trace of the ablution / his ablution" → ghusl throughout.
    (Same row as #20.)
23. Ibn Hibban 1185 (idInBook 1127) — **فاغتسلنا** منه جميعًا = "we both
    performed ghusl (bathed) from it", was "we all performed ablution".

Note: row counts — 22 rows were written by the script (rows #20/#22 are
the same physical row, and the five class-1 rows span two spine files).

## Known remaining caveats

- `db/by_chapter/` (legacy 2023 layout) still contains the old wording,
  including old Ahmad English rows that no longer exist on the rebuilt
  spine. Nothing consumes it; left as-is like every fix before this one.
- Rows carrying "(Using translation from X)" tags that were edited here
  (Tabarani 16373, Nasa'i al-Kubra 9310) now differ slightly from the row
  they borrowed from; the tag is kept since it still names the source of
  the base translation.
- The wider `isAiTranslated` corpus (13 hadithunlocked books) remains
  unaudited beyond these rows and Bayhaqi 14109 — this audit only swept
  rows containing "ejaculat*". The same error classes (invented clauses,
  ghusl/wudu swaps, misattributed speakers) almost certainly exist
  elsewhere in the AI-translated rows.
