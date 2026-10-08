# Button Invoices — specification

Revision 3, October 8, 2026 (three tabs instead of a home screen; archive; Settings frozen into finished invoices; template typos corrected). Source of truth for the project; propose changes to Caleb
rather than diverging. Status and test results: Docs/progress.md.

## Goal

Daphné Verley makes ceramic buttons and sells them to Alix of Bohemia (AOB). To be paid
she sends AOB an invoice. Until now she texted Caleb quantities, photos and shipping
receipts, and Caleb built each invoice in an Excel template and sent back a PDF. This app
lets her do it herself on her iPhone or iPad: pick or add buttons, add shipping, check
the total, and send a PDF that looks like the ones AOB already gets.

Scope is buttons for AOB. Other products and customers are out of scope (the bill-to
details are editable, but there is one customer at a time).

## Who uses it

Daphné only. She is not comfortable with Excel and works from an iPhone and an iPad.
Design rules that follow:

- One obvious action per screen, large text and buttons, plain words ("Add Buttons",
  "Finish"), no jargon (no "variant", "SKU" only where it's printed).
- Accept input the way she already writes it: "12 ladybugs @ $8 = $96", "blush
  nautilus", "navy blue mushrooms", "Off White Dogwoods". Pick from photos, not names.
- The app does all arithmetic. She may type her own total to compare.
- Nothing she does can silently change an invoice already sent.

## Data

Stored on the device with SwiftData (App/Sources/Models.swift), included in iCloud
Backup. Model shapes follow SwiftData's CloudKit rules so iCloud sync between her iPhone
and iPad can be switched on later without a migration (see Open questions).

- **Design**: a button shape she makes ("Nautilus", "Cowrie Shell"), with its SKU letters.
- **Button** (one design in one color and size): colors, size, SKU, price, photo
  (square transparent PNG, ≤ 800 px), words she has used for it (aliases), hidden flag.
- **Invoice**: number, date, status (Draft / Finished / Paid), lines, shipping charges,
  "no shipping" flag; once finished, the business details it was finished with and its PDF.
- **Line**: copies of the SKU, name and photo (≤ 400 px) at the time it was added,
  quantity, price each, discount each in dollars (and the percentage, if she entered
  one). Later catalog edits update lines on Draft invoices only.
- **Button history**: a copy of a button's name, SKU, price and photo, saved before each
  change to it (shown under "Before your changes" when she edits the button).
- **Shipping charge**: amount, a note for her, optional receipt photo.
- **Business details** (Settings tab): seller name and address, bill-to, routing and
  account numbers, the "BUTTON" and "daphné verley ceramics" lines, the PDF name prefix.
  Copied into an invoice when it is finished, with the PDF itself.

First launch loads the catalog from App/Resources/Seed, which `make seed` builds from
the 0260903 workbook's Reference sheet (37 buttons). Business details come from the same
workbook into Seed/business.json. Typos in the workbook are corrected on the way in
(Tools/seed/extract_seed.py), and were corrected in the two template files too (originals
in Examples/…/Originals before typo fixes):

| Was | Now |
|---|---|
| Pineaple, Yellow / Brown | Pineapple, Yellow / Brown |
| Dogwood, Celedon | Dogwood, Celadon |
| Elipse, Lavender, Mini | Ellipse, Lavender, Mini |
| Ladybug, Red (SKU 26LRW, photo "Red : White") | Ladybug, Red / White |
| 123 Example St, Suit 100 | 123 Example St, Suite 100 |
| Crab, Blue 26CBLW (the clover's SKU) | Crab, Blue 26CBL |
| Shell, Yellow 26SW | Shell, Yellow 26SY |

Kept: Pineapple's 26PYB (on sent invoice 0260812, though Brown is BR elsewhere), and
"Rose, White / Green" (the edited photo is named "White : Blue", but its leaves are the
same teal she calls Green on the strawberry). The sent invoices themselves are unchanged.

### Privacy

Examples/ (real invoices, photos) and Seed/business.json (bank details) are gitignored.
The app makes no network requests.

## Names

Printed as "Design, Color / Color, Size": "Daisy, Black / White, Large". Size is left out
for one-size designs ("Nautilus, Black"). Cleanup when she types a new button
(InvoiceKit/Naming.swift): extra spaces removed, each word capitalized, the design made
singular ("ladybugs" → "Ladybug", "strawberries" → "Strawberry"; "Nautilus", "Lips" kept),
colors split on "/", ",", "&", "and". Words the iOS spell checker doesn't know, and that
aren't already in the catalog, get a "Did you mean …?" suggestion she can tap.

## SKUs

Two-digit year the button was first saved, the design's letters (initials: N, CS, FB),
a code per color, a size letter (Mini M, Small S, Medium M, Large L, Extra Large XL):
"Daisy, Black / White, Large" saved in 2026 → 26DBWL (InvoiceKit/SKU.swift).

- Color codes in use are kept: Black B, White W, Brown BR, Blue BL, Burgundy B, Navy N,
  Red R, Green G, Yellow Y, Ivory I, Celadon C, Lavender L, Pale Pink PP, Matte Pink MP,
  Matte White MW, Unglazed UG. A new color gets its initials, or more letters of its
  first word until no other color has that code (Bronze → BRO). Codes are re-learned from
  saved SKUs, so a new color keeps the code it was first given.
- If the SKU is taken, the design part grows a letter (a Star in Black / White would be
  26STBW because the Sailboat is 26SBW), then a number is added.
- A saved button keeps its SKU when its name is edited; the form offers the rule-based
  SKU as a choice. SKUs can be typed by hand; duplicates are refused.
- These rules reproduce 33 of the template's 37 SKUs. The other four are inconsistent in
  the template itself and were kept as they are (Open questions).

Hypothesis (unconfirmed): the year in an SKU is the year the button was first saved and
never changes. If Caleb re-years all SKUs each January, this needs a change.

## Layout

Three tabs in the floating Liquid Glass tab bar (Caleb, Oct 8, 2026):

- **Invoices**: "Hello, Daphné. What would you like to do today?", New Invoice, then
  Drafts (tap to carry on), Finished, waiting for payment, and Paid. Swipe left to delete,
  right to copy an invoice into a new draft. Drafts are saved as she goes, including when
  she leaves the app; a new invoice left with nothing on it is discarded.
- **Buttons**: every saved button, a section per shape (with a count) and a row per color
  and size. A floating Add a Button (Liquid Glass) starts the new-button steps; each
  shape's ⋯ menu adds a color or size or renames the shape. Swipe left (or open a button)
  to Archive; archived buttons are listed at the bottom, aren't offered for new lines,
  and can be unarchived. A button can be deleted only if it has never been invoiced.
- **Settings**: each field printed on the invoice, in page order (your business, bill to,
  the lines above and below each button, routing and account, the PDF name), plus a
  sample invoice preview and the greeting name.

## Settings

Edits apply to drafts and new invoices. Finishing an invoice stores its business details
and its PDF; a finished invoice always shows and shares that PDF. Make Changes reopens it
as a draft that keeps the stored details (the Review step offers "Use the details in
Settings instead"). Probe, Oct 8, 2026 (FreezeProbe): after finishing, changing the
address and routing in Settings and renaming, repricing and archiving the button left the
finished PDF byte-identical and the line "Heart, Navy, Medium $4.00".

## Making an invoice

Three steps with a step bar at the top, a one-line instruction on each, and a bar at the
bottom with the running total, Back and Next (Finish on the last step). Save & Exit is at
the top left throughout. The tab bar is hidden while she works through an invoice. She can go back to any step, and forward to any step whose
earlier steps are complete; Next is disabled with the reason shown until the current step
is complete.

1. **Buttons**: at least one line, each with a quantity and price.
2. **Shipping**: at least one charge, or "No shipping on this invoice".
3. **Review**: invoice number and date (editable), each line, subtotal, shipping, total,
   an optional "your total" check, the checks below, and the PDF preview. Change buttons
   jump to step 1 or 2. Finish asks to confirm, marks the invoice Finished, makes the PDF
   and opens the share sheet (Messages, Mail, AirDrop, Save to Files, Print).

A finished invoice shows its stored PDF, Share, a "has paid" switch, and Make Changes,
which returns it to Draft (she then finishes and sends it again).

## Adding a line

Shape first: a grid of shapes with photos. Picking one lists its saved colors (with
photos), then its sizes if it has more than one. A saved combination fills in the button
("Use this button"); one that isn't saved offers "Add it as a new button" with the shape,
color and size filled in, as do "Another color" and "Another size". Typing in the box
above the shapes ("12 red hearts @ $4") is a shortcut straight to matching buttons
(Finding a button). Then the quantity screen: quantity, price each (prefilled; "save as
this button's price from now on" if she changes it), optional discount in $ off each
button or % off, and the line total.

## Finding a button

One search box: "Type like: 12 red hearts". A leading number is the quantity, "@ $8" or
"$8" the price, "= $96" is ignored (InvoiceKit/Matcher.swift). The rest is matched
against design, colors, size, SKU and aliases, ignoring case, accents and plurals, with
one-typo tolerance on design names and a few color words from her messages (blush → pale
pink, olive → green, off white → ivory, navy blue → navy). Results are ranked photo
tiles, recently used first when the box is empty. When she picks a button after typing
words it doesn't answer to, those words are saved as its aliases. All 17 lines from her
2026 messages find the button Caleb invoiced (MatcherTests).

## Adding a new button

Four steps, from an invoice or from the Buttons tab:

1. **Photo**: take or choose one; the background is removed (Button photos), with Touch
   Up. "No photo right now" skips to step 3.
2. **Is it already saved?** The photo is compared with every saved photo (Vision feature
   prints, InvoiceKit/LookAlike.swift). A close match is a warning, not a block: each
   match offers "It's this one" (use it) or "Same shape, new color or size" (fills in its
   shape, colors, size and price to edit). The saved buttons of the shape she already
   picked are listed too. "No, it's a new button" continues.
3. **Shape, colors and price**: as filled in so far, cleaned up as she types (Names), with
   the SKU suggested (SKUs). A button with the same name or SKU can't be saved twice.
4. **Review**: photo, name, SKU, price, and whether it's a new shape; "Save and Add to
   Invoice" goes straight to the quantity screen.

Archived buttons are included in the photo check; choosing one ("It's this one")
unarchives it.

Photo-match thresholds (probe, October 8, 2026: her 8 raw photos against the 37 saved
ones; LookAlikeTests): the same button 0.040–0.098, the same shape in another color (red
vs navy heart) 0.241–0.312, different shapes 0.337 and up. The app warns "looks like" below
0.2 and lists "similar" below 0.4. Hypothesis until checked with a new photo of a button
that is already saved. Vision's feature prints fail in the Simulator ("Failed to create
espresso context", Oct 8, 2026); the step then says it couldn't compare photos and still
lists the chosen shape's saved buttons.

## Button history

Changing a saved button keeps a copy of how it was before (name, SKU, price, photo).
Finished invoices never change: lines keep their own copies of name, SKU, price and
photo. Draft invoices pick up a corrected name or photo.

## Button photos

Take a photo or choose one; the background is removed with Vision's subject lifting
(the same as in Photos), then cropped to a square transparent PNG like the hand-edited
ones. Probe, October 8, 2026, M4 Max: all 8 raw photos in Examples/Images/Raw lifted
cleanly at 1600 px in about 0.02 s each (build/sample-pdfs/cutouts). Where Vision fails
(the Simulator: "Could not create inference context", also with CPU only), the colors
around the photo's edges are removed instead: the background's 5th–95th percentile color
range plus 2%, flood-filled from the edges, keeping the largest shape. Against Vision's
masks of the 8 raw photos it agrees at 0.81–0.97 intersection over union (PhotoTests).

Touch Up: Erase / Restore brush with size slider, Undo, Start Over, original shown faintly
underneath. With several buttons in one photo she taps the one to keep. Known difference
from the Photoshop edits: button holes keep the background showing through unless she
erases them.

## Shipping

Any number of shipping charges, each a SHIPPING row on the PDF. Optional receipt photo:
the app reads the dollar amounts and date (Vision text recognition) and shows them as
buttons to tap, most repeated first, and fills the note with "Shipped <date>". It never
fills the amount without her seeing it, because receipts list several shipments and she
circles hers (probe: one circled $36.48 was read as $30.48 once and $36.48 once).

## Invoice numbers

"0" + yyMMdd of the invoice date: 3 Sep 2026 → 0260903. A second invoice dated the same
day gets "-2", then "-3". Changing the date renumbers until she types her own number.
Duplicate numbers block sending.

## Totals

Line total = (price − discount) × quantity, discount being per button as in the template
(0260426-3: 106 × ($8 − $4) = $424). A percentage discount is turned into dollars per
button, rounded to the cent (10% of $8.00 = $0.80), which is what the PDF prints. Total = buttons + all shipping. Amounts are whole
cents. The app's totals equal the printed totals of all nine example invoices
(InvoiceTests).

## Checks on the Review step

Problems block Finish (no buttons, a zero price or quantity, a duplicate or empty invoice
number); warnings don't (a line without a photo, an SKU twice, missing bank details).

## The PDF

US Letter, laid out like the Excel printout (InvoiceKit/InvoicePDF.swift; positions
measured from 0260903.pdf): logo, seller block, grey INVOICE, invoice # and date box,
BILL TO, the table (SKU, IMAGE, DESCRIPTION, QTY, PRICE, DISCOUNT, SUBTOT) with 58 pt
rows, SUBTOTAL / SHIPPING… / TOTAL, routing and account beside the last two total rows.
Accounting-style amounts ("$ 9.00", "$ -"). Nine buttons fit on page 1 as in Excel;
later pages repeat the column header (Excel's didn't). Named
"Daphné Verley Invoice - AOB <number>.pdf".

Fonts: Aptos Narrow and Calibri are Microsoft's and can't be bundled, so the iOS system
font stands in (condensed for Aptos Narrow). `make sample-pdfs` re-creates the nine
example invoices for side-by-side comparison.

## Platform

- iPhone and iPad, iOS 18 or later (every iPhone since the XS/XR). Public APIs only.
- Swift 6, SwiftUI, SwiftData, Vision. No third-party code in the app.
- Project from project.yml (XcodeGen pinned in Tools/BuildTools); logic in the
  Packages/InvoiceKit Swift package, tested on the Mac with `make test`.
- Distribution to her devices: TestFlight once Caleb's paid developer account is approved
  (builds last 90 days, she installs updates herself). Until then, development builds
  over a cable, which stop opening after 7 days with the free Personal Team (README).

## Milestones

| | Milestone | Test |
|---|---|---|
| M1 | Core logic and PDF in InvoiceKit | `make test` passes; Caleb compares `make sample-pdfs` with Examples/ |
| M2 | App in the Simulator | Caleb runs Docs/m2-test.md in the Simulator; Part 2 results in Docs/progress.md |
| M3 | App on her iPhone | She makes her next real invoice with it; Caleb checks the PDF before it goes to AOB |

## Open questions (for Caleb)

1. Template data, corrected Oct 8, 2026 (Data). Still open: Nautilus, Unglazed shares
   Matte White's photo and Nautilus, Brown, Large shares Brown's; Pineapple keeps 26PYB.
2. SKU year: fixed at first save (assumed), or re-yeared every January?
3. Same-day numbering: the April batch was -1…-5 from the first; the app gives the first
   one no suffix and the second "-2". Fine?
6. Discounts: the template takes a dollar amount off each button. The app also accepts a
   percentage but prints the dollar amount in the DISCOUNT column. Should the PDF show
   the percentage instead?
4. iCloud sync between her iPhone and iPad needs the paid account and an iCloud container.
   Worth turning on then?
5. 29 of the 37 starting photos are the small copies embedded in the workbook (~70 px).
   If the original edited PNGs exist, put them in Examples/Images/Edited and run
   `make seed` before installing.
