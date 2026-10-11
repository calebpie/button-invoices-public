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
    @State private var askDiscard = false
    @State private var original: String

    init(variant: ButtonVariant) {
        self.variant = variant
        let draft = ButtonDraft(editing: variant)
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft.snapshot)
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
                .padding(.vertical, 8)
                PhotoSourceButtons(takeLabel: draft.photo == nil ? "Take Photo" : "Retake Photo",
                                   chooseLabel: "Choose from Photos") { image in
                    draft.source = image
                    cutoutSource = .init(image: image)
                }
                if let source = draft.source, draft.photo != nil {
                    Button { cutoutSource = .init(image: source) } label: {
                        Label("Touch Up", systemImage: "paintbrush.pointed")
                    }
                }
            } header: {
                Text("Photo")
            }

            ButtonDetailsSections(draft: draft, editing: variant)

            Section {
                TextField("Like olive, blush", text: $draft.aliasesText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Also known as")
            } footer: {
                // The search learns these when she picks this button after typing them, so
                // she can see and correct what it learned (Machine learning, "Corrections").
                Text("Other words that find this button when you type an order. The app adds words you used to find it; remove any that are wrong. Separate words with commas.")
            }

            Section {
                Button(variant.isHidden ? "Unarchive This Button" : "Archive This Button",
                       systemImage: variant.isHidden ? "tray.and.arrow.up" : "archivebox") {
                    Undo.perform(variant.isHidden ? "Unarchive" : "Archive", context, .setHidden([variant], !variant.isHidden))
                    dismiss()
                }
                if neverInvoiced {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        DestructiveLabel("Delete This Button", systemImage: "trash")
                    }
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
                    Text("Earlier versions")
                } footer: {
                    Text("A copy is kept each time you change this button. Finished invoices keep what they had.")
                }
            }

            Section {
                Button(action: save) {
                    Text("Save Changes").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .prominentButton()
                .disabled(problem != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let problem { Notice(problem) }
            }
        }
        .navigationTitle("Change Button")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CancelButton { if isDirty { askDiscard = true } else { dismiss() } }
                    .discardQuestion(isAsking: $askDiscard) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ConfirmButton(title: "Save", action: save).disabled(problem != nil)
            }
        }
        .confirmsDiscard(isDirty) { dismiss() }
        .fullScreenCover(item: $cutoutSource) { source in
            PhotoCutoutView(source: source.image) { png in draft.photo = png }
        }
        .alert("Delete \(variant.title)?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Button", role: .destructive, action: delete)
        } message: {
            Text("It has never been on an invoice, so nothing else changes.")
        }
    }

    private var problem: String? { draft.problem(designs, variants, editing: variant) }

    private var isDirty: Bool { draft.snapshot != original }

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

/// The new-button steps on their own, from the Buttons tab.
struct NewButtonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ButtonDraft
    @State private var path: [NewButtonStep] = []
    @State private var askDiscard = false

    init(design: ButtonDesign?) {
        _draft = State(initialValue: ButtonDraft(design: design,
                                                 price: design?.visibleVariants.first { $0.price > .zero }?.price))
    }

    var body: some View {
        NavigationStack(path: $path) {
            step(.photo)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CancelButton { if draft.hasContent { askDiscard = true } else { dismiss() } }
                            .discardQuestion(isAsking: $askDiscard) { dismiss() }
                    }
                }
                .navigationDestination(for: NewButtonStep.self) { step($0) }
        }
        .confirmsDiscard(draft.hasContent) { dismiss() }
    }

    private func step(_ s: NewButtonStep) -> some View {
        NewButtonStepView(draft: draft, step: s, purpose: .catalog) { path.append($0) } finished: { _ in dismiss() }
    }
}
