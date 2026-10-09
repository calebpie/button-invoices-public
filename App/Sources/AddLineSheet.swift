import InvoiceKit
import SwiftData
import SwiftUI
import TipKit

enum AddRoute: Hashable {
    case design(ButtonDesign)
    /// The quantity and price she typed, if any, travel with the button she picked.
    case quantity(ButtonVariant, OrderRequest)
    case newButton(ButtonDraft, NewButtonStep)
}

/// Adding one line (SPEC.md, "Adding a line"): pick the shape, then its color and size, then
/// how many. Typing the way she texts ("12 red hearts") is a shortcut. If the color or size
/// isn't saved yet, the new-button steps start with what she picked filled in.
struct AddLineSheet: View {
    let invoice: Invoice

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @State private var path: [AddRoute] = []
    @State private var search = ""
    /// Quantity and price typed in the search before starting a new button, for its quantity screen.
    @State private var newButtonRequest = OrderRequest.empty
    @State private var askDiscard = false

    /// A new button she has started would be lost by closing the sheet.
    private var startedNewButton: Bool {
        path.contains { if case .newButton(let draft, _) = $0 { draft.hasContent } else { false } }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ShapePickerView(search: $search) { design in
                newButtonRequest = .empty
                path.append(.design(design))
            } pickVariant: { variant in
                TypeOrderTip().invalidate(reason: .actionPerformed)
                path.append(.quantity(variant, Matcher.parse(search)))
            } newShape: {
                let guess = Catalog.guessNewButton(from: search, designs: designs)
                let request = Matcher.parse(search)
                newButtonRequest = request
                startNewButton(ButtonDraft(design: guess.design, newDesignName: guess.designName,
                                           colors: Naming.cleanColors(guess.colors), size: guess.size,
                                           price: request.unitPrice))
            }
            .navigationTitle("Add a Button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton { if startedNewButton { askDiscard = true } else { dismiss() } }
                        .discardQuestion(isAsking: $askDiscard) { dismiss() }
                }
            }
            .navigationDestination(for: AddRoute.self) { route in
                switch route {
                case .design(let design):
                    VariantPickerView(design: design) { variant in
                        path.append(.quantity(variant, .empty))
                    } newVariant: { colors, size in
                        startNewButton(ButtonDraft(design: design, colors: colors, size: size,
                                                   price: design.visibleVariants.first(where: { $0.price > .zero })?.price))
                    }
                case .quantity(let variant, let request):
                    LineEditorView(mode: .new(invoice: invoice, variant: variant, request: request, search: search)) {
                        dismiss()
                    }
                case .newButton(let draft, let step):
                    NewButtonStepView(draft: draft, step: step, purpose: .invoice) { next in
                        path.append(.newButton(draft, next))
                    } finished: { variant in
                        path = [.quantity(variant, newButtonRequest)]
                    }
                }
            }
        }
        .confirmsDiscard(startedNewButton) { dismiss() }
    }

    private func startNewButton(_ draft: ButtonDraft) {
        path.append(.newButton(draft, .photo))
    }
}

// MARK: - Shape

