import CoreGraphics
import CoreVideo
import Foundation
import OSLog
import Vision

/// A photo of a button with the background marked for removal (SPEC.md, "Button photos").
/// Masks are 8-bit grayscale, the photo's size: white keeps, black removes.
public struct SubjectCutout: @unchecked Sendable {
    /// The upright photo.
    public let photo: CGImage
    /// Everything Vision saw as foreground.
    public let mask: CGImage
    /// One mask per object when the photo shows several (two buttons side by side), so she
    /// can tap the one to keep. Empty when there's only one.
    public let objectMasks: [CGImage]
    /// True when Vision found nothing and the background was removed by color instead.
    public let usedColorFallback: Bool

    public init(photo: CGImage, mask: CGImage, objectMasks: [CGImage], usedColorFallback: Bool) {
        self.photo = photo
        self.mask = mask
        self.objectMasks = objectMasks
        self.usedColorFallback = usedColorFallback
    }
}

public enum Cutout {
    /// Separates the button from the background. Uses Vision's subject lifting (the same
    /// as long-pressing a photo in Photos); if that fails, as it can in the Simulator,
    /// removes the color around the edges instead.
    public static func lift(_ photo: CGImage) async -> SubjectCutout {
        // The default devices first; then the CPU alone, which is all the Simulator has.
        for cpuOnly in [false, true] {
            do {
                if let (mask, objects) = try await visionMasks(photo, cpuOnly: cpuOnly) {
                    return SubjectCutout(photo: photo, mask: mask, objectMasks: objects.count > 1 ? objects : [],
                                         usedColorFallback: false)
                }
                log.notice("Vision found no subject (cpuOnly: \(cpuOnly))")
            } catch {
                log.error("Vision subject lifting failed (cpuOnly: \(cpuOnly)): \(String(describing: error), privacy: .public)")
            }
        }
        return SubjectCutout(photo: photo, mask: edgeColorMask(photo), objectMasks: [], usedColorFallback: true)
    }

    static let log = Logger(subsystem: "InvoiceKit", category: "Cutout")

