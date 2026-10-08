# Button Invoices — specification

Revision 10, October 8, 2026 (Buttons tab title level with search and + circles; see Design guidelines). Source of truth for the project; propose changes to Caleb
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
  change to it (shown under "Earlier versions" when she edits the button).
- **Shipping charge**: amount, a note for her, optional receipt photo.
- **Business details** (Settings tab): seller name and address, bill-to, routing and
  account numbers, the "BUTTON" and "daphné verley ceramics" lines, the PDF name prefix.
  Copied into an invoice when it is finished, with the PDF itself. The routing and account
  numbers are kept in the iOS keychain, the rest in the app's settings.

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

Photos: Caleb's edited PNG of every button (Examples/Images/Edited, added Oct 8, 2026),
at most 600 px, mapped to SKUs by an explicit table in the seed script because the file
names differ from the invoice names (each pair checked by eye against the workbook
thumbnail). The invoice names are kept; the file names say:

| File name | Invoiced as |
|---|---|
| Daisy, Red : White, Large | Daisy, Red / White, Small (26DRWS) |
| Elipse, Lilac | Ellipse, Lavender, Mini (26ELM) |
| Flower, Bue : White, Large | Clover, Blue / White (26CBLW) |
| Flower Burst, Burgundy : White, Medium | Flower Burst, Burgundy / White (26FBBW) |
| Nautilus, Cotton Tail | Nautilus, White (26NW) |
| Star, Burgundy, Mini | Star, Burgundy, Small (26SBS) |
| Dogwood Flower, … | Dogwood, … |

Sent invoices: the nine invoices in Examples/ (0260426-1 … 0260903) are extracted into
Seed/invoices.json (gitignored) from the values Excel saved in each workbook: number,
the date printed (=TODAY() as last calculated; it matches each PDF), each line's SKU,
quantity, price and discount, and the shipping rows. The script stops if lines plus
shipping don't equal the printed total. On first launch the app loads them as Paid
invoices, finished the way the app finishes one (business details stored; the PDF is
rendered and stored the first time each is opened or shared), with lines taking the catalog's current names and photos (so "Ladybug, Red /
White", "Pineapple", "Suite 100"). SKUs, quantities, prices, shipping and totals are as
sent. Invoice numbers already in the app are skipped. Probe, Oct 8, 2026: all nine load
with the printed totals; first launch took 0.86 s in the Simulator with the PDFs made up
front, 0.36 s with them made on first open.

Kept: Pineapple's 26PYB (on sent invoice 0260812, though Brown is BR elsewhere), and
"Rose, White / Green" (the edited photo is named "White : Blue", but its leaves are the
same teal she calls Green on the strawberry). The sent invoices themselves are unchanged.

### Privacy

Examples/ (real invoices, photos) and Seed/business.json (bank details) are gitignored.
The app makes no network requests. On the device the routing and account numbers are in
the keychain (readable only while the device is unlocked); they are still printed on
every invoice, as on the Excel ones.

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
  right to copy an invoice into a new draft; touching and holding an invoice offers the
  same (Duplicate, Share PDF…, Delete…). Drafts are saved as she goes, including when she
  leaves the app; a new invoice left with nothing on it is discarded. The app reopens on
  the tab, and the draft, she left.
- **Buttons**: every saved button, a section per shape (with a count) and a row per color
  and size. The title sits on the bar's row, level with a search circle and an orange +
  circle: large at the top of the list, shrinking with the scroll to the standard size,
  with the scroll edge effect under the bar (Caleb, Oct 8, 2026). + starts the
  new-button steps; search opens a field above the keyboard ("No Results" when nothing
  matches); each shape's ⋯ menu adds a color or size or renames the shape. Swipe left (or open a button)
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
bottom with the running total ("saved"), Back to the previous step and Next (Finish on
the last step). The standard back button at the top left (or a swipe from the left edge)
returns to the Invoices list; everything is already saved, so there is no Save & Exit.
The tab bar stays visible. The ⋯ menu at the top right has Delete Draft…. She can go back
to any step, and forward to any step whose earlier steps are complete; Next is disabled
with the reason shown until the current step is complete. At the largest text sizes the
two bars stop growing (touch and hold one of their buttons to see it enlarged), so the
step itself keeps most of the screen.

