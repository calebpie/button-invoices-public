import InvoiceKit
import QuickLook
import SwiftData
import SwiftUI

/// A finished invoice: its PDF, Share, paid or not, and Make Changes.
struct FinishedInvoiceView: View {
    @Bindable var invoice: Invoice
    @Binding var shareWhenOpened: Bool

    @Environment(BusinessSettings.self) private var settings
    @State private var pdfURL: URL?
    @State private var pages: [UIImage] = []
    @State private var sharing = false
    @State private var fullScreen: URL?
    @State private var confirmChanges = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(invoice.total.formatted).font(.largeTitle.bold()).monospacedDigit()
                        Spacer()
                        Text(invoice.status.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(invoice.status == .paid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                    }
                    Text("Invoice \(invoice.number) · \(invoice.date.formatted(.dateTime.day().month(.wide).year()))")
                        .foregroundStyle(.secondary)
                    Text("\(invoice.buttonCount) buttons · shipping \(invoice.shippingTotal.formatted)")
                        .foregroundStyle(.secondary)
                }
                .card()

                Button {
                    sharing = true
                } label: {
                    Label("Share the PDF", systemImage: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pdfURL == nil)
                Text("Send it by Messages, Mail or AirDrop, or save it to Files.")
                    .font(.footnote).foregroundStyle(.secondary)

                Toggle("Alix of Bohemia has paid", isOn: Binding(
                    get: { invoice.status == .paid },
                    set: { invoice.status = $0 ? .paid : .finalized }))
                    .card()

                PDFPages(pages: pages) { fullScreen = pdfURL }

                Button("Make Changes to This Invoice") { confirmChanges = true }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Invoice \(invoice.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Finished invoices print exactly what was saved when she tapped Finish.
            if let url = try? InvoiceExport.writePDF(invoice, profile: settings.profile) {
                pdfURL = url
                pages = PDFPages.render(url, width: 900)
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
        .confirmationDialog("Make changes to invoice \(invoice.number)?", isPresented: $confirmChanges, titleVisibility: .visible) {
            Button("Make Changes") {
                invoice.status = .draft
                invoice.finalizedAt = nil
            }
        } message: {
            Text("It goes back to being a draft. If you already sent it, send the new PDF when you finish.")
        }
    }
}
