# M2 test: the app in the Simulator

About 40 minutes. Record results in Docs/progress.md under "M2", using the Part N, step M
labels below. Commands run in Terminal from the project folder
(`cd "/Users/calebpietrafesa/Developer/DV Button Invoicer"`).

## Part 1: Logic and PDF

1. Run `make test`. Expected: "Test run with 35 tests in 9 suites passed".
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
   (an error that nothing is installed is fine), then `make sim`. Device Hub (Xcode 27's
   Simulator) opens with the app on the iPhone 17; if it shows another device, click
   **iPhone 17** in its sidebar. Expected: tab bar Invoices · Buttons · Settings; Invoices shows "Hello,
   Daphné. What would you like to do today?", New Invoice, and under Paid the nine sent
   invoices, newest first (0260903 $4,178.69 … 0260426-1 $947.21). Open 0260812: two pages,
   $976.90, same lines as Examples/…/0260812.pdf with "Ladybug, Red / White" and
   "Pineapple" spelled that way. Buttons lists 37 buttons by
   shape (Bunny first) with **Add a Button** floating bottom right; Pineapple, Celadon,
   Ellipse, "Ladybug, Red / White", Crab 26CBL and Shell 26SY are spelled that way.
   Settings shows "123 Example St, Suite 100".
2. Add test photos to the Simulator:
   `xcrun simctl addmedia booted Examples/Images/Raw/IMG_8516.heic "Examples/Images/Shipping Receipts/IMG_9049.heic"`
3. Invoices tab → **New Invoice**. Expected: a standard back arrow at the top left, the
   step bar 1 Buttons · 2 Shipping · 3 Review with 2 and 3 grayed out, the tab bar still
   at the bottom, "Total so far · saved $0.00", and Next disabled with "Add at least one
   button to go on."
4. Tap **Add a Button** → **Heart** → **Navy**. Expected: "Heart, Navy, Medium, $4.00 ·
   26HNM" and **Use This Button**. Tap it, type 12 as the quantity (or tap **+**), tap **Add
   to Invoice**. Expected: line "12 × $4.00 … $48.00", total $48.00, Next enabled.
5. **Add Another Button** → type `500 navy blue mushrooms @ $8` in the search field.
   Expected: heading "Which button? Tap it.", "500 buttons · $8.00 each. Now tap the
   button." and Mushroom, Navy / White first. Tap it. Expected: quantity 500, price 8. Tap
   **Add Discount** → **Percent** → type 10 → keyboard **Done**. Expected: "$0.80 off each
   button", line total $3,600.00. Tap **Add to Invoice**.
6. **Add Another Button** → **Daisy** → **Red / White** → **Large**. Expected: "There's no
   Daisy, Red / White, Large saved yet." Tap **Add as a New Button**.
7. **Choose from Photos** → the strawberry photo. Expected: "The background was removed by
   color" (Simulator) and the strawberry on a checkerboard. Tap **Touch Up**, erase a little
   of the edge, **Undo**, then the **✓** at the top right, then **Use This Photo**.
8. Tap **Next**. Expected in the Simulator: "Couldn't compare photos on this device."
   (photo matching needs a real device; on the Mac it picks the strawberry) and "Your saved
   Daisy buttons:" with the four daisies, each with **It's This One** and **Same Shape, New
   Color or Size**. Tap **It's a New Button**.
9. Expected: shape Daisy, colors Red / White, size Large, price $7.50, SKU 26DRWL. Tap
   **Next** → **Save and Add to Invoice**, quantity 10, **Add to Invoice**.
