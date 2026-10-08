import AppIntents

/// App Shortcuts (App Shortcuts guidelines): start an invoice or add a button from Siri,
/// Spotlight, the Shortcuts app or the Action button. Both open the app at that screen.
struct NewInvoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "New Invoice"
    static let description = IntentDescription("Starts a new invoice for Alix of Bohemia.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.handle(.newInvoice)
        return .result()
    }
}

struct NewButtonIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Button"
    static let description = IntentDescription("Adds a new button design, starting with its photo.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.handle(.newButton)
        return .result()
    }
}

struct InvoicesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NewInvoiceIntent(), phrases: [
            "Start an invoice in \(.applicationName)",
            "New \(.applicationName)",
            "Make a new invoice in \(.applicationName)",
        ], shortTitle: "New Invoice", systemImageName: "doc.badge.plus")
        AppShortcut(intent: NewButtonIntent(), phrases: [
            "Add a button in \(.applicationName)",
        ], shortTitle: "Add a Button", systemImageName: "plus.circle")
    }
}
