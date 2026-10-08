import InvoiceKit
import PhotosUI
import SwiftUI
import UIKit

/// Photo decoding and resizing.
enum Photos {
    /// Longest side of photos handed to the background remover.
    nonisolated static let workingSize = 1600

    nonisolated static func thumbnailPNG(_ png: Data, maxSide: Int) -> Data? {
        guard let image = ImageTools.uprightImage(from: png, maxSide: maxSide) else { return nil }
        return ImageTools.pngData(image)
    }

    /// An upright CGImage from a camera photo, at most `maxSide` pixels on its longer side.
    static func upright(_ image: UIImage, maxSide: Int = workingSize) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, CGFloat(maxSide) / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}

/// Small decoded copies of button photos, so lists scroll smoothly.
@MainActor final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for data: Data, side: CGFloat) -> UIImage? {
        let pixels = Int(side * 3)
        let key = "\(data.count)-\(data.hashValue)-\(pixels)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let cg = ImageTools.uprightImage(from: data, maxSide: pixels) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A button photo, or a placeholder circle when there is none.
struct ButtonPhoto: View {
    let data: Data?
    var side: CGFloat = 56

    var body: some View {
        Group {
            if let data, let image = ThumbnailCache.shared.image(for: data, side: side) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "camera")
                    .font(.system(size: side * 0.3))
                    .foregroundStyle(.secondary)
                    .frame(width: side * 0.8, height: side * 0.8)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// Squares behind cutouts, so she can see what's been removed. System grays, so it adapts
/// to Dark Mode instead of glowing white (Dark Mode, "Soften the color of white backgrounds").
struct Checkerboard: View {
    var square: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(.systemGray6)))
            let cols = Int(size.width / square) + 1, rows = Int(size.height / square) + 1
            for r in 0..<rows {
                for c in 0..<cols where (r + c).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(c) * square, y: CGFloat(r) * square, width: square, height: square)
                    context.fill(Path(rect), with: .color(Color(.systemGray4)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The camera, as a sheet.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// "Take Photo" and "Choose from Photos" buttons that hand back an upright image.
struct PhotoSourceButtons: View {
    let takeLabel: String
    let chooseLabel: String
    let onImage: (CGImage) -> Void

    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        if CameraPicker.isAvailable {
            Button {
                showCamera = true
            } label: {
                Label(takeLabel, systemImage: "camera")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let cg = Photos.upright(image) { onImage(cg) }
                }
                .ignoresSafeArea()
            }
        }
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(chooseLabel, systemImage: "photo.on.rectangle")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let cg = ImageTools.uprightImage(from: data, maxSide: Photos.workingSize) {
                    onImage(cg)
                }
                pickerItem = nil
            }
        }
    }
}
