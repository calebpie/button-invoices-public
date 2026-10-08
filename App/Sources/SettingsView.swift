import InvoiceKit
import SwiftData
import SwiftUI

/// Business details: what's printed at the top and bottom of every invoice.
struct SettingsView: View {
    @Environment(BusinessSettings.self) private var settings
    @Query private var variants: [ButtonVariant]
    @Query private var invoices: [Invoice]

    var body: some View {
        @Bindable var settings = settings
        Form {
                Section("Your business") {
                    TextField("Business name", text: $settings.profile.sellerName)
                    lines($settings.profile.sellerLines, placeholders: ["Street", "Town, State ZIP", "Phone"])
                }
                Section("Bill to") {
                    TextField("Customer name", text: $settings.profile.billToName)
                    lines($settings.profile.billToLines, placeholders: ["Street", "City, State", "ZIP"])
                }
                Section {
                    TextField("Routing number", text: $settings.profile.routing).keyboardType(.numberPad)
                    TextField("Account number", text: $settings.profile.account).keyboardType(.numberPad)
                } header: {
                    Text("Payment details")
                } footer: {
                    Text("Printed at the bottom of each invoice.")
                }
                Section {
                    TextField("Above each name", text: $settings.profile.productLabel)
                    TextField("Below each name", text: $settings.profile.makerLine)
                    TextField("PDF name starts with", text: $settings.profile.fileNamePrefix)
                    LabeledContent("Home screen says Hello,") {
                        TextField("Name", text: $settings.profile.greetingName).multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Invoice wording")
                } footer: {
                    Text("The PDF is named “\(InvoicePDF.fileName(prefix: settings.profile.fileNamePrefix, number: "0260903"))”.")
                }
                Section {
                    LabeledContent("Buttons saved", value: "\(variants.count)")
                    LabeledContent("Invoices", value: "\(invoices.count)")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                } header: {
                    Text("About")
                } footer: {
                    Text("Everything is stored on this device and included in its iCloud Backup.")
                }
            }
            .readableWidth()
            .navigationTitle("Business Details")
    }

    /// Three single-line fields over an array of lines.
    private func lines(_ binding: Binding<[String]>, placeholders: [String]) -> some View {
        ForEach(placeholders.indices, id: \.self) { i in
            TextField(placeholders[i], text: Binding(
                get: { i < binding.wrappedValue.count ? binding.wrappedValue[i] : "" },
                set: { value in
                    var lines = binding.wrappedValue
                    while lines.count <= i { lines.append("") }
                    lines[i] = value
                    while lines.last?.isEmpty == true { lines.removeLast() }
                    binding.wrappedValue = lines
                }))
        }
    }
}
