# UI nits

Small UI issues Caleb notices, logged as they come up and fixed together in the bug bash
before the app goes to her iPhone (SPEC.md, Milestones; Docs/m3-test.md, Part 2). Each
entry says what Caleb saw, how it was reproduced, what was found, the likely cause and what
to try. App code isn't changed for a nit until the bug bash.

| # | Nit | Where | Status |
|---|---|---|---|
| 1 | Grey strip under the tab bar as the keyboard goes away | Buttons, search | Fixed (the list); strip left as iOS's; Caleb to check |
| 2 | "Hello, Daphné." fades in place instead of sliding with the page | Invoices, opening an invoice | Fixed; Caleb to check |
| 3 | The receipt photo can't be opened full size to check the amount | Invoice step 2, Shipping | Fixed; Caleb to check |
| 4 | Swipe-delete: the row vanishes before she confirms; after she confirms, it vanishes with no animation | Invoices list | Fixed; Caleb to check |
| 5 | One letter in search finds nothing and says "No Results" | Buttons search; Add a Button in an invoice | Fixed |
| 6 | Closing search with text in it: the shape cards jump up, then back down | Add a Button in an invoice | Fixed; Caleb to check |
| 7 | Search circle: opens slowly; on close it collapses mid-bar, then slides over | Buttons tab, search | Fixed; Caleb to check |
| 8 | The PDF page's top corners are rounded off | Finished invoice, "The PDF" | Fixed; Caleb to check |
| 9 | More space below New Invoice than above it | Invoices | Fixed; Caleb to check |
| 10 | The Buttons title sits further left than the other tabs' titles | Buttons tab | Fixed; Caleb to check |
| 11 | "Archived (1)" can't be opened, so archived buttons can't be seen or unarchived from the list | Buttons tab | Fixed; Caleb to check |
| 12 | A discount bigger than the price shows a negative line total, and Add is greyed out with no reason | Quantity screen | Fixed; Caleb to check |
| 13 | "Add a Button" means two different things | Invoice step 1; Home Screen, Siri, Buttons + | Fixed (spec changed); Caleb to check |
| 14 | The missing-bank-details warning sends her to "Home → Business details", which doesn't exist | Invoice step 3, Review | Fixed; Caleb to check |
| 15 | Two ‹ back buttons on a draft, each going somewhere different | Draft invoice | Fixed (spec changed); Caleb to check |
| 16 | Questions show only the red button; "Keep Editing" and Cancel never appear | Discard and Delete questions | Fixed; Caleb to check |
| 17 | The orange "why can't I go on" text is 2.1:1 in light mode | New Button step 3, Change Button | Fixed; Caleb to check |
| 18 | The big camera picture on the photo step looks tappable but does nothing | New Button step 1 | Fixed; Caleb to check |
| 19 | Step 3 picks the shape from a list of 20 names, no photos | New Button step 3, Change Button | Fixed; Caleb to check |
| 20 | Picking a saved shape leaves size "One size" and price empty, so a near-duplicate is easy | New Button step 3 | Fixed; Caleb to check |
| 21 | "Change" buttons are 24 points tall | Invoice step 3, Review | Fixed; Caleb to check |
| 22 | "Already Saved" reads like a label, and the two card buttons differ in size | New Button step 2 | Fixed; Caleb to check |
| 23 | Side margins are 16 points on some screens and 20 on others | Draft bars, Review, Add a Button, new-button steps, photo | Fixed; Caleb to check |
| 24 | Remove Shipping hangs under the bare Save button, with square corners and no icon | Shipping sheet (changing a charge) | Fixed; Caleb to check |
| 25 | Unreached steps in the step bar are 1.6:1, too faint to read | Draft step bar | Fixed; Caleb to check |
| 26 | Invoice rows wrap "of buttons" onto a third line | Invoices list | Fixed; Caleb to check |
| 27 | A 1-pixel seam crosses the Paid card | Invoices list | Fixed; Caleb to check |
| 28 | The draft's ⋯ menu holds one item | Draft invoice | Fixed; Caleb to check |
| 29 | Same thing, different words: Town / City, No price / No price yet / $0.00, alert capitals | Settings, Buttons, New Button | Open (UX review; polish) |
| 30 | The line total, the number that matters, is in grey | Quantity screen | Open (UX review; polish) |
| 31 | Red, burgundy and brown dots vanish on picked (orange) color chips | New Button step 3, Change Button | Open (UX review; polish) |
| 32 | Two prominent confirm buttons on one sheet | Add to Invoice, Change Line, Change Button, Shipping, photo | Open (UX review; polish; spec) |
| 33 | The receipt viewer closes with ✓, though nothing is confirmed | Receipt viewer | Open (UX review; polish) |
| 34 | The PDF page is a picture with a tap, not a button: no press feedback | Review, finished invoice | Open (UX review; polish) |
| 35 | Saved-color captions under the shape are cut off ("Burgundy,…") | New Button step 3, Change Button | Open (UX review; polish) |
| 36 | Row separators start 64–84 points in from the card's left edge but end 20 from its right | Invoices list, Buttons tab | Fixed; Caleb to check |

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

**Rechecked after nit 7** (Oct 8, 2026; iOS 27.0 Simulator, iPhone 15 Pro Max, on-screen
keyboard, 30 fps; the tab bar spans y 851–910, so 22 points of screen show below it):

| Time (s) | Keyboard's top edge, x 20 (y) | Grey below the tab bar |
|---|---|---|
| 11.27 | full keyboard | — |
| 11.40 | 864 | none (the keyboard covers the tab bar) |
| 11.43 | 897 | 22 pt, the whole gap |
| 11.47 | 915 | 17 pt |
| 11.50 | 925 | 7 pt |
| 11.53 | gone | — |

The empty stretch had changed with nit 7's fix, which cleared the text only once the field
had closed: the title "Buttons" was back by 11.57 s with the three "He" results still
under it, and the full list snapped in at 11.83 s.

**Apple's own app** (Files, Recents tab, same Simulator; it has the same floating tab bar,
and its search field and ✕ move to the top like ours): the keyboard's top edge at x 20 is
at y 872 at 18.47 s, 901 at 18.50 (about 22 pt below its tab bar, which ends at y 909),
917 at 18.53, 926 at 18.57, gone at 18.60. The same grey slab, the same height, gone after
the same 3 frames. So the strip is iOS 26's look, and it stays. The keyboard is its own
window above the app; nothing the app draws can cover its slide.

**Fixed** (Oct 8, 2026; CatalogView.swift, Platform.swift `SearchTitleBar.close`), the
list part:

- The search results now lie over the whole list instead of replacing it, as iOS's own
  search results do. The list stays drawn underneath, hidden from VoiceOver while she
  searches, so ✕ uncovers it rather than rebuilding it.
- ✕ clears the text at once again. Rebuilding the list was what held the field still for
  0.1 s (nit 7); uncovering it doesn't.

**Checked** (same Simulator; 🔍, "he", ✕):

| | Before | After |
|---|---|---|
| ✕ to the full list | 0.55 s (results under the title from 11.57, list at 11.83) | one frame (results at 14.57, list at 14.60) |
| Rows that were under the keyboard | there, as the list was drawn late | there, as the keyboard slides away |
| ✕ to the field moving | one frame | one frame (moving from 14.63, at rest by 15.00) |

Also checked:

- Scrolling the list still shrinks the title, with the frosted edge under the bar.
- "Q" still shows "No Results for "Q"". Its near-white background (f8f8f8, against the list's
  f0f0f0) is the same as before the change.
- Scrolled down to Crab, then 🔍, "q", ✕: the list is still at Crab, title small.

**Check** (Caleb, iPhone): Buttons → 🔍, type "he", ✕: the whole list is back at once as
the field closes, with no results left under the title and no empty space where the
keyboard was. The grey strip under the tab bar as the keyboard leaves is still there: the
Files app does the same.

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

**Fixed** (Oct 8, 2026): on iOS 26, `shrinkingTitle` (Invoices and Settings) now draws the
title in our own bar like the Buttons tab, and hides the navigation bar. Both bars share one
row (`BarRow` in Platform.swift), so all three tabs line up (nit 10). Before iOS 26 nothing
changes. Settings' form lost the 35 points above its first card when the navigation bar went
away; `contentMargins` puts them back.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, recording at 30 fps):

