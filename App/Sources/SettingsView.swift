import InvoiceKit
import QuickLook
import SwiftData
import SwiftUI

/// The Settings tab (SPEC.md, "Settings"): each field printed on the invoice, in the order
/// it appears on the page. Changes apply to drafts and new invoices; finished invoices keep
/// the details and PDF they were finished with.
struct SettingsView: View {
    @Environment(BusinessSettings.self) private var settings
    @Query private var variants: [ButtonVariant]
    @Query private var invoices: [Invoice]
    @State private var preview: URL?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Label("Changes here go on new invoices and drafts. Finished invoices keep the details they were finished with.",
                      systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                field("Name", text: $settings.profile.sellerName, prompt: "Daphné Verley Ceramics")
                line($settings.profile.sellerLines, 0, "Street", prompt: "123 Example St")
                line($settings.profile.sellerLines, 1, "Town", prompt: "Warren, RI 02805")
                line($settings.profile.sellerLines, 2, "Phone", prompt: "(401) 555-0100", keyboard: .phonePad)
            } header: {
                Text("Business")
            } footer: {
                Text("Top left of the invoice. The name is printed in bold.")
            }

            Section {
                field("Name", text: $settings.profile.billToName, prompt: "Alix of Bohemia")
                line($settings.profile.billToLines, 0, "Street", prompt: "61 Greenpoint Avenue")
                line($settings.profile.billToLines, 1, "City", prompt: "Brooklyn, NY")
                line($settings.profile.billToLines, 2, "ZIP", prompt: "11222", keyboard: .numbersAndPunctuation)
            } header: {
                Text("Bill to")
            } footer: {
                Text("Under BILL TO, on the left.")
            }

            Section {
                field("Above each name", text: $settings.profile.productLabel, prompt: "BUTTON")
                field("Below each name", text: $settings.profile.makerLine, prompt: "daphné verley ceramics")
            } header: {
                Text("Each button on the invoice")
            } footer: {
                Text("Printed above and below each button's name, like “BUTTON / Nautilus, Black / daphné verley ceramics”.")
            }

            Section {
                field("Routing", text: $settings.profile.routing, prompt: "Routing number", keyboard: .numberPad)
                field("Account", text: $settings.profile.account, prompt: "Account number", keyboard: .numberPad)
            } header: {
                Text("Payment")
            } footer: {
                Text("Bottom left, beside the totals, so Alix of Bohemia knows where to pay.")
            }

            Section {
                field("Starts with", text: $settings.profile.fileNamePrefix, prompt: "Daphné Verley Invoice - AOB")
            } header: {
                Text("PDF file name")
            } footer: {
                Text("The PDF is named “\(InvoicePDF.fileName(prefix: settings.profile.fileNamePrefix, number: InvoiceNumber.base(for: Date())))”.")
            }

            Section {
                Button {
                    preview = samplePDF()
                } label: {
                    Label("Preview Sample Invoice", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section {
                field("Hello,", text: $settings.profile.greetingName, prompt: "Daphné")
            } header: {
                Text("Invoices tab greeting")
            }

            Section {
                LabeledContent("Buttons saved", value: "\(variants.count)")
                LabeledContent("Invoices", value: "\(invoices.count)")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            } header: {
                Text("About")
            } footer: {
                Text("Everything is kept on this device and included in its iCloud Backup. The bank numbers are kept in the device's keychain.")
            }
        }
        .readableWidth()
        .navigationTitle("Settings")
        .quickLookPreview($preview)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        LabeledContent(label) {
            TextField(label, text: text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .onChange(of: text.wrappedValue) { _, new in
                    // Bank numbers are digits only.
                    if keyboard == .numberPad, NumericInput.whole.clean(new) != new {
                        text.wrappedValue = NumericInput.whole.clean(new)
                    }
                }
        }
    }

    /// One line of an address kept as a list of lines; trailing empty lines are dropped.
    private func line(_ lines: Binding<[String]>, _ i: Int, _ label: String, prompt: String,
                      keyboard: UIKeyboardType = .default) -> some View {
        field(label, text: Binding(
            get: { i < lines.wrappedValue.count ? lines.wrappedValue[i] : "" },
            set: { value in
                var all = lines.wrappedValue
                while all.count <= i { all.append("") }
                all[i] = value
                while all.last?.isEmpty == true { all.removeLast() }
                lines.wrappedValue = all
            }), prompt: prompt, keyboard: keyboard)
    }

    /// Two saved buttons and a shipping line, with the current details. Nothing is saved.
    private func samplePDF() -> URL? {
        let profile = settings.profile
        let picks = variants.filter { !$0.isHidden && $0.price > .zero }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }.prefix(2)
        let lines = picks.map { v in
            InvoiceDocument.Line(sku: v.sku, productLabel: profile.productLabel, description: v.title,
                                 makerLine: profile.makerLine, quantity: 10, unitPrice: v.price,
                                 image: v.photo.flatMap { ImageTools.uprightImage(from: $0, maxSide: 400) })
        }
        let doc = InvoiceDocument(number: "SAMPLE", date: Date(), seller: profile.seller, billTo: profile.billTo,
                                  lines: Array(lines), shipping: [Money(cents: 1621)], payment: profile.payment,
                                  logo: InvoiceExport.logo)
        return try? InvoiceExport.write(InvoicePDF.render(doc), number: "SAMPLE", profile: profile)
    }
}
