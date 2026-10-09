# M3 test: the app on a real iPhone

Record results in Docs/progress.md under "M3 results", using these Part N, step M labels.

## Part 1: Your iPhone (now, free Personal Team)

Checks the parts the Simulator couldn't run: Vision's background removal and photo
matching, the camera, shaking to undo, the Finish haptic and sharing from the phone. The
app is on your iPhone from `make ios`; with the free team it stops opening after 7 days
(run `make ios` again with the phone connected).

1. Open **Invoices** on the iPhone. Expected: "Hello, Daphné." and, under Paid, the nine
   sent invoices, as in the Simulator.
2. On the Mac, in Finder, open Examples/Images/Raw, Control-click **IMG_8516.heic** (the
   strawberry) → **Share** → **AirDrop** → your iPhone. Do the same for
   Examples/Images/Shipping Receipts/**IMG_9049.heic** (the receipt). On the iPhone, accept
   both; they go to Photos.
3. Buttons tab → **+** → **Choose from Photos** → the strawberry. Expected: the strawberry
   on a checkerboard with its outline and leaves clean, and no "The background was removed
   by color" note (that note means the color fallback ran instead of Vision). Compare with
   Examples/Images/Edited.
4. Tap **Use This Photo**, then **Next**. Expected: "This looks like a button you already
   saved." with **Strawberry, Red / Green** (26SRG) first, not "Couldn't compare photos on
   this device." Tap **✕** at the top left → **Discard Changes**.
5. **+** → **Take Photo**. When asked, allow the camera. Photograph any small object (a
   real button, a coin) on a plain sheet of paper, then **Use Photo**. Expected: the
   background removed around it. Tap **Next**. Expected: "It doesn't look like any saved
   button." or a short list of similar ones. **✕** → **Discard Changes**.
6. Invoices tab → **New Invoice** → **Add a Button** → **Heart** → **Red** → **Use This
   Button**, quantity 2, **Add to Invoice**. Expected: the number pad, with no Done bar;
   tapping the heart photo closes it.
7. Swipe the heart line left → **Delete**, then shake the iPhone. Expected: "Undo Remove
   Button" with **Undo**. Tap **Undo**. Expected: the line is back. Then Buttons tab → the
   search circle → type **heart**. Expected: each letter appears as you type and the Heart
   buttons are listed (typing is unaffected by the shake fix). Tap **✕**, then go back to
   the Invoices tab.
8. Tap step **2 Shipping** in the step bar → **Add Shipping** → **Choose from Photos** →
   the receipt. Expected: $36.48 filled in, $36.48 / $19.58 / $16.90 to tap, note "Shipped
   8/31/2026". Tap **Add Shipping**.
9. Tap step **3 Review** → **Finish**. Expected: a short tap in your hand, and the share
   sheet with "Daphné Verley Invoice - AOB 0yyMMdd.pdf" (today's date). Send it to
   yourself with **Mail** or **AirDrop** to the Mac. Expected: on the Mac the PDF matches
   the Simulator's layout; total $44.48 ($8.00 + $36.48).
10. Back on the Invoices tab, swipe the new invoice left → **Delete** → **Delete
    Invoice**.

## Part 2: Her iPhone (once the paid team is approved)

First, the bug bash: every open item in Docs/ui-nits.md fixed and rechecked.

TestFlight steps will be added here and in the README when the paid team exists: upload a
build, invite her, she installs TestFlight and the app, no cable. Expected: the app opens
on her iPhone with her saved data seeded, as in Part 1, step 1.

## Part 3: Her next real invoice (SPEC.md, Milestones)

1. She makes her next invoice for Alix of Bohemia in the app, with her own photos.
2. Before it goes to AOB, she sends you the PDF; check it against her messages and the
   buttons she shipped. Record what she found confusing, even where it worked.

## Part 4: UX review checks on your iPhone (Oct 9, 2026)

What the UX review (Docs/ui-nits.md, nits 11–35) couldn't see in the Simulator: Vision's
cutout and photo matching, loading a photo from iCloud, and the on-screen keyboard. Use the
strawberry photo from Part 1, step 2. Record what you see, and screenshots where something
looks off.

1. Buttons tab → **Crab** heading's **⋯** → **Add Color or Size…** → **Choose from Photos** →
   the strawberry → **Use This Photo** → **Next**. Expected: a list of look-alike buttons with
   **Strawberry, Red / Green** first, then "Your saved Crab buttons:". Note: whether each
   card's two buttons fit side by side or wrap (nit 22), and how the heading reads.
   Swipe the sheet down → **Discard Changes**.
2. **+** → **Choose from Photos** → a photo that is only in iCloud (an old one, or one taken on
   another device). Expected: something on screen while it downloads. Note how many seconds
   pass between tapping the photo and the cutout screen, and whether anything shows meanwhile.
   **✕** at the top left.
3. Invoices tab → **New Invoice** → **Add a Button** → **Heart** → **Red** → **Use This Button**.
   Tap the quantity, then **Add Discount** and the discount field. Expected: the number pad,
   with each field's whole row above it; tapping the heart photo puts it away. Note anything
   hidden under the keyboard.
4. Tap **Add to Invoice**, then tap the heart line to change it, change the quantity and swipe
   the sheet down. Expected: a box in the middle, "Discard your changes?", with **Discard
   Changes** and **Keep Editing** (nit 16). Tap **Keep Editing**; the sheet stays with your
   change. Tap **✕** → **Discard Changes**.
5. **⋯ → Delete Draft…**. Expected: **Cancel** and **Delete Draft** side by side. Tap
   **Delete Draft**.