- Opening Invoice 0260819 from the list (11.27–11.73 s): "Hello, Daphné." slides left with
  the page. The invoice's bar (‹, "Invoice 0260819", ⋯, Share) fades in over the first
  frames as it did before, overlapping the sliding greeting for about 0.1 s.
- Back button on Invoice 0260903 (18.37–18.77 s): the greeting slides in from the left with
  its page; the invoice's bar slides out with its page.
- Back swipe (13.4–14.6 s): the greeting follows the finger with the page.
- At rest, nothing moved: Invoices title at x 22.0, subtitle baseline y 117.3, New Invoice
  y 139.3–201.3, "Paid" at y 233.3; Settings title x 21.3, first card's text at y 187.3. All
  the same as before.
- Scrolling still shrinks the title on Invoices, with the same frosted edge under the bar as
  the Buttons tab.

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

**Fixed** (Oct 8, 2026; AddLineSheet.swift, `ShapePickerView`): once she types, the content
ignores the keyboard (`ignoresSafeArea(.keyboard)`) and keeps its own room under it (bottom
padding the keyboard's height, so the last results still scroll clear of it), until the
keyboard has gone. With nothing typed, nothing changes.

- The Simulator needs the on-screen keyboard to show this. With the Mac keyboard attached
  iOS hides it, and ✕ closes smoothly. Turned on for the iPhone 15 Pro Max with
  `xcrun simctl spawn <device> defaults write com.apple.keyboard.preferences
  AutomaticMinimizationEnabled -bool NO` and a restart of the simulated iPhone.
- The cause isn't the switch from results to shapes, as first thought: keeping the results
  showing until the search had closed, they jumped the same way (4.30–4.50 s, then down at
  4.53). Closing with nothing typed doesn't jump. Closing with text clears it, so the sheet
  redraws in the middle of the bar's and keyboard's animations, and the content, following
  the keyboard's shrinking space in that redraw, is drawn too high. Ignoring the keyboard
  everywhere fixed it (probe), but then closing while scrolled to the end of the shapes
  jumped instead, by about two rows, where the original slides smoothly; hence only once
  she types.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, on-screen keyboard, recordings at
30 fps; points from the top, the heading's letters at x 60):

- "n" typed (9 Nautilus results), ✕: the heading moves 164 → 171 → 185 → 196 → 204 → 209 →
  212 (2.06–2.30 s) and stays; the shapes fade in in place. Before: drawn about 130 points
  too high for 5 frames ("ge", 4.27–4.43 s), then down in one frame.
- Nothing typed, the shapes scrolled to the end with the keyboard up, ✕: slides from 2.00 to
  2.33 s and ends where the original code does (same rows at y 250, 319, 387).
- "n" typed, keyboard up: the results scroll up until Add a New Button sits above the
  keyboard.

**Check** (Caleb, iPhone): a draft → Add a Button → tap the search, type "he" → ✕ at the
top right. The shapes come back without jumping up first. Then type "n" and scroll down:
Add a New Button can be scrolled above the keyboard.

## 7. Search circle: opens slowly; on close it collapses mid-bar, then slides over

**Reported** (Caleb, Oct 8, 2026, iPhone 17 Simulator, screen recording 19.37.22): on the
Buttons tab, the 🔍 circle grows into the search field a bit too slowly. And closing
it, the field first shrinks into a circle that stays toward the middle of the bar, then
jumps over to its place, with the 🔍 icon sliding in.

**From the recording** (5.8 s, every frame 1/30 s, the top bar only; x in points from the
left):

- Opening: 🔍 pressed (highlighted) from 1.50 s. Nothing moves until 1.70 s. The title
  fades and the circle stretches left into the field from 1.70 s; the field reaches about
  its full width at 2.10 s and stops moving at 2.23–2.27 s. So about 0.55 s of movement,
  and about 0.75 s from the press to rest.
- Closing: ✕ tapped about 3.35 s (it greys from 3.37 s). The full field (x 16–332) is
  there at 3.43 s and gone at 3.47 s, in one frame: in its place is a 44-point circle at
  x ≈ 174, the middle of where the field was, showing a clipped piece of the placeholder
  ("…ns" of "Search buttons"). The circle sits there to 3.53 s, then moves right to the
  🔍 place beside + over 3.57–3.90 s, its 🔍 icon fading in as it moves; the title
  "Buttons" fades in from 3.57 s and the + turns back from ✕ over the same time.

**Apple's guidance:** the Human Interface Guidelines (Motion) give no durations; they
ask for brief, precise feedback that doesn't make people wait for the animation to finish.
The app uses `withAnimation(.smooth)` for both (Platform.swift, `SearchTitleBar.open` /
`close`), and `.smooth` is a spring of 0.5 s perceptual duration by default (SwiftUI,
`smooth(duration: TimeInterval = 0.5, extraBounce:)`), which matches the ~0.55 s measured.
Third-party guides (not Apple) suggest 0.3–0.5 s for transitions like this.

**Likely causes:**

- Slow: the 0.5 s default spring, plus ~0.2 s before anything moves after the press
  (possibly the button's own press-and-release before the action runs, not timed yet).
- The close: the field and the circle share one glass ID ("search"), so the glass morphs
  between them, but the content inside doesn't: the field's text and icon are removed at
  once, and the circle's glass starts at the field's centre with the new layout's content
  (the 🔍) arriving from where the field's contents were. `close()` also sets
  `focused = false` before the animation and clears `text` after it, outside it.

**To try in the bug bash:**

- A shorter spring for both, e.g. `.smooth(duration: 0.3)` or `.snappy(duration: 0.3)`,
  and compare frame by frame with iOS's own minimized search (a tab bar search tab) if
  one can be found in the Simulator's apps.
- For the close: animate the field's width down to the circle's size first (the field
  shrinking to the right, into the 🔍 place), then swap to the circle; or give the field's
  contents their own transition so they fade out as the glass shrinks; clear `text` and
  drop focus inside the same animation.
- Recheck the press-to-movement delay with a probe log at `open()`.

**Fixed** (Oct 8, 2026; Platform.swift, `SearchTitleBar`):

- The 🔍 circle and the search field are now one view that only changes width: opening grows
  it to the left into the field, closing shrinks it to the right back into place, the 🔍
  moving inside it. The field's text fades in and out with it.
- Both use `.smooth(duration: 0.3)` instead of `.smooth`'s 0.5 s.
- ✕ clears the text once the field has closed, not at once: clearing it brings back the
  whole list, and drawing that held the field still for about 0.1 s before it moved. (Replaced in
  nit 1: the results now lie over the list, so ✕ clears the text at once.)

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, recordings at 30 fps):

| | Before | After |
|---|---|---|
| Open, first movement to rest | about 0.45 s | 0.27 s (2.17 → 2.43 s) |
| Close | a circle mid-bar with "…ns" in it (6.13 s), sliding right to 6.53 s | shrinks straight into place, 6.13 → 6.37 s |
| ✕ to first movement | about 0.1 s still | one frame (✕ greyed 6.10 s, moving 6.13 s) |

The full list comes back at 6.63 s, after the field has settled. Same with the on-screen
keyboard: ✕ greyed at 5.05 s, shrinking from 5.15 s, at rest 5.42 s. Press-to-movement on
opening wasn't timed (the Simulator's taps are instant).

**Check** (Caleb, iPhone): Buttons → 🔍: the circle stretches left into the field. Type
"he", then ✕: the field shrinks back to the right into the 🔍 circle, with no circle
left in the middle of the bar.

## 8. The PDF page's top corners are rounded off

**Reported** (Caleb, Oct 8, 2026, iPhone, dark mode, screenshot): on a finished invoice
(0260903), the picture of the PDF under "The PDF" has its top corners cut round, as if by
a container's corner radius.

**Reproduced** (iOS 27.0 Simulator, iPhone 17, Invoice 0260903; 3x screenshots, points):

- Dark mode: the page's top edge at y 540. Its left edge, going down from the top: x 23.3
  at the top row, 21.7 at 2 points down, 19.0 at 6, 17.7 at 10, 16.7 at 16, 16.3 from 18
  on. So a rounded corner of roughly 20 points; the right corner matches by eye.