struct ShapePickerView: View {
    @Binding var search: String
    let pickDesign: (ButtonDesign) -> Void
    let pickVariant: (ButtonVariant) -> Void
    let newShape: () -> Void

    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]
    /// From her first letter until the keyboard has gone, the content ignores the keyboard
    /// and keeps its own room for it (nit 6).
    @State private var ownKeyboardRoom = false
    @State private var keyboardHeight: CGFloat = 0

    @ScaledMetric private var tileWidth: CGFloat = 104
    private var grid: [GridItem] { [GridItem(.adaptive(minimum: tileWidth), spacing: 12)] }
    private let typeTip = TypeOrderTip()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TipView(typeTip)
                let searching = !search.trimmingCharacters(in: .whitespaces).isEmpty
                Text(searching ? "Which button? Tap it." : "Which button? Tap its shape.")
                    .font(.title3.weight(.semibold)).heading()

                if !searching {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(designs.filter { !$0.visibleVariants.isEmpty }) { design in
                            Button { pickDesign(design) } label: { DesignTile(design: design) }
                                .buttonStyle(.plain)
                        }
                    }
                } else {
                    let request = Matcher.parse(search)
                    let parts = [request.quantity.map { "\($0) buttons" }, request.unitPrice.map { "\($0.formatted) each" }].compactMap { $0 }
                    if !parts.isEmpty {
                        Label(parts.joined(separator: " · ") + ". Now tap the button.", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    let results = Catalog.search(search, in: variants)
                    if results.isEmpty {
                        Text("No saved button matches “\(request.query)”.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(results) { variant in
                            Button { pickVariant(variant) } label: { ButtonTile(variant: variant) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("A shape you haven't sold before?").foregroundStyle(.secondary)
                    Button(action: newShape) {
                        Label("Add a New Button", systemImage: "plus.circle")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, ownKeyboardRoom ? keyboardHeight : 0)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // Closing the search with text in it (✕) clears the text, so the sheet redraws while
        // the bar grows back and the keyboard goes. Following the keyboard's shrinking space in
        // that redraw drew the content about 130 points too high for 5 frames, then dropped it
        // into place (Docs/ui-nits.md, nit 6). So once she types, the content ignores the
        // keyboard and makes its own room under it, until the keyboard has gone. With nothing
        // typed, the system's own handling stays: it slides smoothly, even scrolled to the end.
        .ignoresSafeArea(ownKeyboardRoom ? .keyboard : [], edges: .bottom)
        .onChange(of: search) { _, new in
            if !new.isEmpty { ownKeyboardRoom = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { note in
            keyboardHeight = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            ownKeyboardRoom = false
        }
        // The system search field, in its usual place (Search fields).
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Type an order, like 12 red hearts")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}

struct DesignTile: View {
    let design: ButtonDesign

    var body: some View {
        VStack(spacing: 6) {
            ButtonPhoto(data: design.coverPhoto, side: 84)
            Text(design.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            let n = design.visibleVariants.count
            Text(n == 1 ? "1 kind" : "\(n) kinds").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ButtonTile: View {
    let variant: ButtonVariant
    var selected = false

    var body: some View {
        VStack(spacing: 6) {
            ButtonPhoto(data: variant.photo, side: 84)
            Text(variant.title)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity)
            Text(variant.price > .zero ? variant.price.formatted : "No price yet").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: selected ? 3 : 0))
        .opacity(variant.isHidden ? 0.5 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Color and size

/// The colors and sizes she has saved for one shape. Picking both fills in the button; a
/// combination that isn't saved offers to add it. Sizes are offered for every shape, even one
/// she has only made in one size, so a new size is always one tap away.
struct VariantPickerView: View {
    let design: ButtonDesign
    let pick: (ButtonVariant) -> Void
    let newVariant: (_ colors: [String], _ size: String) -> Void

    @State private var color: String?
    @State private var size: String?

    @ScaledMetric private var tileWidth: CGFloat = 104
    private var grid: [GridItem] { [GridItem(.adaptive(minimum: tileWidth), spacing: 12)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Which color?").font(.title3.weight(.semibold)).heading()
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(colorOptions, id: \.self) { option in
                        Button {
                            color = option
                            let sizes = Set(variants.filter { $0.colorsText == option }.map(\.size))
                            if sizes.count == 1 { size = sizes.first }
                            else if let size, !sizes.contains(size) { self.size = nil }
                        } label: {
                            ColorTile(photo: variants.first { $0.colorsText == option && $0.photo != nil }?.photo,
                                      label: option, selected: color == option)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { newVariant([], size ?? (sizeOptions.count == 1 ? sizeOptions[0] : "")) } label: {
                        ColorTile(photo: nil, label: "Another Color", selected: false, systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }

                if color != nil {
                    Text("Which size?").font(.title3.weight(.semibold)).heading()
                    FlowChips {
                        ForEach(sizeOptions, id: \.self) { option in
                            let exists = variants.contains { $0.colorsText == color && $0.size == option }
                            Button { size = option } label: {
                                HStack(spacing: 4) {
                                    if size == option { Image(systemName: "checkmark") }
                                    Text(option.isEmpty ? "One size" : option)
                                    if !exists { Text("(new)").foregroundStyle(size == option ? .white : .secondary) }
                                }
                                .font(.body.weight(size == option ? .semibold : .regular))
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(size == option ? .accentColor : .primary)
                            .background(Capsule().fill(size == option ? Color.accentColor : .clear))
                            .foregroundStyle(size == option ? .white : .primary)
                        }
                        Button("Another Size", systemImage: "plus") { newVariant(chosenColors, "") }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                    }
                }

                result
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(design.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if variants.count == 1, let only = variants.first {
                color = only.colorsText
                size = only.size
            }
        }
    }

    @ViewBuilder private var result: some View {
        if let match {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ButtonPhoto(data: match.photo, side: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.title).font(.headline)
                        Text("\(match.price > .zero ? match.price.formatted : "No price yet") · \(match.sku)")
                            .foregroundStyle(.secondary)
                    }
                }
                Button { pick(match) } label: {
                    Text("Use This Button").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButton()
            }
            .card()
        } else if color != nil, size != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("There's no \(Naming.description(design: design.name, colors: chosenColors, size: chosenSize)) saved yet.")
                    .font(.headline)
                Button { newVariant(chosenColors, chosenSize) } label: {
                    Text("Add as a New Button").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButton()
            }
            .card()
        }
    }

    private var variants: [ButtonVariant] { design.visibleVariants }

    private var colorOptions: [String] {
        var seen = Set<String>()
        return variants.map(\.colorsText).filter { seen.insert($0).inserted }
    }

    private var sizeOptions: [String] {
        let order = [""] + Naming.sizes
        return Set(variants.map(\.size)).sorted { (order.firstIndex(of: $0) ?? 99, $0) < (order.firstIndex(of: $1) ?? 99, $1) }
    }

    private var chosenColors: [String] { color.map { Naming.cleanColors($0) } ?? [] }
    private var chosenSize: String { size ?? "" }

    private var match: ButtonVariant? {
        guard let color, let size else { return nil }
        return variants.first { $0.colorsText == color && $0.size == size }
    }
}

private struct ColorTile: View {
    let photo: Data?
    let label: String
    let selected: Bool
    var systemImage: String?

    var body: some View {
        VStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.title).foregroundStyle(.tint).frame(width: 72, height: 72)
            } else {
                ButtonPhoto(data: photo, side: 72)
            }
            Text(label).font(.footnote.weight(.medium)).multilineTextAlignment(.center).lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: selected ? 3 : 0))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Chips that wrap onto more lines when they don't fit.
struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (items: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.items.isEmpty && current.width + spacing + size.width > width {
                rows.append(current)
                current = ([], 0, 0)
            }
            current.width += (current.items.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.items.append(index)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