1. **Buttons**: at least one line, each with a quantity and price.
2. **Shipping**: at least one charge, or "No shipping on this invoice".
3. **Review**: invoice number and date (editable), each line, subtotal, shipping, total,
   an optional "your total" check, the checks below, and the PDF preview. Change buttons
   jump to step 1 or 2. Finish marks the invoice Finished (with a success tap from the
   phone), makes the PDF and opens the share sheet (Messages, Mail, AirDrop, Save to
   Files, Print). It doesn't ask to confirm: nothing is sent until she picks where to
   send it, and Make Changes undoes it.

A finished invoice shows its total, Share PDF (also at the top right), an "Alix of
Bohemia has paid" switch, its stored PDF, and a ⋯ menu with Duplicate, Make Changes… (it
returns to Draft; she then finishes and sends it again) and Delete….

## Adding a line

Shape first: a grid of shapes with photos. Picking one lists its saved colors (with
photos), then, once she picks a color, its sizes with "Another Size", even for a shape
made in one size so far (Caleb, Oct 8, 2026). A saved combination fills in the button
("Use This Button"); one that isn't saved offers "Add as a New Button" with the shape,
color and size filled in, as do "Another Color" and "Another Size". Typing in the search
field above the shapes ("12 red hearts @ $4") is a shortcut straight to matching buttons
(Finding a button). Then the quantity screen: quantity (typed, or − and + one at a time),
price each (prefilled; "save as this button's price from now on" if she changes it),
optional discount in Dollars off each button or Percent off, and the line total.

## Finding a button

One search field: "Type an order, like 12 red hearts". A leading number is the quantity, "@ $8" or
"$8" the price, "= $96" is ignored (InvoiceKit/Matcher.swift). The rest is matched
against design, colors, size, SKU and aliases, ignoring case, accents and plurals, with
one-typo tolerance on design names and a few color words from her messages (blush → pale
pink, olive → green, off white → ivory, navy blue → navy). Results are ranked photo
tiles, recently used first when the box is empty. When she picks a button after typing
words it doesn't answer to, those words are saved as its aliases. She can see and correct
them under "Also known as" when she edits the button. All 17 lines from her
2026 messages find the button Caleb invoiced (MatcherTests).

## Adding a new button

Four steps, from an invoice or from the Buttons tab:

1. **Photo**: take or choose one; the background is removed (Button photos), with Touch
   Up. "Skip Photo" goes to step 3.
2. **Is it already saved?** The photo is compared with every saved photo (Vision feature
   prints, InvoiceKit/LookAlike.swift). A close match is a warning, not a block: each
   match offers "It's This One" (use it) or "Same Shape, New Color or Size" (fills in its
   shape, colors, size and price to edit). The saved buttons of the shape she already
   picked are listed too. "It's a New Button" continues.