- Light mode: the same rounding, but white page on the near-white background, so it
  barely shows. Same with the page's faint shadow.
- Not checked yet: the bottom corners (the page runs under the tab bar at this scroll),
  and the Review screen (step 3), which shows the same pages in a plain scroll view.

**Cause:** FinishedInvoiceView shows the pages as a row of its `List` (`Section("The PDF")`
with `PDFPages`, `.listRowBackground(Color.clear)`). On iOS 26 an inset-grouped list
clips each section's rows to the section's rounded card, about 20 points here; the clear
row background hides the card but not the clip. The page is a sharp-cornered rectangle
(PDFPages in ReviewView.swift), so its corners are cut.

**To try in the bug bash:**

- Take the pages out of the list's sections: show them below the list (for example the
  screen as a `ScrollView` like ReviewView, or the pages in a `safeAreaInset`/footer),
  so nothing clips them.
- Or keep them in the list and give the page itself a small corner radius and inset
  (for example 8 points in from the card's edges), so the card's corners fall outside it.
  Simpler, but the page would no longer look like a sheet of paper.
- Check the Review screen and the bottom corners in both modes.

**Fixed** (Oct 9, 2026; FinishedInvoiceView.swift): the pages are now the footer of the
"The PDF" section instead of its row. A list doesn't clip a footer to the section's card.
A footer is inset 20 points further than the cards, which made the page 350 points wide
(x 40–390) in a first try. It's padded back out by those 20 points, so it's as wide as
before and lines up with the cards above it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, Invoice 0260903; 3x screenshots,
points; the page's left and right edges going down from its top row):

| Points below the page's top | Before (light) | After (light) | After (dark) |
|---|---|---|---|
| 0 | 27.3 / 402.7 | 20.0 / 410.0 | 20.0 / 410.0 |
| 1 | 26.3 / 403.7 | 20.0 / 410.0 | 20.0 / 410.0 |
| 2 | 25.3 / 404.7 | 20.0 / 410.0 | 20.0 / 410.0 |
| 4 | 24.0 / 406.0 | 20.0 / 410.0 | 20.0 / 410.0 |
| 6 | 22.7 / 407.3 | 20.0 / 410.0 | 20.0 / 410.0 |
| 8 | 22.3 / 407.7 | 20.0 / 410.0 | 20.0 / 410.0 |

Also checked:

- The bottom corners (dark, scrolled to the end; page bottom at y 815): 20.0 / 410.0 on
  every row up to 8 points above it.
- The page's shadow now shows along its sides; before, the card cut it off.
- Tapping the page still opens it full size.
- Not checked on screen: the Review screen (step 3). It's a `ScrollView` with no list, so
  nothing clips its pages.

**Check** (Caleb, iPhone, dark mode): open Invoice 0260903 and scroll to "The PDF": the page
has square corners at the top and bottom, as wide as the cards above it.

## 9. More space below New Invoice than above it

**Reported** (Caleb, Oct 8, 2026): the New Invoice button on the Invoices tab could use more
room above it; there is more white space below it than above.

**Reproduced** (iOS 27.0 Simulator, iPhone 15 Pro Max, light mode; 3x screenshot, points
from the top of the screen):

- "What would you like to do today?": letters from y 107.7 to the baseline at 117.3 (the
  "y" descender to 119.7).
- New Invoice button: y 139.3 to 201.3 (62 points tall).
- The "Paid" section header's letters start at y 233.3.
- So 22 points from the line of text to the button (19.6 from the descender), and 32 points
  from the button to the next header: about 10 points more below.

**Cause:** the space above is set by hand (the subtitle row's bottom inset, 16 points, in
InvoicesTab's first `Section`); the space below is the list's own gap between sections plus
the header's top padding.

**To try in the bug bash:**

- Raise the subtitle row's bottom inset so the two gaps match (about 26 points), or match
  them by eye if the header's letters make an exact match look off.
- Check with no finished invoices (the empty state instead of "Paid") and with the tip
  showing, which also sit under the button, and at a large text size.

**Fixed** (Oct 8, 2026; InvoicesTab.swift): the subtitle row's bottom inset is 26 points
instead of 16, so New Invoice sits 10 points lower and everything below moves down with it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light mode; 3x screenshot, points):
subtitle baseline y 117.3 (descender to 119.3), New Invoice y 149.3–211.3, "Paid" letters
from y 243.3. So 32.0 points above the button and 32.0 below. Not checked: the empty state,
the tip and large text sizes (the gap above is fixed, the one below follows the text size).

**Check** (Caleb, iPhone): Invoices tab: the space between "What would you like to do
today?" and New Invoice now looks the same as between New Invoice and the next heading.

## 10. The Buttons title sits further left than the other tabs' titles

**Reported** (Caleb, Oct 8, 2026): the left padding of the page headers changes between
tabs; the Buttons header is a bit further to the left.

**Reproduced** (iOS 27.0 Simulator, iPhone 15 Pro Max; 3x screenshots, leftmost pixel of the
large title):

| Tab | Title | Left edge |
|---|---|---|
| Invoices | Hello, Daphné. | x 22.0 |
| Buttons | Buttons | x 18.0 |
| Settings | Settings | x 21.3 |

The list cards below start at about x 20.5 on all three. H and B have about the same space
before them in the font, so the Buttons title is about 4 points further left; Settings' S
starts a little further left than H by its shape.

**Cause:** Invoices and Settings put the title in the navigation bar (`shrinkingTitle`, a
`topBarLeading` toolbar item), which iOS places about 20 points in. Buttons draws its own bar
(`SearchTitleBar` in Platform.swift, so the search circle can open into the field), with
`.padding(.horizontal, 16)`.

**To try in the bug bash:**

- Pad the Buttons bar's title by 20 points instead of 16 (or measure iOS's toolbar inset and
  use that), keeping the circles on the right where they are, and recheck the left edges.
- If nit 2 moves Invoices and Settings onto the Buttons tab's own bar, set the inset once
  there instead.
- Check on iPad too, where the bar's insets differ.

**Fixed** (Oct 8, 2026, with nit 2): all three tabs' titles are now in the same row of our
own bar, in from the edges by the screen's system margin (UIKit's
`systemMinimumLayoutMargins`, the one navigation bars and lists use: 20 points on this
iPhone, 16 on most others) instead of a fixed 16. The search and + circles moved in by the
same 4 points, level with the right edge of the list cards.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max): Buttons title now at x 22.0, the same
as Invoices (22.0); Settings 21.3 as before. The + circle's right edge is at x 410.5, the
cards' right edge at about 409.5. Not checked: iPad, and an iPhone with 16-point margins.

## The UX review (Oct 9, 2026): nits 11–35

Found by Claude reviewing the app against Apple's Human Interface Guidelines as published
on Oct 9, 2026 (Docs/ux-review/hig-checklist.md; every screen in Docs/ux-review/screens.md),
not reported by Caleb. Checked in the iOS 27.0 Simulator, iPhone 15 Pro Max, fresh install
with the seed data, light and dark, default text size, Bold Text off. Measurements are from
3x screenshots, in points. Screenshots are in build/ux-review/shots (gitignored: some show
her bank numbers); each nit names its file.

