import InvoiceKit
import SwiftData
import SwiftUI
import TipKit

/// The Invoices tab: a greeting, New Invoice, then drafts to continue and finished invoices
/// to see or share (SPEC.md, "Invoices"). Every swipe action is also in the row's context
/// menu and on the invoice's own screen (Accessibility, "Offer alternatives to gestures").
struct InvoicesTab: View {
    @Environment(\.modelContext) private var context
    @Environment(BusinessSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Query(sort: [SortDescriptor(\Invoice.date, order: .reverse), SortDescriptor(\Invoice.number, order: .reverse)])
    private var invoices: [Invoice]
    @State private var pendingDelete: Invoice?
    @State private var sharing: URL?
    private let repeatTip = RepeatOrderTip()

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.invoicePath) {
            List {
                Section {
                    // The greeting itself is the screen's title, in the bar (`shrinkingTitle`).
                    Text("What would you like to do today?")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                    Button(action: newInvoice) {
                        Label("New Invoice", systemImage: "plus.circle.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .prominentButton()
                    .keyboardShortcut("n", modifiers: .command)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if invoices.contains(where: { $0.status != .draft }) {
                    TipView(repeatTip)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                ForEach(InvoiceStatus.allCases) { status in
                    let group = invoices.filter { $0.status == status }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { invoice in
                                NavigationLink(value: invoice) { InvoiceRow(invoice: invoice) }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            // Asked once the row has slid closed; asked while
                                            // it closes, the question never appears.
                                            Task {
                                                try? await Task.sleep(for: .milliseconds(400))
                                                pendingDelete = invoice
                                            }
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(invoice) }
                                            .tint(.blue)
                                    }
                                    .contextMenu {
                                        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(invoice) }
                                        if invoice.status != .draft {
                                            Button("Share PDF…", systemImage: "square.and.arrow.up") {
                                                sharing = InvoiceExport.storedPDF(invoice, profile: settings.profile)
                                            }
                                        }
                                        Divider()
                                        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = invoice }
                                    }
                                    // On the row, so on iOS 26 the question points at the
                                    // invoice being deleted (Action sheets).
                                    .confirmationDialog(deleteTitle(invoice), isPresented: isDeleting(invoice),
                                                        titleVisibility: .visible) {
                                        Button("Delete Invoice", role: .destructive) {
                                            InvoiceActions.delete(invoice, context)
                                            pendingDelete = nil
                                        }
                                    } message: {
                                        Text(invoice.status == .draft
                                             ? "The buttons stay saved; only this draft is removed."
                                             : "This removes the invoice and its PDF from the app. Copies you already sent aren't affected.")
                                    }
                            }
                        } header: {
                            Text(Self.heading(status))
                        } footer: {
                            if status == .draft { Text("Tap a draft to carry on where you left off.") }
                        }
                    }
                }
            }
            // The question reads as the greeting's second line, not a section away.
            .contentMargins(.top, 0, for: .scrollContent)
            .shrinkingTitle(greeting)
            .overlay {
                if invoices.isEmpty {
                    ContentUnavailableView("No Invoices Yet", systemImage: "doc.text",
                                           description: Text("Tap New Invoice to start one."))
                        .offset(y: 80)
                }
            }
            .readableWidth()
            .navigationDestination(for: Invoice.self) { InvoiceScreen(invoice: $0) }
            .onAppear(perform: removeEmptyDrafts)
            .onAppear(perform: handleRequest)
            .onChange(of: router.request) { handleRequest() }
            .sheet(item: $sharing) { url in
                ShareSheet(url: url).presentationDetents([.medium, .large])
            }
        }
    }

    /// "Hello, Daphné." from Settings, as the tab's title (Caleb, Oct 8, 2026).
    private var greeting: String {
        let name = settings.profile.greetingName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Hello." : "Hello, \(name)."
    }

    static func heading(_ status: InvoiceStatus) -> String {
        switch status {
        case .draft: "Drafts"
        case .finalized: "Finished, waiting for payment"
        case .paid: "Paid"
        }
    }

    private func deleteTitle(_ invoice: Invoice) -> String {
        invoice.status == .draft ? "Delete draft \(invoice.number)?" : "Delete invoice \(invoice.number)?"
    }

    private func isDeleting(_ invoice: Invoice) -> Binding<Bool> {
        Binding(get: { pendingDelete?.persistentModelID == invoice.persistentModelID },
                set: { if !$0 { pendingDelete = nil } })
    }

    private func handleRequest() {
        guard router.request == .newInvoice else { return }
        router.request = nil
        newInvoice()
    }

    private func newInvoice() {
        router.invoicePath = [InvoiceActions.newInvoice(context, existing: invoices.map(\.number))]
    }

    private func duplicate(_ source: Invoice) {
        repeatTip.invalidate(reason: .actionPerformed)
        router.invoicePath = [InvoiceActions.duplicate(source, context, existing: invoices.map(\.number))]
    }

    /// An invoice she started and left without adding anything isn't kept.
    private func removeEmptyDrafts() {
        guard router.invoicePath.isEmpty else { return }
        for invoice in invoices where invoice.status == .draft && invoice.isEmpty {
            context.delete(invoice)
        }
    }
}

/// Creating, duplicating and deleting invoices, shared by the list and the invoice screens.
@MainActor enum InvoiceActions {
    static func newInvoice(_ context: ModelContext, existing: [String]) -> Invoice {
        let today = Date()
        let invoice = Invoice(number: InvoiceNumber.next(for: today, existing: existing), date: today)
        context.insert(invoice)
        try? context.save()
        return invoice
    }

    /// A new draft with the same buttons and quantities at today's prices, no shipping.
    static func duplicate(_ source: Invoice, _ context: ModelContext, existing: [String]) -> Invoice {
        let copy = newInvoice(context, existing: existing)
        for line in source.sortedLines {
            let new = InvoiceLine(copying: line)
            context.insert(new)
            new.invoice = copy
        }
        try? context.save()
        return copy
    }

    /// Deleting can be undone with a shake (Undo and redo, "describe the operation").
    static func delete(_ invoice: Invoice, _ context: ModelContext) {
        context.undoManager?.setActionName("Delete Invoice")
        context.delete(invoice)
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        AdaptiveRow {
            IconTextStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(invoice.status == .paid ? Color.green : Color.accentColor)
                    .frame(minWidth: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invoice \(invoice.number)").font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Text(invoice.total.formatted).font(.headline).monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(invoice.status.label)
    }

    private var icon: String {
        switch invoice.status {
        case .draft: "pencil.circle.fill"
        case .finalized: "paperplane.circle.fill"
        case .paid: "checkmark.circle.fill"
        }
    }

    private var detail: String {
        let date = invoice.date.formatted(.dateTime.day().month(.abbreviated).year())
        let kinds = invoice.sortedLines.count
        return "\(date) · \(kinds == 1 ? "1 kind" : "\(kinds) kinds") of buttons"
    }
}

/// A draft opens in the step-by-step flow; a finished one opens its PDF.
struct InvoiceScreen: View {
    @Bindable var invoice: Invoice
    /// Set when she taps Finish, so the share sheet opens as soon as the PDF is shown.
    @State private var shareWhenOpened = false

    var body: some View {
        Group {
            if invoice.status == .draft {
                InvoiceFlowView(invoice: invoice) { shareWhenOpened = true }
            } else {
                FinishedInvoiceView(invoice: invoice, shareWhenOpened: $shareWhenOpened)
            }
        }
        .finishHaptic(invoice.status != .draft)
    }
}
