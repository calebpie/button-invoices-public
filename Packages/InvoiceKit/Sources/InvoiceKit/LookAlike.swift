import CoreGraphics
import Foundation
import Vision

/// The photo half of the duplicate check (SPEC.md, "Adding a new button"): how alike two
/// button photos look, using Vision's image feature prints. Transparent cutouts are put on
/// white first so the background doesn't count. Smaller distance = more alike.
public enum LookAlike {
    /// Thresholds from the probe of Oct 8, 2026 (LookAlikeTests, her 8 raw photos against the
    /// 37 saved ones): the same button 0.040-0.098; the same shape in another color (red vs
    /// navy heart) 0.241-0.312; different shapes 0.337 and up. Hypothesis until checked on
    /// a new photo of an already-saved button (SPEC.md, "Adding a new button").
    public static let sameButton = 0.2
    public static let similar = 0.4

    public struct Print: @unchecked Sendable {
        let observation: FeaturePrintObservation
    }

    public static func print(of image: CGImage) async throws -> Print {
        let flat = onWhite(ImageTools.downscaled(image, maxSide: 512))
        return Print(observation: try await GenerateImageFeaturePrintRequest().perform(on: flat))
    }

    public static func distance(_ a: Print, _ b: Print) -> Double {
        (try? a.observation.distance(to: b.observation)) ?? .infinity
    }

    static func onWhite(_ image: CGImage) -> CGImage {
        guard let ctx = ImageTools.rgbaContext(width: image.width, height: image.height) else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
        return ctx.makeImage() ?? image
    }
}