- **Severity:** *blocks her* (she can't do the task), *confuses her* (she can, but is likely
  to stall, misread or mis-tap), *polish* (looks or feels off; she'd manage).
- **Not HIG** marks a judgment of Claude's own, with the evidence beside it.
- **Spec** marks a nit that conflicts with SPEC.md; those are proposals for Caleb.
- Not covered: the on-screen keyboard (the Simulator's typing tool counts as a hardware
  keyboard and hides it; nits 1 and 6 covered keyboard motion), the empty catalog, and what
  needs a real phone (Docs/m3-test.md, Part 4).

## 11. "Archived (1)" can't be opened, so archived buttons can't be seen or unarchived from the list

**Found:** Buttons tab, swipe Bunny left (Archive), scroll to the end. The list ends with
the heading "Archived (1)" and nothing under it, with no chevron. Tapping the heading (twice,
at x 85 and 100) does nothing. Shots 04-buttons-archived-dark, 05-buttons-archived-header-dark.

**Cause:** `Section(isExpanded: $showArchived)` (CatalogView.swift:103) starts collapsed. In
an inset-grouped list iOS draws no disclosure control on the header (it does in the sidebar
style), so nothing can set it to true. Search does find archived buttons, and Undo brings one
back, but SPEC.md, "Layout", says archived buttons "are listed at the bottom … and can be
unarchived".

**Guideline:** none needed: a bug against the spec. (Search finds archived buttons and offers
Unarchive, but nothing tells her so.)

**To try:** a plain section (always open), its rows dimmed as now; or a row "Show Archived
Buttons (1)" with a chevron that opens them on their own screen.

**Severity:** blocks her from browsing archived buttons; search is a hidden way round.

**Fix** (Caleb chose the always-open section): the Archived section is a plain section, so
its rows always show, dimmed and with the shape in the name ("Bunny, Black / White"). A note
under it says how to bring one back: "Archived buttons aren't offered for new invoices. To
use one again, tap it, then Unarchive This Button at the bottom." The wording matches the
Change Button sheet's note, and "at the bottom" because the button is the last on that sheet.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max): Bunny archived, end of the list: the
heading, the Bunny row and the note, in light and dark (shots 44-nit11-archived-open-light,
45-nit11-archived-open-dark). Tapping the row opened Change Button with Unarchive This Button
at the bottom; tapping it closed the sheet, Bunny went back under its shape and the Archived
section went away.

**Check** (Caleb, iPhone): Buttons tab, swipe Bunny left → **Archive**, scroll to the end.
Expected: "Archived (1)" with Bunny under it, dimmed, and the note. Tap Bunny → scroll to
**Unarchive This Button** → tap it. Expected: Bunny back at the top under "Bunny".

## 12. A discount bigger than the price shows a negative line total, and Add is greyed out with no reason

**Found:** quantity screen for Heart, Red, Medium ($4.00), Add Discount, Dollars, type 5.
Line total "-$12.00", "12 × -$1.00"; ✓ and Add to Invoice go grey. Nothing says why. The
shot (10-quantity-discount-over-price-dark) shows the field at 55: "-$612.00", "12 ×
-$51.00".

**Cause:** `isValid` refuses a discount above the price (LineEditorView.swift:214–217), but
the line total and the warning icon don't: the orange icon shows only when the text isn't a
number (:82). A price of 0 and an empty quantity are also refused silently.

**Guideline:** Writing: display an error message "as close to the problem as possible …
and be clear about what someone can do to fix it." (Entering data endorses greying out the
button; the gap is the missing reason.) The invoice steps already show theirs beside Next.

**To try:** under the discount, "The discount can't be more than the price ($4.00)." and
"—" for the line total; the same one-line reason under Add to Invoice for a missing quantity
or price.

**Severity:** confuses her.

**Fix:** one `problem` sentence decides both the grey button and what's said, shown in orange
under Add to Invoice (or Save), as New Button step 3 does under Next. In order: "Enter how
many.", "Enter the price for one button.", "The percent off can't be more than 100.", "The
discount isn't a number.", "The discount can't be more than the price ($4.00)." While there's
a problem the line total shows "—" and the "12 × …" line is hidden; the orange ! beside the
discount also shows for a discount over the price. The orange is nit 17's, fixed there.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): New Invoice → Add a Button →
Heart → Red → Use This Button: "Enter how many." under the grey button, total "—" (shot
46-nit12-no-quantity-light). 12, then a $55 discount: the !, "—", and "The discount can't be
more than the price ($4.00)." (47-nit12-discount-over-price-light). Percent, 550: "The percent
off can't be more than 100." Remove Discount: $48.00, "12 × $4.00", no sentence; Add to
Invoice added the line at $48.00.

**Check** (Caleb, iPhone): the same steps. With the number pad up, the sentence under the
button may be hidden by it; the ! and "—" should still show above it. Note whether that's
enough, or whether the discount's own reason should also sit under the discount field.

## 13. "Add a Button" means two different things

**Found:**
- In a draft, **Add a Button** (InvoiceFlowView.swift:304) opens the sheet titled "Add a
  Button" that puts a saved button on the invoice.
- The Home Screen quick action **Add a Button** (project.yml:86), the Siri/Shortcuts action
  of the same name (AppShortcuts.swift:18, "Adds a new button design") and the Buttons tab's +
  (its label, CatalogView.swift:42) start the new-button steps, titled "New Button".
- Inside the Add a Button sheet, making a new one is **Add a New Button**.

**Guideline:** Writing: "Create a list of common terms, and reference that list to keep your
language consistent."

**To try:** keep **Add a Button** for putting one on an invoice (her most frequent action);
call making one **New Button** everywhere: the quick action, the App Shortcut ("New button in
Invoices"), the + label, and the sheet's "Add a New Button".

**Severity:** confuses her (from the Home Screen, "Add a Button" lands her in a camera step,
not on an invoice).

**Fix** (Caleb approved, spec included): "Add" now always means putting a button on an
invoice, and making one is "New Button". Renamed: the Home Screen quick action (project.yml),
the App Shortcut's title and short title, its phrases ("New button in Invoices", "Save a new
button in Invoices"; "Add a button in Invoices" dropped), its description ("Saves a new button
design, starting with its photo."), and the Buttons tab's + label (CatalogView.swift).
Unchanged: Add a Button in a draft and its sheet, and "Add a New Button" / "Add as a New
Button" inside it, which make a button and put it on the invoice. SPEC.md (Platform
conventions) and README.md say New Button.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max): touch and hold the icon: New Invoice,
New Button (shot 50-nit13-quick-actions-after; before, 48-nit13-quick-actions); New Button
opens New Button, step 1. The built App Intents metadata lists NewButtonIntent "New Button",
the new description, and both phrases.

**Check** (Caleb, iPhone): touch and hold the app icon → **New Button**. Expected: New Button,
step 1. Say "New button in Invoices" to Siri. Expected: the same screen. (Siri may need a
minute after installing to learn the new phrase.)

## 14. The missing-bank-details warning sends her to "Home → Business details", which doesn't exist

**Found:** ReviewView.swift:191: "The bank routing or account number is empty (Home →
Business details)." The app's tabs are Invoices, Buttons and Settings; the fields are under
Settings → **Payment** (SettingsView.swift:60). Read from the code: the seed has bank numbers,
so the warning didn't show on screen.

**Guideline:** Writing: "If you need to direct someone to a setting, provide a direct link or
button, rather than trying to describe its location."

**To try:** "The bank routing or account number is empty. Add them in Settings, under
Payment." with a **Open Settings** button that switches to the Settings tab.

**Severity:** confuses her.

**Fix** (Caleb chose the sheet): the warning reads "The bank routing or account number is
empty, so the invoice won't say where to pay." with an **Add Bank Details** button under it
(large, bordered). It opens a Bank Details sheet (BankDetailsSheet.swift): Routing and Account
(digits only), the note "Printed bottom left, beside the totals, so Alix of Bohemia knows where
to pay. Also in Settings, under Payment.", Save (and ✓), greyed with "Enter both numbers."
until both are filled; ✕ or a swipe asks before discarding. Save writes the same keychain
values as Settings → Payment. A reopened invoice that keeps the details it was finished with
gets the two numbers too, and nothing else from Settings.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): the numbers are in the keychain,
so the Simulator's keychain was reset to empty them. Review showed the warning and the button
(shot 51-nit14-bank-warning-light); the sheet opened with both fields empty and Save grey
(52-nit14-bank-sheet-light). Test numbers 000000000 and 1234 → Save: the warning went away and
the PDF preview printed them (53-nit14-pdf-after-test-numbers-light). Her numbers were then
restored by resetting the keychain again and reinstalling, which reads them from the seed
file; Settings → Payment showed them.

**Check** (Caleb, iPhone): can't be seen without emptying her numbers, so check it in the
Simulator if at all: `xcrun simctl keychain booted reset`, open a draft's Review, tap **Add
Bank Details**. Afterwards reset the keychain again and run `make sim` after deleting the app
from the Simulator, to restore them.

## 15. Two ‹ back buttons on a draft, each going somewhere different

