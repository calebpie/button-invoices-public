import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Bitmap helpers shared by the cutout, the PDF and the catalog photos.
public enum ImageTools {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// The image scaled so its longer side is at most `maxSide` pixels (unchanged if smaller).
    public static func downscaled(_ image: CGImage, maxSide: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxSide else { return image }
        let scale = Double(maxSide) / Double(longest)
        let w = max(1, Int((Double(image.width) * scale).rounded()))
        let h = max(1, Int((Double(image.height) * scale).rounded()))
        guard let ctx = rgbaContext(width: w, height: h) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    public static func pngData(_ image: CGImage) -> Data? {
        encode(image, type: .png, properties: [:])
    }

    public static func jpegData(_ image: CGImage, quality: Double = 0.8) -> Data? {
        encode(image, type: .jpeg, properties: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    /// The image flattened onto white and re-decoded from JPEG data, so a PDF context can
    /// embed the JPEG bytes directly.
    public static func jpegOnWhite(_ image: CGImage, quality: Double = 0.85) -> CGImage? {
        guard let ctx = rgbaContext(width: image.width, height: image.height) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
        guard let flat = ctx.makeImage(), let data = jpegData(flat, quality: quality),
              let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Decodes PNG/JPEG/HEIC data, applying the EXIF orientation so the result is upright,
    /// and scaling so the longer side is at most `maxSide`.
    public static func uprightImage(from data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func rgbaContext(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    static func grayContext(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    }

    private static func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
