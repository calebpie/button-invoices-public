import InvoiceKit
import OSLog
import SwiftData
import SwiftUI

@main
struct ButtonInvoicesApp: App {
    let container: ModelContainer
    @State private var settings = BusinessSettings()

    init() {
        // On this device only for now; iCloud sync needs the paid developer account
        // (SPEC.md, "Open questions").
        let config = ModelConfiguration(schema: Schema(AppSchema.models), cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: Schema(AppSchema.models), configurations: config)
        } catch {
            fatalError("Couldn't open the app's data: \(error)")
        }
        Seeder.seedCatalogIfNeeded(container.mainContext)
        #if DEBUG
        Self.runCutoutProbeIfAsked()
        if UserDefaults.standard.bool(forKey: "FreezeProbe") { Self.runFreezeProbe(container.mainContext) }
        #endif
    }

    #if DEBUG
    /// Probe for SPEC.md, "Settings" and "Button history": finishes an invoice, then changes
    /// Settings and the button's name, price and photo, and logs whether the finished PDF and
    /// lines changed. Uses a temporary in-memory store, so her data isn't touched.
    static func runFreezeProbe(_ unused: ModelContext) {
        let log = Logger(subsystem: "InvoiceKit", category: "Probe")
        guard let memory = try? ModelContainer(for: Schema(AppSchema.models),
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true)) else { return }
        let ctx = memory.mainContext
        let design = ButtonDesign(name: "Heart", code: "H")
        ctx.insert(design)
        let heart = ButtonVariant(design: design, colors: ["Navy"], size: "Medium", sku: "26HNM", price: Money(cents: 400), photo: nil)
        ctx.insert(heart)
        let invoice = Invoice(number: "0261008", date: Date())
        ctx.insert(invoice)
        let line = InvoiceLine(position: 0, variant: heart, quantity: 12, unitPrice: heart.price)
        ctx.insert(line)
        line.invoice = invoice
        var profile = BusinessProfile()
        profile.sellerLines = ["123 Example St, Suite 100"]
        // Finish, as InvoiceFlowView.finish does.
        invoice.businessSnapshot = try? JSONEncoder().encode(profile)
        invoice.finishedPDF = InvoiceExport.render(invoice, profile: profile)
        invoice.status = .finalized
        let before = invoice.finishedPDF
        // Later edits: Settings and the button.
        var later = profile
        later.sellerLines = ["1 New Street"]
        later.routing = "999"
        let draft = ButtonDraft(editing: heart)
        draft.colorsText = "Red"
        draft.priceText = "4.50"
        draft.apply(to: heart, isHidden: true, ctx, [design])
        let reread = invoice.businessProfile(current: later)
        log.notice("probe: freeze pdfUnchanged=\(invoice.finishedPDF == before) profileKept=\(reread.sellerLines == profile.sellerLines) line=\(line.itemDescription, privacy: .public) \(line.unitPrice.formatted, privacy: .public) button=\(heart.title, privacy: .public) \(heart.price.formatted, privacy: .public) archived=\(heart.isHidden) versions=\(heart.versions?.count ?? 0)")
    }

    /// Probes: `xcrun simctl launch <device> <bundle id> -CutoutProbe <photo> -ReceiptProbe <photo>`
    /// log whether Vision lifted the subject and read the receipt on this device
    /// (subsystem InvoiceKit, category Probe).
    static func runCutoutProbeIfAsked() {
        if let path = UserDefaults.standard.string(forKey: "ReceiptProbe") {
            Task.detached {
                let log = Logger(subsystem: "InvoiceKit", category: "Probe")
                guard let data = FileManager.default.contents(atPath: path),
                      let image = ImageTools.uprightImage(from: data, maxSide: 3000) else { return }
                do {
                    let scan = try await ReceiptReader.read(image)
                    log.notice("probe: receipt amounts=\(scan.amounts.map(\.formatted), privacy: .public) date=\(scan.date ?? "-", privacy: .public)")
                } catch {
                    log.error("probe: receipt failed \(String(describing: error), privacy: .public)")
                }
            }
        }
        if let pair = UserDefaults.standard.string(forKey: "LookAlikeProbe") {
            Task.detached {
                let log = Logger(subsystem: "InvoiceKit", category: "Probe")
                let paths = pair.split(separator: "|").map(String.init)
                let images = paths.compactMap { FileManager.default.contents(atPath: $0) }
                    .compactMap { ImageTools.uprightImage(from: $0, maxSide: 512) }
                guard images.count == 2 else { return }
                do {
                    let a = try await LookAlike.print(of: images[0]), b = try await LookAlike.print(of: images[1])
                    log.notice("probe: lookalike distance=\(LookAlike.distance(a, b))")
                } catch {
                    log.error("probe: lookalike failed \(String(describing: error), privacy: .public)")
                }
            }
        }
        guard let path = UserDefaults.standard.string(forKey: "CutoutProbe") else { return }
        Task.detached {
            let log = Logger(subsystem: "InvoiceKit", category: "Probe")
            guard let data = FileManager.default.contents(atPath: path),
                  let photo = ImageTools.uprightImage(from: data, maxSide: Photos.workingSize) else {
                log.error("probe: can't read \(path, privacy: .public)")
                return
            }
            let start = Date()
            let cut = await Cutout.lift(photo)
            let bounds = Cutout.opaqueBounds(Cutout.apply(cut.mask, to: photo)!)
            log.notice("probe: \(path, privacy: .public) fallback=\(cut.usedColorFallback) objects=\(cut.objectMasks.count) bounds=\(String(describing: bounds), privacy: .public) seconds=\(Date().timeIntervalSince(start))")
        }
    }
    #endif

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .keyboardDoneButton()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Drafts save as she goes; this catches the last change when she leaves the app.
            if phase != .active { try? container.mainContext.save() }
        }
    }
}

/// Three tabs in the floating Liquid Glass tab bar (SPEC.md, "Layout").
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Invoices", systemImage: "doc.text") {
                InvoicesTab()
            }
            Tab("Buttons", systemImage: "circle.grid.2x2") {
                NavigationStack { CatalogView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
        }
    }
}

extension View {
    /// A Done button above every keyboard. The number pads have no Return key, so without it
    /// the keyboard covers the rest of the form.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }

    /// On iPad, keeps forms and lists to a comfortable reading width instead of the full screen.
    func readableWidth() -> some View {
        frame(maxWidth: 760).frame(maxWidth: .infinity).background(Color(.systemGroupedBackground))
    }
}
