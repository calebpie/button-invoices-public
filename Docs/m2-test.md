# M2 test: the app in the Simulator

About 30 minutes. Record results in Docs/progress.md under "M2", using the Part N, step M
labels below. Commands run in Terminal from the project folder
(`cd "/Users/calebpietrafesa/Developer/DV Button Invoicer"`).

## Part 1: Logic and PDF

1. Run `make test`. Expected: "Test run with 34 tests in 8 suites passed".
2. Run `make sample-pdfs`. A Finder window opens on build/sample-pdfs.
3. Open "Daphné Verley Invoice - AOB 0260903.pdf" there and the same file in
   Examples/Invoice Excel and Output PDFs side by side (select both in Finder, press
   Space, use the arrows). Expected: same layout, numbers and totals ($4,178.69); the
   font is Apple's instead of Aptos/Calibri.
4. Repeat Part 1, step 3 for 0260812 (two pages, 9 buttons on page 1) and 0260426-3
   (the $4.00 discount).
5. Open build/sample-pdfs/cutouts. Expected: 8 buttons with transparent backgrounds,
   comparable to Examples/Images/Edited.

## Part 2: The app

1. Start fresh: `xcrun simctl uninstall booted com.calebpietrafesa.ButtonInvoices`
   (an error that nothing is installed is fine), then `make sim`. The Simulator opens
   the app. Expected: "Hello, Daphné. What would you like to do today?" and "My buttons:
   37 saved".
2. Add test photos to the Simulator:
   `xcrun simctl addmedia booted Examples/Images/Raw/IMG_8516.heic "Examples/Images/Shipping Receipts/IMG_9049.heic"`
3. Tap **Start a new invoice**. Expected: step bar 1 Buttons · 2 Shipping · 3 Review with
   2 and 3 grayed out; "Total so far $0.00"; Next disabled with "Add at least one button
   to go on."
4. Tap **Add the first button** → **Heart** → **Navy**. Expected: "Heart, Navy, Medium,
   $4.00 · 26HNM" and **Use this button**. Tap it, type 12 as the quantity, tap **Add**.
   Expected: line "12 × $4.00 … $48.00", total $48.00, Next enabled.
5. **Add another button** → type `500 navy blue mushrooms @ $8` in the box. Expected:
   "500 buttons · $8.00 each" and Mushroom, Navy / White first. Tap it. Expected:
   quantity 500, price 8. Tap **Add a discount** → **% off** → type 10 → keyboard
   **Done**. Expected: "$0.80 off each button", line total $3,600.00. Tap **Add**.
6. **Add another button** → **Daisy** → **Red / White** → **Large**. Expected: "There's no
   Daisy, Red / White, Large saved yet." Tap **Add it as a new button**.
7. **Choose from Photos** → the strawberry photo. Expected: "Background removed by color"
   (Simulator) and the strawberry on a checkerboard. Tap **Touch Up**, erase a little of
   the edge, **Undo**, **Done**, **Use This Photo**.
8. Tap **Next: Is it already saved?** Expected in the Simulator: "Couldn't compare photos
   on this device." (photo matching needs a real device; on the Mac it picks the
   strawberry) and "Your saved Daisy buttons:" with the four daisies, each with "It's
   this one" and "Same shape, new color or size". Tap **No, it's a new button**.
9. Expected: shape Daisy, colors Red / White, size Large, price $7.50, SKU 26DRWL. Tap
   **Next: Check it** → **Save and Add to Invoice**, quantity 10, **Add**.
10. Tap **Save & Exit**. Expected: home screen lists "Continue a draft" with this
    invoice. Quit the app (in the Simulator: swipe up from the bottom edge and hold, swipe
    the app away), reopen it from the Home Screen ("Invoices"). Expected: the draft is
    still there with 3 lines; tapping it reopens at step 2, Shipping.
11. **Add shipping** → **Choose from Photos** → the receipt. Expected: $36.48 filled in,
    $36.48 / $19.58 / $16.90 to tap, note "Shipped 8/31/2026". Tap **Add Shipping**.
12. **Add another box**, type 16.21, **Add Shipping**. Expected: total $3,775.69
    ($48.00 + $3,600.00 + $75.00 + $36.48 + $16.21).
13. Tap step **1 Buttons** in the step bar, then **3 Review**. Expected: both work.
14. On Review, type 3775.69 under "Check against your own total". Expected: "Matches."
    Tap the PDF page. Expected: full-screen PDF with 3 lines, DISCOUNT $0.80 on the
    mushrooms, two SHIPPING rows. Close it.
15. Tap **Finish** → **Finish and Share the PDF**. Expected: share sheet with
    "Daphné Verley Invoice - AOB 0yyMMdd.pdf" with today's date (0261008 on Oct 8, 2026). Tap **Save to Files** →
    **On My iPhone** → **Save**, then close.
16. Back on the home screen: **See or share a finished invoice** lists it under "Waiting
    for payment". Open it, turn on **Alix of Bohemia has paid**. Expected: it moves to
    "Paid".
17. **My buttons** → tap Heart, Navy, Medium → change the price to 4.50 → **Save**. Tap it
    again. Expected: "Before your changes" shows the $4.00 version. Open the finished
    invoice. Expected: the heart line is still $4.00 each.
18. Repeat Part 2, steps 1–4 with `SIMULATOR="iPad Air 11-inch (M4)" make sim`. Expected:
    the same screens, centered at a readable width.

## Notes for the results

For each step, record pass, or what you saw instead. Note anything that would confuse
your mother even if it works.
