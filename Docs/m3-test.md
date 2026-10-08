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
   Button" with **Undo**. Tap **Undo**. Expected: the line is back.
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

TestFlight steps will be added here and in the README when the paid team exists: upload a
build, invite her, she installs TestFlight and the app, no cable. Expected: the app opens
on her iPhone with her saved data seeded, as in Part 1, step 1.

## Part 3: Her next real invoice (SPEC.md, Milestones)

1. She makes her next invoice for Alix of Bohemia in the app, with her own photos.
2. Before it goes to AOB, she sends you the PDF; check it against her messages and the
   buttons she shipped. Record what she found confusing, even where it worked.