3. **Shape, colors and price**: as filled in so far, cleaned up as she types (Names), with
   the SKU suggested (SKUs). A button with the same name or SKU can't be saved twice.
   Colors are tapped, not typed (Caleb, Oct 8, 2026): every color used so far is a chip
   with a dot of that color (her glazes as measured from her photos, then common color
   words; InvoiceKit/Swatch.swift; a word it doesn't know gets no dot);
   the ones she picks show first, in order, each with ✕ to take it off, and the first is
   the main color. "New Color" adds one by name; it is kept for future buttons even before
   a saved button uses it.
4. **Review**: photo, name, SKU, price, and whether it's a new shape; "Save and Add to
   Invoice" goes straight to the quantity screen.

Archived buttons are included in the photo check; choosing one ("It's This One")
unarchives it.

Photo-match thresholds (probe, October 8, 2026: her 8 raw photos against the 37 saved
edited photos; LookAlikeTests): the same button 0.041–0.103, the same shape in another
color (hearts, mushrooms) 0.241–0.313, different shapes 0.338 and up. The app warns "looks like" below
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
Accounting-style amounts ("$ 9.00", "$ -"). Button photos are embedded as 200 px JPEGs on
white, so an invoice is 66–212 KB (the nine examples; 153 KB–1.1 MB as PNGs). Nine buttons fit on page 1 as in Excel;
later pages repeat the column header (Excel's didn't). Named
"Daphné Verley Invoice - AOB <number>.pdf".

Fonts: Aptos Narrow and Calibri are Microsoft's and can't be bundled, so the iOS system
font stands in (condensed for Aptos Narrow). `make sample-pdfs` re-creates the nine
example invoices for side-by-side comparison.

## Platform

- iPhone and iPad, iOS 18 or later (every iPhone since the XS/XR). Public APIs only.
- Swift 6, SwiftUI, SwiftData, Vision, TipKit, App Intents. No third-party code in the app.
- iPhone in portrait only; iPad in every orientation.
- Project from project.yml (XcodeGen pinned in Tools/BuildTools); logic in the
  Packages/InvoiceKit Swift package, tested on the Mac with `make test`.
- Distribution to her devices: TestFlight once Caleb's paid developer account is approved
  (builds last 90 days, she installs updates herself). Until then, development builds
  over a cable, which stop opening after 7 days with the free Personal Team (README).

## Design guidelines

Apple's Human Interface Guidelines (HIG), reviewed in full on Oct 8, 2026: every page that
applies to iOS and iPadOS, including all of Foundations; pages for other platforms and
for features the app doesn't have (games, Wallet, HealthKit, CarPlay and so on) were read
for anything general. Shared pieces are in App/Sources/Platform.swift. Where the iOS 26
form doesn't exist on iOS 18, the iOS 18 equivalent is used.

Applied (HIG page in parentheses):

- Navigation: the standard back button and edge swipe everywhere, the tab bar always
  visible, filled tab symbols (Tab bars, Toolbars). Controls over scrolling content use
  the system scroll edge effect (Layout).
- Sheets: Cancel (✕) at the top left and the confirm action (✓) at the top right, the
  one prominent button. Edits in a sheet are never lost silently: Cancel or swiping the
  sheet down asks "Discard your changes?", from the ✕ when she tapped it (Sheets,
  Toolbars).
- One prominent button per screen; title-case labels; "…" on menu items that ask a
  question first (Buttons, Menus, Writing).
- No confirmation for Finish; a success haptic marks it (Alerts, Playing haptics).
  Confirmations stay for deleting and for reopening a sent invoice.
- Every swipe action is also in the touch-and-hold menu (Context menus, Gestures).
- Buttons tab: search and add are symbols in the bar, add the prominent one; search
  opens into a field above the keyboard (Toolbars, Search fields, "Search in a toolbar").
  The title is custom so it can sit level with them; it keeps the system title for
  VoiceOver and the app switcher. On iOS 18, search is the field under the title.
- Grouped rows always form whole rounded cards: a button photo sits on its card with
  Take Photo and Choose from Photos; a bare prominent button never has a card row under
  it (Skip Photo is plain text; Remove from Invoice has its own card). Destructive rows
  carry an icon like the rows beside them (Lists and tables, Buttons).
- Keyboards: no Done bar above the number pads (Caleb, Oct 8, 2026). Tapping anywhere
  outside a field puts the keyboard away, as does dragging it down. Tapping anywhere in a
  field's row, its label included, goes into the field (SwiftUI otherwise takes only the
  middle 26 points of a 56-point row). A field's whole row is kept clear of the keyboard
  (Virtual keyboards, Text fields).
- Number fields take only digits, and dollars and percents one decimal point with two
  places, whether typed on a hardware keyboard or pasted (Text fields).
- A question before deleting or changing an invoice comes from what she tapped: the
  invoice's row, or ⋯ (Action sheets).
