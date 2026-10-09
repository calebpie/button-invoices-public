# UI nits

Small UI issues Caleb notices, logged as they come up and fixed together in the bug bash
before the app goes to her iPhone (SPEC.md, Milestones; Docs/m3-test.md, Part 2). Each
entry says what Caleb saw, how it was reproduced, what was found, the likely cause and what
to try. App code isn't changed for a nit until the bug bash.

| # | Nit | Where | Status |
|---|---|---|---|
| 1 | Grey strip under the tab bar as the keyboard goes away | Buttons, search | Open |
| 2 | "Hello, Daphné." fades in place instead of sliding with the page | Invoices, opening an invoice | Open |
| 3 | The receipt photo can't be opened full size to check the amount | Invoice step 2, Shipping | Fixed; Caleb to check |
| 4 | Swipe-delete: the row vanishes before she confirms; after she confirms, it vanishes with no animation | Invoices list | Fixed; Caleb to check |
| 5 | One letter in search finds nothing and says "No Results" | Buttons search; Add a Button in an invoice | Fixed |
| 6 | Closing search with text in it: the shape cards jump up, then back down | Add a Button in an invoice | Open |

## 1. Grey strip under the tab bar as the keyboard goes away

**Reported** (Caleb, Oct 8, 2026, iPhone): closing search on the Buttons tab, the keyboard
goes away as usual, but a grey bar about half an inch tall stays at the bottom of the
screen, under the tab bar, for a moment before it also disappears.

**Reproduced** (iOS 27.0 Simulator, iPhone 17, on-screen keyboard, screen recording at
30 fps; times are within each recording):

- ✕ tapped at about 1.60 s. The keyboard slides down from 1.63 s. Its rounded top edge
  shows below the floating tab bar as a grey strip: about 58 points tall at 1.73 s, 28 at
  1.77 s, 19 at 1.80–1.83 s, gone at 1.87 s.
- The keyboard's blue search key instead (search stays open, only the keyboard goes): the
  same strip at 1.97–2.03 s. So it comes with any keyboard dismissal on this screen, not
  with ✕ in particular.
- With ✕ only: the part of the list that was under the keyboard stays empty (plain
  background) for about 0.3 s, 1.67–2.00 s, before the rows below "Crab" appear.

**Cause:** the strip is the system keyboard itself, sliding out under the tab bar. The tab
bar floats with clear space beneath it, so the last stretch of the keyboard's slide shows
through there. The empty stretch: on ✕ the full list replaces the search results while the
keyboard is still leaving, and the rows that had been under the keyboard aren't drawn
until it has gone.

**To try in the bug bash:**

- First compare with Apple's own apps that have a tab bar and a keyboard. If they show the
  same strip, it's iOS's look; probably leave it.
- Hide the tab bar while the search keyboard is up and bring it back once the keyboard has
  gone, so nothing sits over the keyboard's slide.
- For the empty stretch: switch back to the full list only after the keyboard is down, or
  without animation.

## 2. "Hello, Daphné." fades in place instead of sliding with the page

**Reported** (Caleb, Oct 8, 2026): on the Invoices tab, New Invoice slides the Invoices
page left to show the new invoice, but the header, "Hello, Daphné.", grows and dissolves
instead of moving with the page.

**Reproduced** (iOS 27.0 Simulator, iPhone 17, screen recording at 30 fps):

- New Invoice, 1.70–2.00 s: the page content ("What would you like to do today?", New
  Invoice) slides left. "Hello, Daphné." stays where it is, grows slightly, blurs and has
  faded by 1.86 s, while the invoice's bar (back arrow, "Invoice 0261008-2", ⋯) fades in.
- Back arrow, 9.07–9.27 s: the reverse. The greeting fades back in where it sits, blurred
  then sharp, instead of sliding in from the left.
- The same happens opening any invoice from the list. Invoices is the only tab that opens
  screens this way; Buttons and Settings use sheets.

**Cause:** the greeting is drawn as an item in the navigation bar (`shrinkingTitle` in
Platform.swift), so it can sit level with bar buttons and shrink as she scrolls. When a
screen opens, iOS cross-fades the old and new bar items in place (iOS 26's blur and scale);
only the page content slides. The Buttons tab already avoids this: its title is in our own
bar (`safeAreaBar`), part of the page.

**To try in the bug bash:** use the Buttons tab's own bar for Invoices (and Settings, so
all three tabs stay identical), so the title moves with the page. Then watch the push and
pop, including the back swipe: the Invoices page hides the navigation bar and the invoice
screen shows its own, and that bar's appearance should look clean while sliding.

## 3. The receipt photo can't be opened full size to check the amount