**Found:** on step 2 or 3 of a draft, the top-left ‹ (x 20–64, y 59–103) goes back to the
Invoices list, and the bottom ‹ circle beside Next (about x 254–304, y 789–838 on step 3) goes to
the previous step. Same symbol, same glass circle, different destinations. Shots
14-step2-dark, 18-review-dark.

**Guideline:** Toolbars: people know the standard Back button "lets them retrace their steps
through a hierarchy"; Design principles, Familiarity: "Keep visuals and interactions
consistent."

**To try:** give the bottom one words, not the chevron alone: "‹ Buttons" / "‹ Shipping"
(the earlier "Back" was cut to "Ba…", Docs/progress.md, so use the step name, which is short),
or drop it and let the step bar be the way back, as it already is.

**Severity:** confuses her.

**Fix** (Caleb chose to remove it): the ‹ circle beside Next / Finish is gone
(InvoiceFlowView.swift); the bottom bar is the total and Next or Finish. The top-left ‹ is
the only back button, and the step bar goes back a step. SPEC.md ("Making an invoice") listed
"Back to the previous step" in the bottom bar, so it and the README now say the step bar does
it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): Duplicate of Invoice 0260903
opens on step 2 with the total and Next only (shot 55-nit15-step2-one-back-light); tapping
**1 Buttons** in the step bar went back to step 1.

**Check** (Caleb, iPhone): on step 2 or 3 of a draft, one ‹ (top left); tap **1 Buttons** or
**2 Shipping** at the top to go back a step.

## 16. Questions show only the red button; "Keep Editing" and Cancel never appear

**Found:** "Discard your changes?" (swipe down a New Button sheet, or ✕ on Change Button)
shows a single **Discard Changes**; "Delete draft 0261009-2?" shows a single **Delete
Draft**. The code also offers **Keep Editing** (Platform.swift:511), and Docs/progress.md
describes it, but it isn't drawn. Tapping outside the bubble does keep editing, but nothing
says so. Shots 05-buttons-bottom-dark,
36-newbutton-swipe-discard-light, 39-delete-draft-question-light.

**Cause:** these are confirmation dialogs anchored to a control; on iOS 26 and later they
show as a small bubble and leave out the button with the cancel role ("Keep Editing",
Platform.swift:511; SwiftUI's own Cancel in InvoicesTab.swift:79, InvoiceFlowView.swift:63,
FinishedInvoiceView.swift:119 and :128, EditButtonView.swift:133).

**Guideline:** Not HIG. Action sheets: "If necessary, provide a Cancel button that lets
people reject an action that might destroy data", but it's SwiftUI's own Cancel that iOS hides
here, and a bubble that closes on a tap outside is iOS 26's standard. The judgment: for her,
a question whose only visible answer is the destructive one invites the wrong tap.

**To try:** give Keep Editing (and a "Keep Draft" / "Keep Invoice") a normal role instead of
`.cancel`, so it's drawn; check it appears in the bubble, below the red one. If the bubble
still drops it, use an alert for these.

**Severity:** confuses her (on the discard and delete questions the only visible choice is
the destructive one; Make Changes isn't red but has the same gap).

**Fix** (Caleb chose alerts): every question is an alert instead of a confirmation dialog, so
iOS draws the cancel button: `discardQuestion` (Platform.swift; every sheet's ✕ and swipe
down, and "Discard your touch-up?"), Delete Draft (draft ⋯), Delete Draft / Delete Invoice
(Invoices list), Make Changes and Delete Invoice (finished invoice), Delete Button (Change
Button). Titles and messages unchanged; each has Cancel or Keep Editing. With short labels
iOS puts the two side by side; "Discard Changes" / "Keep Editing" are long, so they stack,
red on top.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): swipe a draft left → Delete:
"Delete draft 0261009?" with Cancel and Delete Draft side by side (shot
56-nit16-delete-alert-light); Cancel kept the draft. Shipping sheet, type 77, ✕: "Discard your
changes?" with Discard Changes and Keep Editing (57-nit16-discard-alert-light); Keep Editing
kept the sheet and 77; swiping the sheet down asked again; Discard Changes closed it with no
charge added.

**Check** (Caleb, iPhone): Docs/m3-test.md, Part 4, steps 4 and 5.

## 17. The orange "why can't I go on" text is 2.1:1 in light mode

**Found:** New Button step 3 with no price: under the grey Next, "Enter the price for one
button." in #FF8D28 on #F2F2F7: **2.07:1**, at 13 points. Shot 34-step3-lower-light. The same
footer style is on Change Button (EditButtonView.swift:115) and step 3 (NewButtonFlow.swift:446).
Dark mode is fine (orange on black).

**Guideline:** Accessibility: 4.5:1 for text up to 17 points (WCAG AA).

**To try:** the footer in the standard secondary color with an orange ⚠︎ symbol in front, or
`.red` text, which is darker; recheck at 4.5:1. Review's orange warnings are on white cards:
check those too once a warning can be shown (nit 14's warning, a line with no photo).

**Severity:** confuses her (it's the only explanation of the grey button).

**Fix** (Caleb chose dark text and an amber symbol): a shared `Notice` view (Platform.swift)
draws every warning as a ⚠︎ in a new **Warning** color with the words in the normal text
color. Warning (Assets.xcassets): #B45309 in light mode, yellower than the rust tint #C0472A
so it doesn't read as tappable; iOS's orange #FF9230 in dark mode. Used for the "why it's
grey" sentences (New Button step 3, Change Button, the quantity screen, Bank Details), Review's
checks (problems keep a red ✕ octagon; "Matches." a green ✓, also dark text now), the
look-alike and duplicate warnings, and "No price" in the Buttons list; the ! beside a bad
discount or price is amber. No orange text is left (`grep .orange App/Sources` is empty).
Gotcha: in a section footer `.primary` resolves to the footer's grey, so the text uses
`Color.primary`.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max; 3x screenshots):

| Where | Text | Symbol |
|---|---|---|
| New Button step 3, under Next, light (shot 58-nit17-step3-notice-light) | #000000 on #F2F2F7, 18.8:1 | #B45309, 4.50:1 |
| Same, dark (59-nit17-step3-notice-dark) | #FFFFFF on #1C1C1E, 17.0:1 | #FF9230, 7.62:1 |
| Review, "Your total is $126.00 less…", light, white card (60-nit17-review-notice-light) | #000000 on #FFFFFF, 21:1 | #B45309, 5.02:1 |

Before: the orange text was 2.07:1.

**Check** (Caleb, iPhone, light mode): Buttons tab → **+** → **Skip Photo**, scroll to the
end: a brown-orange ⚠︎ and black "Pick the shape or type its name." under the grey Next.

## 18. The big camera picture on the photo step looks tappable but does nothing

**Found:** New Button step 1: a 200-point checkerboard with a large camera symbol in a
circle (NewButtonFlow.swift:225–228, Photos.swift:55–59). Tapping it (215, 405) does nothing;
Take Photo is the row below. Shots 27-newbutton-step1-light, tmp2.

**Guideline:** Not HIG: a judgment that a large camera symbol where the photo goes reads as
"tap here" (the same symbol is on the Take Photo row below it). Loosely, Gestures: "Indicate
when a gesture isn't available."

**To try:** make the picture a button that does what Take Photo does (Choose from Photos in
the Simulator), or show the empty checkerboard without the camera symbol.

**Severity:** confuses her.

**Fix** (Caleb chose to make it do Take Photo): before there's a photo, the frame is a button
that does what Take Photo does (Choose from Photos on a device without a camera)
(NewButtonFlow.swift). Once there's a photo, tapping it does nothing; Retake Photo, Choose
from Photos and Touch Up the Edges are the rows below. To start it from outside,
`PhotoSourceButtons` takes a `start` binding, and its Choose from Photos is now a plain
button with `.photosPicker(isPresented:)` instead of a `PhotosPicker` view (same look; also
used by Shipping and Change Button).

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): the iOS 27 Simulator has a
simulated camera, so tapping the frame opened the camera (shot
61-nit18-frame-opens-photos-light), twice in a row; ✕ came back. Choose from Photos → the
strawberry → Use This Photo: the photo fills the frame, undimmed, and tapping it did nothing
(62-nit18-photo-tap-does-nothing-light).

**Check** (Caleb, iPhone): Buttons tab → **+** → tap the big camera picture. Expected: the
camera. Cancel, then **Choose from Photos** still opens Photos.

