import CoreGraphics
import Foundation
import Testing
@testable import InvoiceKit

@Suite struct LookAlikeTests {
    /// Raw photos in Examples/Images/Raw of one button, and the button (SKU in the seed
    /// catalog). The IMG_8* photos are the shots Caleb's edited photos were made from; the
    /// IMG_41* ones were added and labeled by Caleb on Oct 8, 2026.
    static let rawLabels = [
        "IMG_8515.heic": "26SBW", "IMG_8516.heic": "26SRG", "IMG_8536.heic": "26HNM", "IMG_8537.heic": "26HRM",
        "IMG_8538.heic": "26LRW", "IMG_8539.heic": "26PYB", "IMG_8540.heic": "26RWG", "IMG_8981.heic": "26MBW",
        "IMG_4144.jpeg": "26HBM", "IMG_4146.jpeg": "26DBWS", "IMG_4147.jpeg": "26DBWL", "IMG_4149.jpeg": "26FBBW",
    ]

    /// Photos the duplicate check gets wrong. IMG_4147, the large daisy: closest is the small
    /// daisy at 0.226, and the saved large daisy's photo (taken at an angle) is 14th.
    static let knownMismatches: Set<String> = ["IMG_4147.jpeg"]

    /// Raw photos of several buttons, each kind they show (Caleb, Oct 8, 2026). Not used by a
    /// test yet: for picking one button out of a batch, as her tap does, and for screenshots.
    static let rawGroups: [String: [String]] = [
        "IMG_4085.heic": ["26SNM"],  // about 50, filling the frame; Vision finds no subject
        "IMG_4145.jpeg": ["26SBS"],  // three
        "IMG_4162.jpeg": ["26CSB"], "IMG_4163.jpeg": ["26CSPP"], "IMG_4164.jpeg": ["26NPP"],
        "IMG_4165.jpeg": ["26NB"], "IMG_4166.jpeg": ["26NMP"], "IMG_4167.jpeg": ["26NBR"],
        // Her plate: clockwise from the top, then the middle. The bright white nautilus are
        // the unglazed porcelain ones.
        "IMG_4175.jpeg": ["26NMP", "26NB", "26NPP", "26NUG", "26CSB", "26NBR", "26CSPP"],
        "IMG_4205.jpeg": ["26MBLW"], "IMG_4206.jpeg": ["26MRW"],
        "IMG_7078.heic": ["26LR"],
        // Screenshots, with the phone's own screen around the photo.
        "IMG_4707.png": ["26MNW", "26CR"],  // and part of a shell
        "IMG_4708.png": ["26BBW", "26CBL"],  // the crab at the edge
        "IMG_4709.png": ["26CR", "26CBL"],  // a message; the red crab's saved photo is cut from it
        // Shells in several glazes she tried; only the yellow was made for AOB and is saved.
        "IMG_4710.png": ["26SY", "26CBL"],  // the crab at the edge
    ]

    /// Probe: for each raw photo's cutout, the closest saved photos and their distances.
    /// The right button should come first, inside the "looks like" threshold, and the next
    /// one outside it; the numbers also show how far apart different colors of one shape are
    /// (red vs navy heart, burgundy vs navy mushroom), which sets that threshold in the app.
    @Test(.enabled(if: !PhotoTests.rawPhotos.isEmpty, "needs Examples/Images/Raw"))
    func findsTheSameButton() async throws {
        let catalog = try Repo.catalog()
        var saved: [(String, String, LookAlike.Print)] = []
        for v in catalog.variants {
            guard let file = v.photo, let image = Repo.image(Repo.seed.appendingPathComponent("Photos/\(file)")) else { continue }
            saved.append((v.sku, Naming.description(design: v.design, colors: v.colors, size: v.size), try await LookAlike.print(of: image)))
        }
        for url in PhotoTests.rawPhotos {
            let name = url.lastPathComponent
            let photo = try #require(ImageTools.uprightImage(from: Data(contentsOf: url), maxSide: 1600))
            let cut = await Cutout.lift(photo)
            let masked = try #require(Cutout.apply(cut.mask, to: photo))
            let square = try #require(Cutout.squareCrop(masked))
            let print = try await LookAlike.print(of: square)
            let ranked = saved.map { ($0.0, $0.1, LookAlike.distance(print, $0.2)) }.sorted { $0.2 < $1.2 }
            Swift.print(name, ranked.prefix(4).map { String(format: "%@ %.3f", $0.1, $0.2) }.joined(separator: " | "))
            let check = {
                #expect(ranked.first?.0 == Self.rawLabels[name], "\(name)")
                #expect(ranked[0].2 < LookAlike.sameButton && ranked[1].2 > LookAlike.sameButton, "\(name)")
            }
            if Self.knownMismatches.contains(name) {
                withKnownIssue("the duplicate check doesn't find this button", check)
            } else {
                check()
            }
        }
    }
}
