# Screens, sheets, dialogs and states

Every place the UX review checks, from App/Sources (Oct 9, 2026), with how to reach it. "S"
is a screen pushed in a navigation stack, "Sh" a sheet, "FS" full screen, "D" a question
(confirmation dialog), "A" an alert, "M" a menu. States are indented.

## Invoices tab (InvoicesTab.swift)

1. S Invoices list: "Hello, Daphné." title, question, New Invoice, tip, Drafts / Finished, waiting for payment / Paid. Launch.
   - empty: "No Invoices Yet" (delete every invoice)
   - title shrunk (scroll down)
   - Repeat an Order tip (shows once a finished invoice exists)
   - row swipe left: Delete; swipe right: Duplicate
   - M row context menu: Duplicate, Share PDF… (finished only), Delete…
   - D "Delete draft N?" / "Delete invoice N?"
   - Sh Share sheet (context menu → Share PDF…)
2. S Draft invoice (InvoiceFlowView.swift): step bar, step content, bottom bar (total, ‹, Next / Finish). New Invoice, or tap a draft.
   - M ⋯: Delete Draft… → D "Delete draft N?"
   - Step 1 Buttons: guide, lines, Add a Button / Add Another Button; footer; Next disabled with reason
     - row swipe left Delete; M row context menu Change…, Remove
   - Step 2 Shipping: guide, charges, Add Shipping / Add Another Box, "No shipping on this invoice" switch
   - Step 3 Review (ReviewView.swift): guide, checks card (problems red, warnings orange), Invoice # and Date, "Use Current Settings" (reopened invoice whose details differ), Buttons card + Change, Shipping card + Change, Total due, your-total check (match / more / less), The PDF
     - FS Quick Look of the PDF (tap the page)
     - Sh Bank Details (BankDetailsSheet.swift): Routing, Account, Save; from the empty-bank-numbers warning's Add Bank Details
   - Finish → finished screen with the share sheet open
3. S Finished invoice (FinishedInvoiceView.swift): total, number and date, Share PDF, paid switch, The PDF. Tap a finished or paid invoice.
   - toolbar Share (ShareLink) and M ⋯: Duplicate, Make Changes…, Delete…
   - D "Make changes to invoice N?"; D "Delete invoice N?"
   - FS Quick Look of the PDF
   - Sh Share sheet (Share PDF)

## Add a Button sheet, from a draft's step 1 (AddLineSheet.swift)

4. Sh Shape picker: search field ("Type an order, like 12 red hearts"), Type the Order Line tip, "Which button? Tap its shape.", shape grid, "A shape you haven't sold before?" Add a New Button. ✕ (asks only if a new button was started).
   - searching: "Which button? Tap it.", parsed quantity/price line, results grid
   - no results: "No saved button matches …"
5. S Shape's colors and sizes (VariantPickerView): "Which color?" tiles + Another Color; "Which size?" chips (with "(new)") + Another Size; result card Use This Button, or "There's no … saved yet." Add as a New Button. One-variant shapes preselect.
6. S Quantity (LineEditorView, "Add to Invoice"): photo, name, SKU; How many? field + stepper; Price each + "Save $X as this button's price from now on" switch; Discount (Add Discount → Dollars/Percent, field, Remove Discount); Line total; Add to Invoice; ✓ Add.
   - invalid discount icon; price changed switch
7. New-button steps inside the sheet (see 12–15), ending at the quantity screen.

## Change Line sheet (LineEditorView, edit mode)

8. Sh Change Line: as 6 plus ✕, ✓ Save, Save, Remove from Invoice. Tap a line in step 1.
   - D "Discard your changes?" (✕ or swipe down after an edit)

## Shipping sheet (ShippingEditorView.swift)

9. Sh Shipping: Amount; Receipt (optional) with Take Photo of Receipt / Choose from Photos; Note (just for you); Add Shipping / Save; Remove Shipping (edit); ✕, ✓. Add Shipping, or tap a charge.
   - reading: "Reading the receipt…"
   - amounts found: photo, "Tap the receipt to see it full size.", amount buttons
   - none found: "No amounts found. …"
   - D "Discard your changes?"
10. FS Receipt viewer (ReceiptViewer.swift): zoomable photo, amount buttons, ✓. Tap the receipt.
11. FS Camera (UIImagePickerController); Sh Photos picker. Device only for the camera.

## New button steps (NewButtonFlow.swift), from Buttons tab + or a shape's ⋯, or inside Add a Button

12. Step 1 Photo: header "New button · step 1 of 4", checkerboard, Take Photo / Choose from Photos, Touch Up the Edges, footer, Next (disabled without photo), Skip Photo. ✕ (Buttons tab sheet).
    - FS Photo cutout (PhotoCutoutView.swift): "Removing the background…"; result with message (one button / several "Tap the one to keep" / "removed by color"); Use This Photo, Touch Up; ✕, ✓ Use Photo
      - Touch Up: Erase/Restore, brush size, Undo, Start Over; ✓ Done; D "Discard your touch-up?"
13. Step 2 Is it already saved?: photo, "Comparing…", then "looks like" warning / "look similar" / "doesn't look like any"; match cards (It's This One or Already Saved, Same Shape, New Color or Size); "Your saved X buttons"; It's a New Button.
    - Simulator: "Couldn't compare photos on this device."
14. Step 3 Shape, colors and price (ButtonDetailsSections): Shape picker (New shape… field, spelling suggestion, sibling strip), Colors chips + New Color, Size picker, Price each, Name and SKU (Reset, "Use … made from the new name"), problem footer, Next.
    - A New Color (text field)
15. Step 4 Check the new button: photo, On the invoice, SKU, Price each, Shape; warnings; Save Button / Save and Add to Invoice; "To change anything, go back a step."

## Buttons tab (CatalogView.swift)

16. S Buttons list: title with 🔍 and + circles; a section per shape with count and ⋯; rows (photo, colors/size, SKU, price or "No price"); Archived (N) section.
    - search open, typing, results, "No Results for …"
    - empty: "No Buttons Yet"
    - row swipe left Archive / Unarchive; M row context menu Change…, Archive
    - M shape ⋯: Add Color or Size…, Rename…, Archive Shape
    - A "Rename shape"
17. Sh Change Button (EditButtonView.swift): photo card + Take/Retake/Choose/Touch Up; Shape, Colors, Size, Price each, Name and SKU; Also known as; Archive This Button / Unarchive; Delete This Button (never invoiced); Earlier versions; Save Changes; ✕, ✓.
    - D "Delete …?"; D "Discard your changes?"
18. Sh New Button (NewButtonSheet): steps 12–15, ending back on the list.

## Settings tab (SettingsView.swift)

19. S Settings: info line; Business; Bill to; Each button on the invoice; Payment; PDF file name; Preview Sample Invoice; Invoices tab greeting; About.
    - FS Quick Look of the sample PDF

## System entry points

20. Home Screen quick actions: New Invoice, Add a Button. App Shortcuts: same two. Launch restores tab and open draft.
21. Shake / three-finger swipe: "Undo Delete Draft", "Undo Delete Invoice", "Undo Remove Button", "Undo Remove Shipping", "Undo Archive", "Undo Unarchive", "Undo Archive <Shape>".
