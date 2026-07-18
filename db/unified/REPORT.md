# Unified editions build report

Built: 2026-07-18T03:47:54.927756Z

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

- bukhari: attached undiacritized Arabic on 7554 hadiths (ara1)
- muslim: attached undiacritized Arabic on 7360 hadiths (ara1)
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
- ahmad: no sagad Indonesian by_book file
- darimi: sagad Indonesian present but 0 matches (sagad rows: 3406, unmatched: 39)
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
| ben-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| ben-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| ben-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| ben-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| ben-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| ben-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| ben-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| ben-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4041 | 97.90% |
| eng-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| eng-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| eng-dehlawi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| eng-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| eng-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| eng-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| eng-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| eng-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| eng-qudsi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| eng-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4041 | 97.90% |
| fra-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| fra-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| fra-dehlawi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| fra-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| fra-malik.min.json | 1899 | 1858 | 0 | 41 | 1858 | 1985 | 93.60% |
| fra-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| fra-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| fra-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| fra-qudsi.min.json | 40 | 40 | 0 | 0 | 40 | 40 | 100.00% |
| ind-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| ind-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| ind-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| ind-malik.min.json | 1859 | 1858 | 0 | 1 | 1858 | 1985 | 93.60% |
| ind-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| ind-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| ind-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4041 | 97.90% |
| rus-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| rus-bukhari.min.json | 7590 | 7563 | 0 | 27 | 7563 | 7579 | 99.79% |
| rus-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| tam-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| tam-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| tur-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| tur-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| tur-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| tur-malik.min.json | 1858 | 1858 | 0 | 0 | 1858 | 1985 | 93.60% |
| tur-muslim.min.json | 7563 | 7563 | 0 | 0 | 7563 | 7669 | 98.62% |
| tur-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| tur-nawawi.min.json | 42 | 42 | 0 | 0 | 42 | 42 | 100.00% |
| tur-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4041 | 97.90% |
| urd-abudawud.min.json | 5274 | 5274 | 0 | 0 | 5274 | 5278 | 99.92% |
| urd-ahmad.min.json | 27621 | 27621 | 0 | 0 | 27621 | 27648 | 99.90% |
| urd-bukhari.min.json | 7589 | 7563 | 0 | 26 | 7563 | 7579 | 99.79% |
| urd-ibnmajah.min.json | 4343 | 4341 | 0 | 2 | 4341 | 4344 | 99.93% |
| urd-malik.min.json | 1889 | 1858 | 0 | 31 | 1858 | 1985 | 93.60% |
| urd-muslim.min.json | 7564 | 7563 | 0 | 1 | 7563 | 7669 | 98.62% |
| urd-nasai.min.json | 5765 | 5758 | 0 | 7 | 5758 | 5809 | 99.12% |
| urd-tirmidhi.min.json | 3998 | 3956 | 0 | 42 | 3956 | 4041 | 97.90% |

### Muslim highlight

- `ben-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `eng-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `fra-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `ind-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `rus-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `tam-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `tur-muslim.min.json`: spine 7563/7669; unmatched fawaz 0 (skipped, no invented ids)
- `urd-muslim.min.json`: spine 7563/7669; unmatched fawaz 1 (skipped, no invented ids)

## Catalog summary

Total unified editions: 97

