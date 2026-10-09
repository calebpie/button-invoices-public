import InvoiceKit
import SwiftUI
import UIKit

/// The receipt full screen, to check the amounts with her own eyes: pinch, double-tap or
/// drag to zoom, and the amounts the app read along the bottom to pick from
/// (Docs/ui-nits.md, nit 3). Not Quick Look: it opened photos with no visible way out
/// until she tapped the picture, and offered Markup.
struct ReceiptViewer: View {
    let image: UIImage
    let amounts: [Money]
    let selected: Money?
    let onPick: (Money) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZoomableImage(image: image)
                .ignoresSafeArea(edges: .horizontal)
                .accessibilityLabel("Receipt photo. Pinch or double-tap to zoom.")
                .safeAreaInset(edge: .bottom) {
                    if !amounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tap the amount for this order:").font(.subheadline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(amounts, id: \.self) { amount in
                                        Button(amount.formatted) {
                                            onPick(amount)
                                            dismiss()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.large)
                                        .tint(selected == amount ? .accentColor : .secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        .systemHorizontalMargin()
                        .background(.bar)
                    }
                }
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        ConfirmButton(title: "Done") { dismiss() }
                    }
                }
        }
    }
}

/// A picture that fits the space and zooms like Photos: pinch, double-tap, drag.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomView { ZoomView(image: image) }
    func updateUIView(_ view: ZoomView, context: Context) {}

    final class ZoomView: UIScrollView, UIScrollViewDelegate {
        private let imageView: UIImageView

        init(image: UIImage) {
            imageView = UIImageView(image: image)
            super.init(frame: .zero)
            delegate = self
            maximumZoomScale = 1 // set from the image's size in layoutSubviews
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            contentInsetAdjustmentBehavior = .never
            addSubview(imageView)
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
            doubleTap.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTap)
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        private var fittedFor: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != fittedFor, bounds.width > 0, let size = imageView.image?.size else { return }
            fittedFor = bounds.size
            // At zoom 1 the whole receipt fits; zooming goes up to the photo's own pixels,
            // and at least 3 times, so the amounts can always be made large.
            let fit = min(bounds.width / size.width, bounds.height / size.height)
            imageView.frame = CGRect(origin: .zero, size: CGSize(width: size.width * fit, height: size.height * fit))
            contentSize = imageView.frame.size
            zoomScale = 1
            maximumZoomScale = max(3, 1 / fit / (window?.screen.scale ?? 3) * 2)
            center()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { center() }

        /// Keeps the picture in the middle while it's smaller than the screen.
        private func center() {
            let x = max(0, (bounds.width - contentSize.width) / 2)
            let y = max(0, (bounds.height - contentSize.height) / 2)
            contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        }

        @objc private func toggleZoom(_ tap: UITapGestureRecognizer) {
            if zoomScale > 1 {
                setZoomScale(1, animated: true)
            } else {
                let point = tap.location(in: imageView)
                let scale = min(maximumZoomScale, 3)
                let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
                zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                width: size.width, height: size.height), animated: true)
            }
        }
    }
}
