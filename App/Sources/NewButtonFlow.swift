import InvoiceKit
import SwiftData
import SwiftUI
import UIKit

/// Adding a new button, in four steps (SPEC.md, "Adding a new button"): photo, is it already
/// saved?, name and price, review. Nothing is saved until the last step, so leaving partway
/// loses only that button.
enum NewButtonStep: Int, Hashable {
    case photo, matches, details, review
}

enum NewButtonPurpose {
    /// Started from an invoice: saving goes on to the quantity screen.
    case invoice
    /// Started from the Buttons tab: saving ends the flow.
    case catalog
}

/// What she has entered for a new button, or the edits to a saved one.
@Observable final class ButtonDraft: Hashable {
    /// The photo before the background was removed, for touching up again.
    var source: CGImage?
    /// Square transparent PNG.
    var photo: Data?
    var designID: PersistentIdentifier?
    var newDesignName = ""
    var colorsText = ""
    var size = ""
    var priceText = ""
    var skuText = ""
    var skuEdited = false
    /// Other words she uses for the button, comma-separated ("olive").
    var aliasesText = ""
    /// Saved buttons the photo looks like, closest first, from the photo check.
    var lookAlikes: [(variant: ButtonVariant, distance: Double)] = []

    init(design: ButtonDesign? = nil, newDesignName: String = "", colors: [String] = [], size: String = "", price: Money? = nil) {
        designID = design?.persistentModelID
        self.newDesignName = design == nil ? newDesignName : ""
        colorsText = colors.joined(separator: " / ")
        self.size = size
        priceText = price.map(\.editingText) ?? ""
        if let design { fillFromShape(design) }
    }

    init(editing v: ButtonVariant) {
        designID = v.design?.persistentModelID
        colorsText = v.colorsText
        size = v.size
        priceText = v.price.editingText
        skuText = v.sku
        aliasesText = v.aliasesText
        photo = v.photo
    }

    static func == (a: ButtonDraft, b: ButtonDraft) -> Bool { a === b }

    /// Everything she has entered, to tell whether there's anything to lose.
    var snapshot: String {
        [String(photo?.count ?? 0), String(describing: designID), newDesignName, colorsText, size, priceText, skuText, aliasesText]
            .joined(separator: "|")
    }