- Share uses the system share sheet and the standard Share button (Collaboration and
  sharing). The paid switch sits in a list row (Toggles).
- Larger text: rows stack their parts at the accessibility sizes, photo above text;
  the invoice bars stop growing and offer the large content viewer (Typography,
  Accessibility). VoiceOver headings on section titles, labels on photos and icon-only
  buttons, the photo checkerboard hidden from VoiceOver (Accessibility, VoiceOver).
- Color: the terracotta accent has darker and lighter versions for Increase Contrast and
  Dark Mode. White on the light accent is 5.0:1 (6.7:1 with Increase Contrast). In Dark
  Mode it is 3.1:1 on filled buttons (their text is large and bold) and 5.4:1 for accent
  text on cards; with Increase Contrast, 2.8:1 and 5.5:1, the same trade-off Apple's
  own red makes (Color, Dark Mode, Accessibility).
- Privacy: bank numbers in the keychain; the camera prompt says what the camera is for
  (Privacy).
- Search: the system search field, always visible, above the shapes (Search fields).
- Quantity stepper; Dollars / Percent as a segmented control (Steppers, Segmented
  controls).
- Undo: shake to undo (or three-finger swipe) for removing a line or shipping charge,
  archiving and deleting, each named ("Undo Delete Invoice") (Undo and redo).
- The app reopens where she left off (Launching, Multitasking).
- Two tips, typing an order line and repeating an order with Duplicate, each shown until
  she closes it or uses the feature, at most one new tip a day (Offering help).
- Home Screen quick actions (touch and hold the icon) and App Shortcuts for Siri and
  the Shortcuts app: New Invoice, Add a Button. ⌘N on an iPad keyboard (Home Screen quick
  actions, App Shortcuts, Keyboards).
- Photos can be dragged in from another app on iPad (Drag and drop).
- A layered app icon made with Icon Composer, so iOS 26 can render it in Liquid Glass,
  dark and tinted (App icons).
- Launch: invoice PDFs are made when first opened, not at first launch (Launching).
- Corrections to the button finder are visible and editable as "Also known as" (Machine
  learning, "Let people correct mistakes").

Not adopted, and why:

- Widgets, Live Activities, notifications, Spotlight indexing: nothing in her week needs
  them, and each is something more for her to learn or dismiss.
- Landscape on iPhone: the invoice steps are cramped sideways, so the iPhone app stays
  upright (Caleb, Oct 8, 2026). iPad turns every way.
- An iPad sidebar: three tabs fit; the system tab bar already moves to the top on iPad.
- Assistive Access: a whole separate mode, out of scope unless she needs it.
- Sign in with Apple, in-app purchase, Apple Pay, SharePlay: not used.

## Milestones

| | Milestone | Test |
|---|---|---|
| M1 | Core logic and PDF in InvoiceKit | `make test` passes; Caleb compares `make sample-pdfs` with Examples/ |
| M2 | App in the Simulator | Caleb runs Docs/m2-test.md in the Simulator; Part 2 results in Docs/progress.md |
| M3 | App on her iPhone | She makes her next real invoice with it; Caleb checks the PDF before it goes to AOB |

## Open questions (for Caleb)

1. Template data, corrected Oct 8, 2026 (Data). Still open: Nautilus, Unglazed shares
   Matte White's photo and Nautilus, Brown, Large shares Brown's; Pineapple keeps 26PYB;
   the photo file names suggest different sizes or colors for six buttons (Data, second
   table): which names are right?
2. SKU year: fixed at first save (assumed), or re-yeared every January?
3. Same-day numbering: the April batch was -1…-5 from the first; the app gives the first
   one no suffix and the second "-2". Fine?
6. Discounts: the template takes a dollar amount off each button. The app also accepts a
   percentage but prints the dollar amount in the DISCOUNT column. Should the PDF show
   the percentage instead?
4. iCloud sync between her iPhone and iPad needs the paid account and an iCloud container.
   Worth turning on then?
5. Done Oct 8, 2026: all 37 starting photos are now Caleb's edited PNGs.
