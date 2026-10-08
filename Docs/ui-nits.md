# UI nits

Small UI issues Caleb notices, logged as they come up and fixed together in the bug bash
before the app goes to her iPhone (SPEC.md, Milestones; Docs/m3-test.md, Part 2). Each
entry says what Caleb saw, how it was reproduced, what was found, the likely cause and what
to try. App code isn't changed for a nit until the bug bash.

| # | Nit | Where | Status |
|---|---|---|---|
| 1 | Grey strip under the tab bar as the keyboard goes away | Buttons, search | Open |
| 2 | "Hello, Daphné." fades in place instead of sliding with the page | Invoices, opening an invoice | Open |

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
