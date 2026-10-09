import InvoiceKit
import SwiftData
import SwiftUI

/// The Buttons tab (SPEC.md, "Buttons"): every saved button, a section per shape with a row
/// per color and size, Search and New Button in the navigation bar, and Archive. Archiving or changing a button
/// never changes an invoice that already has it.
struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]

    @State private var search = ""
    @State private var editing: ButtonVariant?
    @State private var adding: NewButton?
    @State private var renaming: ButtonDesign?
    @State private var newName = ""

    struct NewButton: Identifiable {
        let id = UUID()
        let design: ButtonDesign?
    }

    var body: some View {
        // The results lie over the whole list instead of replacing it, as iOS's own search
        // results do: the list stays drawn underneath, so ✕ uncovers it at once. Rebuilding
        // it then held the search field still for 0.1 s, and rebuilding it after the field
        // had closed left the results under the title for 0.25 s (Docs/ui-nits.md, nit 1).
        ZStack {
            catalog
                .accessibilityHidden(!search.isEmpty)
            if !search.isEmpty {
                results
            }
        }
        // Search and add as circles level with the title, there at any scroll position:
        // symbols, add the prominent one (Toolbars, "Prefer simple, recognizable symbols";
        // "Use the .prominent style for key actions").
        .searchTitleBar("Buttons", text: $search, prompt: "Search buttons", searchLabel: "Search Buttons",
                        action: TitleBarAction(title: "New Button", systemImage: "plus") {
                            adding = NewButton(design: nil)
                        })
        .overlay {
            if variants.isEmpty {
                ContentUnavailableView("No Buttons Yet", systemImage: "circle.grid.2x2",
                                       description: Text("Tap + to save your first one."))
            }
        }
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

    private var catalog: some View {
        List {
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
                                    Undo.perform("Archive \(design.name)", context, .setHidden(design.variants ?? [], true))
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
                Section {
                    ForEach(archived) { row($0) }
                } header: {
                    Text("Archived (\(archived.count))")
                } footer: {
                    Text("Archived buttons aren't offered for new invoices. To use one again, tap it, then Unarchive This Button at the bottom.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var results: some View {
        let found = Catalog.search(search, in: variants, includeArchived: true)
        return List {
            Section {
                ForEach(found) { row($0, inSearch: true) }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if found.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    /// The New Button quick action and App Shortcut open the new-button steps here.
    private func handleRequest() {
        guard router.request == .newButton else { return }
        router.request = nil
        adding = NewButton(design: nil)
    }

    private var archived: [ButtonVariant] {
        variants.filter(\.isHidden).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// In the results a row shows its whole name, as there's no shape heading above it.
    private func row(_ variant: ButtonVariant, inSearch: Bool = false) -> some View {
        Button {
            editing = variant
        } label: {
            AdaptiveRow {
                IconTextStack {
                    ButtonPhoto(data: variant.photo, side: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(!inSearch && !variant.isHidden ? variantName(variant) : variant.title)
                            .font(.body.weight(.medium))
                        Text(variant.sku).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                    }
                }
            } trailing: {
                if variant.price > .zero {
                    Text(variant.price.formatted).monospacedDigit()
                } else {
                    Notice("No price")
                }
            }
            .opacity(variant.isHidden ? 0.5 : 1)
            // The separator starts under the photo, 20 points from the card's edge on both
            // sides (nit 36).
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
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
                Undo.perform("Unarchive", context, .setHidden([variant], false))
            }
            .tint(.blue)
        } else {
            Button("Archive", systemImage: "archivebox") {
                Undo.perform("Archive", context, .setHidden([variant], true))
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
