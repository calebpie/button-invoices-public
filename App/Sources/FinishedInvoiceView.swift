import InvoiceKit
import QuickLook
import SwiftData
import SwiftUI

/// A finished invoice: its stored PDF, Share, paid or not, and a More menu with Duplicate,
/// Make Changes and Delete. Share sits in the toolbar where people look for it, and as the
/// screen's one prominent button (Collaboration and sharing; Buttons).
struct FinishedInvoiceView: View {
    @Bindable var invoice: Invoice
    @Binding var shareWhenOpened: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(BusinessSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Query private var allInvoices: [Invoice]
    @State private var pdfURL: URL?
    @State private var pages: [UIImage] = []
    @State private var sharing = false
    @State private var fullScreen: URL?
    @State private var confirmChanges = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(invoice.total.formatted).font(.largeTitle.bold()).monospacedDigit()
                        .textSelection(.enabled)
                    Text("Invoice \(invoice.number) · \(invoice.date.formatted(.dateTime.day().month(.wide).year()))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("\(invoice.buttonCount) buttons · shipping \(invoice.shippingTotal.formatted)")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    sharing = true
                } label: {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pdfURL == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Send it by Messages, Mail or AirDrop, or save it to Files.")
            }

            Section {
                // A switch belongs in a list row (Toggles).
                Toggle("Alix of Bohemia has paid", isOn: Binding(
                    get: { invoice.status == .paid },
                    set: { invoice.status = $0 ? .paid : .finalized }))
            }

            Section("The PDF") {
                PDFPages(pages: pages) { fullScreen = pdfURL }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
        .readableWidth()
        .navigationTitle("Invoice \(invoice.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let pdfURL { ShareLink(item: pdfURL) }
            }
            // Top bar trailing, not secondary: a secondary item lands inside the system's own
            // overflow menu, which made her tap ⋯ and then More.
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .task {
            // Exactly the PDF made when she tapped Finish; later edits to buttons or
            // Settings don't reach it.
            pdfURL = InvoiceExport.storedPDF(invoice, profile: settings.profile)
            if let pdfURL {
                pages = PDFPages.render(pdfURL, width: 900)
                if shareWhenOpened {
                    shareWhenOpened = false
                    sharing = true
                }
            }
        }
        .sheet(isPresented: $sharing) {
            if let pdfURL {
                ShareSheet(url: pdfURL).presentationDetents([.medium, .large])
            }
        }
        .quickLookPreview($fullScreen)
    }

    private var moreMenu: some View {
        Menu {
            Button("Duplicate", systemImage: "plus.square.on.square") {
                router.invoicePath = [InvoiceActions.duplicate(invoice, context, existing: allInvoices.map(\.number))]
            }
            Button("Make Changes…", systemImage: "pencil") { confirmChanges = true }
            Divider()
            Button("Delete…", systemImage: "trash", role: .destructive) { confirmDelete = true }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        // On the menu, so on iOS 26 the questions point at ⋯.
        .confirmationDialog("Make changes to invoice \(invoice.number)?", isPresented: $confirmChanges, titleVisibility: .visible) {
            Button("Make Changes") {
                invoice.status = .draft
                invoice.finalizedAt = nil
                invoice.finishedPDF = nil
            }
        } message: {
            Text("It goes back to being a draft. If you already sent it, send the new PDF when you finish.")
        }
        .confirmationDialog("Delete invoice \(invoice.number)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Invoice", role: .destructive) {
                dismiss()
                InvoiceActions.delete(invoice, context)
            }
        } message: {
            Text("This removes the invoice and its PDF from the app. Copies you already sent aren't affected.")
        }
    }
}
