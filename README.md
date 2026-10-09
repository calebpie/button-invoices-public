# Button Invoices

An iPhone and iPad app for Daphné Verley to invoice Alix of Bohemia for buttons: pick
buttons by typing the way she texts ("12 red hearts @ $4"), add new ones with a photo
(background removed for you), add shipping, check the total, and send a PDF that looks
like the Excel invoices. Design and decisions: [SPEC.md](SPEC.md). Status: [Docs/progress.md](Docs/progress.md).

## Layout

| Path | What |
|---|---|
| `App/Sources` | The app's screens (SwiftUI) and saved data (SwiftData) |
| `App/Resources/Seed` | Starting catalog from the Excel template, loaded on first launch (`make seed`) |
| `Packages/InvoiceKit` | Everything testable on the Mac: names, SKUs, search, totals, PDF, photo cutout, receipts |
| `Tools/seed/extract_seed.py` | Reads an invoice workbook's Reference sheet into the seed (standard-library Python) |
| `Examples/` | Real invoices, photos and messages (gitignored) |
| `project.yml` | Xcode project definition; `make generate` writes `ButtonInvoices.xcodeproj` (never edit that) |

## Commands

```bash
make test
```
Runs the InvoiceKit tests (34, about 10 s): name cleanup, SKUs against the template, her
17 message lines against the catalog, the nine example totals, PDF pagination, photo
cutouts, and the photo duplicate check.

```bash
make sample-pdfs
```
Re-creates the nine example invoices as PDFs in `build/sample-pdfs` (with a PNG of each
first page, and cutouts of the raw photos) and opens the folder, for comparison with
`Examples/Invoice Excel and Output PDFs`.