10. Tap the back arrow at the top left. Expected: the Invoices tab lists this invoice under
    Drafts. Quit the app (Device Hub menu bar → **Controls → App Switcher**, then drag
    the app's card up and away), reopen it from the Home Screen ("Invoices"). Expected: the draft is
    still there with 3 lines; tapping it reopens at step 2, Shipping.
11. **Add Shipping** → **Choose from Photos** → the receipt. Expected: $36.48 filled in,
    $36.48 / $19.58 / $16.90 to tap, note "Shipped 8/31/2026". Tap **Add Shipping**.
12. **Add Another Box**, type 16.21, **Add Shipping**. Expected: total $3,775.69
    ($48.00 + $3,600.00 + $75.00 + $36.48 + $16.21).
13. Tap step **1 Buttons** in the step bar, then **3 Review**. Expected: both work. On step
    2, the round **‹** button at the bottom goes back to step 1.
14. On Review, type 3775.69 under "Compare with your own total (optional)". Expected:
    "Matches." Tap the PDF page. Expected: full-screen PDF with 3 lines, DISCOUNT $0.80 on
    the mushrooms, two SHIPPING rows. Close it.
15. Tap **Finish**. Expected: no question first; the share sheet opens with "Daphné Verley
    Invoice - AOB 0yyMMdd.pdf" with today's date (0261008 on Oct 8, 2026). Tap **Save to
    Files** → **On My iPhone** → **Save**, then close.
16. Back on the Invoices tab it's listed under "Finished, waiting for payment". Open it.
    Expected: total, **Share PDF** with a white share icon, a Share button and **⋯** at the top right, the switch
    **Alix of Bohemia has paid**, and the PDF. Tap **⋯**. Expected: **Duplicate**, **Make
    Changes…** and **Delete…** right away; tap outside to close it. Turn the switch on, go back. Expected: it's
    under "Paid".
17. Buttons tab → Heart section → tap **Navy, Medium** → change the price to 4.50 →
    **Save Changes**. Tap it again. Expected: "Before your changes" shows the $4.00
    version. Tap **Archive This Button**. Expected: it moves to "Archived" at the bottom of
    the list.
18. Settings tab → change Street to "1 Test Street". Invoices tab → open the finished
    invoice. Expected: the PDF still shows Suite 100 and the heart at $4.00. Then go back,
    **New Invoice** → **Add a Button** → **Heart**. Expected: Navy isn't offered
    (archived). Tap **✕** at the top left, then the back arrow. Put Settings back to "123
    Example St, Suite 100" and unarchive the heart (Buttons → Archived → tap it →
    **Unarchive This Button**).
19. Repeat Part 2, steps 1–4 with `SIMULATOR="iPad Air 11-inch (M4)" make sim`. Expected:
    the same screens, with the tabs at the top and the content centered at a readable
    width. Then **Controls → Rotate Left**. Expected: the iPad app turns to landscape.

## Part 3: Template typo fixes

1. Open Examples/Invoice Excel and Output PDFs/BUTTON INVOICE TEMPLATE.xltx in Excel.
   Expected: it opens without a repair prompt; Reference sheet shows Celadon, Ellipse,
   Pineapple, "Ladybug, Red / White", Crab 26CBL, Shell 26SY; Invoice sheet shows
   "123 Example St, Suite 100"; the photos are still in column C.
2. Repeat Part 3, step 1 for BUTTON INVOICE TEMPLATE.xlsx. The originals are in
   "Originals before typo fixes" in the same folder.

## Part 4: Apple's design guidelines

Checks for SPEC.md, "Design guidelines". Use the iPhone Simulator from Part 2.

1. Invoices tab → touch and hold the paid invoice from Part 2, step 16. Expected: a menu
   with **Duplicate**, **Share PDF…** and **Delete…**. Tap **Duplicate**. Expected: a new
   draft opens at step 2, Shipping, with the same three buttons and no shipping yet.
2. In that draft, tap the mushroom line. Expected: a form with **✕** at the top left and
   **✓** at the top right. Change the quantity to 400, then swipe the form down from its
   top. Expected: "Discard your changes?" with **Discard Changes**. Tap it. Expected: the
   line still says 500. Open it again, change to 400, tap **✕**. Expected: the same
   question; tap outside it to keep editing, then **✕** → **Discard Changes**.
3. Swipe left on the mushroom line → **Delete**. Then click the Device Hub window and press
   **⌘Z**. Expected: the line is back. (Device Hub has no Shake; ⌘Z runs the same undo.
   Shaking the phone, with its "Undo Remove Button" question, is checked in M3.)
4. Go back to the Invoices tab, swipe the duplicate left → **Delete**. Expected: the
   question points at that invoice. Tap **Delete Invoice**. Press **⇧⌘H** (Home Screen), touch and hold the **Invoices** icon. Expected:
   **New Invoice** and **Add a Button**. Tap **Add a Button**. Expected: the app opens on
   the Buttons tab with the new-button steps. Tap **✕**.
5. In Terminal:
   `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`
   Expected: the app's text gets much larger; invoice rows put the icon above the text and
   no invoice number is split; in a draft the two bars stay a usable size. Put it back:
   `xcrun simctl ui booted content_size large`
6. In Terminal: `xcrun simctl ui booted appearance dark`. Expected: dark screens, the
   accent a lighter terracotta, the photo checkerboard dark gray. Put it back:
   `xcrun simctl ui booted appearance light`
7. Device Hub menu bar → **Controls → Rotate Left**. Expected: the iPhone turns, but the
   app stays upright (portrait only on iPhone). **Controls → Rotate Right** to return.
8. Home Screen: expected app icon, a terracotta button with four holes on cream.

## Notes for the results

For each step, record pass, or what you saw instead. Note anything that would confuse
your mother even if it works.
