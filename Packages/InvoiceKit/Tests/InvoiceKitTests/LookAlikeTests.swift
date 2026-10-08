import CoreGraphics
import Foundation
import Testing
@testable import InvoiceKit

@Suite struct LookAlikeTests {
    /// What each raw photo in Examples/Images/Raw shows (SKU in the seed catalog).
    static let rawLabels = [
        "IMG_8515": "26SBW", "IMG_8516": "26SRG", "IMG_8536": "26HNM", "IMG_8537": "26HRM",
        "IMG_8538": "26LRW", "IMG_8539": "26PYB", "IMG_8540": "26RWG", "IMG_8981": "26MBW",
    ]

    /// Probe: for each raw photo's cutout, the closest saved photos and their distances.
    /// The seed has an edit of the same shot, so the right button should come first; the
    /// numbers also show how far apart different colors of one shape are (red vs navy heart,
    /// burgundy vs navy mushroom), which sets the "looks like" threshold in the app.
    @Test(.enabled(if: !PhotoTests.rawPhotos.isEmpty, "needs Examples/Images/Raw"))
    func findsTheSameButton() async throws {
        let catalog = try Repo.catalog()
        var saved: [(String, String, LookAlike.Print)] = []
        for v in catalog.variants {
            guard let file = v.photo, let image = Repo.image(Repo.seed.appendingPathComponent("Photos/\(file)")) else { continue }
            saved.append((v.sku, Naming.description(design: v.design, colors: v.colors, size: v.size), try await LookAlike.print(of: image)))
        }
        for url in PhotoTests.rawPhotos {
            let name = url.deletingPathExtension().lastPathComponent
            let photo = try #require(ImageTools.uprightImage(from: Data(contentsOf: url), maxSide: 1600))
            let cut = await Cutout.lift(photo)
            let masked = try #require(Cutout.apply(cut.mask, to: photo))
            let square = try #require(Cutout.squareCrop(masked))
            let print = try await LookAlike.print(of: square)
            let ranked = saved.map { ($0.0, $0.1, LookAlike.distance(print, $0.2)) }.sorted { $0.2 < $1.2 }
            Swift.print(name, ranked.prefix(4).map { String(format: "%@ %.3f", $0.1, $0.2) }.joined(separator: " | "))
            #expect(ranked.first?.0 == Self.rawLabels[name], "\(name)")
            #expect(ranked[0].2 < LookAlike.sameButton && ranked[1].2 > LookAlike.sameButton, "\(name)")
        }
    }
}
