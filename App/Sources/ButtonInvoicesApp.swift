import InvoiceKit
import OSLog
import SwiftData
import SwiftUI
import TipKit
import UIKit

@main
struct ButtonInvoicesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
        let start = Date()
        Seeder.seedCatalogIfNeeded(container.mainContext)
        Seeder.seedSentInvoicesIfNeeded(container.mainContext)
        #if DEBUG
        Logger(subsystem: "InvoiceKit", category: "Probe").notice("probe: startup seeding took \(Date().timeIntervalSince(start)) s")
        if UserDefaults.standard.bool(forKey: "ExportFinishedPDFs") { Self.exportFinishedPDFs(container.mainContext) }
        #endif
        try? Tips.configure([.displayFrequency(.daily)])
        #if DEBUG
        Self.runCutoutProbeIfAsked()
        if UserDefaults.standard.bool(forKey: "FreezeProbe") { Self.runFreezeProbe(container.mainContext) }
        #endif
    }

    #if DEBUG
    /// Probe: writes every finished invoice's stored PDF to tmp/StoredPDFs and logs totals.
    static func exportFinishedPDFs(_ context: ModelContext) {
        let log = Logger(subsystem: "InvoiceKit", category: "Probe")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoredPDFs")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for invoice in (try? context.fetch(FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.date)]))) ?? [] {
            let pdf = invoice.finishedPDF ?? InvoiceExport.render(invoice, profile: invoice.businessProfile(current: BusinessProfile()))
            try? pdf.write(to: folder.appendingPathComponent("\(invoice.number).pdf"))
            log.notice("probe: stored \(invoice.number, privacy: .public) \(invoice.status.label, privacy: .public) \(InvoiceDocument.formatDate(invoice.date), privacy: .public) lines=\(invoice.sortedLines.count) total=\(invoice.total.formatted, privacy: .public) pdfBytes=\(pdf.count)")
        }
    }

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
                .environment(AppRouter.shared)
                .keyboardDoneButton()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Drafts save as she goes; this catches the last change when she leaves the app.
            if phase != .active { try? container.mainContext.save() }
        }
    }
}

/// Three tabs in the floating Liquid Glass tab bar (SPEC.md, "Layout"). Filled symbols, as
/// the tab bar guidelines prefer. Remembers the tab and the open draft between launches
/// (Launching, "Restore the previous state").
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @SceneStorage("tab") private var savedTab = AppTab.invoices.rawValue
    @SceneStorage("openInvoice") private var savedInvoice = ""
    @State private var restored = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Invoices", systemImage: "doc.text.fill", value: AppTab.invoices) {
                InvoicesTab()
            }
            Tab("Buttons", systemImage: "circle.grid.2x2.fill", value: AppTab.buttons) {
                NavigationStack { CatalogView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .onAppear {
            // Shake to undo, and the three-finger swipe, act on the saved data
            // (Undo and redo).
            context.undoManager = undoManager
            restore()
            #if DEBUG
            // Probe: `-OrientationProbe landscape` turns the headless Simulator sideways.
            if UserDefaults.standard.string(forKey: "OrientationProbe") == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            #endif
        }
        .onChange(of: router.tab) { _, tab in savedTab = tab.rawValue }
        .onChange(of: router.invoicePath) { _, path in
            savedInvoice = path.last.map { $0.status == .draft ? $0.number : "" } ?? ""
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        guard router.request == nil else { return } // a quick action decides where to go
        router.tab = AppTab(rawValue: savedTab) ?? .invoices
        if !savedInvoice.isEmpty {
            let number = savedInvoice
            let match = try? context.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.number == number })).first
            if let match, match.status == .draft { router.invoicePath = [match] }
        }
    }
}

/// Home Screen quick actions (Home Screen quick actions guidelines): New Invoice and Add a
/// Button, defined in project.yml. SwiftUI keeps managing the window; this delegate only
/// passes the chosen action to the router.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickAction.perform(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickAction.perform(shortcutItem))
    }
}

enum QuickAction {
    @discardableResult @MainActor
    static func perform(_ item: UIApplicationShortcutItem) -> Bool {
        switch item.type {
        case "NewInvoice": AppRouter.shared.handle(.newInvoice)
        case "NewButton": AppRouter.shared.handle(.newButton)
        default: return false
        }
        return true
    }
}