## 19. Step 3 picks the shape from a list of 20 names, no photos

**Found:** New Button step 3 and Change Button: **Shape** is a menu of names ("New shape…",
Bunny … Strawberry), 20 lines, scrolling (NewButtonFlow.swift:560). Shot 32-shape-menu-light.

**Guideline:** SPEC.md, "Who uses it": "Pick from photos, not names." (HIG Menus allows long
menus of user-defined items, so this is a spec point.) The Add a Button sheet already has a
grid of shape photos (AddLineSheet.swift:114).

**To try:** open the same shape grid (DesignTile) as a pushed screen, with "A new shape" as
its last tile.

**Severity:** confuses her. **Spec:** follows a spec rule the screen breaks.

**Fix** (Caleb chose the grid): the Shape row opens **Which shape?** (`ShapeChoiceView`,
NewButtonFlow.swift): the Add a Button sheet's photo tiles (`DesignTile`), the chosen one
outlined in the accent color, and **A New Shape** ("Type its name") last. Picking a shape
goes back with its photo and name in the row and its saved colors in the strip below; A New
Shape goes back to "Pick a saved shape" with the name field. Shared by New Button step 3 and
Change Button. SPEC.md unchanged: the screen now follows it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): New Button → Skip Photo → the
row reads "Pick a saved shape ›" (shot 63-nit19-shape-row-new-light); the grid, 20 shapes and
A New Shape (64-nit19-which-shape-light); Heart → the row shows the heart and Heart, with
Burgundy, Navy and Red below (65-nit19-heart-picked-light); Strawberry, then the grid again:
Strawberry outlined; A New Shape → the name field is back. Change Button for Bunny: the row
shows Bunny; the grid opens with Bunny outlined.

**Check** (Caleb, iPhone): Buttons tab → **+** → **Skip Photo** → tap **Pick a saved shape**
→ **Heart**. Expected: the Heart row with its photo, and its saved colors under it.

## 20. Picking a saved shape leaves size "One size" and price empty, so a near-duplicate is easy

**Found:** New Button (from +), step 3: Shape → Heart, color Red. Every saved Heart is
Medium at $4.00, but Size stays **One size** and Price is empty. With $4 typed, Next is
allowed and step 4 offers to save **Heart, Red** (26HR) beside the existing **Heart, Red,
Medium** (26HRM), "New color or size of Heart". Shots 33–35.

**Cause:** the draft takes the shape's price only when it starts from that shape (the ⋯
menu's Add Color or Size…, EditButtonView.swift:169–170), and never its size; picking the
shape in step 3 fills in neither. The duplicate check compares whole names
(NewButtonFlow.swift:105), so "Heart, Red" passes.

**Guideline (not HIG):** Entering data: "prefill fields with reasonable default values";
Machine learning, Mistakes: "Anticipate mistakes."

**To try:** when she picks a shape whose saved buttons all share a size, set that size (and
the most common price) if she hasn't chosen one; and warn "Heart, Red, Medium is already
saved. Is this a different size?" when the only difference is a missing size.

**Severity:** confuses her (a second red heart on later invoices, under a new SKU).

**Fix** (Caleb chose both): `ButtonDraft.fillFromShape` (NewButtonFlow.swift) fills, when a
saved shape is picked for a new button and only where she hasn't: the size, if all the
shape's buttons share one, and the price they use most (ties to the higher). It runs when a
draft starts from a shape (Add Color or Size…, Add as a New Button) and when she picks one in
step 3; Change Button is left alone. `sizeTwin` finds a saved button of the same shape and
colors that has a size when this one has none; step 3 shows "Heart, Red, Medium is already
saved. Is this a different size?" under Size, and step 4 shows it too, as a warning: Next
and Save stay allowed. Also: step 4's problem line was red text; it's now the red ✕ with
dark text (nit 17's style).

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): New Button → Skip Photo → Heart
→ Red: Size **Medium**, Price **4**, "Heart, Red, Medium" is already saved and Next is grey
(shot 66-nit20-heart-filled-light). Size → One size: the warning under Size, "Heart, Red",
26HR, Next allowed (67-nit20-size-twin-light). Next: step 4 shows the same warning, Save
Button allowed (68-nit20-step4-twin-light). Discarded; nothing saved.

**Check** (Caleb, iPhone): Buttons tab → **+** → **Skip Photo** → **Pick a saved shape** →
**Heart**, color **Navy**. Expected: Size Medium, Price 4, and "Heart, Navy, Medium" is
already saved. Swipe down → **Discard Changes**.

## 21. "Change" buttons are 24 points tall

**Found:** Review step: the two **Change** buttons measure 64.7 × 24.3 and 64.7 × 23.3
points (x 333–398). Shot 18-review-dark. `.controlSize(.small)` (ReviewView.swift:122).

**Guideline:** Buttons: "a hit region of at least 44x44 pt"; Accessibility: 28 × 28 minimum.

**To try:** `.controlSize(.regular)` (about 34 points) with the hit area padded to 44, or make
the whole card's header row the button.

**Severity:** confuses her (missed taps). **Spec:** "large text and buttons".

**Fix** (Caleb chose standard-size buttons): "✎ Change", bordered, regular size, with a
44-point-tall touch area (`.frame(minHeight: 44)` and a content shape) (ReviewView.swift).
SPEC.md unchanged: the screen now follows it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light; 3x screenshot, column scans
through the capsule's middle): both capsules 34.3 points tall (before 24.3 and 23.3); shot
70-nit21-change-after-light. A tap at y 412, 3 points below the Buttons card's capsule (y
374.3–408.7), opened step 1.

**Check** (Caleb, iPhone): a draft's Review → tap **Change** beside Buttons, then beside
Shipping. Each goes to its step.

## 22. "Already Saved" reads like a label, and the two card buttons differ in size

**Found:** New Button from the Buttons tab, step 2 (from a Crab's ⋯ → Add Color or Size…,
strawberry photo): each saved Crab's card has **Already Saved** (one line) and **Same Shape,
New Color or Size** (wrapped onto two lines, a taller pill). Tapping Already Saved ends the
flow without saving. Shot 43-step2-same-shape-light (the Simulator can't compare photos, so
these cards are the same-shape list; on her iPhone the photo matches use the same card).

**Guideline:** Writing: labels are verbs; Buttons: "Use style — not size — to visually
distinguish the preferred choice."

**To try:** **Use This One** (catalog) as in the invoice's "It's This One", and **New Color
or Size** as the second; both the same height, stacked full width if they don't fit side by
side.

**Severity:** confuses her.

**Fix** (Caleb approved): the card's buttons are **It's This One** (both purposes; was
"Already Saved" from the Buttons tab) and **New Color or Size**, equal width and height, side
by side when both fit on one line, else stacked (`ViewThatFits`) (NewButtonFlow.swift). From
the Buttons tab, a note above the cards: "If it's one of these, tap It's This One. Nothing new
is saved." Also: "It doesn't look like any saved button." was green text, 1.99:1 on the
grouped background; it's now dark text with a green ✓ (nit 17's style).

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): Crab ⋯ → Add Color or Size… →
the strawberry → Next: "Couldn't compare photos on this device.", the note, then both Crab
cards with It's This One and New Color or Size side by side, both 50.0 points tall (before
23 and 37) (shot 71-nit22-match-cards-light). It's This One on Crab, Blue closed the sheet;
Crab still has 2 buttons.

**Check** (Caleb, iPhone): Docs/m3-test.md, Part 4, step 1 (now with photo matches).

## 23. Side margins are 16 points on some screens and 20 on others

**Found** (left / right edges, points):

| Screen | Edges | Set by |
|---|---|---|
| Lists, tab titles, New Invoice, toolbar circles | 20 / 410 | system margins (nit 10) |
| Draft bottom bar (total, Next) | 16.7 / 414.0 | InvoiceFlowView.swift:171 `.padding(.horizontal)` |
| Review cards | 16.0 / 414 | ReviewView.swift:104 `.padding()` |
| Add a Button heading and grid | 16.3 | AddLineSheet.swift:150 |
| New Button steps 2 and 4, photo cutout | 16 | NewButtonFlow.swift:338, :512; PhotoCutoutView.swift:105, :137, :160 |
| "What would you like to do today?" | 26.0 (title at 22.0) | InvoicesTab.swift:33, leading inset 4 |

