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
/// The step bar and the running total stay on screen; the standard Back button (and swipe)
/// returns to the list, and the draft is saved as she goes, so there's nothing to lose
/// (Toolbars, "Use the standard Back and Close buttons"; Tab bars, "Make sure the tab bar is
/// visible").
struct InvoiceFlowView: View {
    @Bindable var invoice: Invoice
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(BusinessSettings.self) private var settings
    @State private var step: FlowStep = .buttons
    @State private var started = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            switch step {
            case .buttons: ButtonsStep(invoice: invoice)
            case .shipping: ShippingStep(invoice: invoice)
            case .review: ReviewStep(invoice: invoice) { step = $0 }
            }
        }
        .background(Color(.systemGroupedBackground))
        // The bars stop growing at the largest standard text size, like the system tab bar,
        // so the step's content keeps most of the screen; touching and holding one of their
        // controls shows it in the large content viewer (Accessibility, "Large Content Viewer").
        .controlBar(edge: .top) {
            StepIndicator(step: $step, isReachable: isReachable)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .controlBar(edge: .bottom) {
            bottomBar.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .navigationTitle("Invoice \(invoice.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Draft…", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .confirmationDialog("Delete draft \(invoice.number)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete Draft", role: .destructive) {
                        dismiss()
                        InvoiceActions.delete(invoice, context)
                    }
                } message: {
                    Text("The buttons stay saved; only this draft is removed.")
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
        .onDisappear { try? context.save() }
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
            return "Add the shipping, or turn on “No shipping on this invoice”."
        case .review:
            return nil
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let blockedMessage {
                Text(blockedMessage).font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            AdaptiveRow {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total so far · saved").font(.caption).foregroundStyle(.secondary)
                    Text(invoice.total.formatted).font(.title2.bold()).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                        .animation(.default, value: invoice.total)
                }
                .accessibilityElement(children: .combine)
            } trailing: {
                HStack(spacing: 12) {
                    if let previous = FlowStep(rawValue: step.rawValue - 1) {
                        Button { step = previous } label: {
                            Label("Back", systemImage: "chevron.backward")
                                .labelStyle(.iconOnly)
                                .font(.headline)
                                .frame(minWidth: 36, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Back to \(previous.title)")
                        .accessibilityShowsLargeContentViewer {
                            Label("Back to \(previous.title)", systemImage: "chevron.backward")
                        }
                    }
                    if let next = FlowStep(rawValue: step.rawValue + 1) {
                        Button { step = next } label: {
                            Label("Next", systemImage: "chevron.forward")
                                .labelStyle(TrailingIcon())
                                .font(.headline)
                                .frame(minHeight: 36)
                        }
                        .prominentButton()
                        .disabled(!isDone(step))
                        .accessibilityLabel("Next: \(next.title)")
                        .accessibilityShowsLargeContentViewer {
                            Label("Next: \(next.title)", systemImage: "chevron.forward")
                        }
                    } else {
                        Button(action: finish) {
                            Label("Finish", systemImage: "checkmark").font(.headline).frame(minHeight: 36)
                        }
                        .prominentButton()
                        .disabled(!ReviewStep.canFinish(invoice, others: otherNumbers))
                        .accessibilityShowsLargeContentViewer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    @Query private var allInvoices: [Invoice]

    private var otherNumbers: [String] {
        allInvoices.filter { $0.persistentModelID != invoice.persistentModelID }.map(\.number)
    }

    /// Freezes the invoice: its business details (kept from the first Finish if she reopened
    /// it) and the PDF that Share will send. No confirmation: it can be reopened with Make
    /// Changes (Alerts, "Avoid displaying alerts for common, undoable actions").
    private func finish() {
        let profile = invoice.businessProfile(current: settings.profile)
        invoice.businessSnapshot = try? JSONEncoder().encode(profile)
        invoice.finishedPDF = InvoiceExport.render(invoice, profile: profile)
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

/// 1 Buttons · 2 Shipping · 3 Review. Steps she can't reach yet are dimmed. At the largest
/// text sizes only the numbers and the current step's name fit (the bar is capped at the largest
/// standard size; see InvoiceFlowView).
struct StepIndicator: View {
    @Binding var step: FlowStep
    let isReachable: (FlowStep) -> Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var circle: CGFloat = 26

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FlowStep.allCases) { s in
                Button {
                    step = s
                } label: {
                    HStack(spacing: 6) {
                        Text("\(s.rawValue + 1)")
                            .font(.subheadline.bold())
                            .frame(width: circle, height: circle)
                            .background(Circle().fill(s == step ? Color.accentColor : Color(.tertiarySystemFill)))
                            .foregroundStyle(s == step ? .white : .primary)
                        if typeSize < .xxLarge || s == step {
                            Text(s.title).font(.subheadline.weight(s == step ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(!isReachable(s))
                .opacity(isReachable(s) ? 1 : 0.4)
                .accessibilityLabel("Step \(s.rawValue + 1), \(s.title)")
                .accessibilityAddTraits(s == step ? .isSelected : [])
                .accessibilityShowsLargeContentViewer {
                    Label(s.title, systemImage: "\(s.rawValue + 1).circle")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
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
                            .contextMenu {
                                Button("Change…", systemImage: "pencil") { editing = line }
                                Button("Remove", systemImage: "trash", role: .destructive) { remove(line) }
                            }
                    }
                    .onDelete(perform: delete)
                    .onMove(perform: move)
                } footer: {
                    Text("Tap a button to change it. Touch and hold, or swipe left, to remove it.")
                }
            }
            Section {
                Button {
                    adding = true
                } label: {
                    Label(invoice.sortedLines.isEmpty ? "Add a Button" : "Add Another Button",
                          systemImage: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .addButtonStyle(prominent: invoice.sortedLines.isEmpty)
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

    private func remove(_ line: InvoiceLine) {
        context.undoManager?.setActionName("Remove Button")
        context.delete(line)
        for (i, other) in invoice.sortedLines.filter({ $0 !== line }).enumerated() { other.position = i }
    }

    private func delete(at offsets: IndexSet) {
        let lines = invoice.sortedLines
        context.undoManager?.setActionName("Remove Button")
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
        AdaptiveRow {
            IconTextStack {
                ButtonPhoto(data: line.photo, side: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.itemDescription).font(.headline)
                    Text("\(line.quantity) × \(line.unitPrice.formatted)").font(.subheadline).monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let discount = line.discountText {
                        Text(discount).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        } trailing: {
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
                            .contextMenu {
                                Button("Change…", systemImage: "pencil") { editing = charge }
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    context.undoManager?.setActionName("Remove Shipping")
                                    context.delete(charge)
                                }
                            }
                    }
                    .onDelete { offsets in
                        let charges = invoice.sortedShipping
                        context.undoManager?.setActionName("Remove Shipping")
                        for i in offsets { context.delete(charges[i]) }
                    }
                }
            }
            Section {
                Button {
                    invoice.noShipping = false
                    adding = true
                } label: {
                    Label(invoice.sortedShipping.isEmpty ? "Add Shipping" : "Add Another Box",
                          systemImage: "shippingbox.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .addButtonStyle(prominent: invoice.sortedShipping.isEmpty && !invoice.noShipping)
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
        AdaptiveRow {
            Label(charge.note.isEmpty ? "Shipping" : charge.note,
                  systemImage: charge.receiptPhoto == nil ? "shippingbox" : "doc.text.image")
        } trailing: {
            Text(charge.amount.formatted).font(.headline).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The add button is the screen's prominent action only until the step has something in
    /// it; after that, Next is (Buttons, "Keep the number of prominent buttons to one or two").
    @ViewBuilder func addButtonStyle(prominent: Bool) -> some View {
        if prominent {
            prominentButton()
        } else {
            buttonStyle(.bordered).labelStyle(.titleAndIcon)
        }
    }
}
