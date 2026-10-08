# Button Invoices — notes for Claude Code

An iPhone/iPad app for Daphné Verley (Caleb's mother) to invoice Alix of Bohemia for
ceramic buttons. SPEC.md is the source of truth; propose spec changes to Caleb rather
than diverging. Status and test results: Docs/progress.md.

## Working agreement

- Caleb is a senior technical PM with no Apple-platform experience. Give exact click paths
  for anything outside the terminal. Put durable instructions in README.md.
- The user of the app is Daphné, who is not comfortable with technology: plain words, big
  targets, one action per screen, nothing that silently changes a finished invoice.
- Configuration lives in text: `project.yml` (XcodeGen) and `Configs/*.xcconfig`. Never
  edit the generated `.xcodeproj`.
- Each milestone ends with a test Caleb runs, recorded in Docs/progress.md with
  "Part N, step M" labels.
- Show raw numbers before conclusions. Unknown API behavior → write a probe and run it
  (debug launch arguments in App/Sources/ButtonInvoicesApp.swift).
- Examples/ holds real invoices, photos and bank details: gitignored, never commit or
  publish it. Same for App/Resources/Seed/business.json.

## Commands

- `make test`: InvoiceKit tests (swift-testing; needs Xcode's toolchain)
- `make sample-pdfs`: the nine example invoices re-rendered into build/sample-pdfs
- `make sim` / `make ios`: build and run in the Simulator / on the connected iPhone
- `make seed`: rebuild App/Resources/Seed from the 0260903 workbook in Examples/
- `make generate`, `make setup`, `make icon`: see README

## Layout

- `Packages/InvoiceKit`: logic with no UI (Money, Naming, SKU, Matcher, InvoiceNumber,
  InvoicePDF, Cutout, LookAlike, ReceiptReader). Platform-neutral so tests run on the Mac.
- `App/Sources`: SwiftUI screens and SwiftData models. Swift 6, MainActor by default.
- Vision (subject lifting, feature prints) fails in the Simulator; the app has fallbacks.