**Reported** (Caleb, Oct 8, 2026): when adding shipping from a receipt photo, on the screen
where she taps the amount for this order, tapping the receipt should open it full size so
she can pan and zoom and check the amount with her own eyes.

**Reproduced** (iOS 27.0 Simulator, iPhone 17; a test draft, deleted afterwards): New
Invoice → Bunny, Black / White, quantity 1 → step **2 Shipping** → **Add Shipping** →
**Choose from Photos** → the receipt (IMG_9049). The sheet shows $36.48 filled in and the
amounts $36.48 / $19.58 / $16.90 under the photo.

- Tapping the photo: nothing happens. Pinching it (two fingers spreading over 0.3 s):
  nothing happens.
- The photo is 165 × 220 points on screen (measured from a 3x screenshot: x 118.7–283.7,
  y 301.3–521.3).
- On it, the digits of the Subtotal "$36.48" are 3.7 points tall and 10.3 wide, against
  17-point text elsewhere in the sheet. The receipt's amounts can't be read at that size.
- The same screen opens when she taps a saved shipping line to change it, so it has the
  same gap.

**Cause:** the photo is a plain picture capped at 220 points tall
(`.frame(maxHeight: 220)` in ShippingEditorView.swift), with nothing attached to a tap.
What's stored is enough to zoom: the photo comes in at 1600 pixels on its long side
(`Photos.workingSize`), 2.4 times the 660 pixels shown. Fitted to the full screen width it
would be about 536 points tall, so the same digits would be about 9 points, at the photo's
own resolution; zooming further would show them larger but softer.

**To try in the bug bash:**

