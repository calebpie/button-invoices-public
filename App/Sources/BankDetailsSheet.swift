import InvoiceKit
import SwiftUI

/// The two bank numbers, opened from the warning on Review so she can fill them in without
/// leaving the invoice (Writing, "provide a direct link or button, rather than trying to
/// describe its location"). The same values as Settings → Payment.
struct BankDetailsSheet: View {
    @Bindable var invoice: Invoice

    @Environment(BusinessSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var routing = ""
    @State private var account = ""
    @State private var loaded = false
    @State private var askDiscard = false

    var body: some View {
        Form {
            Section {
                number("Routing", text: $routing, prompt: "Routing number")
                number("Account", text: $account, prompt: "Account number")
            } footer: {
                Text("Printed bottom left, beside the totals, so Alix of Bohemia knows where to pay. Also in Settings, under Payment.")
            }
            Section {
                Button(action: save) {
                    Text("Save").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .prominentButton()
                .disabled(problem != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let problem { Text(problem).foregroundStyle(.orange) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Bank Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CancelButton { if isDirty { askDiscard = true } else { dismiss() } }
                    .discardQuestion(isAsking: $askDiscard) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton(title: "Save", action: save).disabled(problem != nil)
            }
        }
        .confirmsDiscard(isDirty) { dismiss() }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            routing = settings.profile.routing
            account = settings.profile.account
        }
    }

    private func number(_ label: String, text: Binding<String>, prompt: String) -> some View {
        LabeledContent(label) {
            TextField(label, text: text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .numericInput(text, .whole)
        }
    }

    private var problem: String? {
        routing.isEmpty || account.isEmpty ? "Enter both numbers." : nil
    }

    private var isDirty: Bool { routing != settings.profile.routing || account != settings.profile.account }

    private func save() {
        settings.profile.routing = routing
        settings.profile.account = account
        // A reopened invoice prints the details it was finished with; give it the numbers too,
        // and nothing else of what's in Settings now.
        if var snapshot = invoice.businessSnapshot.flatMap({ try? JSONDecoder().decode(BusinessProfile.self, from: $0) }) {
            snapshot.routing = routing
            snapshot.account = account
            invoice.businessSnapshot = try? JSONEncoder().encode(snapshot)
        }
        dismiss()
    }
}
