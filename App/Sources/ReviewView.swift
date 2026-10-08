import InvoiceKit
import QuickLook
import SwiftData
import SwiftUI

/// Step 3: everything on the invoice, the checks, and a preview of the PDF.
struct ReviewStep: View {
    @Bindable var invoice: Invoice
    let goTo: (FlowStep) -> Void

    @Environment(BusinessSettings.self) private var settings
    @Query private var allInvoices: [Invoice]
    @State private var expectedText = ""
    @State private var pages: [UIImage] = []
    @State private var pdfURL: URL?
    @State private var fullScreen: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StepGuide(number: 3, text: "Check everything. Tap Change to fix a part, or Finish when it's right.")

                let checks = Self.checks(invoice, others: otherNumbers, profile: profile)
                if !checks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(checks) { check in
                            Label(check.text, systemImage: check.level == .problem ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(check.level == .problem ? .red : .orange)
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Invoice #") {
                        TextField("Invoice #", text: numberBinding)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospacedDigit())
                    }
                    DatePicker("Date", selection: $invoice.date, displayedComponents: .date)
                    if invoice.businessSnapshot != nil && profile != settings.profile {
                        Divider()
                        Text("This invoice keeps the business details it was first finished with, not the ones in Settings now.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Use Current Settings") { invoice.businessSnapshot = nil }
                            .font(.subheadline)
                    }
                }
                .card()
                .onChange(of: invoice.date) { _, date in
                    if !invoice.numberIsCustom { invoice.number = InvoiceNumber.next(for: date, existing: otherNumbers) }
                }

                section("Buttons", step: .buttons) {
                    ForEach(invoice.sortedLines) { line in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.itemDescription)
                                Text("\(line.quantity) × \(line.unitPrice.formatted)" + (line.discountText.map { ", \($0)" } ?? ""))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(line.subtotal.formatted).monospacedDigit()
                        }
                    }
                    Divider()
                    row("Buttons subtotal", invoice.buttonsSubtotal, bold: true)
                }

                section("Shipping", step: .shipping) {
                    if invoice.sortedShipping.isEmpty {
                        Text("No shipping").foregroundStyle(.secondary)
                    }
                    ForEach(invoice.sortedShipping) { charge in
                        row(charge.note.isEmpty ? "Shipping" : charge.note, charge.amount)
                    }
                }

                HStack {
                    Text("Total due").font(.title3.bold())
                    Spacer()
                    Text(invoice.total.formatted).font(.title.bold()).monospacedDigit()
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare with your own total (optional)").font(.subheadline.weight(.semibold))
                    MoneyField(title: "Total from your notes", text: $expectedText)
                    if let expected = Money(parsing: expectedText) {
                        if expected == invoice.total {
                            Label("Matches.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            let gap = expected - invoice.total
                            Label("Your total is \(Money(cents: abs(gap.cents)).formatted) \(gap.cents > 0 ? "more" : "less") than the invoice. Check the quantities and shipping.",
                                  systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                }
                .card()

                Text("The PDF").font(.headline).heading()
                PDFPages(pages: pages) { fullScreen = pdfURL }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .task(id: fingerprint) {
            if let url = try? InvoiceExport.writePDF(invoice, profile: profile) {
                pdfURL = url
                pages = PDFPages.render(url, width: 900)
            }
        }
        .quickLookPreview($fullScreen)
    }

    private func section(_ title: String, step: FlowStep, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline).heading()
                Spacer()
                Button("Change") { goTo(step) }.buttonStyle(.bordered).controlSize(.small)
                    .accessibilityLabel("Change \(title)")
            }
            content()
        }
        .card()
    }

    private func row(_ label: String, _ amount: Money, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount.formatted).monospacedDigit()
        }
        .fontWeight(bold ? .semibold : .regular)
    }

    /// The details this invoice will print with.
    private var profile: BusinessProfile { invoice.businessProfile(current: settings.profile) }

    private var otherNumbers: [String] {
        allInvoices.filter { $0.persistentModelID != invoice.persistentModelID }.map(\.number)
    }

    private var numberBinding: Binding<String> {
        Binding(get: { invoice.number }, set: { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            invoice.numberIsCustom = !trimmed.isEmpty
            invoice.number = trimmed.isEmpty ? InvoiceNumber.next(for: invoice.date, existing: otherNumbers) : trimmed
        })
    }

    /// Changes whenever something printed on the invoice changes.
    private var fingerprint: String {
        var parts = [invoice.number, invoice.date.description, String(invoice.total.cents)]
        parts += invoice.sortedLines.map { "\($0.sku)\($0.itemDescription)\($0.quantity)\($0.unitPriceCents)\($0.discountCents)\($0.photo?.count ?? 0)" }
        parts += invoice.sortedShipping.map { String($0.amountCents) }
        parts.append(String(describing: profile))
        return parts.joined(separator: "|")
    }

    // MARK: Checks

    struct Check: Identifiable {
        enum Level { case problem, warning }
        let id = UUID()
        let level: Level
        let text: String
    }

    /// Problems stop Finish; warnings don't.
    static func checks(_ invoice: Invoice, others: [String], profile: BusinessProfile) -> [Check] {
        var out: [Check] = []
        let lines = invoice.sortedLines
        if lines.isEmpty { out.append(.init(level: .problem, text: "Add at least one button.")) }
        for line in lines where line.unitPrice <= .zero || line.quantity <= 0 {
            out.append(.init(level: .problem, text: "\(line.itemDescription) needs a quantity and a price."))
        }
        if invoice.number.isEmpty || others.contains(invoice.number) {
            out.append(.init(level: .problem, text: "Invoice number \(invoice.number) is already used. Change it above."))
        }
        for line in lines where line.photo == nil {
            out.append(.init(level: .warning, text: "\(line.itemDescription) has no photo."))
        }
        let skus = lines.map(\.sku)
        for sku in Set(skus) where skus.filter({ $0 == sku }).count > 1 {
            out.append(.init(level: .warning, text: "\(sku) is on the invoice more than once."))
        }
        if profile.routing.isEmpty || profile.account.isEmpty {
            out.append(.init(level: .warning, text: "The bank routing or account number is empty (Home → Business details)."))
        }
        return out
    }

    static func canFinish(_ invoice: Invoice, others: [String]) -> Bool {
        !checks(invoice, others: others, profile: BusinessProfile()).contains { $0.level == .problem }
    }
}

/// The PDF's pages as pictures; tapping one opens the real PDF full screen.
struct PDFPages: View {
    let pages: [UIImage]
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if pages.isEmpty { ProgressView().frame(maxWidth: .infinity, minHeight: 200) }
            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                Image(uiImage: page).resizable().scaledToFit()
                    .background(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .onTapGesture(perform: onTap)
                    .accessibilityLabel("Invoice page. Double-tap to see it full size.")
            }
            if !pages.isEmpty {
                Text("Tap the page to see it full size.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    static func render(_ url: URL, width: CGFloat) -> [UIImage] {
        guard let doc = CGPDFDocument(url as CFURL) else { return [] }
        return (1...max(doc.numberOfPages, 1)).compactMap { i in
            guard let page = doc.page(at: i) else { return nil }
            let box = page.getBoxRect(.mediaBox)
            let scale = width / box.width
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: width, height: box.height * scale), format: format).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: box.height * scale))
                ctx.cgContext.translateBy(x: 0, y: box.height * scale)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                ctx.cgContext.drawPDFPage(page)
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// The system share sheet for a file: Messages, Mail, AirDrop, Save to Files, Print.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
