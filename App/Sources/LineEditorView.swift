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
    @State private var original = ""
    @State private var askDiscard = false
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
                // Typing suits 500; the stepper suits nudging 12 to 13 (Steppers, "Consider
                // pairing a stepper with a text field").
                HStack {
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.numberPad)
                        .numericInput($quantityText, .whole)
                        .font(.title.monospacedDigit())
                        .focused($quantityFocused)
                    Stepper("Quantity", value: Binding(
                        get: { quantity ?? 0 },
                        set: { quantityText = $0 > 0 ? String($0) : "" }), in: 0...100_000)
                        .labelsHidden()
                }
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
                        Text("Dollars").tag(false)
                        Text("Percent").tag(true)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        if !discountIsPercent { Text("$").foregroundStyle(.secondary) }
                        TextField(discountIsPercent ? "Percent off" : "Dollars off each button", text: $discountText)
                            .keyboardType(.decimalPad)
                            .numericInput($discountText, .decimal)
                            .font(.title3.monospacedDigit())
                        if discountIsPercent { Text("%").foregroundStyle(.secondary) }
                        if discountIsWrong {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                                .accessibilityLabel("Not a valid discount")
                        }
                    }
                    if discountIsPercent, let discount, discount > .zero {
                        Text("\(discount.formatted) off each button").foregroundStyle(.secondary)
                    }
                    Button("Remove Discount", role: .destructive) {
                        discountText = ""
                        showDiscount = false
                    }
                } else {
                    Button("Add Discount", systemImage: "tag") { showDiscount = true }
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
                if problem == nil, let quantity, let price {
                    Text("\(quantity) × \((price - (discount ?? .zero)).formatted)")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }

            Section {
                Button(action: save) {
                    Text(isNew ? "Add to Invoice" : "Save")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .prominentButton()
                .disabled(!isValid)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                // Why the button is grey, as the new-button steps say under Next.
                if let problem { Text(problem).foregroundStyle(.orange) }
            }
            if case .edit(let line) = mode {
                // Its own card: under the bare Save button it had square top corners.
                Section {
                    Button(role: .destructive) {
                        if let invoice = line.invoice {
                            Undo.perform("Remove Button", context, .remove([line], from: invoice))
                        }
                        dismiss()
                    } label: {
                        DestructiveLabel("Remove from Invoice", systemImage: "trash")
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "Add to Invoice" : "Change Line")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .edit = mode {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton { if isDirty { askDiscard = true } else { dismiss() } }
                        .discardQuestion(isAsking: $askDiscard) { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton(title: isNew ? "Add" : "Save", action: save).disabled(!isValid)
            }
        }
        .confirmsDiscard(isEditing && isDirty) { dismiss() }
        .onAppear(perform: load)
    }

    // MARK: State

    private var isNew: Bool { if case .new = mode { true } else { false } }
    private var isEditing: Bool { !isNew }

    private var snapshot: String { [quantityText, priceText, discountText, String(discountIsPercent), String(savePrice)].joined(separator: "|") }
    private var isDirty: Bool { loaded && snapshot != original }

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

    /// Nil while anything is wrong, so a discount over the price never shows a negative total.
    private var lineTotal: Money? {
        guard problem == nil, let quantity, let price, let discount else { return nil }
        return (price - discount) * quantity
    }

    /// What's stopping the line from being added, in her words; nil when it can be.
    private var problem: String? {
        guard quantity != nil else { return "Enter how many." }
        guard let price, price > .zero else { return "Enter the price for one button." }
        if discountIsPercent, discountPercent > 100 { return "The percent off can't be more than 100." }
        guard let discount, discount >= .zero else { return "The discount isn't a number." }
        if discount > price { return "The discount can't be more than the price (\(price.formatted))." }
        return nil
    }

    private var isValid: Bool { problem == nil }

    private var discountIsWrong: Bool {
        guard let discount else { return true }
        if let price { return discount > price } else { return false }
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
        original = snapshot
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
                .numericInput($text, .decimal)
                .font(.title3.monospacedDigit())
            if !text.isEmpty && Money(parsing: text) == nil {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    .accessibilityLabel("Not a dollar amount")
            }
        }
    }
}
