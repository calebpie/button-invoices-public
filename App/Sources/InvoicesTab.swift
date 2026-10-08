import InvoiceKit
import SwiftData
import SwiftUI

/// The Invoices tab: a greeting, New Invoice, then drafts to continue and finished invoices
/// to see or share (SPEC.md, "Invoices").
struct InvoicesTab: View {
    @Environment(\.modelContext) private var context
    @Environment(BusinessSettings.self) private var settings
    @Query(sort: \Invoice.date, order: .reverse) private var invoices: [Invoice]
    @State private var path: [Invoice] = []
    @State private var pendingDelete: Invoice?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello, \(settings.profile.greetingName).").font(.title.bold())
                        Text("What would you like to do today?").foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
                    Button(action: newInvoice) {
                        Label("New Invoice", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(InvoiceStatus.allCases) { status in
                    let group = invoices.filter { $0.status == status }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { invoice in
                                NavigationLink(value: invoice) { InvoiceRow(invoice: invoice) }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = invoice }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("Copy", systemImage: "doc.on.doc") { duplicate(invoice) }.tint(.blue)
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
            .overlay {
                if invoices.isEmpty {
                    ContentUnavailableView("No invoices yet", systemImage: "doc.text",
                                           description: Text("Tap New Invoice to start one."))
                        .offset(y: 80)
                }
            }
            .readableWidth()
            .navigationTitle("Invoices")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: Invoice.self) { InvoiceScreen(invoice: $0) }
            .onAppear(perform: removeEmptyDrafts)
            .confirmationDialog(deleteTitle, isPresented: .init(get: { pendingDelete != nil },
                                                               set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete Invoice", role: .destructive) {
                    if let invoice = pendingDelete { context.delete(invoice) }
                    pendingDelete = nil
                }
            } message: {
                Text(pendingDelete?.status == .draft
                     ? "Your buttons stay saved; only this draft is removed."
                     : "This removes the invoice and its PDF from the app. Copies you already sent aren't affected.")
            }
        }
    }

    static func heading(_ status: InvoiceStatus) -> String {
        switch status {
        case .draft: "Drafts"
        case .finalized: "Finished, waiting for payment"
        case .paid: "Paid"
        }
    }

    private var deleteTitle: String {
        guard let invoice = pendingDelete else { return "" }
        return invoice.status == .draft ? "Delete draft \(invoice.number)?" : "Delete finished invoice \(invoice.number)?"
    }

    private func newInvoice() {
        let today = Date()
        let invoice = Invoice(number: InvoiceNumber.next(for: today, existing: invoices.map(\.number)), date: today)
        context.insert(invoice)
        try? context.save()
        path.append(invoice)
    }

    /// A new draft with the same buttons and quantities at today's prices, no shipping.
    private func duplicate(_ source: Invoice) {
        let today = Date()
        let copy = Invoice(number: InvoiceNumber.next(for: today, existing: invoices.map(\.number)), date: today)
        context.insert(copy)
        for line in source.sortedLines {
            let new = InvoiceLine(copying: line)
            context.insert(new)
            new.invoice = copy
        }
        try? context.save()
        path.append(copy)
    }

    /// An invoice she started and left without adding anything isn't kept.
    private func removeEmptyDrafts() {
        guard path.isEmpty else { return }
        for invoice in invoices where invoice.status == .draft && invoice.isEmpty {
            context.delete(invoice)
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(invoice.status == .paid ? Color.green : Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Invoice \(invoice.number)").font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(invoice.total.formatted).font(.headline).monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
        if invoice.status == .draft {
            InvoiceFlowView(invoice: invoice) { shareWhenOpened = true }
        } else {
            FinishedInvoiceView(invoice: invoice, shareWhenOpened: $shareWhenOpened)
        }
    }
}

extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}
