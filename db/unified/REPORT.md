# Unified editions build report

Built: 2026-07-14T17:06:48.878495Z

## Sources
- AhmedBaset spine: `db/by_book` (structure, arabic, english narrator/text, chapters)
- muallimai: grade + reference already merged into spine
- fawazahmed0: `db/editions/files/{lang}-{book}.min.json` (non-English translations + multi-grader grades)
- sagad: `db/by_locale/id/by_book` Indonesian drafts for books without fawaz `ind-*`

## Discarded / non-primary fawaz editions

- ara-abudawud1 (kept as optional ara1-* undiacritized edition)
- ara-bukhari1 (kept as optional ara1-* undiacritized edition)
- ara-dehlawi1 (kept as optional ara1-* undiacritized edition)
- ara-ibnmajah1 (kept as optional ara1-* undiacritized edition)
- ara-malik1 (kept as optional ara1-* undiacritized edition)
- ara-muslim1 (kept as optional ara1-* undiacritized edition)
- ara-nasai1 (kept as optional ara1-* undiacritized edition)
- ara-nawawi1 (kept as optional ara1-* undiacritized edition)
- ara-qudsi1 (kept as optional ara1-* undiacritized edition)
- ara-tirmidhi1 (kept as optional ara1-* undiacritized edition)

- bukhari: attached undiacritized Arabic on 7268 hadiths (ara1)
- muslim: attached undiacritized Arabic on 7291 hadiths (ara1)
- nasai: absorbed multi-grader grades from `eng-nasai.min.json` into 5757 hadiths
- nasai: attached undiacritized Arabic on 5672 hadiths (ara1)
- abudawud: absorbed multi-grader grades from `eng-abudawud.min.json` into 5274 hadiths
- abudawud: attached undiacritized Arabic on 5272 hadiths (ara1)
- tirmidhi: absorbed multi-grader grades from `eng-tirmidhi.min.json` into 3952 hadiths
- tirmidhi: attached undiacritized Arabic on 3889 hadiths (ara1)
- ibnmajah: absorbed multi-grader grades from `eng-ibnmajah.min.json` into 4341 hadiths
- ibnmajah: attached undiacritized Arabic on 4336 hadiths (ara1)
- malik: absorbed multi-grader grades from `eng-malik.min.json` into 1858 hadiths
- malik: attached undiacritized Arabic on 1829 hadiths (ara1)
- ahmad: Indonesian draft from sagad on 1359 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- darimi: sagad Indonesian present but 0 matches (sagad rows: 3406, unmatched: 0)
- nawawi40: attached undiacritized Arabic on 42 hadiths (ara1)
- nawawi40: Indonesian draft from sagad on 42 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- qudsi40: attached undiacritized Arabic on 40 hadiths (ara1)
- qudsi40: Indonesian draft from sagad on 40 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- shahwaliullah40: attached undiacritized Arabic on 40 hadiths (ara1)
- shahwaliullah40: Indonesian draft from sagad on 40 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- riyadussalihin: Indonesian draft from sagad on 1896 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- mishkat: Indonesian draft from sagad on 4428 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- adab: Indonesian draft from sagad on 1320 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- shamail: Indonesian draft from sagad on 402 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- bulugh: Indonesian draft from sagad on 1767 hadiths (unmatched sagad rows: 0; no fawaz ind-* for this book)
- hisn: no sagad Indonesian by_book file
## Fawaz ↔ spine match rates

| Edition | Fawaz rows | Matched hn | Matched an-only | Unmatched fawaz | Spine covered | Spine total | Coverage |
|---|---:|---:|---:|---:|---:|---:|---:|
| ben-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| ben-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| ben-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| ben-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| ben-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| ben-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| ben-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| ben-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4053 | 97.61% |
| eng-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| eng-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| eng-dehlawi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| eng-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| eng-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| eng-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| eng-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| eng-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| eng-qudsi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| eng-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4053 | 97.61% |
| fra-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| fra-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| fra-dehlawi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| fra-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| fra-malik.min.json | 1899 | 1858 | 0 | 41 | 1858 | 1985 | 93.60% |
| fra-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| fra-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| fra-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| fra-qudsi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| ind-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| ind-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| ind-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| ind-malik.min.json | 1859 | 1858 | 0 | 1 | 1858 | 1985 | 93.60% |
| ind-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| ind-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| ind-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4053 | 97.61% |
| rus-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| rus-bukhari.min.json | 7590 | 7277 | 0 | 313 | 7277 | 7277 | 100.00% |
| rus-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| tam-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| tam-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| tur-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| tur-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| tur-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| tur-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| tur-muslim.min.json | 7563 | 7459 | 23 | 81 | 7459 | 7459 | 100.00% |
| tur-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| tur-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| tur-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4053 | 97.61% |
| urd-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5276 | 99.96% |
| urd-bukhari.min.json | 7589 | 7277 | 0 | 312 | 7277 | 7277 | 100.00% |
| urd-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4345 | 99.91% |
| urd-malik.min.json | 1889 | 1858 | 0 | 31 | 1858 | 1985 | 93.60% |
| urd-muslim.min.json | 7564 | 7459 | 23 | 82 | 7459 | 7459 | 100.00% |
| urd-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5768 | 99.83% |
| urd-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4053 | 97.61% |

### Muslim highlight

- `ben-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `eng-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `fra-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `ind-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `rus-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `tam-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `tur-muslim.min.json`: spine 7459/7459; unmatched fawaz 81 (skipped, no invented ids)
- `urd-muslim.min.json`: spine 7459/7459; unmatched fawaz 82 (skipped, no invented ids)

## Catalog summary

Total unified editions: 99

