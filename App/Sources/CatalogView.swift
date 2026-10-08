import InvoiceKit
import SwiftData
import SwiftUI

/// The Buttons tab (SPEC.md, "Buttons"): every saved button, a section per shape with a row
/// per color and size, Search and Add a Button in the navigation bar, and Archive. Archiving or changing a button
/// never changes an invoice that already has it.
struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
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
                                    Button("Add Color or Size…", systemImage: "plus") {
                                        adding = NewButton(design: design)
                                    }
                                    Button("Rename…", systemImage: "pencil") {
                                        newName = design.name
                                        renaming = design
                                    }
                                    Button("Archive Shape", systemImage: "archivebox") {
                                        context.undoManager?.setActionName("Archive \(design.name)")
                                        for variant in design.variants ?? [] { variant.isHidden = true }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").font(.title3)
                                        .frame(minWidth: 44, minHeight: 44)
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
        }
        .listStyle(.insetGrouped)
        .shrinkingTitle("Buttons")
        .toolbar {
            searchCircle
            ToolbarItem(placement: .topBarTrailing) { addButton }
        }
        .overlay {
            if variants.isEmpty {
                ContentUnavailableView("No Buttons Yet", systemImage: "circle.grid.2x2",
                                       description: Text("Tap + to save your first one."))
            } else if !search.isEmpty, Catalog.search(search, in: variants, includeArchived: true).isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        // On iOS 26 search is a circle in the bar that opens into a field above the keyboard
        // (Search fields, "Search in a toolbar"); on iOS 18 it's the field under the title.
        .searchable(text: $search, placement: .toolbar, prompt: "Search buttons")
        .minimizedSearch()
        .readableWidth()
        .sheet(item: $editing) { variant in
            NavigationStack { EditButtonView(variant: variant) }
        }
        .sheet(item: $adding) { target in
            NewButtonSheet(design: target.design)
        }
        .onAppear(perform: handleRequest)
        .onChange(of: router.request) { handleRequest() }
        .alert("Rename shape", isPresented: .init(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { rename() }
        } message: {
            Text("Changes the name on new invoices and drafts. SKUs and finished invoices stay the same.")
        }
    }

    /// The Add a Button quick action and App Shortcut open the new-button steps here.
    private func handleRequest() {
        guard router.request == .newButton else { return }
        router.request = nil
        adding = NewButton(design: nil)
    }

    private var archived: [ButtonVariant] {
        variants.filter(\.isHidden).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Search, then Add, as circles in the bar, level with the title and there at any scroll
    /// position: symbols, the add one prominent (Toolbars, "Prefer simple, recognizable
    /// symbols"; "Use the .prominent style for key actions").
    @ToolbarContentBuilder private var searchCircle: some ToolbarContent {
        if #available(iOS 26.0, *) {
            DefaultToolbarItem(kind: .search, placement: .topBarTrailing)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
    }

    private var addButton: some View {
        Button("Add a Button", systemImage: "plus") { adding = NewButton(design: nil) }
            .glassProminentButton()
    }

    private func row(_ variant: ButtonVariant) -> some View {
        Button {
            editing = variant
        } label: {
            AdaptiveRow {
                IconTextStack {
                    ButtonPhoto(data: variant.photo, side: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(search.isEmpty && !variant.isHidden ? variantName(variant) : variant.title)
                            .font(.body.weight(.medium))
                        Text(variant.sku).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                    }
                }
            } trailing: {
                Text(variant.price > .zero ? variant.price.formatted : "No price")
                    .monospacedDigit()
                    .foregroundStyle(variant.price > .zero ? .primary : Color.orange)
            }
            .opacity(variant.isHidden ? 0.5 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityValue(variant.isHidden ? "Archived" : "")
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) { archiveButton(variant) }
        .contextMenu {
            Button("Change…", systemImage: "pencil") { editing = variant }
            archiveButton(variant)
        }
    }

    @ViewBuilder private func archiveButton(_ variant: ButtonVariant) -> some View {
        if variant.isHidden {
            Button("Unarchive", systemImage: "tray.and.arrow.up") {
                context.undoManager?.setActionName("Unarchive")
                variant.isHidden = false
            }
            .tint(.blue)
        } else {
            Button("Archive", systemImage: "archivebox") {
                context.undoManager?.setActionName("Archive")
                variant.isHidden = true
            }
            .tint(.gray)
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
    /// iOS 26: the search field folds into a circle in the bar until she taps it.
    @ViewBuilder func minimizedSearch() -> some View {
        if #available(iOS 26.0, *) {
            searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }
}
