import InvoiceKit
import SwiftUI

/// Removes the background from a button photo, then lets her fix it with a finger:
/// Erase paints background away, Restore paints the button back.
struct PhotoCutoutView: View {
    let source: CGImage
    let onDone: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cutout: SubjectCutout?
    @State private var canvas: MaskCanvas?
    @State private var mask: CGImage?
    @State private var touchingUp = false
    @State private var restoring = false
    @State private var brushSize: Double = 28
    @State private var lastPoint: CGPoint?
    @State private var fingerAt: CGPoint?
    @State private var saving = false
    @State private var askDiscard = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if cutout == nil {
                    Spacer()
                    ProgressView("Removing the background…").controlSize(.large)
                    Spacer()
                } else {
                    message
                    editor
                    controls
                }
            }
            .padding(.bottom)
            .navigationTitle(touchingUp ? "Touch Up" : "Button Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Touch-up work isn't thrown away without asking (Photo editing, "Confirm
                    // cancellation of edits").
                    CancelButton { if canvas?.canUndo == true { askDiscard = true } else { dismiss() } }
                        .discardQuestion("Discard your touch-up?", isAsking: $askDiscard) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: touchingUp ? "Done" : "Use Photo") {
                        if touchingUp { touchingUp = false } else { finish() }
                    }
                    .disabled(cutout == nil || saving)
                }
            }
        }
        .task {
            let result = await Cutout.lift(source)
            cutout = result
            canvas = MaskCanvas(mask: result.mask)
            mask = result.mask
        }
    }

    @ViewBuilder private var message: some View {
        if let cutout, !touchingUp {
            if cutout.objectMasks.count > 1 {
                Label("There are \(cutout.objectMasks.count) buttons in this photo. Tap the one to keep.", systemImage: "hand.tap")
                    .padding(.horizontal)
            } else if cutout.usedColorFallback {
                Label("The background was removed by color. Use Touch Up if anything is missing.", systemImage: "info.circle")
                    .padding(.horizontal)
            } else {
                Text("Background removed. Use Touch Up to fix any edges.").padding(.horizontal)
            }
        } else if touchingUp {
            Text(restoring ? "Paint over parts of the button to bring them back." : "Paint over leftover background to erase it.")
                .padding(.horizontal)
        }
    }

    private var editor: some View {
        GeometryReader { geo in
            let fit = fitted(CGSize(width: source.width, height: source.height), in: geo.size)
            ZStack {
                Checkerboard()
                if touchingUp {
                    Image(decorative: source, scale: 1).resizable().opacity(0.3)
                }
                if let mask {
                    Image(decorative: source, scale: 1).resizable()
                        .mask { Image(decorative: mask, scale: 1).resizable().luminanceToAlpha() }
                        .accessibilityLabel(touchingUp ? "Photo being touched up" : "Button photo with the background removed")
                }
                if touchingUp, let fingerAt {
                    Circle().stroke(.white, lineWidth: 2).shadow(radius: 1)
                        .frame(width: brushSize, height: brushSize)
                        .position(fingerAt)
                }
            }
            .frame(width: fit.width, height: fit.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(touchingUp ? paint(fit: fit) : nil)
            .simultaneousGesture(SpatialTapGesture().onEnded { pick(at: $0.location, fit: fit) },
                                 including: !touchingUp && (cutout?.objectMasks.count ?? 0) > 1 ? .all : .subviews)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var controls: some View {
        if touchingUp {
            VStack(spacing: 12) {
                Picker("Brush", selection: $restoring) {
                    Text("Erase").tag(false)
                    Text("Restore").tag(true)
                }
                .pickerStyle(.segmented)
                HStack {
                    Image(systemName: "circle.fill").font(.caption2)
                    Slider(value: $brushSize, in: 8...80)
                    Image(systemName: "circle.fill").font(.title2)
                }
                .accessibilityLabel("Brush size")
                HStack {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        canvas?.undo()
                        mask = canvas?.mask
                    }
                    .disabled(!(canvas?.canUndo ?? false))
                    Spacer()
                    Button("Start Over", systemImage: "arrow.counterclockwise") {
                        if let original = cutout?.mask {
                            canvas?.replace(with: original)
                            mask = canvas?.mask
                        }
                    }
                }
            }
            .padding(.horizontal)
        } else {
            VStack(spacing: 10) {
                Button {
                    finish()
                } label: {
                    // An activity indicator in the button while the photo is prepared
                    // (Buttons, iOS).
                    HStack(spacing: 8) {
                        if saving { ProgressView().tint(.white) }
                        Text(saving ? "Saving Photo…" : "Use This Photo")
                    }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                }
                .prominentButton()
                .disabled(saving)
                Button {
                    touchingUp = true
                } label: {
                    Label("Touch Up", systemImage: "paintbrush.pointed").frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }

    // MARK: Actions

    private func fitted(_ image: CGSize, in box: CGSize) -> CGSize {
        let scale = min(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    /// View point → photo pixel.
    private func pixel(_ p: CGPoint, fit: CGSize) -> CGPoint {
        CGPoint(x: p.x / fit.width * CGFloat(source.width), y: p.y / fit.height * CGFloat(source.height))
    }

    private func paint(fit: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let canvas else { return }
                let p = pixel(value.location, fit: fit)
                if lastPoint == nil { canvas.beginStroke() }
                let radius = brushSize / 2 * CGFloat(source.width) / fit.width
                canvas.stroke(from: lastPoint ?? p, to: p, radius: radius, keep: restoring)
                lastPoint = p
                fingerAt = value.location
                mask = canvas.mask
            }
            .onEnded { _ in
                lastPoint = nil
                fingerAt = nil
            }
    }

    /// With several buttons in the photo, keep the one she tapped.
    private func pick(at location: CGPoint, fit: CGSize) {
        guard let cutout, cutout.objectMasks.count > 1, let canvas else { return }
        let p = pixel(location, fit: fit)
        if let chosen = cutout.objectMasks.first(where: { Cutout.maskKeeps($0, x: Int(p.x), y: Int(p.y)) }) {
            canvas.replace(with: chosen)
            mask = canvas.mask
            self.cutout = SubjectCutout(photo: cutout.photo, mask: chosen, objectMasks: [], usedColorFallback: cutout.usedColorFallback)
        }
    }

    private func finish() {
        guard let mask else { return }
        saving = true
        let photo = source
        Task {
            let png = await Task.detached {
                Cutout.apply(mask, to: photo).flatMap { Cutout.squareCrop($0) }.flatMap(ImageTools.pngData)
            }.value
            saving = false
            if let png {
                onDone(png)
                dismiss()
            }
        }
    }
}
