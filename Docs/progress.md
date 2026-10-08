# Progress

## Status (October 8, 2026)

| Milestone | State |
|---|---|
| M1 Core logic and PDF | Built; automated tests pass; Caleb's comparison (Docs/m2-test.md, Part 1) pending |
| M2 App in the Simulator | Built and walked through by Claude in the Simulator; Caleb's run of Docs/m2-test.md, Part 2 pending |
| M3 App on her iPhone | Not started (needs signing, README "Installing on her iPhone or iPad") |

## Automated results (Claude, Oct 8, 2026, M4 Max, Xcode 27.0, iOS 27.0 Simulator)

`make test`: 34 tests in 8 suites passed.

- Totals: the app's totals equal the printed totals of all nine example invoices
  (0260426-1 … 0260903).
- SKUs: the rules reproduce 33 of the template's 37 SKUs; the other 4 are inconsistent in
  the template (SPEC.md, Open questions, item 1).
- Search: all 17 lines from her messages find the SKU that was invoiced.
- Background removal (Vision, Mac): all 8 raw photos lifted, about 0.02 s each.
- Color fallback vs Vision, intersection over union per raw photo: IMG_8515 0.963,
  IMG_8516 0.971, IMG_8536 0.973, IMG_8537 0.953, IMG_8538 0.953, IMG_8539 0.918,
  IMG_8540 0.945, IMG_8981 0.805.
- Photo duplicate check (feature-print distance, Mac): each raw photo's closest saved
  photo is the right button, 0.040–0.098; next closest 0.241 (red vs navy heart) to 0.408.
- Receipt reading (Mac and Simulator): IMG_9049 gives $36.48, $19.58, $16.90 and
  8/31/2026; IMG_9063 gives $16.21 and 9/2/2026.

In the Simulator, Vision's subject lifting and feature prints fail ("Could not create
inference context", "Failed to create espresso context"); the app falls back to the color
cutout and says it couldn't compare photos. To be confirmed on her iPhone in M3.

## Simulator walkthrough by Claude (Oct 8, 2026)

Home → new invoice → shape picker → Daisy → Red / White → Large (not saved) → new button
from the strawberry photo (color cutout, Touch Up erase and Undo) → review → saved as
26DRWL at $7.50 → quantity. Typed "500 navy blue mushrooms @ $8" → quantity 500 and $8
filled in → 10% discount → $3,600.00. Shipping from receipt IMG_9049 → $36.48 filled in.
Review → Finish → share sheet with "Daphné Verley Invoice - AOB 0261008.pdf". The PDF
from the app shows DISCOUNT $0.80 and TOTAL $3,636.48. Quitting mid-invoice kept the draft;
an empty new invoice was discarded.

Fixed during the walkthrough: typed quantity and price weren't carried to the quantity
screen; number pads had no way to close; "Next: Review" wrapped onto two lines.

## Revision 3 (Oct 8, 2026)

Three-tab layout (Invoices, Buttons, Settings) restored per Caleb; Archive; finished
invoices store their business details and PDF. FreezeProbe in the Simulator: after
finishing, changing Settings and renaming, repricing and archiving the button left the
finished PDF byte-identical (pdfUnchanged=true, profileKept=true, line "Heart, Navy,
Medium $4.00", button now "Heart, Red, Medium $4.50", 1 version kept).

Template typos corrected in the seed and in both template files (SPEC.md, "Data"); both
files pass zip and XML checks and macOS QuickLook renders them. Opening them in Excel is
Docs/m2-test.md, Part 3. `make test`: 34 tests passed.

## M2 results (Caleb)

Pending. Use the Part N, step M labels from Docs/m2-test.md.

| Step | Result |
|---|---|
| | |
