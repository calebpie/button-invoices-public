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
        if let n = UserDefaults.standard.string(forKey: "UndoSaveProbe").flatMap(Int.init) { Self.runUndoSaveProbe(n) }
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
    /// Probe: deletes an invoice with two lines, undoes it, saves, and logs what a fresh
    /// context reads back from the store. Once with no save between the delete and the
    /// undo, once with one (the app's autosave). Uses a throwaway store in tmp.
    static func runUndoSaveProbe(_ only: Int) {
        let log = Logger(subsystem: "InvoiceKit", category: "Probe")
        // 0: no save between; 1: delete saved first; 2: as 1, then re-insert what undo put
        // back; 3: a saved field change (statusRaw) instead of a delete, undone and saved.
        // 4: our own undo: registration off while deleting (5: undo manager detached
        // instead), saved, then an undo step that inserts a copy.
        // One case per launch (`-UndoSaveProbe N`): cases in one process trip each other.
        for saveBetween in [only] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("undo-probe-\(saveBetween).store")
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
            // Written by one container, then read by another, as on any launch after the first.
            do {
                guard let writer = try? ModelContainer(for: Schema(AppSchema.models),
                                                       configurations: ModelConfiguration(url: url)) else { return }
                let w = ModelContext(writer)
                let design = ButtonDesign(name: "Heart", code: "H")
                w.insert(design)
                let heart = ButtonVariant(design: design, colors: ["Navy"], size: "Medium", sku: "26HNM", price: Money(cents: 400), photo: nil)
                w.insert(heart)
                let invoice = Invoice(number: "0261008-2", date: Date())
                w.insert(invoice)
                for i in 0..<2 {
                    let line = InvoiceLine(position: i, variant: heart, quantity: 12, unitPrice: heart.price)
                    w.insert(line)
                    line.invoice = invoice
                }
                try? w.save()
            }
            guard let container = try? ModelContainer(for: Schema(AppSchema.models),
                                                      configurations: ModelConfiguration(url: url)) else { return }
            let ctx = container.mainContext // as the app's; a separate ModelContext traps on undo
            ctx.autosaveEnabled = false
            defer { ctx.undoManager = nil } // or the next case's undo trips this context
            // Attached after the data exists, as RootView does at launch.
            let undo = UndoManager()
            undo.groupsByEvent = false // runs before the UI: groups are opened and closed here
            ctx.undoManager = undo
            func group(_ body: () -> Void) { undo.beginUndoGrouping(); body(); undo.endUndoGrouping() }
            guard let invoice = try? ctx.fetch(FetchDescriptor<Invoice>()).first else { return }
            func count<T: PersistentModel>(_ c: ModelContext, _: T.Type) -> Int { (try? c.fetchCount(FetchDescriptor<T>())) ?? -1 }
            func stored() -> String {
                let fresh = ModelContext(container)
                return "stored invoices=\(count(fresh, Invoice.self)) lines=\(count(fresh, InvoiceLine.self))"
            }
            log.notice("probe: undo-save[\(saveBetween)] before: \(stored(), privacy: .public)")

            if saveBetween == 3 {
                group { invoice.statusRaw = InvoiceStatus.paid.rawValue }
                try? ctx.save()
                log.notice("probe: undo-save[3] field saved: stored \((try? ModelContext(container).fetch(FetchDescriptor<Invoice>()))?.first?.statusRaw ?? "none", privacy: .public)")
                undo.undo()
                try? ctx.save()
                let fresh = ModelContext(container)
                let back = (try? fresh.fetch(FetchDescriptor<Invoice>()))?.first
                log.notice("probe: undo-save[3] field: in context \(invoice.statusRaw, privacy: .public), stored \(back?.statusRaw ?? "none", privacy: .public)")
                continue
            }
            if saveBetween >= 4 {
                let number = invoice.number, date = invoice.date
                let saved = invoice.sortedLines.map { (sku: $0.sku, description: $0.itemDescription, quantity: $0.quantity, price: $0.unitPrice) }
                if saveBetween == 4 { undo.disableUndoRegistration() } else { ctx.undoManager = nil }
                ctx.delete(invoice)
                try? ctx.save()
                if saveBetween == 4 { undo.enableUndoRegistration() } else { ctx.undoManager = undo }
                log.notice("probe: undo-save[\(saveBetween)] deleted+saved: \(stored(), privacy: .public) canUndo=\(undo.canUndo) name='\(undo.undoActionName, privacy: .public)'")
                undo.beginUndoGrouping()
                undo.registerUndo(withTarget: ctx) { ctx in
                    MainActor.assumeIsolated {
                        let copy = Invoice(number: number, date: date)
                        ctx.insert(copy)
                        for (i, l) in saved.enumerated() {
                            let line = InvoiceLine(position: i, sku: l.sku, description: l.description, quantity: l.quantity, unitPrice: l.price)
                            ctx.insert(line)
                            line.invoice = copy
                        }
                    }
                }
                undo.setActionName("Delete Draft")
                undo.endUndoGrouping()
                log.notice("probe: undo-save[\(saveBetween)] registered: canUndo=\(undo.canUndo) name='\(undo.undoActionName, privacy: .public)'")
                undo.undo()
                try? ctx.save()
                log.notice("probe: undo-save[\(saveBetween)] undone+saved: \(stored(), privacy: .public) canUndo=\(undo.canUndo) canRedo=\(undo.canRedo)")
                continue
            }
            group { ctx.delete(invoice) } // as InvoiceActions.delete
            log.notice("probe: undo-save[\(saveBetween)] deleted: canUndo=\(undo.canUndo) isDeleted=\(invoice.isDeleted) context lines=\(invoice.lines?.count ?? -1) hasChanges=\(ctx.hasChanges)")
            if saveBetween > 0 {
                try? ctx.save()
                log.notice("probe: undo-save[\(saveBetween)] saved delete: \(stored(), privacy: .public) canUndo=\(undo.canUndo)")
            }
            undo.undo()
            if saveBetween == 2 { for model in ctx.insertedModelsArray { ctx.insert(model) } }
            let inContext = (try? ctx.fetch(FetchDescriptor<Invoice>())) ?? []
            log.notice("probe: undo-save[\(saveBetween)] undone: isDeleted=\(invoice.isDeleted) context invoices=\(inContext.count) lines=\(invoice.lines?.count ?? -1) hasChanges=\(ctx.hasChanges) inserted=\(ctx.insertedModelsArray.count) deleted=\(ctx.deletedModelsArray.count) changed=\(ctx.changedModelsArray.count)")
            do { try ctx.save() } catch { log.notice("probe: undo-save[\(saveBetween)] save error \(String(describing: error), privacy: .public)") }
            log.notice("probe: undo-save[\(saveBetween)] after save: \(stored(), privacy: .public)")
        }
    }

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
                .keyboardHandling()
                .shakeToUndo()
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
            // Shake to undo, and the three-finger swipe (Undo and redo). Not attached to the
            // data: the app records its own undo steps (Undo.swift).
            Undo.manager = undoManager
            restore()
            #if DEBUG
            // Probe: `-OrientationProbe landscape` turns the headless Simulator sideways.
            if UserDefaults.standard.string(forKey: "OrientationProbe") == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            #endif
        }
        #if DEBUG
        // Probe: `-UndoProbe YES` logs, every 2 s, which undo manager a shake would find.
        .task {
            guard UserDefaults.standard.bool(forKey: "UndoProbe") else { return }
            let log = Logger(subsystem: "InvoiceKit", category: "Probe")
            @MainActor func describe(_ u: UndoManager?) -> String {
                guard let u else { return "nil" }
                return "\(Unmanaged.passUnretained(u).toOpaque()) canUndo=\(u.canUndo) name='\(u.undoActionName)'"
            }
            while !Task.isCancelled {
                let first = UIResponder.current
                let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows).first { $0.isKeyWindow }
                log.notice("probe: undo first=\(first.map { String(describing: type(of: $0)) } ?? "none", privacy: .public) firstUM=\(describe(first?.undoManager), privacy: .public) windowUM=\(describe(window?.undoManager), privacy: .public) envUM=\(describe(undoManager), privacy: .public) contextUM=\(describe(context.undoManager), privacy: .public) shakeToEdit=\(UIApplication.shared.applicationSupportsShakeToEdit)")
                try? await Task.sleep(for: .seconds(2))
            }
        }
        // Probe: `-KeyProbe YES` logs the responder chain from the first responder, with the
        // keyboard shortcuts each link offers, and every view controller's shortcuts.
        .task {
            guard UserDefaults.standard.bool(forKey: "KeyProbe") else { return }
            let log = Logger(subsystem: "InvoiceKit", category: "Probe")
            try? await Task.sleep(for: .seconds(3))
            @MainActor func keys(_ r: UIResponder) -> String {
                (r.keyCommands ?? []).map { "\($0.modifierFlags.contains(.command) ? "⌘" : "")\($0.input ?? "?")" }.joined(separator: ",")
            }
            var link = UIResponder.current
            while let r = link {
                log.notice("probe: key chain \(String(describing: type(of: r)), privacy: .public) [\(keys(r), privacy: .public)]")
                link = r.next
            }
            @MainActor func walk(_ vc: UIViewController, _ depth: Int) {
                log.notice("probe: key vc \(depth) \(String(describing: type(of: vc)), privacy: .public) [\(keys(vc), privacy: .public)] view [\(keys(vc.view), privacy: .public)]")
                vc.children.forEach { walk($0, depth + 1) }
                if let p = vc.presentedViewController, p.presentingViewController === vc { walk(p, depth + 1) }
            }
            let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).first { $0.isKeyWindow }
            if let root = window?.rootViewController { walk(root, 0) }
        }
        #endif
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
