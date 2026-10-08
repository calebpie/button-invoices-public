import InvoiceKit
import SwiftData
import SwiftUI

/// Quantity, price and discount for one line, adding it or changing it.
struct LineEditorView: View {
    enum Mode {
        case new(invoice: Invoice, variant: ButtonVariant, request: OrderRequest, search: String)
        case edit(InvoiceLine)
    }

    let mode: Mode
    var onDone: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var discountText = ""
    @State private var discountIsPercent = false
    @State private var showDiscount = false
    @State private var savePrice = false
    @State private var loaded = false
    @FocusState private var quantityFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    ButtonPhoto(data: photo, side: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.title3.bold())
                        Text(sku).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("How many?") {
                TextField("Quantity", text: $quantityText)
                    .keyboardType(.numberPad)
                    .font(.title.monospacedDigit())
                    .focused($quantityFocused)
            }

            Section {
                MoneyField(title: "Price each", text: $priceText)
                if let variant, let price, price != variant.price {
                    Toggle("Save \(price.formatted) as this button's price from now on", isOn: $savePrice)
                }
            } header: {
                Text("Price each")
            } footer: {
                if let variant { Text("Saved price: \(variant.price.formatted)") }
            }

            Section {
                if showDiscount {
                    Picker("Discount in", selection: $discountIsPercent) {
                        Text("$ off each button").tag(false)
                        Text("% off").tag(true)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        if !discountIsPercent { Text("$").foregroundStyle(.secondary) }
                        TextField(discountIsPercent ? "Percent off" : "Dollars off each button", text: $discountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                        if discountIsPercent { Text("%").foregroundStyle(.secondary) }
                        if discount == nil {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                                .accessibilityLabel("Not a valid discount")
                        }
                    }
                    if discountIsPercent, let discount, discount > .zero {
                        Text("\(discount.formatted) off each button").foregroundStyle(.secondary)
                    }
                    Button("No discount", role: .destructive) {
                        discountText = ""
                        showDiscount = false
                    }
                } else {
                    Button("Add a discount", systemImage: "tag") { showDiscount = true }
                }
            } header: {
                Text("Discount")
            } footer: {
                if showDiscount { Text("Taken off the price of each button. The invoice shows it in dollars.") }
            }

            Section {
                LabeledContent("Line total") {
                    Text(lineTotal?.formatted ?? "—").font(.title3.bold()).monospacedDigit()
                }
                if let quantity, let price {
                    Text("\(quantity) × \((price - (discount ?? .zero)).formatted)")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }

            Section {
                Button(action: save) {
                    Text(isNew ? "Add to Invoice" : "Save")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if case .edit(let line) = mode {
                    Button("Remove from Invoice", role: .destructive) {
                        context.delete(line)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .keyboardDoneButton()
        .navigationTitle(isNew ? "Add to Invoice" : "Change Line")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .edit = mode {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save", action: save).disabled(!isValid)
            }
        }
        .onAppear(perform: load)
    }

    // MARK: State

    private var isNew: Bool { if case .new = mode { true } else { false } }

    private var variant: ButtonVariant? {
        switch mode {
        case .new(_, let variant, _, _): variant
        case .edit(let line): line.variant
        }
    }

    private var title: String {
        switch mode {
        case .new(_, let variant, _, _): variant.title
        case .edit(let line): line.itemDescription
        }
    }

    private var sku: String {
        switch mode {
        case .new(_, let variant, _, _): variant.sku
        case .edit(let line): line.sku
        }
    }

    private var photo: Data? {
        switch mode {
        case .new(_, let variant, _, _): variant.photo
        case .edit(let line): line.photo
        }
    }

    private var quantity: Int? { Int(quantityText.filter(\.isNumber)).flatMap { $0 > 0 ? $0 : nil } }
    private var price: Money? { Money(parsing: priceText) }
    /// Per-button discount in dollars, or nil if what's typed isn't a number.
    private var discount: Money? {
        let text = discountText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return .zero }
        if discountIsPercent {
            guard let percent = Double(text.replacingOccurrences(of: "%", with: "")), percent >= 0, percent <= 100,
                  let price else { return nil }
            return price.percent(percent)
        }
        return Money(parsing: text)
    }

    private var discountPercent: Double {
        Double(discountText.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var lineTotal: Money? {
        guard let quantity, let price, let discount else { return nil }
        return (price - discount) * quantity
    }

    private var isValid: Bool {
        guard let price, let discount, quantity != nil else { return false }
        return price > .zero && discount >= .zero && discount <= price
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new(_, let variant, let request, _):
            quantityText = request.quantity.map(String.init) ?? ""
            priceText = (request.unitPrice ?? (variant.price > .zero ? variant.price : nil))?.editingText ?? ""
            quantityFocused = request.quantity == nil
        case .edit(let line):
            quantityText = String(line.quantity)
            priceText = line.unitPrice.editingText
            discountIsPercent = line.discountIsPercent
            discountText = line.discount > .zero
                ? (line.discountIsPercent ? line.discountPercent.formatted(.number.grouping(.never)) : line.discount.editingText) : ""
            showDiscount = line.discount > .zero
        }
    }

    private func setDiscount(_ line: InvoiceLine, _ discount: Money) {
        line.discount = discount
        line.discountIsPercent = discountIsPercent && discount > .zero
        line.discountPercent = line.discountIsPercent ? discountPercent : 0
    }

    /// A new saved price, keeping a copy of the button as it was (SPEC.md, "Button history").
    private func updatePrice(_ variant: ButtonVariant, _ price: Money) {
        guard variant.price != price else { return }
        if variant.price > .zero {
            let version = ButtonVersion(of: variant)
            context.insert(version)
            version.variant = variant
        }
        variant.price = price
    }

    private func save() {
        guard let quantity, let price, let discount else { return }
        switch mode {
        case .new(let invoice, let variant, _, let search):
            let line = InvoiceLine(position: (invoice.lines ?? []).count, variant: variant, quantity: quantity, unitPrice: price)
            setDiscount(line, discount)
            context.insert(line)
            line.invoice = invoice
            variant.lastUsedAt = Date()
            variant.aliases += Matcher.newAliases(from: search, chosen: variant.matchCandidate)
            if savePrice || variant.price == .zero { updatePrice(variant, price) }
            try? context.save()
            onDone()
        case .edit(let line):
            line.quantity = quantity
            line.unitPrice = price
            setDiscount(line, discount)
            if savePrice, let variant = line.variant { updatePrice(variant, price) }
            try? context.save()
            dismiss()
        }
    }
}

/// A dollar amount typed on the number pad.
struct MoneyField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text("$").foregroundStyle(.secondary)
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .font(.title3.monospacedDigit())
            if !text.isEmpty && Money(parsing: text) == nil {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    .accessibilityLabel("Not a dollar amount")
            }
        }
    }
}