    /// True once she has started a new button: a photo, or anything typed.
    var hasContent: Bool {
        photo != nil || !newDesignName.trimmingCharacters(in: .whitespaces).isEmpty
            || !colorsText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    /// When she picks a saved shape, fill what she hasn't: the size if all its buttons share
    /// one, and the price they use most (nit 20). Without this, Heart, Red saved beside
    /// Heart, Red, Medium.
    func fillFromShape(_ design: ButtonDesign) {
        let saved = design.visibleVariants
        let sizes = Set(saved.map(\.size))
        if size.isEmpty, sizes.count == 1, let only = sizes.first, !only.isEmpty { size = only }
        let priced = saved.filter { $0.price > .zero }.map(\.price.cents)
        if price == nil, let common = Dictionary(grouping: priced, by: { $0 })
            .max(by: { ($0.value.count, $0.key) < ($1.value.count, $1.key) })?.key {
            priceText = Money(cents: common).editingText
        }
    }

    // MARK: Derived

    func chosenDesign(_ designs: [ButtonDesign]) -> ButtonDesign? {
        designs.first { $0.persistentModelID == designID }
    }

    func designName(_ designs: [ButtonDesign]) -> String {
        chosenDesign(designs)?.name ?? Naming.cleanDesign(newDesignName)
    }

    var colors: [String] { Naming.cleanColors(colorsText) }
    var price: Money? { Money(parsing: priceText).flatMap { $0 > .zero ? $0 : nil } }
    var sku: String { skuText.trimmingCharacters(in: .whitespaces).uppercased() }

    func title(_ designs: [ButtonDesign]) -> String {
        let name = designName(designs)
        return name.isEmpty ? "" : Naming.description(design: name, colors: colors, size: size)
    }

    /// The SKU the rules give for what's typed now.
    func ruleSKU(_ designs: [ButtonDesign], _ variants: [ButtonVariant], editing: ButtonVariant?) -> String {
        let name = designName(designs)
        guard !name.isEmpty else { return "" }
        let design = chosenDesign(designs) ?? designs.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let others = variants.filter { $0 !== editing }
        return Catalog.skuRules(variants).suggestSKU(
            year: Catalog.currentYear, designName: name,
            designCode: design?.code ?? SKURules.designCode(for: name),
            colors: colors, size: size, taken: Set(others.map(\.sku)))
    }

    /// A saved button of the same shape and colors that has a size, when this one has none:
    /// likely the same button with the size left out. A warning, not a block (nit 20).
    func sizeTwin(_ designs: [ButtonDesign], editing: ButtonVariant?) -> ButtonVariant? {
        guard size.isEmpty, !colors.isEmpty, let design = chosenDesign(designs) else { return nil }
        let mine = colors.map { $0.lowercased() }
        return design.visibleVariants.first {
            $0 !== editing && !$0.size.isEmpty && $0.colors.map { $0.lowercased() } == mine
        }
    }

    func duplicate(_ designs: [ButtonDesign], _ variants: [ButtonVariant], editing: ButtonVariant?) -> ButtonVariant? {
        let t = title(designs)
        guard !t.isEmpty else { return nil }
        return variants.first { $0 !== editing && $0.title.caseInsensitiveCompare(t) == .orderedSame }
    }

    /// Why it can't be saved yet, in her words, or nil.
    func problem(_ designs: [ButtonDesign], _ variants: [ButtonVariant], editing: ButtonVariant?) -> String? {
        if designName(designs).isEmpty { return "Pick the shape or type its name." }
        if colors.isEmpty { return "Pick at least one color." }
        if price == nil { return "Enter the price for one button." }
        if sku.isEmpty { return "The SKU can't be empty." }
        if let clash = variants.first(where: { $0 !== editing && $0.sku.caseInsensitiveCompare(sku) == .orderedSame }) {
            return "SKU \(sku) is already used by “\(clash.title)”."
        }
        if let twin = duplicate(designs, variants, editing: editing) {
            return "“\(twin.title)” is already saved."
        }
        return nil
    }

    // MARK: Saving

    private func resolveDesign(_ context: ModelContext, _ designs: [ButtonDesign]) -> ButtonDesign {
        if let chosen = chosenDesign(designs) { return chosen }
        let name = designName(designs)
        if let same = designs.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return same }
        let design = ButtonDesign(name: name, code: SKURules.designCode(for: name))
        context.insert(design)
        return design
    }

    func saveNew(_ context: ModelContext, _ designs: [ButtonDesign]) -> ButtonVariant {
        let variant = ButtonVariant(design: resolveDesign(context, designs), colors: colors, size: size,
                                    sku: sku, price: price ?? .zero, photo: photo)
        context.insert(variant)
        try? context.save()
        return variant
    }

    /// Saves edits to a button, first keeping a copy of how it was (SPEC.md, "Button history").
    /// Draft invoices pick up the new name and photo; finished ones keep theirs.
    func apply(to v: ButtonVariant, isHidden: Bool, _ context: ModelContext, _ designs: [ButtonDesign]) {
        let design = resolveDesign(context, designs)
        let newPrice = price ?? v.price
        if v.design !== design || v.colors != colors || v.size != size || v.sku != sku || v.price != newPrice || v.photo != photo {
            let version = ButtonVersion(of: v)
            context.insert(version)
            version.variant = v
        }
        let oldDesign = v.design
        v.design = design
        v.colors = colors
        v.size = size
        v.sku = sku
        v.price = newPrice
        v.photo = photo
        v.isHidden = isHidden
        v.aliases = aliasesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        if let oldDesign, oldDesign !== design, (oldDesign.variants ?? []).allSatisfy({ $0 === v }) {
            context.delete(oldDesign)
        }
        for line in v.invoiceLines ?? [] where line.invoice?.status == .draft {
            line.copyDetails(from: v)
        }
        try? context.save()
    }
}

