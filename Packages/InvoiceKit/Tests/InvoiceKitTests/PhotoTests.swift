import CoreGraphics
import Foundation
import Testing
@testable import InvoiceKit

@Suite struct PhotoTests {
    static let rawPhotos: [URL] = {
        let dir = Repo.examples.appendingPathComponent("Images/Raw")
        return ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "heic" }.sorted { $0.path < $1.path }
    }()

    /// Her raw photos (Examples/Images/Raw) come out as square transparent PNGs. Writes the
    /// results to build/sample-pdfs/cutouts for a look.
    @Test(.enabled(if: !rawPhotos.isEmpty, "needs Examples/Images/Raw"))
    func liftsHerPhotos() async throws {
        let out = Repo.output.appendingPathComponent("cutouts")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for url in Self.rawPhotos {
            let photo = try #require(ImageTools.uprightImage(from: Data(contentsOf: url), maxSide: 1600))
            let cut = await Cutout.lift(photo)
            #expect(!cut.usedColorFallback, "Vision found no subject in \(url.lastPathComponent)")
            let masked = try #require(Cutout.apply(cut.mask, to: photo))
            let square = try #require(Cutout.squareCrop(masked))
            #expect(square.width == square.height)
            // The button fills most of the frame and the corners are transparent.
            let bounds = try #require(Cutout.opaqueBounds(square))
            #expect(Double(max(bounds.width, bounds.height)) > 0.85 * Double(square.width))
            #expect(!Cutout.maskKeeps(cut.mask, x: 2, y: 2))
            try ImageTools.pngData(square)!.write(to: out.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".png"))
        }
    }

    /// The color fallback (used where Vision isn't available, e.g. the Simulator) finds
    /// nearly the same button outline as Vision on her photos: intersection over union of the
    /// two masks, printed per photo.
    @Test(.enabled(if: !rawPhotos.isEmpty, "needs Examples/Images/Raw"))
    func colorFallbackAgreesWithVision() async throws {
        for url in Self.rawPhotos {
            let photo = try #require(ImageTools.uprightImage(from: Data(contentsOf: url), maxSide: 1600))
            let vision = await Cutout.lift(photo).mask
            let fallback = Cutout.edgeColorMask(photo)
            let iou = Self.intersectionOverUnion(vision, fallback)
            print(String(format: "%@ fallback vs Vision IoU %.3f", url.lastPathComponent, iou))
            let out = Repo.output.appendingPathComponent("fallback")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            if let png = Cutout.apply(fallback, to: photo).flatMap(ImageTools.pngData) {
                try png.write(to: out.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".png"))
            }
            #expect(iou > 0.8, "\(url.lastPathComponent)")
        }
    }

    static func intersectionOverUnion(_ a: CGImage, _ b: CGImage) -> Double {
        func bytes(_ m: CGImage) -> [UInt8] {
            let ctx = ImageTools.grayContext(width: a.width, height: a.height)!
            ctx.draw(m, in: CGRect(x: 0, y: 0, width: a.width, height: a.height))
            return Array(UnsafeBufferPointer(start: ctx.data!.bindMemory(to: UInt8.self, capacity: a.width * a.height),
                                             count: a.width * a.height))
        }
        let x = bytes(a), y = bytes(b)
        var both = 0, either = 0
        for i in x.indices {
            let p = x[i] > 127, q = y[i] > 127
            if p && q { both += 1 }
            if p || q { either += 1 }
        }
        return either == 0 ? 0 : Double(both) / Double(either)
    }

    /// The fallback removes a plain background around a darker shape.
    @Test func colorFallbackFindsAShape() throws {
        let ctx = try #require(ImageTools.rgbaContext(width: 200, height: 160))
        ctx.setFillColor(CGColor(red: 0.6, green: 0.6, blue: 0.58, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 160))
        ctx.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 60, y: 40, width: 80, height: 80))
        let photo = try #require(ctx.makeImage())
        let mask = Cutout.edgeColorMask(photo)
        #expect(Cutout.maskKeeps(mask, x: 100, y: 80))
        #expect(!Cutout.maskKeeps(mask, x: 5, y: 5))
        let masked = try #require(Cutout.apply(mask, to: photo))
        let square = try #require(Cutout.squareCrop(masked, margin: 0))
        #expect(abs(square.width - 80) <= 2)
    }

    @Test func brushPaintsAndUndoes() throws {
        let black = try #require(Cutout.grayImage(bytes: [UInt8](repeating: 0, count: 100 * 50), width: 100, height: 50))
        let canvas = try #require(MaskCanvas(mask: black))
        canvas.beginStroke()
        canvas.stroke(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 10), radius: 4, keep: true)
        #expect(Cutout.maskKeeps(canvas.mask!, x: 20, y: 10))
        #expect(!Cutout.maskKeeps(canvas.mask!, x: 20, y: 40))
        canvas.undo()
        #expect(!Cutout.maskKeeps(canvas.mask!, x: 20, y: 10))
    }

    /// OCR lines from IMG_9049 (two shipments, $36.48 circled; OCR misread the circled copy).
    @Test func suggestsReceiptAmounts() {
        let lines = ["Ground Residential", "Date.: 8/31/2026", "TOTAL", "$16.90", "$16.90", "$0.00", "$19.50", "$19.58",
                     "$0.00", "$36.48", "$0.00", "$0.00", "$36.48", "$30.48"]
        let scan = ReceiptReader.scan(lines: lines)
        #expect(scan.amounts.first == Money(cents: 3648))
        #expect(scan.amounts.contains(Money(cents: 1690)) && !scan.amounts.contains(.zero))
        #expect(scan.date == "8/31/2026")
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: Repo.examples.appendingPathComponent("Images/Shipping Receipts/IMG_9063.heic").path)))
    func readsAReceipt() async throws {
        let url = Repo.examples.appendingPathComponent("Images/Shipping Receipts/IMG_9063.heic")
        let image = try #require(ImageTools.uprightImage(from: Data(contentsOf: url), maxSide: 3000))
        let scan = try await ReceiptReader.read(image)
        #expect(scan.amounts.first == Money(cents: 1621))
        #expect(scan.date == "9/2/2026")
    }
}
