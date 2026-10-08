import InvoiceKit
import SwiftData
import SwiftUI

/// Changing a saved button: photo, shape, colors, size, price, SKU. Each save keeps a copy of
/// how it was before; finished invoices are never changed.
struct EditButtonView: View {
    let variant: ButtonVariant

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)]) private var designs: [ButtonDesign]
    @Query private var variants: [ButtonVariant]
    @State private var draft: ButtonDraft
    @State private var cutoutSource: NewButtonPhotoStep.CutoutSource?
    @State private var confirmDelete = false

    init(variant: ButtonVariant) {
        self.variant = variant
        _draft = State(initialValue: ButtonDraft(editing: variant))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ZStack {
                        Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12))
                        ButtonPhoto(data: draft.photo, side: 150)
                    }
                    .frame(width: 170, height: 170)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                PhotoSourceButtons(takeLabel: draft.photo == nil ? "Take Photo" : "Retake Photo",
                                   chooseLabel: "Choose from Photos") { image in
                    draft.source = image
                    cutoutSource = .init(image: image)
                }
                if let source = draft.source, draft.photo != nil {
                    Button { cutoutSource = .init(image: source) } label: {
                        Label("Touch Up the Edges", systemImage: "paintbrush.pointed")
                    }
                }
            } header: {
                Text("Photo")
            }

            ButtonDetailsSections(draft: draft, editing: variant)

            Section {
                Button(variant.isHidden ? "Unarchive This Button" : "Archive This Button",
                       systemImage: variant.isHidden ? "tray.and.arrow.up" : "archivebox") {
                    variant.isHidden.toggle()
                    try? context.save()
                    dismiss()
                }
                if neverInvoiced {
                    Button("Delete This Button", role: .destructive) { confirmDelete = true }
                }
            } footer: {
                Text(neverInvoiced
                     ? "Archived buttons aren't offered for new invoices. You can unarchive them any time. A button that's never been invoiced can also be deleted."
                     : "Archived buttons aren't offered for new invoices. Invoices that already have this button keep it exactly as it was.")
            }

            if !variant.sortedVersions.isEmpty {
                Section {
                    ForEach(variant.sortedVersions) { version in
                        HStack(spacing: 12) {
                            ButtonPhoto(data: version.photo, side: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.title)
                                Text("\(version.sku) · \(version.price.formatted)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(version.savedAt, format: .dateTime.day().month(.abbreviated).year())
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Before your changes")
                } footer: {
                    Text("A copy is kept each time you change this button. Finished invoices keep what they had.")
                }
            }

            Section {
                Button(action: save) {
                    Text("Save Changes").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(problem != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let problem { Text(problem).foregroundStyle(.orange) }
            }
        }
        .navigationTitle("Change Button")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(problem != nil) }
        }
        .fullScreenCover(item: $cutoutSource) { source in
            PhotoCutoutView(source: source.image) { png in draft.photo = png }
        }
        .confirmationDialog("Delete \(variant.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Button", role: .destructive, action: delete)
        } message: {
            Text("It has never been on an invoice, so nothing else changes.")
        }
    }

    private var problem: String? { draft.problem(designs, variants, editing: variant) }

    private var neverInvoiced: Bool { (variant.invoiceLines ?? []).isEmpty }

    private func save() {
        guard problem == nil else { return }
        draft.apply(to: variant, isHidden: variant.isHidden, context, designs)
        dismiss()
    }

    private func delete() {
        let design = variant.design
        context.delete(variant)
        if let design, (design.variants ?? []).allSatisfy({ $0 === variant }) { context.delete(design) }
        try? context.save()
        dismiss()
    }
}

/// The new-button steps on their own, from My Buttons.
struct NewButtonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ButtonDraft
    @State private var path: [NewButtonStep] = []

    init(design: ButtonDesign?) {
        _draft = State(initialValue: ButtonDraft(design: design,
                                                 price: design?.visibleVariants.first { $0.price > .zero }?.price))
    }

    var body: some View {
        NavigationStack(path: $path) {
            step(.photo)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
                .navigationDestination(for: NewButtonStep.self) { step($0) }
        }
    }

    private func step(_ s: NewButtonStep) -> some View {
        NewButtonStepView(draft: draft, step: s, purpose: .catalog) { path.append($0) } finished: { _ in dismiss() }
    }
}
