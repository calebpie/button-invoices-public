import InvoiceKit
import SwiftData
import SwiftUI

enum HomeRoute: Hashable {
    case invoice(Invoice)
    case finishedInvoices
    case buttons
    case settings
}

/// "Hello, Daphné. What would you like to do today?" and the five things she can do.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(BusinessSettings.self) private var settings
    @Query(sort: \Invoice.createdAt, order: .reverse) private var invoices: [Invoice]
    @Query private var variants: [ButtonVariant]
    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hello, \(settings.profile.greetingName).")
                            .font(.largeTitle.bold())
                        Text("What would you like to do today?")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    Button(action: newInvoice) {
                        Label("Start a new invoice", systemImage: "plus.circle.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)

                    if !drafts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Continue a draft").font(.headline).padding(.top, 8)
                            ForEach(drafts) { invoice in
                                NavigationLink(value: HomeRoute.invoice(invoice)) {
                                    DraftRow(invoice: invoice)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        HomeTile(title: "See or share a finished invoice", subtitle: finishedSubtitle,
                                 systemImage: "doc.richtext", route: .finishedInvoices)
                        HomeTile(title: "My buttons", subtitle: "\(variants.count) saved: photos, names and prices",
                                 systemImage: "circle.grid.2x2", route: .buttons)
                        HomeTile(title: "Business details", subtitle: "Address and bank account on the invoice",
                                 systemImage: "building.2", route: .settings)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .invoice(let invoice): InvoiceScreen(invoice: invoice)
                case .finishedInvoices: FinishedInvoicesView()
                case .buttons: CatalogView()
                case .settings: SettingsView()
                }
            }
            .onAppear(perform: removeEmptyDrafts)
        }
    }

    private var drafts: [Invoice] { invoices.filter { $0.status == .draft } }

    private var finishedSubtitle: String {
        let waiting = invoices.filter { $0.status == .finalized }.count
        let count = invoices.count - drafts.count
        if count == 0 { return "None yet" }
        return waiting > 0 ? "\(count) finished, \(waiting) waiting for payment" : "\(count) finished"
    }

    private func newInvoice() {
        let today = Date()
        let invoice = Invoice(number: InvoiceNumber.next(for: today, existing: invoices.map(\.number)), date: today)
        context.insert(invoice)
        try? context.save()
        path.append(.invoice(invoice))
    }

    /// An invoice she started and left without adding anything isn't kept.
    private func removeEmptyDrafts() {
        guard path.isEmpty else { return }
        for invoice in drafts where invoice.isEmpty {
            context.delete(invoice)
        }
    }
}

private struct HomeTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let route: HomeRoute

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

private struct DraftRow: View {
    let invoice: Invoice

    var body: some View {
        HStack {
            Image(systemName: "pencil.circle.fill").font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Invoice \(invoice.number)").font(.headline)
                Text("Started \(invoice.createdAt.formatted(.dateTime.day().month(.abbreviated))) · \(invoice.sortedLines.count) kinds of buttons")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(invoice.total.formatted).font(.headline).monospacedDigit()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .card()
    }
}

/// A draft opens in the step-by-step flow; a finished one opens its PDF.
struct InvoiceScreen: View {
    @Bindable var invoice: Invoice
    /// Set when she taps Finish, so the share sheet opens as soon as the PDF is ready.
    @State private var shareWhenOpened = false

    var body: some View {
        if invoice.status == .draft {
            InvoiceFlowView(invoice: invoice) { shareWhenOpened = true }
        } else {
            FinishedInvoiceView(invoice: invoice, shareWhenOpened: $shareWhenOpened)
        }
    }
}

/// Every finished invoice, unpaid first.
struct FinishedInvoicesView: View {
    @Query(sort: \Invoice.date, order: .reverse) private var invoices: [Invoice]

    var body: some View {
        List {
            ForEach([InvoiceStatus.finalized, .paid]) { status in
                let group = invoices.filter { $0.status == status }
                if !group.isEmpty {
                    Section(status == .finalized ? "Waiting for payment" : "Paid") {
                        ForEach(group) { invoice in
                            NavigationLink(value: HomeRoute.invoice(invoice)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(invoice.number).font(.headline)
                                        Text(invoice.date, format: .dateTime.day().month(.abbreviated).year())
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(invoice.total.formatted).font(.headline).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if !invoices.contains(where: { $0.status != .draft }) {
                ContentUnavailableView("No finished invoices yet", systemImage: "doc.richtext",
                                       description: Text("Invoices appear here after you tap Finish."))
            }
        }
        .readableWidth()
        .navigationTitle("Finished Invoices")
    }
}

extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}
