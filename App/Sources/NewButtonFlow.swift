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
    /// Started from My Buttons: saving ends the flow.
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
    /// Saved buttons the photo looks like, closest first, from the photo check.
    var lookAlikes: [(variant: ButtonVariant, distance: Double)] = []

    init(design: ButtonDesign? = nil, newDesignName: String = "", colors: [String] = [], size: String = "", price: Money? = nil) {
        designID = design?.persistentModelID
        self.newDesignName = design == nil ? newDesignName : ""
        colorsText = colors.joined(separator: " / ")
        self.size = size
        priceText = price.map(\.editingText) ?? ""
    }

    init(editing v: ButtonVariant) {
        designID = v.design?.persistentModelID
        colorsText = v.colorsText
        size = v.size
        priceText = v.price.editingText
        skuText = v.sku
        photo = v.photo
    }

    static func == (a: ButtonDraft, b: ButtonDraft) -> Bool { a === b }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

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

    func duplicate(_ designs: [ButtonDesign], _ variants: [ButtonVariant], editing: ButtonVariant?) -> ButtonVariant? {
        let t = title(designs)
        guard !t.isEmpty else { return nil }
        return variants.first { $0 !== editing && $0.title.caseInsensitiveCompare(t) == .orderedSame }
    }

    /// Why it can't be saved yet, in her words, or nil.
    func problem(_ designs: [ButtonDesign], _ variants: [ButtonVariant], editing: ButtonVariant?) -> String? {
        if designName(designs).isEmpty { return "Pick the shape or type its name." }
        if colors.isEmpty { return "Type at least one color." }
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
            Text(title).font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: 1. Photo

struct NewButtonPhotoStep: View {
    let draft: ButtonDraft
    let advance: (NewButtonStep) -> Void
    @State private var cutoutSource: CutoutSource?

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
                    ZStack {
                        Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12))
                        ButtonPhoto(data: draft.photo, side: 180)
                    }
                    .frame(width: 200, height: 200)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                PhotoSourceButtons(takeLabel: draft.photo == nil ? "Take Photo" : "Retake Photo",
                                   chooseLabel: "Choose from Photos") { image in
                    draft.source = image
                    cutoutSource = CutoutSource(image: image)
                }
                if let source = draft.source, draft.photo != nil {
                    Button { cutoutSource = CutoutSource(image: source) } label: {
                        Label("Touch Up the Edges", systemImage: "paintbrush.pointed")
                    }
                }
            } footer: {
                Text("Put one button on a plain table or sheet of paper, in good light, and fill the frame. The background is removed for you.")
            }
            Section {
                Button { advance(.matches) } label: {
                    Text("Next: Is it already saved?").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.photo == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                Button("No photo right now") { advance(.details) }
                    .frame(maxWidth: .infinity)
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
                        Label("This looks like a button you already saved.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.headline)
                    } else if !close.isEmpty {
                        Text("These saved buttons look similar:").font(.headline)
                    } else {
                        Label("It doesn't look like any saved button.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.headline)
                    }
                    ForEach(Array(close), id: \.variant.persistentModelID) { match in
                        matchCard(match.variant)
                    }
                }
                if !checking, !sameShape.isEmpty, let design = draft.chosenDesign(designs) {
                    Text("Your saved \(design.name) buttons:").font(.headline).padding(.top, 4)
                    ForEach(sameShape) { matchCard($0) }
                }
                Button { advance(.details) } label: {
                    Text("No, it's a new button").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(checking)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
        .task { await check() }
    }

    private func matchCard(_ v: ButtonVariant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ButtonPhoto(data: v.photo, side: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.title).font(.headline)
                    Text("\(v.price.formatted) · \(v.sku)" + (v.isHidden ? " · archived" : "")).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(purpose == .invoice ? "It's this one" : "Already saved") {
                    v.isHidden = false // using it again brings it back from the archive
                    chose(v)
                }
                    .buttonStyle(.bordered)
                Button("Same shape, new color or size") {
                    draft.designID = v.design?.persistentModelID
                    draft.newDesignName = ""
                    if draft.colorsText.isEmpty { draft.colorsText = v.colorsText }
                    if draft.size.isEmpty { draft.size = v.size }
                    if draft.price == nil { draft.priceText = v.price.editingText }
                    advance(.details)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .card()
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
                    Text("Next: Check it").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(problem != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let problem { Text(problem).foregroundStyle(.orange) }
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
                    Label("The photo looks a lot like \(best.variant.title). That's fine if this one is a different color or size.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if draft.photo == nil {
                    Label("No photo yet. You can add one later from My Buttons.", systemImage: "camera")
                        .foregroundStyle(.secondary)
                }
                if let problem = draft.problem(designs, variants, editing: nil) {
                    Label(problem, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                }
                Button {
                    saved(draft.saveNew(context, designs))
                } label: {
                    Text(purpose == .invoice ? "Save and Add to Invoice" : "Save Button")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.problem(designs, variants, editing: nil) != nil)
                Text("Tap Back to change anything.").font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Button")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared form sections

/// Shape, colors, size, price, and the name and SKU as they'll be printed. Used for new
/// buttons and for changing saved ones.
struct ButtonDetailsSections: View {
    @Bindable var draft: ButtonDraft
    let editing: ButtonVariant?

    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    var body: some View {
        Group {
            designSection
            Section {
                TextField("Colors, like Navy / White", text: $draft.colorsText)
                    .textInputAutocapitalization(.words)
                colorChips
                if let fix = Spelling.suggestion(for: draft.colorsText, known: knownWords) {
                    suggestion(fix) { draft.colorsText = fix }
                }
            } header: {
                Text("Colors")
            } footer: {
                Text("Main color first. Separate two colors with “/”.")
            }
            Section("Size") {
                Picker("Size", selection: $draft.size) {
                    Text("One size").tag("")
                    ForEach(sizeChoices, id: \.self) { Text($0).tag($0) }
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
    }

    private var designSection: some View {
        Section {
            Picker("Shape", selection: $draft.designID) {
                Text("New shape…").tag(PersistentIdentifier?.none)
                ForEach(designs) { Text($0.name).tag(Optional($0.persistentModelID)) }
            }
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
                Label("“\(twin.title)” is already saved (SKU \(twin.sku)).", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Name and SKU")
        } footer: {
            Text("The SKU is the year, then letters for the shape, colors and size. A saved button keeps its SKU unless you change it here.")
        }
    }

    private var colorChips: some View {
        let current = Set(draft.colors.map { $0.lowercased() })
        let chips = Catalog.knownColors(variants).filter { !current.contains($0.lowercased()) }.prefix(14)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(chips), id: \.self) { color in
                    Button(color) { draft.colorsText = (draft.colors + [color]).joined(separator: " / ") }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
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
        let text = (variants.map(\.title) + designs.map(\.name)).joined(separator: " ")
        return Set(Naming.splitWords(text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "/", with: " "))
            .map { $0.lowercased() })
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