```bash
make sim
```
Builds the app and opens it in the Simulator on an iPhone 15 Pro Max, her iPhone's model
(made the first time if Xcode has none), shown in Device Hub (Xcode 27 replaced the
Simulator app with Device Hub; Spotlight finds it by name). Its menus:
Controls → Home (⇧⌘H), App Switcher (⌃⇧⌘H), Rotate Left (⌘←) and Rotate Right (⌘→);
Device → Appearance, Accessibility and Orientation. It has no Shake; with its window in
front, ⌘Z undoes instead. Another device:
`SIMULATOR="iPad Air 11-inch (M4)" make sim`. In the Simulator, background removal falls
back to removing the background by color (Vision's subject lifting fails there with
"Could not create inference context"). The photo duplicate check fails there too ("Failed
to create espresso context") and the app says it couldn't compare photos. Both ran on the
Mac in `make test`; on a real iPhone they are checked in M3. Receipt reading works in the
Simulator. To try photos there, add some to its Photos library first:
```bash
xcrun simctl addmedia booted Examples/Images/Raw/IMG_8516.heic "Examples/Images/Shipping Receipts/IMG_9049.heic"
```

```bash
make seed
```
Rebuilds the starting catalog and the nine sent invoices (loaded as paid) from the
workbooks in Examples/; the catalog comes from 0260903 (another workbook:
`python3 Tools/seed/extract_seed.py --xlsx <file>`) and the edited PNGs in
`Examples/Images/Edited`. Only affects a fresh install: the app loads the
seed once, on first launch. business.json and invoices.json are gitignored (bank details,
real sales), so a fresh clone needs Examples/ and `make seed` before building. To start the Simulator over with a fresh seed:
```bash
xcrun simctl uninstall booted com.calebpietrafesa.ButtonInvoices
```

## First-time setup (Mac)

Steps 1–5 are done on Caleb's M4 Max as of October 8, 2026 (Xcode 27.0 installed, signed in).

1. Install Xcode from the Mac App Store, open it once, accept the license, and let it
   install the iOS platform when asked.
2. `make test` should pass. `make sim` should open Device Hub with the app on the iPhone
   15 Pro Max.
3. Signing: Xcode → Settings… (⌘,) → Accounts → select the Apple ID → select the team →
   Manage Certificates… → + → Apple Development → Done.
4. Run `make setup` (paid team) or `ALLOW_PERSONAL_TEAM=1 make setup` (free Personal Team),
   and check that the team name it prints is yours. It writes `Configs/Signing.xcconfig`.
5. If Xcode says the bundle ID is taken, change `BUNDLE_ID_PREFIX` in
   `Configs/Signing.xcconfig` and run `make ios` again.

## Installing on her iPhone or iPad

### Now: over a cable (free or paid team)

1. Connect the iPhone to the Mac with a cable, unlock it, tap **Trust** and enter the passcode.
2. `make ios` finds the connected iPhone (or iPad), builds for it, installs the app and
   opens it. The first time, it also registers the iPhone with your signing team so Xcode
   can make a provisioning profile for it (the Mac must be online and signed in to Xcode).
3. If it says Developer Mode is off: on the iPhone, Settings → Privacy & Security →
   Developer Mode → on, restart, confirm, and run `make ios` again. (The switch appears only
   after the iPhone has been connected to Xcode, which `make ios` does.)
4. First launch only: if the iPhone says "Untrusted Developer", go to Settings → General →
   VPN & Device Management → your Apple ID → Trust, then open **Invoices** from the Home Screen.

If the build still says "Your team has no devices", register the iPhone through Xcode
once: `make open`, choose the iPhone from the device menu at the top center of the Xcode
window, then Product → Run (⌘R). After that, `make ios` works on its own. With several
devices connected, pick one: `DEVICE="Daphné's iPhone" make ios` (its name as shown in
Finder).

With the free Personal Team the app stops opening after 7 days; run `make ios` again
with the phone connected. Her data is kept.

### Once the paid account is approved: TestFlight (recommended)

TestFlight lets her install and update the app herself, with no cable, and each build
lasts 90 days. Steps will be added to this README when the paid team exists (SPEC.md,
"Platform").

## Before the first install for her

- Settings tab: check the address, bill-to, and the routing and account numbers (copied
  from the template, with "Suit 100" corrected to "Suite 100").
- Buttons tab: check the names. Six photo file names disagree with the invoice names (SPEC.md,
  "Data"); the app uses the invoice names.
- Data lives on the device and is included in its iCloud Backup. Deleting the app deletes
  the invoices and buttons.

## How she uses it

Three tabs at the bottom: **Invoices**, **Buttons**, **Settings**.

1. **Invoices → New Invoice.** The number and date are filled in.
2. **Step 1, Buttons.** **Add a Button**: tap its shape, its color, then its size
   (**Another Size** for a new one).
   Or type the line from her notes in the search field ("125 burgundy mushrooms @ $8") and
   tap the photo. Check the quantity (type it, or **−** / **+**) and price, add a discount
   if any (**Dollars** or **Percent**), tap **Add to Invoice** (or ✓ at the top right).
   Repeat with **Add Another Button**, then **Next**.
3. A button that isn't saved yet: **Add as a New Button** (or **Add a New Button** under
   the shapes). Take its photo on a plain background, check the cutout (**Touch Up the
   Edges** if needed), say whether it's one already saved, check the name and price,
   **Save and Add to Invoice**.
4. **Step 2, Shipping.** **Add Shipping** for each box: type the amount, or photograph the
   receipt and tap the amount for this order. Then **Next**.
5. **Step 3, Review.** Check the lines and total (optionally type her own total to
   compare), then **Finish**. The phone gives a short tap and the share sheet opens:
   Messages or Mail.

Everything is saved as she goes. The back arrow at the top left (or a swipe from the left
edge of the screen) returns to the Invoices tab, where the draft waits under Drafts; the
round **‹** button at the bottom goes back one step. In a form that slides up from the
bottom, **✕** at the top left cancels (it asks first if she typed something) and **✓** at
the top right saves. Finished invoices are listed on the Invoices tab too; tap one to share
its PDF again or mark it paid. Touch and hold an invoice for **Duplicate** (a new draft
with the same buttons), **Share PDF…** and **Delete…**. Shake the phone to undo a removal
or deletion.

Shortcuts: touch and hold the app icon on the Home Screen for **New Invoice** and **Add a
Button**. Siri knows them too: "Start an invoice in Invoices", "Add a button in Invoices".

**Buttons tab**: every button by shape. The magnifying glass at the top right searches
(tap ✕ to close it) and **+** adds a new button; both stay put as you scroll. Tap a button to change
its photo, name or price; swipe left to **Archive** it. Neither
changes invoices that are already finished.

**Settings tab**: the details printed on every invoice. Changes go on new invoices and
drafts only.