Shots 01, 06, 07, 18, 29, 30.

**Guideline:** Layout: "Align elements to make them easier to scan."

**To try:** the system margin BarRow uses (Platform.swift:382–392) for all of these; the
question's leading inset 0.

**Severity:** polish.

**Fix** (Caleb approved): `.systemHorizontalMargin()` (Platform.swift) pads left and right
by the screen's system margin, the one lists and bars use (20 on her iPhone, 16 on smaller
ones); `SystemMargin.current` gives it from the first frame, so nothing shifts 4 points
after appearing. Used instead of the 16-point `.padding()` / `.padding(.horizontal)` in the
draft's bottom bar and step bar, Review, Add a Button's grid and colors-and-sizes screen,
New Button steps 2 and 4, Which shape?, the photo cutout (7 places) and the receipt viewer's
amount bar. The question under "Hello, Daphné." moved 1 point left (see below). No 16-point horizontal
padding is left (`grep '.padding()$\|.padding(.horizontal)$' App/Sources` finds none).

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, 3x screenshots; left / right edge where
a card or control meets the background, points):

| Screen | Before | After |
|---|---|---|
| Review cards (light, 73-nit23-draft-light; dark, 77-nit23-review-dark) | 16.0 / 414.0 | 20.0 / 410.0 |
| Draft bottom bar, Finish's right end | 414.0 | 410.0 |
| Add a Button grid (74-nit23-add-button-light), still 3 tiles a row | 16.3 / 413.7 | 20.0 / 410.0 |
| Photo cutout, photo and buttons (75-nit23-cutout-light) | 16 | 20.0 / 410.0 |
| New Button step 2 cards (76-nit23-step2-light) | 16.0 / 414.0 | 20.0 / 410.0 |
| "What would you like to do today?" ink (72-nit23-invoices-light), title at 22.0 | 26.0, top of the W cut | 21.0, W whole |

The W: a list section's first row is clipped to the section card's rounded corner even
when the card is clear, and that corner cut the top of the W's left stroke (seen by tinting
the text's frame: its top-left corner was rounded). Moving the text or padding it moved the
clip with it; a first try measured the clip edge, not the letter, and Caleb caught it. The
question is now the section's header, which isn't clipped (InvoicesTab.swift). Pixel map at
3x: the W's left stroke now starts on row 322 with the other strokes, 5 pixels wide; before,
it started on row 331. In a header `.secondary` came out a step lighter (#BBBBC1, 1.71:1) and
`Color.secondary` was 3.29:1, so the question is 60% of the text color: #616163 on #F2F2F7,
5.54:1 (light); #999999 on black, 7.37:1 (dark, 80-nit23-question-dark). Before, 3.89:1.
Spacing unchanged (3x pixels): question ink 320–367, New Invoice 448–633, "Drafts" from 728,
as before; it still scrolls under the shrinking title.

**Check** (Caleb, iPhone): go from the Invoices list into a draft and to Review; the cards
shouldn't change width.

## 24. Remove Shipping hangs under the bare Save button, with square corners and no icon

**Found:** open a saved shipping charge: **Remove Shipping** is a card row right under the
bare **Save** button, its top corners square, red text with no icon. Change Line's Remove from
Invoice has its own card and a trash icon. Shot 17-shipping-edit-dark.

**Cause:** both buttons are in one `Section` (ShippingEditorView.swift:76–94).

**Guideline:** SPEC.md, "Design guidelines": "a bare prominent button never has a card row
under it … Destructive rows carry an icon"; Layout: group related items.

**To try:** as LineEditorView.swift:123–135: its own section, `DestructiveLabel("Remove
Shipping", systemImage: "trash")`.

**Severity:** polish. **Spec:** breaks the spec's own rule.

**Fix** (Caleb approved): Remove Shipping is in its own section below Save, as
`DestructiveLabel("Remove Shipping", systemImage: "trash")` (ShippingEditorView.swift), the
same as Change Line's Remove from Invoice. SPEC.md unchanged: the screen now follows it.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): a draft's step 2 → Add Shipping →
12.50 → Add Shipping → tap the charge: Save, then a separate card with a trash icon and
"Remove Shipping", rounded at all four corners (shot 78-nit24-remove-shipping-light). Tapping
it removed the charge; the total went from $4,138.50 back to $4,126.00.

**Check** (Caleb, iPhone): open a shipping charge on a draft; Remove Shipping is its own card
with a trash icon.

## 25. Unreached steps in the step bar are 1.6:1, too faint to read

**Found:** a draft with no shipping yet: "3 Review" is #C2C2C6 on #F2F2F7 (**1.59:1**) in
light, and "2 Shipping" on an empty draft #333333 on black (**1.66:1**) in dark. Shots
06-draft-step1-empty-dark, 37-duplicate-draft-light. `.opacity(0.4)` (InvoiceFlowView.swift:238).

**Guideline:** WCAG leaves unavailable controls out of the contrast rule, but the step bar is
also the map of what comes next; Color: don't rely on color alone. **Not HIG** in part.

**To try:** keep the names in the secondary color (about 4.5:1) and show "can't go yet"
another way: the number's circle outlined instead of filled, and the reason line under the
bar that Next already uses.

**Severity:** polish.

**Fix** (Caleb approved): a step she can't reach yet keeps its name and number in 60% of the
text color, with its number in an outlined circle instead of a filled one
(InvoiceFlowView.swift); the current step stays filled in the accent color, reachable ones in
grey. The 40% opacity is gone, and the steps use `StepButtonStyle`, the plain style without
its dimming of a disabled button (with `.plain`, the disabled label still measured 2.10:1).
Still `.disabled`, so tapping it does nothing and VoiceOver reads it as dimmed.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max; a draft on step 2 with no shipping):

| | Before | After |
|---|---|---|
| "3 Review", light (83-nit25-step-bar-light) | #C2C2C6 on #F2F2F7, 1.59:1 | #616163, 5.54:1 (name, number and ring) |
| "3 Review", dark (84-nit25-step-bar-dark) | 1.66:1 | #999999 on black, 7.37:1 |

Tapping "3 Review" stayed on step 2; tapping "1 Buttons" went to step 1.

**Check** (Caleb, iPhone): a new invoice's step bar: "2 Shipping" and "3 Review" readable,
with outlined numbers, until each step can be reached.

## 26. Invoice rows wrap "of buttons" onto a third line

**Found:** every invoice row at the default text size reads "Sep 3, 2026 · 2 kinds" then "of
buttons" on its own line (detail block 33.7 points, two lines). Shots 01, 02, 24.

**Cause:** the date and count share one subheadline (InvoicesTab.swift:247–249) beside a
right-aligned total.

**Guideline:** Lists and tables: "Keep item text succinct so row content is comfortable to
read."

**To try:** "Sep 3 · 2 kinds" (the year only when it isn't this year), or the count on its
own line.

**Severity:** polish.

**Fix** (Caleb chose "SKUs", on one line, after first trying two lines): the row's detail
is "Sep 3, 2026 · 2 SKUs" ("1 SKU" for one) (InvoicesTab.swift). Rows are one line shorter.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light; 3x pixels): every row is number,
then date and count on one line (shot 85-nit26-rows-light). Widest, "Aug 12, 2026 · 10 SKUs",
ends at 243.0 points, $976.90 starts at 299.7; "Aug 19, 2026 · 2 SKUs" ends 47.7 points
before $2,656.21. #7F7F7F on white, 4.00:1, as before.

**Check** (Caleb, iPhone): the Invoices list; each row's date and SKU count on one line.

## 27. A 1-pixel seam crosses the Paid card