/// One step of the new-button flow.
struct NewButtonStepView: View {
    let draft: ButtonDraft
    let step: NewButtonStep
    let purpose: NewButtonPurpose
    let advance: (NewButtonStep) -> Void
    /// A saved button: the new one, or an existing one she said it already is.
    let finished: (ButtonVariant) -> Void

    var body: some View {
        switch step {
        case .photo: NewButtonPhotoStep(draft: draft, advance: advance)
        case .matches: NewButtonMatchStep(draft: draft, purpose: purpose, advance: advance, chose: finished)
        case .details: NewButtonDetailsStep(draft: draft, advance: advance)
        case .review: NewButtonReviewStep(draft: draft, purpose: purpose, saved: finished)
        }
    }
}

private struct FlowHeader: View {
    let step: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New button · step \(step) of 4").font(.subheadline).foregroundStyle(.secondary)
            Text(title).font(.title2.bold()).heading()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: 1. Photo

struct NewButtonPhotoStep: View {
    let draft: ButtonDraft
    let advance: (NewButtonStep) -> Void
    @State private var cutoutSource: CutoutSource?
    @State private var startPhoto = false

    struct CutoutSource: Identifiable {
        let id = UUID()
        let image: CGImage
    }

    var body: some View {
        Form {
            Section {
                FlowHeader(step: 1, title: "Take a photo of the new button")
                    .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    Spacer()
                    // Before there's a photo, the frame with its camera symbol is a button
                    // that does what Take Photo does: it's what she'll tap first (nit 18).
                    Button { if draft.photo == nil { startPhoto = true } } label: {
                        ZStack {
                            Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12))
                            ButtonPhoto(data: draft.photo, side: 180)
                        }
                        .frame(width: 200, height: 200)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(CameraPicker.isAvailable ? "Take Photo" : "Choose from Photos")
                    .accessibilityHidden(draft.photo != nil)
                    Spacer()
                }
                .padding(.vertical, 8)
                PhotoSourceButtons(takeLabel: draft.photo == nil ? "Take Photo" : "Retake Photo",
                                   chooseLabel: "Choose from Photos", start: $startPhoto) { image in
                    draft.source = image
                    cutoutSource = CutoutSource(image: image)
                }
                if let source = draft.source, draft.photo != nil {
                    Button { cutoutSource = CutoutSource(image: source) } label: {
                        Label("Touch Up", systemImage: "paintbrush.pointed")
                    }
                }
            } footer: {
                Text("Put one button on a plain table or sheet of paper, in good light, and fill the frame. The background is removed for you.")
            }
            Section {
                Button { advance(.matches) } label: {
                    Text("Next").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButton()
                .disabled(draft.photo == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                // Both on the screen's background: a card under a bare button would have
                // square top corners.
                Button("Skip Photo") { advance(.details) }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .readableWidth()
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $cutoutSource) { source in
            PhotoCutoutView(source: source.image) { png in
                draft.photo = png
                draft.lookAlikes = []
            }
        }
        .dropDestination(for: Data.self) { items, _ in
            // Drag a photo in from Photos or Files on iPad (Drag and drop).
            guard let data = items.first, let image = ImageTools.uprightImage(from: data, maxSide: Photos.workingSize) else { return false }
            draft.source = image
            cutoutSource = CutoutSource(image: image)
            return true
        }
    }
}

// MARK: 2. Is it already saved?

struct NewButtonMatchStep: View {
    let draft: ButtonDraft
    let purpose: NewButtonPurpose
    let advance: (NewButtonStep) -> Void
    let chose: (ButtonVariant) -> Void