- Tap the photo to open it in Quick Look, as the Review and finished-invoice screens already
  do for the PDF (`quickLookPreview`, "Tap the page to see it full size."). Quick Look gives
  pinch, double-tap and pan zoom and a Done button. Write the receipt to a temporary JPEG
  for it, and add the same hint under the photo and to its VoiceOver label ("Double-tap to
  see it full size").
- Check Quick Look opens from inside the Shipping sheet, and how its Share button looks to
  her (it would let her save or send the receipt, which is harmless).
- Alternative, if she'd want the amounts beside the zoomed receipt: our own full-screen
  view with a zoomable photo and the amount buttons at the bottom. More code; only if Quick
  Look's round trip (look, Done, tap the amount) proves awkward.
- If the zoomed digits look too soft on her iPhone, keep receipts at a higher resolution
  (for example 3000 pixels, as dropping a photo in on iPad already reads them).

**Fixed** (bug bash, Oct 8, 2026): tapping the receipt opens it full screen in the app's
own viewer (ReceiptViewer.swift), not Quick Look. Under the photo: "Tap the receipt to see
it full size." (VoiceOver: "Receipt photo. Double-tap to see it full size.").

- Tried Quick Look first, as the note proposed. It opened from inside the Shipping sheet,
  but with the photo filling the screen and no Done button or title showing; they appeared
  only after tapping the picture. Its bottom bar also offered Markup. For her, a screen with
  no visible way out is worse than the nit, so not used.
- The viewer: title "Receipt", the app's ✓ button at the top right (always showing), the
  photo fitted to the screen, and pinch, double-tap and drag to zoom. Along the bottom, the
  same "Tap the amount for this order:" buttons as the sheet; tapping one fills the amount
  and closes the viewer, so she can check and pick in one place (the note's alternative).
- Opening a saved shipping line shows the photo with no amounts (they're read only when the
  photo is chosen), so the viewer shows just the photo and ✓.

**Rechecked** (iOS 27.0 Simulator, iPhone 17; a test draft from Duplicate on 0260903,
deleted afterwards): Add Shipping → Choose from Photos → the receipt (IMG_9049): $36.48
filled in, hint under the photo. Tap the photo: the viewer, receipt fitted to the width,
amounts at the bottom. Double-tap on the circled total: zoomed to about 3 times, the
digits about 30 points tall and sharp. Tap $19.58: the viewer closes, the sheet shows
19.58 with $19.58 highlighted. Open it again, tap ✓: closes, amount unchanged. Pinch not
tried in the Simulator.

**Check** (Caleb, iPhone): a draft → step 2 → Add Shipping → Choose from Photos → a receipt.
Tap the photo: it fills the screen. Pinch and double-tap to zoom, drag around. Tap an
amount at the bottom: back to the sheet with that amount filled in. Open it again, tap ✓.

## 4. Swipe-delete: the row vanishes before she confirms; after she confirms, it vanishes with no animation

**Reported** (Caleb, Oct 8, 2026, iPhone, Docs/m3-test.md, Part 1, step 10): on the
Invoices tab, swiping an invoice left and tapping **Delete** makes the row disappear for a
moment, then come back with the "Delete invoice…?" question pointing at it. The row
shouldn't go anywhere until she taps **Delete Invoice**. And once she does, the row vanishes
without an animation and everything below jumps up without a transition.

**Reproduced** (iOS 27.0 Simulator, iPhone 17, screen recording at 30 fps; a test draft made
with Duplicate from Invoice 0261008, deleted in the recording):

- **Delete** tapped at about 8.43 s. 8.47–8.53 s: the row shrinks away and the Drafts
  section is left with only its footer. 8.60–8.80 s: the Paid section has slid up about 94
  points (the row's height). 8.87 s: the row is back in a single frame and Paid jumps down
  again, with no animation either way. 9.27–9.40 s: the question appears over the row.
- **Delete Invoice** tapped at about 17.0 s. 17.15–17.35 s: the question shrinks back into
  the row. 17.68 s: the row is still there. 17.75 s: in one frame, the Drafts header, the row
  and its footer are gone and everything below has moved up 169 points (the "Paid" header,
  measured in screenshots before and after: 411 → 242 points from the top).
- Not checked yet: the same question from touching and holding the row (**Delete…** in its
  menu). From the code, that path shouldn't make the row vanish first (no swipe action is
  involved), but the final delete should jump the same way.
- Also seen: for a draft, the question reads "Delete draft 0261008-2?" but its button says
  **Delete Invoice**; the invoice screen's ⋯ menu says **Delete Draft…**.

**Cause:**

- The vanishing row: the swipe's Delete button has the destructive role
  (`role: .destructive`, InvoicesTab.swift). SwiftUI's list treats a destructive swipe
  action as the delete itself and animates the row out at once. Nothing was deleted (the
  question is asked 0.4 s later), so the next update puts it back, unanimated. The 0.4 s
  wait in that button ("Asked once the row has slid closed") was likely working around
  this same removal.
- The jump after confirming: `InvoiceActions.delete` deletes outside an animation, and the
  list's `@Query` has none of its own, so the list redraws without the row in one step.
  Because it was the only draft, the whole Drafts section went with it.

**To try in the bug bash:**

- The swipe button without the destructive role, colored red with `.tint(.red)`, so the
  row only slides closed. Then check whether the 0.4 s wait is still needed; drop it if the
  question appears without it.
- Delete inside `withAnimation` (or give the `@Query` an animation), so the row collapses
  and the rows below slide up. Check undo too (shaking puts the invoice back): it should
  slide back in, not pop.
- Match the button to the question: **Delete Draft** for a draft, **Delete Invoice** for
  the others.

**Fixed** (bug bash, Oct 8, 2026; InvoicesTab.swift):

- The swipe's Delete button no longer has the destructive role (red with `.tint(.red)`), so
  the row only slides closed. The 0.4 s wait is gone; the question still appears.
- The list's `@Query` is animated, so a deleted invoice collapses and one put back by undo
  slides in.
- With the animation, the fading row showed "$0.00 · 0 kinds of buttons" for about 0.15 s
  (its lines are deleted with it). `InvoiceRow` now keeps what it last showed once its
  invoice is deleted.
- The button says **Delete Draft** for a draft, **Delete Invoice** otherwise, and so does the
  shake prompt ("Undo Delete Draft").

**Rechecked** (iOS 27.0 Simulator, iPhone 17, recordings at 30 fps; top of the first Paid
row's check mark, in points from the top):

- Delete tapped: the row slides closed (pencil icon back in place at 10.87 s); Paid stays at
  470 throughout. Nothing vanishes. The question appears pointing at the row.
- Delete Draft tapped: Paid slides 470 → 301 between 16.07 and 16.53 s (0.46 s, easing out);
  the draft row fades with "$3,723.00 · 3 kinds" shown to the end.
- Shake → Undo: Paid slides back 301 → 470 between 30.73 and 31.17 s, the draft row fading
  in.
- Not checked on screen: **Delete…** from touching and holding the row; it uses the same
  question and delete.

**Check** (Caleb, iPhone): Invoices → Duplicate any invoice (swipe right) → back → swipe the
new draft left → **Delete**: the row only slides closed, then "Delete draft …?" with a
**Delete Draft** button. Tap it: the row fades and the rest slides up. Shake → **Undo**: it
slides back in. Repeat with touch and hold → **Delete…**.

## 5. One letter in search finds nothing and says "No Results"

**Reported** (Caleb, Oct 8, 2026, iPhone, after Docs/m3-test.md, Part 1, step 7): on the
Buttons tab, typing "H" in search shows no results and says it found none. If search needs
more than one letter, it should say so when only one is typed.

**Reproduced** (iOS 27.0 Simulator, iPhone 17, on-screen keys):

- "H": "No Results for "H"" and "Check the spelling or try a new search." Nothing listed.
- "He" (one more letter): Heart, Burgundy, Medium; Heart, Navy, Medium; Heart, Red,
  Medium.
- The same search runs in an invoice's Add a Button sheet (`Catalog.search`, called from
  AddLineSheet.swift), where one letter would show "No saved button matches "h"."; seen in
  the code, not checked on screen.

**Cause:** `Matcher.score` (Packages/InvoiceKit/Sources/InvoiceKit/Matcher.swift) counts a
word she is still typing as a match only from 2 letters up (`w.count >= 2`, the "still
typing" prefix rule). A single letter matches no whole word either, so every button scores
0 and the list is empty. The 2-letter floor keeps stray letters in longer searches ("12 x
red") from matching everything.

**Her catalog** (App/Resources/Seed/catalog.json): 19 designs and 37 buttons. No letter
starts more than 4 designs ("s": 4; "c": 3); by buttons, the biggest is "n" with 9
(Nautilus). "h" starts only Heart: 3 buttons.

**Decided** (Caleb, Oct 8, 2026): the recommended fix below, one letter matching design
names. Not the "Keep typing" hint.

**To try in the bug bash:**

- Recommended: let a search of one letter match the start of design names only ("h" →
  the 3 Hearts, "s" → 5 buttons), not colors, which would match most buttons ("b": black,
  blue, burgundy…). Lists that small are useful from the first letter, which is how the
  search in Apple's own apps behaves, and nothing needs explaining. Keep the 2-letter floor
  for words in longer searches. Add a case to MatcherTests.
- Caleb's suggestion, if one letter should still match nothing: in place of "No Results",
  show a hint such as "Keep typing to search buttons." while only one letter is typed, in
  both the Buttons tab and Add a Button.

**Fixed** (bug bash, Oct 8, 2026): when the whole search is one letter, `Matcher.score`
matches it against the start of the design name only, so "h" lists the 3 Hearts and "s"
lists Star, Shell, Sailboat and Strawberry (5 buttons), not Cowrie Shell or any color.
In longer searches a single letter still counts for nothing. New test:
`MatcherTests.oneLetterMatchesDesignNames` ("h", "S", "s", "b" → only Bunny, "z" → none,
"red h" ranks like "red"); all 38 InvoiceKit tests pass. Simulator (iPhone 17): Buttons,
search, "H" → Heart, Burgundy / Navy / Red, Medium.

**Check** (Caleb, iPhone): Buttons → search → type "H": the three Hearts. Then type "S":
Sailboat, Shell, Star (2), Strawberry. Then in an invoice, Add a Button → type "h": the
three Hearts.

**Checked** (Caleb, Oct 8, 2026, iPhone): Pass.

## 6. Closing search with text in it: the shape cards jump up, then back down

**Reported** (Caleb, Oct 8, 2026, iPhone 17 Simulator, screen recording 19.32.23): in an
invoice, Add a Button → search → type "he" → ✕. The close isn't clean: the button cards
jump up, then back down to where they belong.

**From the recording** (11.1 s, frames every 1/30 s; positions in points from the top,
measured from the frames; "first color" is the top of the first card photo):

- "he" typed by 8.53 s: the three Hearts, heading "Which button? Tap it." at 153, first
  photo at 203.
- ✕ at about 8.57 s: the text clears. 8.60–8.83 s: the search field slides back down
  under the returning "Add a Button" title while the Hearts fade out and the shape grid
  fades in; the heading text overlaps the title in these frames.
- 8.87–8.97 s (4 frames): the shape grid is drawn about 140 points too high, its first
  photos at the top of the content area (120, the top of the measured range, or above),
  behind the search field.
- 9.00 s: in one frame, everything drops to its final place: heading at 146, first photo
  at 261. Steady from then on.
- With an empty field the content doesn't change on ✕ (the shape grid is already showing),
  which fits Caleb seeing it only with characters typed. Not yet checked on screen.

**Likely cause:** two changes in the same moment. ✕ clears `search`, which swaps the
content from the results to the shape grid (ShapePickerView in AddLineSheet.swift, a
different layout of a different height), while the navigation bar grows back from the
search-only bar to title plus search field. The new grid is laid out against the
shorter bar's top inset, then corrected in one step when the bar settles. The Buttons
tab is different: its search comes and goes through `searchOnRequest` (Platform.swift).

**To try in the bug bash:**

- Keep showing the results until the search has finished closing, then switch to the
  shape grid (for example, drive the content from the field's `isPresented` state, or
  switch after the dismissal instead of when the text clears).
- Or make the swap itself animated in the same transaction as the bar, so the grid moves
  with the bar instead of jumping.
- Check the same close on the Buttons tab (nit 1 already covers its keyboard strip), and
  the Cancel/✕ of the sheet itself while search is active.
