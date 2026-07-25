# Cross-check: hadithunlocked.com vs. our existing canonical data

hadithunlocked.com's own export also includes 11 collections we already
have from other sources (fawaz/AhmedBaset/mhashim6). This compares raw
item counts and spot-checks Arabic text agreement, to see whether
hadithunlocked's copy of these books is consistent with what we already
ship, and whether it surfaces anything ours is missing. Not imported —
these 11 stay on their existing sources; this is a quality cross-check
only.

## Count comparison

| book | hadithunlocked items | our canonical count | delta |
|---|---|---|---|
| bukhari | 6,790 | 7,589 | ours has +799 (fawaz-rebuilt lettered splits, expected) |
| muslim | 7,469 | 7,563 | ours has +94 |
| abudawud | 5,276 | 5,274 | +2 |
| tirmidhi | 4,052 | 3,998 | hadithunlocked has +54 |
| ibnmajah | 4,345 | 4,343 | +2 |
| nasai | 5,771 | 5,765 | +6 |
| malik | 1,975 | 1,985 | -10 |
| ahmad | 27,735 | 27,648 | hadithunlocked has +87 |
| darimi | 3,547 | 3,367 | hadithunlocked has +180 |
| adab | 1,326 | 1,326 | exact match |
| riyad | 2,538 | 1,896 | hadithunlocked has +642 (see below) |

Most books are within a few percent — expected noise from different
lettered-split/addendum handling between sources, not a red flag.
Three are worth a closer note:

**Riyad as-Salihin (+642, ~34%)**: hadithunlocked's own item `number`
field only runs 1-1895 (matches the well-known canonical 1896-hadith
count almost exactly), but there are 2,538 total items -- confirmed by
inspection that many numbers repeat (e.g. two separate items both
labeled "1894", with genuinely different `title`/`text`, not duplicate
data). This looks like hadithunlocked splits out narration variants
("and in another version...") as separate items under a shared parent
number, the same way sunnah.com uses lettered splits (690a/690b) for
Bukhari/Muslim -- except Riyad as-Salihin's own spine here doesn't
currently carry those variants at all. Worth a future pass to see if
they're worth adding as addenda, same pattern as `sortKey`/`isAddendum`
already used elsewhere in this repo. Not done tonight -- flagging only.

**Darimi (+180) / Tirmidhi (+54) / Ahmad (+87)**: not investigated in
detail -- plausibly the same kind of narration-variant/addendum gap as
Riyad, but not confirmed. Lower priority than Riyad's since the delta is
a smaller fraction of the book.

## Arabic text spot-check

Sampled ~15 evenly-spaced hadithunlocked items per book, joined onto our
spine by treating hadithunlocked's own `item.number` as `idInBook`, and
scored word-overlap between hadithunlocked's chain+text and our spine's
`arabic` field:

| book | sampled | >50% word-overlap match |
|---|---|---|
| bukhari | 15 | 15/15 |
| tirmidhi | 15 | 15/15 |
| muslim | 12-19 | 0 (see below -- not a real mismatch) |
| darimi | 15-20 | 1-2 (numbering schemes don't align, not investigated further) |

Bukhari/Tirmidhi's clean 15/15 match on a naive number-join is strong
evidence hadithunlocked's text for these books is the same underlying
collection/text, not a different riwaya or a botched scrape.

Muslim's 0/N naive-match result was **not** a hadithunlocked problem --
it's a numbering-format artifact: hadithunlocked's Muslim numbers include
lettered splits ("1485b", "1486a", ...) that a plain `parseInt` truncates
to the base number, so the join itself was broken, not the data. Manually
checked hadithunlocked's own `#1` against our spine's `idInBook: 1` and
found something more useful than the original question: **our own Muslim
spine's `idInBook: 1` has a completely blank `arabic` field**, while
hadithunlocked has the real text (Muslim's book-opening hadith, "Do not
lie about me...", on the authority of 'Ali). This surfaced a genuine gap
in our existing data, not in hadithunlocked's.

## Finding: blank-Arabic gaps in our own canonical spines

Prompted by the Muslim #1 discovery above, checked every one of the 9
core books for hadith with an entirely empty `arabic` field:

| book | total hadith | blank Arabic |
|---|---|---|
| muslim | 7,563 | **203** |
| nasai | 5,765 | 86 |
| tirmidhi | 3,998 | 74 |
| malik | 1,985 | 29 |
| bukhari | 7,589 | 9 |
| ibnmajah | 4,343 | 5 |
| abudawud | 5,274 | 2 |
| darimi | 3,367 | 0 |

408 hadith total, blank in our own existing (non-hadithunlocked) spines.
This is the same class of issue already tracked as "ensure untranslated
hadith are tagged, not blank/missing, in the reader UI" -- except this is
the Arabic side, not the English translation side. Since hadithunlocked
has confirmed-correct Arabic for at least the one case checked (Muslim
#1) and covers all 9 of these books' overlapping numbering ranges, it's a
plausible backfill source for some/most of these 408 gaps.

**Not attempted tonight** -- backfilling would need a proper per-book
content-match pass (hadithunlocked's lettered-split numbering doesn't
join cleanly on a bare integer, as the Muslim spot-check above shows), and
verification that hadithunlocked's text really does align with each blank
slot's intended hadith rather than just filling in *something*. Flagging
as a concrete, scoped follow-up rather than a vague TODO: the join key
would be hadithunlocked's `item.ref` (already `book:number`, matching
sunnah.com-style citations) against our spine's own `idInBook`, restricted
to just the 408 rows that are actually blank.
