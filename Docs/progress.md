# Progress

## Status (October 8, 2026)

| Milestone | State |
|---|---|
| M1 Core logic and PDF | Built; automated tests pass; Caleb ran Docs/m2-test.md, Part 1, steps 1–2 (pass); his comparison, Part 1, steps 3–5, not reported yet |
| M2 App in the Simulator | Built and walked through by Claude; Caleb's first run stopped at Part 2, step 1 (`make sim`, Xcode 27 has no Simulator app), fixed; Parts 2 and 4 pending |
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

## Edited photos (Oct 8, 2026)

Caleb added the edited PNG of every button. Feature-print matching against the ~70 px
workbook thumbnails was unreliable (distances 0.45–0.80, wrong first match for 17 of 27
files), so each file was paired with its SKU by name and the 35 pairs were checked by
eye: all match. All 37 buttons now have an edited photo (600 px, 13 MB in the bundle).
`make test`: 34 passed; duplicate check with the new photos: same button 0.041–0.103,
same shape other color 0.241–0.313, different shapes ≥ 0.338. Sample PDF 0260607 shows the
same photos as the Excel PDF.

## Sent invoices preloaded (Oct 8, 2026)

The nine example invoices load as Paid on first launch (Seed/invoices.json from the
workbooks; numbers, dates and totals cross-checked against the PDFs' text). Stored PDFs
from the Simulator (ExportFinishedPDFs probe): 0260426-1 $947.21, -2 $1,321.14,
-3 $440.14, -4 $4,192.90, -5 $1,876.18, 0260607 $7,422.11, 0260812 $976.90 (2 pages),
0260819 $2,656.21, 0260903 $4,178.69: all equal the printed totals. First launch 0.86 s.
PDF size with JPEG photos: 66–212 KB (was 153 KB–1.1 MB). `make test`: 35 passed.

## Apple design guidelines (Oct 8, 2026)

SPEC.md revision 5, "Design guidelines": all 173 Human Interface Guidelines pages read
(the iOS and iPadOS ones in full). Checked by Claude in the iPhone 17 Simulator (iOS 27.0)
and the iPad Air 11-inch (M4) Simulator:

- Draft flow: standard back arrow, tab bar visible, round ‹ for the previous step (the
  word "Back" was cut to "Ba…" in the first try, so it is now an icon with the VoiceOver
  label "Back to Buttons").
- Shipping form: ✕ and ✓; typing $42.50 then ✕, and separately swiping the form down,
  both asked "Discard your changes?"; Discard Changes closed it with nothing added.
- Add a Button: search field always visible; "12 red hearts" → hearts first, quantity 12
  carried to the quantity screen.
- Largest accessibility text: the step bar showed "1 …" and the bottom bar took half the
  screen; both now stop at the largest standard size. Invoice rows split "0261008" across
  two lines; the icon now moves above the text. Both fixed and rechecked.
- Dark Mode: contrast of white text on the high-contrast dark accent was 2.40:1; changed
  to #EA7A5E (2.82:1, the same as Apple's red) with accent text on dark cards at 5.49:1.
- Landscape (forced with the DEBUG `-OrientationProbe landscape` launch argument, since
  the Simulator here runs without a window): draft flow usable, content scrolls between
  the bars. Later the same day Caleb chose portrait only on iPhone (below).
- Home Screen: the new icon renders; touch and hold shows New Invoice and Add a Button;
  Add a Button opened the new-button steps on the Buttons tab.
- Finished invoice: Share and ⋯ at the top right, paid switch in its own row. The Share PDF
  button touched the summary card; moved to its own section.
- iPad: tabs at the top, readable width, the Repeat an Order tip shown.

Not checked by Claude: shake to undo (Device Hub has no Shake; ⌘Z, the same undo, was
checked later the same day), Siri phrases, drag and drop, ⌘N with a keyboard.

`make test`: 35 tests in 9 suites passed.

## Fixes after Caleb's first M2 run (Claude, Oct 8, 2026)

- `make sim` (Part 2, step 1): Xcode 27.0 (27A266a) ships no Simulator app; its
  Contents/Applications has Device Hub (com.apple.dt.Devices) instead. run-sim.sh now opens
  Simulator if present, otherwise Device Hub, and no longer fails if neither opens.
  Rerun: exit 0, Device Hub showed the iPhone 17 with the app.
- Device Hub's menus: Controls → Home ⇧⌘H, App Switcher ⌃⇧⌘H, Rotate Left ⌘←, Rotate
  Right ⌘→; Device → Accessibility, Appearance, Orientation. No Shake in Device, Controls
  or Edit. With its window in front, ⌘Z undid a deleted invoice (0260903 came back), so
  Docs/m2-test.md, Part 4, step 3 uses ⌘Z; shaking is left to M3 on a real phone.
- iPhone portrait only (Caleb's call): built Info.plist has
  UISupportedInterfaceOrientations~iphone = Portrait, ~ipad = all four. ⌘← turned the
  iPhone; the app stayed upright.
- Found while checking: ⋯ on a finished invoice and on a draft opened a menu holding only
  "More ›" (the secondary toolbar placement puts the item inside the system's own overflow
  menu), so every action took two taps. Now one tap shows Duplicate, Make Changes… and
  Delete… (finished) or Delete Draft… (draft).
- Delete questions on iOS 26 point at their source. From the list, the question pointed
  near the top of the screen instead of the invoice. Attached to the row it pointed at the
  row from touch and hold, but never appeared from a swipe until it waited 0.4 s for the
  row to slide closed. Now both point at the row; from ⋯ it points at ⋯.
- Icons invisible on filled buttons (Caleb, Oct 8): inside a list row SwiftUI colors a
  Label's icon with the accent color, the same as the button's fill. Share PDF, Add a
  Button and Add Shipping in a draft showed no icon; New Invoice was fine only because it
  set its label style. All filled buttons now use one style, `prominentButton()` (and
  `glassProminentButton()`), that keeps the icon white like the title. Rechecked in Device
  Hub: New Invoice, Share PDF, Add a Button, Add Shipping, Next, Finish, the sheet's ✓ and
  the Buttons tab's Add a Button all show their icons.

## Caleb's five notes (Oct 8, 2026)

Checked by Claude in Device Hub, iPhone 17, iOS 27.0, with its on-screen keyboard.

1. Quantity took letters from a hardware keyboard ("text"). Number fields now keep only
   digits (dollars and percents: one decimal point, two places), however the text
   arrives. The filter on sample inputs: "12ab" → "12", "1,234" → "1234", "$1,234.567" →
   "1234.56", "4.5.6" → "4.56", "-3" → "3". Pasting "nothing is pushed" into the quantity
   left it empty. Settings' routing and account numbers take digits only too.
2. Done bar removed. Tapping outside a field puts the keyboard away: checked from the
   quantity (tap on the heart card) and the SKU (tap on a section header). The editors now
   close the keyboard only when she drags it down, not on any scroll.
3. After a color, sizes are always offered: Heart → Red shows "Which size?" with
   **✓ Medium** and **+ Another Size**.
4. Colors are chips: picked ones in orange with ✕ (White ✕ took White off and put it back
   in the list; Black joined as Blue ✕ Black ✕). New Color → "Sage" → Add picked it and
   kept it in the list after it was taken off. A touch-and-hold "Remove from List" on
   added colors didn't open inside the form row in the Simulator, so it was dropped; an
   added color stays in the list. The test color was cleared afterwards.
5. Keyboard overlap: the price row ended about 19 points above the number pad; the SKU
   row, which Caleb's screenshot showed cut off, now sits fully above the keyboard.

Found while checking:

- A tap in the top or bottom 15 points of a 56-point field row missed the field (the
  price field is 26 points tall; logged frame (34, 15, 320 × 26) and tap at y = 42). It
  happened in the previous build too. Any tap in a row with one field, its label
  included, now goes into the field; tapping "SKU" opened the SKU field.
- "Discard your changes?" appeared mid-form. It now comes from the ✕ that asked;
  swiping the form down still asks. Discard Changes left Clover as Blue / White.
- The New Color chip first rendered as a tall "+" pill (a Label in a list row stretches);
  fixed.

## Caleb's next three notes (Oct 8, 2026)

- Color chips: each has a dot of its color, left of the name, with a white ring on the
  orange picked chips. Her glazes come from the median color of each single-color button
  photo in the seed catalog: Red heart #DE3F19, Burgundy heart #B04444, Navy heart
  #131C44, Lavender ellipse #BFAAC9, Matte Pink nautilus #CFA493, Celadon dogwood
  #A1AB8F, Brown nautilus #AA511C. Some medians were pulled off by an outline or
  highlight (Blue crab #97846D, the crab's brown outline; Pale Pink cowrie #C9D0CA;
  Ivory dogwood #A49E95), so those were set by eye from the photos. About 60 common
  color words ("Sage", "Light Blue", "Navy Blue") get a dot too; an unknown word gets
  none. `make test`: 37 tests in 10 suites passed (new: every saved color has a dot;
  color words read right).
- Row corners: the photo now sits on the same white card as Take Photo and Choose from
  Photos (new-button step 1 and Change Button), so the card's top corners are rounded.
  Skip Photo is plain text under Next, and Remove from Invoice has its own card, for the
  same reason.
- Change Button: Delete This Button has a trash icon; "Before your changes" is now
  "Earlier versions". The trash icon first took the accent color while the text was red
  (a list colors row icons with the accent); it is red now, as is Remove from Invoice's.

Checked in Device Hub: Bunny's Change Button screen (photo card, dots on all 16 colors,
trash icon, Earlier versions), new-button step 1, and a line's Change Line screen in a
throwaway draft, deleted afterwards.

## M2 results (Caleb)

Use the Part N, step M labels from Docs/m2-test.md.

| Step | Result |
|---|---|
| Part 1, step 1 | Pass: "Test run with 35 tests in 9 suites passed after 6.765 seconds" |
| Part 1, step 2 | Pass: "Wrote build/sample-pdfs (cutouts of the raw photos are in build/sample-pdfs/cutouts)" |
| Part 1, steps 3–5 | Not reported |
| Part 2, step 1 | Fail (Oct 8): `make sim` built the app, then stopped with "Unable to find application named 'Simulator'" and "make: *** [sim] Error 1". Fixed (above); rerun |