**Found:** a full-width line, 1 pixel tall, in the background color, across the Paid card
(icon column included, where separators don't reach): y 1869 px (623 points) between the 2nd
and 3rd rows at the top of the list, y 1571 px after scrolling, in light (#F2F2F7) and dark
(#000000). Seen in shots 01, 02 (light and dark), and again after relaunching.

**Cause:** not found yet. Likely rows at fractional heights (the rows are 70.3 points), so
one row boundary falls between pixels.

**To try:** round the row's height (padding in InvoiceRow) to whole points and recheck; check
in a release build.

**Severity:** polish.

**Cause, confirmed** (Oct 9, after nit 26): rows were 78.33 points tall, separators 235,
235, 234 and 236 pixels apart; the seam (#F2F2F7 at y 2427 px) sat right under the
separator after the 236-pixel step, where the rounding left a pixel between two rows' white
backgrounds.

**Fix** (Caleb approved): `WholePointHeight` (InvoicesTab.swift) measures each invoice row
and pads its bottom up to the next whole point (78.33 → 79), at any text size.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max): a detector (build/ux-review/seam.sh:
background-colored pixel rows inside a card, in the icon column where separators don't
reach) finds the review's seam (shot 01, y 1869) and today's (y 2427). After the fix, no
seam in 10 distinct scroll positions, 5 light and 5 dark, from flings that stop at arbitrary
offsets (shots 87-nit27-no-seam-light, 88-nit27-no-seam-dark); separators every 237 pixels
(79 points), e.g. 1229, 1466, 1703, 1940, 2177, 2414.

**Check** (Caleb, iPhone): scroll the Invoices list slowly; no hairline crosses the Paid card.

## 28. The draft's ⋯ menu holds one item

**Found:** ⋯ on a draft opens a menu with only **Delete Draft…**. Shot 38-draft-more-menu-light.

**Guideline:** Pull-down buttons: "listing a minimum of three items can help the
interaction feel worthwhile."

**To try:** keep the ⋯ (it matches the finished invoice's) and add Duplicate, which a draft
can use too; or a trash button in its place.

**Severity:** polish.

**Fix** (Caleb approved): the draft's ⋯ has **Duplicate**, a divider, then **Delete Draft…**
(InvoiceFlowView.swift), as a finished invoice's ⋯ starts with Duplicate. It copies the
draft with `InvoiceActions.duplicate` and opens the copy, as Duplicate does from the list.

**Checked** (iOS 27.0 Simulator, iPhone 15 Pro Max, light): Invoice 0261009 → ⋯: Duplicate,
Delete Draft… (shot 94-nit28-draft-menu-light). Duplicate opened Invoice 0261011 (today's
date), $4,126.00, on the step it could reach; the copy was then deleted.

**Check** (Caleb, iPhone): a draft's ⋯ → **Duplicate**: a new draft opens with the same
buttons. Delete it with ⋯ → **Delete Draft…**.

## 29. Same thing, different words

**Found:**
- Settings: Business has **Town** ("Warren, RI 02805"); Bill to has **City** ("Brooklyn, NY")
  and **ZIP** (SettingsView.swift:28, :39–40). Shot 25-settings-light.
- A button with no price: "No price" in orange (Buttons list, CatalogView.swift:154), "No price
  yet" (tiles, AddLineSheet.swift:210), "$0.00" (New Button step 2 cards,
  NewButtonFlow.swift:354).
- Alert titles: "Rename shape" (CatalogView.swift:60) beside "New Color" (NewButtonFlow.swift:687).
- "Touch Up the Edges" (step 1) opens a screen whose button is "Touch Up".

**Guideline:** Writing: consistent terms; "Choose a style for each UI element type and use it
consistently."

**To try:** "Town" → "City, State and ZIP" (one line, as printed); "No price yet" everywhere;
"Rename Shape"; "Touch Up" everywhere.

**Severity:** polish.

## 30. The line total, the number that matters, is in grey

**Found:** quantity screen: "Line total" in the primary color, its amount ($48.00, title3
bold) in the secondary grey. Shots 09, 12.

**Cause:** `LabeledContent` colors its value secondary (LineEditorView.swift:104–106).

**Guideline:** Typography: "Adjust font weight, size, and color as needed to emphasize
important information."

**To try:** `.foregroundStyle(.primary)` on the amount.

**Severity:** polish.

## 31. Red, burgundy and brown dots vanish on picked (orange) color chips

**Found:** step 3, Red picked: its dot #DE4A22 on the chip's #C0472A measured **1.22:1** in
light mode (on a capture since replaced); in dark, Change Button with Red picked, **1.31:1**
(shot 05-buttons-bottom-dark). The white ring carries the shape; the red fill barely shows.
Burgundy and brown not measured.

**Guideline:** Not HIG: the chip's text names the color, so nothing is lost; but the dot is
there to show the glaze (SPEC.md, "Adding a new button"), and on a picked chip it can't.

**To try:** a wider white ring (2.5 points) or a white backing disc under the dot on picked
chips.

**Severity:** polish.

## 32. Two prominent confirm buttons on one sheet

**Found:** Add to Invoice (✓ and **Add to Invoice**), Change Line (✓ and **Save**), Change
Button (✓ and **Save Changes**), Shipping (✓ and **Add Shipping** / **Save**), photo (✓ Use
Photo and **Use This Photo**): each has the tinted ✓ at the top right and a filled button at
the bottom, doing the same thing. The ✓ is also lit before anything has changed. Shots 09,
15, 17, 29.

**Guideline:** Buttons: "Keep the number of prominent buttons to one or two per view"
(allowed); SPEC.md: "One prominent button per screen". **Spec:** the screens break the spec's
own rule.

**Proposal for Caleb:** SPEC.md, "Sheets", makes the ✓ "the one prominent button", so either
make the bottom button plain (bordered), which keeps the spec, or, as a spec change, keep the
big bottom button (one obvious action at the bottom) and make the ✓ plain.

**Severity:** polish.

## 33. The receipt viewer closes with ✓, though nothing is confirmed

**Found:** ReceiptViewer.swift:46–49: the only way out is a tinted ✓ ("Done"); tapping an
amount also closes it. Viewing confirms nothing.

**Guideline:** Toolbars: "the standard Close button closes a modal view"; Sheets: a Done
button is paired with a Cancel.

**To try:** the ✕ (CancelButton, "Close") at the top left, as Quick Look's PDF viewer has.

**Severity:** polish.

## 34. The PDF page is a picture with a tap, not a button: no press feedback

**Found:** `Image(...).onTapGesture` (ReviewView.swift:213), on Review and the finished
invoice. It opens Quick Look, but doesn't dim when pressed, unlike the receipt photo, which is
a button (ShippingEditorView.swift:32).

**Guideline:** Image views: use a button for an interactive image; Buttons: "Always include a
press state for a custom button."

**To try:** a `Button` with a plain style that dims slightly on press.

**Severity:** polish.

## 35. Saved-color captions under the shape are cut off

**Found:** step 3 with Heart picked: "Burgundy,…", "Navy, Medi…", "Red, Medium" under the
three saved hearts, at caption2 (11 points), one line, 70 points wide
(NewButtonFlow.swift:572–575). Shot 33-step3-heart-light.

**Guideline:** Typography: "Avoid truncating text in scrollable regions unless people can
open a separate view to read the rest" (the captions are in a horizontal scroll view).

**To try:** two lines, or only the color (the size shows when it differs).

**Severity:** polish.

## 36. Row separators start 64–84 points in from the card's left edge but end 20 from its right

**Reported:** Caleb, Oct 9, during the bug bash: on the Invoices list the space left of the
separator lines is much larger than on the right.

**Found** (iOS 27.0 Simulator, iPhone 15 Pro Max, 3x screenshots; cards 20.0–410.0 points):
Invoices separators 84.0–390.0 (64 points in on the left, 20 on the right); Buttons tab
104.0–390.0 (84 and 20). Shot 89-separators-light.

**Cause:** iOS's default: a separator starts where the row's text starts, past the icon or
photo, and ends at the row's trailing margin.

**Fix** (Caleb chose 20 on both sides, both lists): `.alignmentGuide(.listRowSeparatorLeading)
{ $0[.leading] }` on InvoiceRow (InvoicesTab.swift) and the catalog row (CatalogView.swift),
so the line starts at the row's margin, under the icon or photo.

**Checked:** Invoices separators all 40.0–390.0, still every 237 pixels (1489, 1726, 1963,
2200, 2437), no seam (nit 27's detector) (shot 90-nit36-invoices-light); Buttons separators
40.0–390.0 (91-nit36-buttons-light, crops 92, 93).

**Check** (Caleb, iPhone): both lists; each line between rows has the same gap at both ends.

