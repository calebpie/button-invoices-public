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
        #endif
    }

    #if DEBUG
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
            HomeView()
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
