import InvoiceKit
import SwiftData
import SwiftUI

/// The Buttons tab (SPEC.md, "Buttons"): every saved button, a section per shape with a row
/// per color and size, a floating Add a Button, and Archive. Archiving or changing a button
/// never changes an invoice that already has it.
struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    @State private var search = ""
    @State private var showArchived = false
    @State private var editing: ButtonVariant?
    @State private var adding: NewButton?
    @State private var renaming: ButtonDesign?
    @State private var newName = ""

    struct NewButton: Identifiable {
        let id = UUID()
        let design: ButtonDesign?
    }

    var body: some View {
        List {
            if search.isEmpty {
                ForEach(designs) { design in
                    let active = design.visibleVariants
                    if !active.isEmpty {
                        Section {
                            ForEach(active) { row($0) }
                        } header: {
                            HStack {
                                Text(design.name)
                                Text("\(active.count)").foregroundStyle(.secondary)
                                Spacer()
                                Menu {
                                    Button("Add a color or size of \(design.name)", systemImage: "plus") {
                                        adding = NewButton(design: design)
                                    }
                                    Button("Rename \(design.name)", systemImage: "pencil") {
                                        newName = design.name
                                        renaming = design
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").font(.title3)
                                }
                                .accessibilityLabel("\(design.name) options")
                                .textCase(nil)
                            }
                        }
                    }
                }
                if !archived.isEmpty {
                    Section(isExpanded: $showArchived) {
                        ForEach(archived) { row($0) }
                    } header: {
                        Text("Archived (\(archived.count))")
                    }
                }
            } else {
                Section {
                    ForEach(Catalog.search(search, in: variants, includeArchived: true)) { row($0) }
                }
            }
            // Room so the last row can scroll clear of the floating button.
            Color.clear.frame(height: 56).listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottomTrailing) { addButton }
        .overlay {
            if variants.isEmpty {
                ContentUnavailableView("No buttons yet", systemImage: "circle.grid.2x2",
                                       description: Text("Tap Add a Button to save your first one."))
            }
        }
        .searchable(text: $search, prompt: "Search buttons")
        .readableWidth()
        .navigationTitle("Buttons")
        .sheet(item: $editing) { variant in
            NavigationStack { EditButtonView(variant: variant) }
        }
        .sheet(item: $adding) { target in
            NewButtonSheet(design: target.design)
        }
        .alert("Rename shape", isPresented: .init(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { rename() }
        } message: {
            Text("Changes the name on new invoices and drafts. SKUs and finished invoices stay the same.")
        }
    }

    private var archived: [ButtonVariant] {
        variants.filter(\.isHidden).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Floats above the tab bar, bottom right.
    private var addButton: some View {
        Button {
            adding = NewButton(design: nil)
        } label: {
            Label("Add a Button", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
        }
        .glassProminentButton()
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }

    private func row(_ variant: ButtonVariant) -> some View {
        Button {
            editing = variant
        } label: {
            HStack(spacing: 12) {
                ButtonPhoto(data: variant.photo, side: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(search.isEmpty && !variant.isHidden ? variantName(variant) : variant.title)
                        .font(.body.weight(.medium))
                    Text(variant.sku).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(variant.price > .zero ? variant.price.formatted : "No price")
                    .monospacedDigit()
                    .foregroundStyle(variant.price > .zero ? .primary : Color.orange)
            }
            .opacity(variant.isHidden ? 0.5 : 1)
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            if variant.isHidden {
                Button("Unarchive", systemImage: "tray.and.arrow.up") { variant.isHidden = false }
                    .tint(.blue)
            } else {
                Button("Archive", systemImage: "archivebox") { variant.isHidden = true }
                    .tint(.gray)
            }
        }
    }

    /// Under its shape's heading a row only needs the variation: "Black / White, Large".
    private func variantName(_ v: ButtonVariant) -> String {
        ([v.colors.joined(separator: " / ")] + (v.size.isEmpty ? [] : [v.size])).joined(separator: ", ")
    }

    private func rename() {
        guard let design = renaming else { return }
        let name = Naming.cleanDesign(newName)
        renaming = nil
        guard !name.isEmpty, name != design.name else { return }
        for variant in design.variants ?? [] {
            let version = ButtonVersion(of: variant)
            context.insert(version)
            version.variant = variant
        }
        design.name = name
        for variant in design.variants ?? [] {
            for line in variant.invoiceLines ?? [] where line.invoice?.status == .draft {
                line.copyDetails(from: variant)
            }
        }
    }
}

extension View {
    /// Liquid Glass on iOS 26 and later; a filled capsule before that.
    @ViewBuilder func glassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }
}
