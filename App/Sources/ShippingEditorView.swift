import InvoiceKit
import SwiftData
import SwiftUI

/// One shipping charge. A receipt photo is optional; the app reads the amounts on it and
/// she taps the one for this order.
struct ShippingEditorView: View {
    let invoice: Invoice
    let charge: ShippingCharge?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var note = ""
    @State private var receipt: Data?
    @State private var scan: ReceiptScan?
    @State private var reading = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Amount") {
                MoneyField(title: "Shipping cost", text: $amountText)
            }
            Section {
                if let receipt, let image = UIImage(data: receipt) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                }
                if reading {
                    ProgressView("Reading the receipt…")
                } else if let scan {
                    if scan.amounts.isEmpty {
                        Text("No amounts found. Type the amount above.").foregroundStyle(.secondary)
                    } else {
                        Text("Tap the amount for this order:").font(.subheadline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(scan.amounts, id: \.self) { amount in
                                    Button(amount.formatted) { amountText = amount.editingText }
                                        .buttonStyle(.bordered)
                                        .tint(Money(parsing: amountText) == amount ? .accentColor : .secondary)
                                }
                            }
                        }
                    }
                }
                PhotoSourceButtons(takeLabel: receipt == nil ? "Take Photo of Receipt" : "Retake Photo",
                                   chooseLabel: "Choose from Photos", onImage: read)
            } header: {
                Text("Receipt (optional)")
            } footer: {
                Text("Check the amount: the app can misread a circled or crumpled receipt.")
            }
            Section("Note (just for you)") {
                TextField("e.g. Shipped 9/2/2026", text: $note)
            }
            Section {
                Button(action: save) {
                    Text(charge == nil ? "Add Shipping" : "Save")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if let charge {
                    Button("Remove Shipping", role: .destructive) {
                        context.delete(charge)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .keyboardDoneButton()
        .navigationTitle("Shipping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .onAppear {
            guard !loaded, let charge else { return }
            loaded = true
            amountText = charge.amount.editingText
            note = charge.note
            receipt = charge.receiptPhoto
        }
    }

    private var amount: Money? { Money(parsing: amountText).flatMap { $0 > .zero ? $0 : nil } }

    private func read(_ image: CGImage) {
        receipt = ImageTools.jpegData(ImageTools.downscaled(image, maxSide: 2000), quality: 0.7)
        reading = true
        Task {
            let result = try? await ReceiptReader.read(image)
            reading = false
            scan = result ?? ReceiptScan(amounts: [], date: nil)
            if amountText.isEmpty, let first = result?.amounts.first { amountText = first.editingText }
            if note.isEmpty, let date = result?.date { note = "Shipped \(date)" }
        }
    }

    private func save() {
        guard let amount else { return }
        let target = charge ?? {
            let new = ShippingCharge(position: (invoice.shipping ?? []).count, amount: amount, note: note)
            context.insert(new)
            new.invoice = invoice
            return new
        }()
        target.amount = amount
        target.note = note.trimmingCharacters(in: .whitespaces)
        target.receiptPhoto = receipt
        dismiss()
    }
}
