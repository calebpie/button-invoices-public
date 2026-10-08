import InvoiceKit
import SwiftData
import SwiftUI

/// My Buttons: every saved button by shape, to add, correct prices, rename or hide.
struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    @State private var search = ""
    @State private var showHidden = false
    @State private var editing: ButtonVariant?
    @State private var adding: NewButton?
    @State private var renaming: ButtonDesign?
    @State private var newName = ""

    struct NewButton: Identifiable {
        let id = UUID()
        let design: ButtonDesign?
    }

    var body: some View {
        Group {
            List {
                if search.isEmpty {
                    ForEach(designs) { design in
                        let shown = design.sortedVariants.filter { showHidden || !$0.isHidden }
                        if !shown.isEmpty {
                            Section {
                                ForEach(shown) { variant in row(variant) }
                                Button {
                                    adding = NewButton(design: design)
                                } label: {
                                    Label("Add a color or size", systemImage: "plus").font(.subheadline)
                                }
                            } header: {
                                HStack {
                                    Text(design.name)
                                    Spacer()
                                    Button("Rename") {
                                        newName = design.name
                                        renaming = design
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(Catalog.search(search, in: variants).filter { showHidden || !$0.isHidden }) { row($0) }
                }
            }
            .overlay {
                if variants.isEmpty {
                    ContentUnavailableView("No buttons yet", systemImage: "circle.grid.2x2",
                                           description: Text("Tap + to add your first button."))
                }
            }
            .searchable(text: $search, prompt: "Search buttons")
            .readableWidth()
            .navigationTitle("My Buttons")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add a Button", systemImage: "plus") { adding = NewButton(design: nil) }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("Show hidden buttons", isOn: $showHidden)
                }
            }
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
                Text("Changes the name on new invoices. SKUs and finished invoices stay the same.")
            }
        }
    }

    private func row(_ variant: ButtonVariant) -> some View {
        Button {
            editing = variant
        } label: {
            HStack(spacing: 12) {
                ButtonPhoto(data: variant.photo, side: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.title).font(.body.weight(.medium))
                    Text(variant.sku).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(variant.price > .zero ? variant.price.formatted : "No price")
                    .monospacedDigit()
                    .foregroundStyle(variant.price > .zero ? .primary : Color.orange)
            }
            .opacity(variant.isHidden ? 0.45 : 1)
        }
        .foregroundStyle(.primary)
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