    @Query private var variants: [ButtonVariant]
    @Query private var designs: [ButtonDesign]
    @State private var checking = true
    @State private var failed = false

    /// Saved buttons of the shape she already picked, not already shown as photo matches.
    private var sameShape: [ButtonVariant] {
        guard let design = draft.chosenDesign(designs) else { return [] }
        let shown = Set(draft.lookAlikes.filter { $0.distance < LookAlike.similar }.prefix(4).map(\.variant.persistentModelID))
        return design.visibleVariants.filter { !shown.contains($0.persistentModelID) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FlowHeader(step: 2, title: "Is it already saved?")
                HStack {
                    Spacer()
                    ButtonPhoto(data: draft.photo, side: 120)
                    Spacer()
                }
                if checking {
                    ProgressView("Comparing with your saved buttons…").frame(maxWidth: .infinity).padding()
                } else if failed {
                    Label("Couldn't compare photos on this device.", systemImage: "info.circle")
                } else {
                    let close = draft.lookAlikes.filter { $0.distance < LookAlike.similar }.prefix(4)
                    if let best = close.first, best.distance < LookAlike.sameButton {
                        Notice("This looks like a button you already saved.").font(.headline)
                    } else if !close.isEmpty {
                        Text("These saved buttons look similar:").font(.headline)
                    } else {
                        Notice("It doesn't look like any saved button.", tone: .good).font(.headline)
                    }
                }
                if purpose == .catalog, !checking, hasCards {
                    Text("If it's one of these, tap It's This One. Nothing new is saved.")
                        .foregroundStyle(.secondary)
                }
                if !checking, !failed {
                    ForEach(closeMatches, id: \.variant.persistentModelID) { match in
                        matchCard(match.variant)
                    }
                }
                if !checking, !sameShape.isEmpty, let design = draft.chosenDesign(designs) {
                    Text("Your saved \(design.name) buttons:").font(.headline).padding(.top, 4)
                    ForEach(sameShape) { matchCard($0) }
                }
                Button { advance(.details) } label: {
                    Text("It's a New Button").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButton()
                .disabled(checking)
            }
            .padding(.vertical)
            .systemHorizontalMargin()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
        .task { await check() }
    }

    private var closeMatches: [(variant: ButtonVariant, distance: Double)] {
        Array(draft.lookAlikes.filter { $0.distance < LookAlike.similar }.prefix(4))
    }

    private var hasCards: Bool { !closeMatches.isEmpty || !sameShape.isEmpty }

    private func matchCard(_ v: ButtonVariant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ButtonPhoto(data: v.photo, side: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.title).font(.headline)
                    Text("\(v.price > .zero ? v.price.formatted : "No price yet") · \(v.sku)" + (v.isHidden ? " · archived" : "")).foregroundStyle(.secondary)
                }
            }
            // Verbs, the same height, side by side when both fit on one line, else stacked
            // (nit 22).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { matchButtons(v) }
                VStack(spacing: 10) { matchButtons(v) }
            }
        }
        .card()
    }

    @ViewBuilder private func matchButtons(_ v: ButtonVariant) -> some View {
        Button {
            v.isHidden = false // using it again brings it back from the archive
            chose(v)
        } label: {
            Text("It's This One").lineLimit(1).fixedSize().frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        Button {
            draft.designID = v.design?.persistentModelID
            draft.newDesignName = ""
            if draft.colorsText.isEmpty { draft.colorsText = v.colorsText }
            if draft.size.isEmpty { draft.size = v.size }
            if draft.price == nil { draft.priceText = v.price.editingText }
            advance(.details)
        } label: {
            Text("New Color or Size").lineLimit(1).fixedSize().frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
    }

    private func check() async {
        guard let photo = draft.photo else {
            checking = false
            failed = true
            return
        }
        if draft.lookAlikes.isEmpty {
            do {
                draft.lookAlikes = try await LookAlikeCache.shared.rank(photo, among: variants)
            } catch {
                failed = true
            }
        }
        checking = false
    }
}

/// Feature prints of saved photos, computed once per launch.
@MainActor final class LookAlikeCache {
    static let shared = LookAlikeCache()
    private var prints: [String: LookAlike.Print] = [:]

    func rank(_ photo: Data, among variants: [ButtonVariant]) async throws -> [(variant: ButtonVariant, distance: Double)] {
        guard let image = ImageTools.uprightImage(from: photo, maxSide: 512) else { return [] }
        let target = try await LookAlike.print(of: image)
        var out: [(variant: ButtonVariant, distance: Double)] = []
        for v in variants {
            guard let data = v.photo else { continue }
            let key = "\(v.sku)|\(data.count)"
            let print: LookAlike.Print
            if let cached = prints[key] {
                print = cached
            } else {
                guard let saved = ImageTools.uprightImage(from: data, maxSide: 512) else { continue }
                print = try await LookAlike.print(of: saved)
                prints[key] = print
            }
            out.append((v, LookAlike.distance(target, print)))
        }
        return out.sorted { $0.distance < $1.distance }
    }
}

// MARK: 3. Name and price

struct NewButtonDetailsStep: View {
    let draft: ButtonDraft
    let advance: (NewButtonStep) -> Void

    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    var body: some View {
        Form {
            Section {
                FlowHeader(step: 3, title: "Shape, colors and price")
                    .listRowBackground(Color.clear)
            }
            ButtonDetailsSections(draft: draft, editing: nil)
            Section {
                Button { advance(.review) } label: {
                    Text("Next").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButton()
                .disabled(problem != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let problem { Notice(problem) }
            }
        }
        .readableWidth()
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var problem: String? { draft.problem(designs, variants, editing: nil) }
}

// MARK: 4. Review

struct NewButtonReviewStep: View {
    let draft: ButtonDraft
    let purpose: NewButtonPurpose
    let saved: (ButtonVariant) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FlowHeader(step: 4, title: "Check the new button")
                HStack {
                    Spacer()
                    ZStack {
                        Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12))
                        ButtonPhoto(data: draft.photo, side: 180)
                    }
                    .frame(width: 200, height: 200)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("On the invoice", value: draft.title(designs))
                    LabeledContent("SKU", value: draft.sku)
                    LabeledContent("Price each", value: draft.price?.formatted ?? "—")
                    LabeledContent("Shape", value: draft.chosenDesign(designs) == nil
                                   ? "New shape" : "New color or size of \(draft.designName(designs))")
                }
                .card()
                if let best = draft.lookAlikes.first, best.distance < LookAlike.sameButton {
                    Notice("The photo looks a lot like \(best.variant.title). That's fine if this one is a different color or size.")
                }
                if let twin = draft.sizeTwin(designs, editing: nil) {
                    Notice("\(twin.title) is already saved. Is this a different size?")
                }
                if draft.photo == nil {
                    Label("No photo yet. You can add one later from the Buttons tab.", systemImage: "camera")
                        .foregroundStyle(.secondary)
                }
                if let problem = draft.problem(designs, variants, editing: nil) {
                    Notice(problem, tone: .problem)
                }
                Button {
                    saved(draft.saveNew(context, designs))
                } label: {
                    Text(purpose == .invoice ? "Save and Add to Invoice" : "Save Button")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .prominentButton()
                .disabled(draft.problem(designs, variants, editing: nil) != nil)
                Text("To change anything, go back a step.").font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
            .systemHorizontalMargin()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared form sections

/// "Which shape?": the saved shapes as photo tiles, and A New Shape last. Picking one goes
/// back to the button's details with it filled in.
struct ShapeChoiceView: View {
    let designs: [ButtonDesign]
    @Binding var chosen: PersistentIdentifier?

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric private var tileWidth: CGFloat = 104
    private var grid: [GridItem] { [GridItem(.adaptive(minimum: tileWidth), spacing: 12)] }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(designs) { design in
                    Button { pick(design.persistentModelID) } label: {
                        DesignTile(design: design)
                            .overlay {
                                if design.persistentModelID == chosen {
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(design.persistentModelID == chosen ? .isSelected : [])
                }
                Button { pick(nil) } label: { newShapeTile }
                    .buttonStyle(.plain)
            }
            .padding(.vertical)
            .systemHorizontalMargin()
        }
        // The plain background, as in Add a Button, so the tiles' cards show.
        .background(Color(.systemBackground))
        .navigationTitle("Which shape?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var newShapeTile: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 84, height: 84)
            Text("A New Shape").font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            Text("Type its name").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func pick(_ id: PersistentIdentifier?) {
        chosen = id
        dismiss()
    }
}

/// Shape, colors, size, price, and the name and SKU as they'll be printed. Used for new
/// buttons and for changing saved ones.
struct ButtonDetailsSections: View {
    @Bindable var draft: ButtonDraft
    let editing: ButtonVariant?

    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]
    /// Colors she added by name, kept for future buttons (see `AddedColors`).
    @AppStorage(AddedColors.key) private var addedColorsText = ""
    @State private var askNewColor = false
    @State private var newColorText = ""

    var body: some View {
        Group {
            designSection
            colorsSection
            Section("Size") {
                Picker("Size", selection: $draft.size) {
                    Text("One size").tag("")
                    ForEach(sizeChoices, id: \.self) { Text($0).tag($0) }
                }
                if let twin = draft.sizeTwin(designs, editing: editing) {
                    Notice("\(twin.title) is already saved. Is this a different size?")
                }
            }
            Section("Price each") {
                MoneyField(title: "Price", text: $draft.priceText)
            }
            nameSection
        }
        .onAppear {
            if draft.skuText.isEmpty { draft.skuText = suggestedSKU }
        }
        .onChange(of: suggestedSKU) { _, sku in if !draft.skuEdited { draft.skuText = sku } }
        .onChange(of: draft.designID) { _, _ in
            // A new button only: a saved one already has its size and price.
            if editing == nil, let design = draft.chosenDesign(designs) { draft.fillFromShape(design) }
        }
    }

    private var designSection: some View {
        Section {
            // Photos, not names (SPEC.md, "Who uses it"; nit 19): the row opens a grid of
            // shape photos, the same tiles as Add a Button.
            NavigationLink {
                ShapeChoiceView(designs: designs, chosen: $draft.designID)
            } label: {
                if let design = draft.chosenDesign(designs) {
                    HStack(spacing: 12) {
                        ButtonPhoto(data: design.coverPhoto, side: 44)
                        Text(design.name).font(.body.weight(.medium))
                    }
                } else {
                    // No saved shape picked: the name field below is for a new one.
                    Text("Pick a saved shape")
                }
            }
            .accessibilityLabel(draft.chosenDesign(designs).map { "Shape: \($0.name)" } ?? "Pick a saved shape")
            if let design = draft.chosenDesign(designs) {
                let siblings = design.visibleVariants.filter { $0 !== editing }
                if !siblings.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(siblings) { v in
                                VStack(spacing: 2) {
                                    ButtonPhoto(data: v.photo, side: 44)
                                    Text(v.colors.joined(separator: "/") + (v.size.isEmpty ? "" : ", \(v.size)"))
                                        .font(.caption2).lineLimit(1)
                                }
                                .frame(width: 70)
                            }
                        }
                    }
                }
            } else {
                TextField("Shape name, like Mushroom", text: $draft.newDesignName)
                    .textInputAutocapitalization(.words)
                let clean = Naming.cleanDesign(draft.newDesignName)
                if !clean.isEmpty && clean != draft.newDesignName.trimmingCharacters(in: .whitespaces) {
                    Text("Will be saved as “\(clean)”").font(.subheadline).foregroundStyle(.secondary)
                }
                if let fix = Spelling.suggestion(for: draft.newDesignName, known: knownWords) {
                    suggestion(fix) { draft.newDesignName = fix }
                }
            }
        } header: {
            Text("Shape")
        } footer: {
            Text(draft.chosenDesign(designs) == nil
                 ? "Pick a shape you already make to add a new color or size of it."
                 : "Already saved in these colors and sizes.")
        }
    }

    private var nameSection: some View {
        Section {
            LabeledContent("On the invoice") {
                Text(draft.title(designs).isEmpty ? "—" : draft.title(designs)).multilineTextAlignment(.trailing)
            }
            HStack {
                Text("SKU")
                TextField("SKU", text: Binding(get: { draft.skuText },
                                               set: { draft.skuText = $0.uppercased(); draft.skuEdited = true }))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                if draft.skuEdited && draft.skuText != suggestedSKU {
                    Button("Reset") { draft.skuText = suggestedSKU; draft.skuEdited = false }.buttonStyle(.borderless)
                }
            }
            if let editing, ruleSKU != draft.skuText, !ruleSKU.isEmpty,
               editing.designName != draft.designName(designs) || editing.colors != draft.colors || editing.size != draft.size {
                Button("Use \(ruleSKU), made from the new name") { draft.skuText = ruleSKU; draft.skuEdited = true }
            }
            if let twin = draft.duplicate(designs, variants, editing: editing) {
                Notice("“\(twin.title)” is already saved (SKU \(twin.sku)).")
            }
        } header: {
            Text("Name and SKU")
        } footer: {
            Text("The SKU is the year, then letters for the shape, colors and size. A saved button keeps its SKU unless you change it here.")
        }
    }

    // MARK: Colors

    /// Colors are tapped, not typed: the ones she picked, in order, each with ✕ to take it
    /// off, then every color she has used, then New Color for one she hasn't.
    private var colorsSection: some View {
        Section {
            if !draft.colors.isEmpty {
                FlowChips {
                    ForEach(Array(draft.colors.enumerated()), id: \.offset) { index, color in
                        Button { removeColor(at: index) } label: {
                            HStack(spacing: 6) {
                                ColorDot(name: color, onAccent: true)
                                Text(color)
                                Image(systemName: "xmark").font(.caption.weight(.bold))
                            }
                        }
                        .prominentButton()
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel(index == 0 ? "\(color), main color" : color)
                        .accessibilityHint("Removes this color")
                    }
                }
            }
            FlowChips {
                ForEach(colorChoices, id: \.self) { color in
                    Button { addColors([color]) } label: {
                        HStack(spacing: 6) {
                            ColorDot(name: color)
                            Text(color)
                        }
                    }
                    .accessibilityLabel(color)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.primary)
                }
                Button { askNewColor = true } label: {
                    // Not a Label: in a list row a Label stretches to the row's height.
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Color")
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .fixedSize()
            }
            if let fix = Spelling.suggestion(for: draft.colorsText, known: knownWords) {
                suggestion(fix) { useSpelling(fix) }
            }
        } header: {
            Text("Colors")
        } footer: {
            Text("Tap one or more colors. The first one is the main color. Tap ✕ to take one off.")
        }
        .alert("New Color", isPresented: $askNewColor) {
            TextField("Like Sage or Coral", text: $newColorText)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { newColorText = "" }
            Button("Add") {
                let colors = Naming.cleanColors(newColorText)
                newColorText = ""
                addedColorsText = AddedColors.adding(colors, to: addedColorsText, known: Catalog.knownColors(variants))
                addColors(colors)
            }
        } message: {
            Text("It's added to this button and kept in the list for future buttons.")
        }
    }

    /// Every color used so far, most used first, then ones she added that no button uses
    /// yet; the ones already picked are left out.
    private var colorChoices: [String] {
        let picked = Set(draft.colors.map { $0.lowercased() })
        return AddedColors.all(Catalog.knownColors(variants), addedColorsText).filter { !picked.contains($0.lowercased()) }
    }

    private func addColors(_ colors: [String]) {
        var result = draft.colors
        for color in colors {
            // A color she already has, typed in other letters, is used as saved.
            let known = AddedColors.all(Catalog.knownColors(variants), addedColorsText)
            let name = known.first { $0.caseInsensitiveCompare(color) == .orderedSame } ?? color
            if !result.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { result.append(name) }
        }
        draft.colorsText = result.joined(separator: " / ")
    }

    private func removeColor(at index: Int) {
        var colors = draft.colors
        colors.remove(at: index)
        draft.colorsText = colors.joined(separator: " / ")
    }

    /// Fixes the spelling in the draft and in the kept list.
    private func useSpelling(_ fix: String) {
        for (old, new) in zip(draft.colors, Naming.cleanColors(fix)) where old != new {
            addedColorsText = AddedColors.replacing(old, with: new, in: addedColorsText)
        }
        draft.colorsText = fix
    }

    private func suggestion(_ fix: String, apply: @escaping () -> Void) -> some View {
        Button(action: apply) {
            Label("Did you mean “\(fix)”?", systemImage: "character.cursor.ibeam")
        }
    }

    private var ruleSKU: String { draft.ruleSKU(designs, variants, editing: editing) }

    /// A saved button keeps its SKU; a new one follows the rules as she types.
    private var suggestedSKU: String {
        if let editing, !editing.sku.isEmpty { return editing.sku }
        return ruleSKU
    }

    private var sizeChoices: [String] {
        Naming.sizes + (draft.size.isEmpty || Naming.sizes.contains(draft.size) ? [] : [draft.size])
    }

    private var knownWords: Set<String> {
        // Colors she added on purpose count as known words too.
        let text = (variants.map(\.title) + designs.map(\.name) + [addedColorsText]).joined(separator: " ")
        return Set(Naming.splitWords(text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "/", with: " "))
            .map { $0.lowercased() })
    }
}

/// A dot of the color a chip names, so she sees the glaze, not just its name. A color word
/// the app doesn't know gets no dot.
struct ColorDot: View {
    let name: String
    /// On a picked (rust) chip the dot sits on a white disc, so a red, burgundy or brown dot
    /// still shows: against the chip they were 1.2:1 (nit 31).
    var onAccent = false

    var body: some View {
        if let rgb = Swatch.rgb(for: name) {
            Circle()
                .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                .overlay(Circle().strokeBorder(onAccent ? Color.black.opacity(0.25) : Color.primary.opacity(0.25),
                                               lineWidth: 0.5))
                .frame(width: 14, height: 14)
                .padding(onAccent ? 2 : 0)
                .background { if onAccent { Circle().fill(Color.white) } }
                .accessibilityHidden(true)
        }
    }
}

/// Spelling suggestions for new shape and color names ("Pineaple" → "Pineapple").
enum Spelling {
    static func suggestion(for text: String, known: Set<String>) -> String? {
        let checker = UITextChecker()
        var result = text
        var changed = false
        var start = 0
        while true {
            let ns = result as NSString
            let range = checker.rangeOfMisspelledWord(in: result, range: NSRange(location: 0, length: ns.length),
                                                      startingAt: start, wrap: false, language: "en_US")
            guard range.location != NSNotFound else { break }
            let word = ns.substring(with: range)
            start = range.location + range.length
            guard !known.contains(word.lowercased()),
                  let guess = checker.guesses(forWordRange: range, in: result, language: "en_US")?.first else { continue }
            result = ns.replacingCharacters(in: range, with: guess)
            start = range.location + (guess as NSString).length
            changed = true
        }
        return changed ? result.split(separator: "/").map { Naming.cleanColor(String($0)) }.joined(separator: " / ") : nil
    }
}
