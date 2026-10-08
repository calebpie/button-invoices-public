import InvoiceKit
import SwiftData
import SwiftUI

enum FlowStep: Int, CaseIterable, Identifiable {
    case buttons, shipping, review
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .buttons: "Buttons"
        case .shipping: "Shipping"
        case .review: "Review"
        }
    }
}

/// Making an invoice, one step at a time (SPEC.md, "Making an invoice"): buttons, shipping,
/// review. She can go back to any step and forward to any step whose earlier steps are done.
/// The running total and Save & Exit stay on screen throughout. Everything saves as she goes.
struct InvoiceFlowView: View {
    @Bindable var invoice: Invoice
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var step: FlowStep = .buttons
    @State private var started = false
    @State private var confirmFinish = false

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(step: $step, isReachable: isReachable)
            Divider()
            switch step {
            case .buttons: ButtonsStep(invoice: invoice)
            case .shipping: ShippingStep(invoice: invoice)
            case .review: ReviewStep(invoice: invoice) { step = $0 }
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Invoice \(invoice.number)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Save & Exit") {
                    try? context.save()
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            // A draft reopens at the first step that still needs something.
            step = FlowStep.allCases.first { !isDone($0) } ?? .review
        }
        .onChange(of: step) { try? context.save() }
        .confirmationDialog("Finish invoice \(invoice.number)?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and Share the PDF", action: finish)
        } message: {
            Text("It's then saved as it is and can be sent. You can still choose Make Changes later.")
        }
    }

    // MARK: Steps

    private func isDone(_ step: FlowStep) -> Bool {
        switch step {
        case .buttons:
            let lines = invoice.sortedLines
            return !lines.isEmpty && lines.allSatisfy { $0.quantity > 0 && $0.unitPrice > .zero }
        case .shipping:
            return !invoice.sortedShipping.isEmpty || invoice.noShipping
        case .review:
            return false
        }
    }

    private func isReachable(_ target: FlowStep) -> Bool {
        FlowStep.allCases.filter { $0.rawValue < target.rawValue }.allSatisfy(isDone)
    }

    private var blockedMessage: String? {
        guard !isDone(step), step != .review else { return nil }
        switch step {
        case .buttons:
            return invoice.sortedLines.isEmpty ? "Add at least one button to go on." : "Every button needs a quantity and a price."
        case .shipping:
            return "Add the shipping, or tap “No shipping on this invoice”."
        case .review:
            return nil
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let blockedMessage {
                Text(blockedMessage).font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total so far").font(.caption).foregroundStyle(.secondary)
                    Text(invoice.total.formatted).font(.title2.bold()).monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.default, value: invoice.total)
                }
                Spacer()
                if let previous = FlowStep(rawValue: step.rawValue - 1) {
                    Button { step = previous } label: {
                        Label("Back", systemImage: "chevron.left").frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                }
                if let next = FlowStep(rawValue: step.rawValue + 1) {
                    Button { step = next } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(TrailingIcon())
                            .font(.headline)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isDone(step))
                } else {
                    Button { confirmFinish = true } label: {
                        Label("Finish", systemImage: "checkmark").font(.headline).frame(minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!ReviewStep.canFinish(invoice, others: otherNumbers))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @Query private var allInvoices: [Invoice]

    private var otherNumbers: [String] {
        allInvoices.filter { $0.persistentModelID != invoice.persistentModelID }.map(\.number)
    }

    private func finish() {
        invoice.status = .finalized
        invoice.finalizedAt = Date()
        for line in invoice.lines ?? [] { line.variant?.lastUsedAt = Date() }
        try? context.save()
        onFinish()
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

/// 1 Buttons · 2 Shipping · 3 Review. Steps she can't reach yet are grayed out.
struct StepIndicator: View {
    @Binding var step: FlowStep
    let isReachable: (FlowStep) -> Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FlowStep.allCases) { s in
                Button {
                    step = s
                } label: {
                    HStack(spacing: 6) {
                        Text("\(s.rawValue + 1)")
                            .font(.subheadline.bold())
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(s == step ? Color.accentColor : Color(.tertiarySystemFill)))
                            .foregroundStyle(s == step ? .white : .primary)
                        Text(s.title).font(.subheadline.weight(s == step ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(!isReachable(s))
                .opacity(isReachable(s) ? 1 : 0.4)
                .accessibilityLabel("Step \(s.rawValue + 1), \(s.title)")
                .accessibilityAddTraits(s == step ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

/// A short instruction at the top of each step.
struct StepGuide: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb").foregroundStyle(.tint)
            Text(text)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Step \(number) of 3. \(text)")
    }
}

// MARK: - Step 1: Buttons

struct ButtonsStep: View {
    let invoice: Invoice
    @Environment(\.modelContext) private var context
    @State private var adding = false
    @State private var editing: InvoiceLine?

    var body: some View {
        List {
            Section {
                StepGuide(number: 1, text: "Add each kind of button in this order, one at a time. Tap Next when they're all in.")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
            }
            if !invoice.sortedLines.isEmpty {
                Section {
                    ForEach(invoice.sortedLines) { line in
                        Button { editing = line } label: { LineRow(line: line) }
                            .foregroundStyle(.primary)
                    }
                    .onDelete(perform: delete)
                    .onMove(perform: move)
                } footer: {
                    Text("Tap a button to change it. Swipe left to remove it.")
                }
            }
            Section {
                Button {
                    adding = true
                } label: {
                    Label(invoice.sortedLines.isEmpty ? "Add the first button" : "Add another button",
                          systemImage: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .readableWidth()
        .sheet(isPresented: $adding) { AddLineSheet(invoice: invoice) }
        .sheet(item: $editing) { line in
            NavigationStack { LineEditorView(mode: .edit(line)) }
        }
    }

    private func delete(at offsets: IndexSet) {
        let lines = invoice.sortedLines
        for i in offsets { context.delete(lines[i]) }
        for (i, line) in lines.enumerated().filter({ !offsets.contains($0.offset) }).map(\.element).enumerated() {
            line.position = i
        }
    }

    private func move(from: IndexSet, to: Int) {
        var lines = invoice.sortedLines
        lines.move(fromOffsets: from, toOffset: to)
        for (i, line) in lines.enumerated() { line.position = i }
    }
}

struct LineRow: View {
    let line: InvoiceLine

    var body: some View {
        HStack(spacing: 12) {
            ButtonPhoto(data: line.photo, side: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(line.itemDescription).font(.headline)
                Text("\(line.quantity) × \(line.unitPrice.formatted)").font(.subheadline).monospacedDigit()
                    .foregroundStyle(.secondary)
                if let discount = line.discountText {
                    Text(discount).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(line.subtotal.formatted).font(.headline).monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 2: Shipping

struct ShippingStep: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var context
    @State private var adding = false
    @State private var editing: ShippingCharge?

    var body: some View {
        List {
            Section {
                StepGuide(number: 2, text: "Add what you paid to mail these buttons: one line for each box. Type the amount or take a photo of the receipt.")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
            }
            if !invoice.sortedShipping.isEmpty {
                Section("Shipping") {
                    ForEach(invoice.sortedShipping) { charge in
                        Button { editing = charge } label: { ShippingRow(charge: charge) }
                            .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        let charges = invoice.sortedShipping
                        for i in offsets { context.delete(charges[i]) }
                    }
                }
            }
            Section {
                Button {
                    invoice.noShipping = false
                    adding = true
                } label: {
                    Label(invoice.sortedShipping.isEmpty ? "Add shipping" : "Add another box",
                          systemImage: "shippingbox.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if invoice.sortedShipping.isEmpty {
                Section {
                    Toggle("No shipping on this invoice", isOn: $invoice.noShipping)
                }
            }
        }
        .readableWidth()
        .sheet(isPresented: $adding) {
            NavigationStack { ShippingEditorView(invoice: invoice, charge: nil) }
        }
        .sheet(item: $editing) { charge in
            NavigationStack { ShippingEditorView(invoice: invoice, charge: charge) }
        }
    }
}

struct ShippingRow: View {
    let charge: ShippingCharge

    var body: some View {
        HStack {
            Image(systemName: charge.receiptPhoto == nil ? "shippingbox" : "doc.text.image")
                .foregroundStyle(.secondary)
            Text(charge.note.isEmpty ? "Shipping" : charge.note)
            Spacer()
            Text(charge.amount.formatted).font(.headline).monospacedDigit()
        }
    }
}