    static func visionMasks(_ photo: CGImage, cpuOnly: Bool) async throws -> (CGImage, [CGImage])? {
        var request = GenerateForegroundInstanceMaskRequest()
        if cpuOnly {
            for (stage, devices) in request.supportedComputeStageDevices {
                if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        }
        let handler = ImageRequestHandler(photo)
        guard let observation = try await handler.perform(request),
              !observation.allInstances.isEmpty else { return nil }
        let all = try observation.generateScaledMask(for: observation.allInstances, scaledToImageFrom: handler)
        guard let mask = grayImage(from: all) else { return nil }
        var objects: [CGImage] = []
        if observation.allInstances.count > 1 {
            for instance in observation.allInstances {
                let buffer = try observation.generateScaledMask(for: IndexSet(integer: instance), scaledToImageFrom: handler)
                if let m = grayImage(from: buffer) { objects.append(m) }
            }
        }
        return (mask, objects)
    }

    /// Fallback when Vision finds nothing: learns the background's range of colors from a
    /// band around the photo's edges (her backgrounds are textured gray, or plain red), marks
    /// pixels in that range and connected to the edge as background, and keeps the largest
    /// remaining shape. Works on a copy at most `workSide` pixels wide, then scales the mask up.
    public static func edgeColorMask(_ photo: CGImage, margin: Double = 0.02, percentile: Int = 5, workSide: Int = 800) -> CGImage {
        let small = ImageTools.downscaled(photo, maxSide: workSide)
        let w = small.width, h = small.height
        guard let ctx = ImageTools.rgbaContext(width: w, height: h) else { return photo }
        ctx.draw(small, in: CGRect(x: 0, y: 0, width: w, height: h))
        let bpr = ctx.bytesPerRow
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * h)

        // Background color box: each channel's 5th to 95th percentile in the edge band, plus
        // a 2% margin. Chosen by sweep against Vision's masks of her 8 raw photos (Oct 8, 2026):
        // agreement (intersection over union) 0.81-0.97, mean 0.935. Wider boxes eat white glaze.
        var samples: [[UInt8]] = [[], [], []]
        let band = max(2, min(w, h) / 25)
        for y in 0..<h {
            for x in 0..<w where x < band || y < band || x >= w - band || y >= h - band {
                let i = y * bpr + x * 4
                for c in 0..<3 { samples[c].append(px[i + c]) }
            }
        }
        let pad = Int(margin * 255)
        let box: [(Int, Int)] = samples.map { values in
            let sorted = values.sorted()
            let lo = Int(sorted[sorted.count * percentile / 100]), hi = Int(sorted[sorted.count * (100 - percentile) / 100])
            return (lo - pad, hi + pad)
        }
        func inBox(_ i: Int) -> Bool {
            let o = (i / w) * bpr + (i % w) * 4
            for c in 0..<3 {
                let v = Int(px[o + c])
                if v < box[c].0 || v > box[c].1 { return false }
            }
            return true
        }

        // Flood fill the background from the edges.
        var background = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        stack.reserveCapacity(w * 4)
        for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
        for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
        while let i = stack.popLast() {
            if background[i] || !inBox(i) { continue }
            background[i] = true
            let x = i % w
            if x > 0 { stack.append(i - 1) }
            if x < w - 1 { stack.append(i + 1) }
            if i >= w { stack.append(i - w) }
            if i < w * (h - 1) { stack.append(i + w) }
        }

        // Keep the largest connected shape; specks of texture left outside it go.
        var label = [Int32](repeating: 0, count: w * h)
        var best: (label: Int32, size: Int) = (0, 0)
        var next: Int32 = 0
        for start in 0..<(w * h) where !background[start] && label[start] == 0 {
            next += 1
            var size = 0
            stack.append(start)
            label[start] = next
            while let i = stack.popLast() {
                size += 1
                let x = i % w
                for j in [x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i - w, i + w] where j >= 0 && j < w * h {
                    if !background[j] && label[j] == 0 {
                        label[j] = next
                        stack.append(j)
                    }
                }
            }
            if size > best.size { best = (next, size) }
        }
        let keep = label.map { $0 == best.label && best.size > 0 ? UInt8(255) : UInt8(0) }
        guard let mask = grayImage(bytes: keep, width: w, height: h) else { return photo }
        guard w != photo.width || h != photo.height,
              let full = ImageTools.grayContext(width: photo.width, height: photo.height) else { return mask }
        full.interpolationQuality = .high
        full.draw(mask, in: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
        return full.makeImage() ?? mask
    }

    /// The photo with the mask applied as transparency.
    public static func apply(_ mask: CGImage, to photo: CGImage) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: photo.width, height: photo.height)
        guard let ctx = ImageTools.rgbaContext(width: photo.width, height: photo.height) else { return nil }
        ctx.clip(to: rect, mask: mask)
        ctx.draw(photo, in: rect)
        return ctx.makeImage()
    }

    /// Crops a transparent cutout to the button, centers it on a square canvas with a small
    /// margin, and scales it to at most `maxSide` (the format of the edited PNGs: square,
    /// transparent, button filling the frame).
    public static func squareCrop(_ cutout: CGImage, margin: Double = 0.04, maxSide: Int = 800) -> CGImage? {
        guard let bounds = opaqueBounds(cutout) else { return nil }
        let side = Int((Double(max(bounds.width, bounds.height)) * (1 + 2 * margin)).rounded(.up))
        let scale = min(1, Double(maxSide) / Double(side))
        let out = max(1, Int((Double(side) * scale).rounded()))
        guard let ctx = ImageTools.rgbaContext(width: out, height: out),
              let cropped = cutout.cropping(to: bounds) else { return nil }
        ctx.interpolationQuality = .high
        let w = Double(bounds.width) * scale, h = Double(bounds.height) * scale
        ctx.draw(cropped, in: CGRect(x: (Double(out) - w) / 2, y: (Double(out) - h) / 2, width: w, height: h))
        return ctx.makeImage()
    }

    /// Pixel bounds (top-left origin, as `CGImage.cropping` expects) of pixels with alpha
    /// above `threshold`, or nil if the image is fully transparent.
    public static func opaqueBounds(_ image: CGImage, threshold: UInt8 = 12) -> CGRect? {
        let w = image.width, h = image.height
        guard let ctx = ImageTools.rgbaContext(width: w, height: h) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let bpr = ctx.bytesPerRow
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * bpr
            for x in 0..<w where px[row + x * 4 + 3] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        // Bitmap rows run top to bottom in memory, which matches CGImage.cropping.
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Whether the mask keeps the pixel at (x, y), top-left origin.
    public static func maskKeeps(_ mask: CGImage, x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height,
              let ctx = ImageTools.grayContext(width: 1, height: 1) else { return false }
        ctx.draw(mask, in: CGRect(x: -x, y: -(mask.height - 1 - y), width: mask.width, height: mask.height))
        return ctx.data!.load(as: UInt8.self) > 127
    }

    // MARK: Conversions

    static func grayImage(from buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h)
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_OneComponent32Float:
            for y in 0..<h {
                let row = (base + y * bpr).assumingMemoryBound(to: Float32.self)
                for x in 0..<w { bytes[y * w + x] = UInt8(max(0, min(1, row[x])) * 255) }
            }
        case kCVPixelFormatType_OneComponent8:
            for y in 0..<h {
                let row = (base + y * bpr).assumingMemoryBound(to: UInt8.self)
                for x in 0..<w { bytes[y * w + x] = row[x] }
            }
        default:
            return nil
        }
        return grayImage(bytes: bytes, width: w, height: h)
    }

    static func grayImage(bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// The touch-up brush (SPEC.md, "Button photos"): paints keep (white) or remove (black)
/// into a copy of the mask. Coordinates are photo pixels from the top-left.
public final class MaskCanvas {
    public let width: Int
    public let height: Int
    private let context: CGContext
    private var history: [CGImage] = []

    public init?(mask: CGImage) {
        guard let ctx = ImageTools.grayContext(width: mask.width, height: mask.height) else { return nil }
        width = mask.width
        height = mask.height
        context = ctx
        draw(mask)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    /// Call at the start of each finger stroke so Undo can take the whole stroke back.
    public func beginStroke() {
        if let snapshot = context.makeImage() {
            history.append(snapshot)
            if history.count > 30 { history.removeFirst() }
        }
    }

    public func stroke(from a: CGPoint, to b: CGPoint, radius: CGFloat, keep: Bool) {
        context.setStrokeColor(gray: keep ? 1 : 0, alpha: 1)
        context.setLineWidth(radius * 2)
        context.move(to: CGPoint(x: a.x, y: CGFloat(height) - a.y))
        context.addLine(to: CGPoint(x: b.x, y: CGFloat(height) - b.y))
        context.strokePath()
    }

    public var canUndo: Bool { !history.isEmpty }

    public func undo() {
        guard let last = history.popLast() else { return }
        draw(last)
    }

    /// Replaces the whole mask (Start over, or picking one of several buttons).
    public func replace(with mask: CGImage) {
        beginStroke()
        draw(mask)
    }

    public var mask: CGImage? { context.makeImage() }

    private func draw(_ image: CGImage) {
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setBlendMode(.normal)
    }
}
