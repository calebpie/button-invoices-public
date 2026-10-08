import CoreGraphics
import Foundation
@testable import InvoiceKit

/// Paths in the repository, found from this file's location.
enum Repo {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let seed = root.appendingPathComponent("App/Resources/Seed")
    /// Gitignored real data; tests that need it are skipped when it's missing.
    static let examples = root.appendingPathComponent("Examples")
    static let output = root.appendingPathComponent("build/sample-pdfs")

    static func catalog() throws -> SeedCatalog {
        try JSONDecoder().decode(SeedCatalog.self, from: Data(contentsOf: seed.appendingPathComponent("catalog.json")))
    }

    static func business() -> BusinessProfile {
        let url = seed.appendingPathComponent("business.json")
        return (try? JSONDecoder().decode(BusinessProfile.self, from: Data(contentsOf: url))) ?? BusinessProfile()
    }

    static func image(_ url: URL) -> CGImage? {
        (try? Data(contentsOf: url)).flatMap { ImageTools.uprightImage(from: $0, maxSide: 4096) }
    }

    static var logo: CGImage? { image(root.appendingPathComponent("App/Resources/InvoiceLogo.png")) }
}

/// The invoices in Examples/, re-entered: (number, date, [(SKU, quantity, discount cents)],
/// shipping cents, total cents printed on the PDF).
struct ExampleInvoice {
    var number: String
    var date: String
    var lines: [(String, Int, Int)]
    var shipping: [Int]
    var printedTotal: Int

    static let all: [ExampleInvoice] = [
        .init(number: "0260426-1", date: "2026-04-25",
              lines: [("26DI", 20, 0), ("26DBWL", 5, 0), ("26DBWS", 9, 0), ("26NB", 30, 0), ("26NW", 30, 0), ("26NUG", 16, 0)],
              shipping: [1621], printedTotal: 94721),
        .init(number: "0260426-2", date: "2026-04-25",
              lines: [("26NB", 30, 0), ("26CSPP", 20, 0), ("26NBRL", 10, 0), ("26NBR", 50, 0), ("26NG", 15, 0), ("26CSB", 20, 0)],
              shipping: [1614], printedTotal: 132114),
        .init(number: "0260426-3", date: "2026-04-25", lines: [("26MBLW", 106, 400)], shipping: [1614], printedTotal: 44014),
        .init(number: "0260426-4", date: "2026-04-25", lines: [("26FBBW", 416, 0), ("26DC", 210, 0)],
              shipping: [1690], printedTotal: 419290),
        .init(number: "0260426-5", date: "2026-04-25", lines: [("26FBBW", 310, 0)], shipping: [1618], printedTotal: 187618),
        .init(number: "0260607", date: "2026-06-07",
              lines: [("26NB", 222, 0), ("26NBR", 222, 0), ("26NG", 97, 0), ("26DI", 315, 0)],
              shipping: [3311], printedTotal: 742211),
        .init(number: "0260812", date: "2026-08-12",
              lines: [("26LRW", 12, 0), ("26PYB", 20, 0), ("26RWG", 20, 0), ("26HRM", 12, 0), ("26HNM", 12, 0),
                      ("26NPP", 14, 0), ("26NB", 2, 0), ("26NW", 7, 0), ("26SRG", 13, 0), ("26SBW", 13, 0)],
              shipping: [1690], printedTotal: 97690),
        .init(number: "0260819", date: "2026-08-19", lines: [("26MBW", 125, 0), ("26HRM", 410, 0)],
              shipping: [1621], printedTotal: 265621),
        .init(number: "0260903", date: "2026-09-03", lines: [("26NB", 14, 0), ("26MNW", 500, 0)],
              shipping: [3648, 1621], printedTotal: 417869),
    ]

    func document(catalog: SeedCatalog, business: BusinessProfile, withImages: Bool) throws -> InvoiceDocument {
        let lines = try lines.map { sku, qty, discount -> InvoiceDocument.Line in
            guard let v = catalog.variants.first(where: { $0.sku == sku }) else { throw Missing(sku: sku) }
            let image = withImages ? v.photo.flatMap { Repo.image(Repo.seed.appendingPathComponent("Photos/\($0)")) } : nil
            return InvoiceDocument.Line(
                sku: v.sku, productLabel: business.productLabel,
                description: Naming.description(design: v.design, colors: v.colors, size: v.size),
                makerLine: business.makerLine, quantity: qty, unitPrice: Money(cents: v.priceCents ?? 0),
                discount: Money(cents: discount), image: image)
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return InvoiceDocument(number: number, date: f.date(from: date)!, seller: business.seller,
                               billTo: business.billTo, lines: lines, shipping: shipping.map(Money.init(cents:)),
                               payment: business.payment, logo: withImages ? Repo.logo : nil)
    }

    struct Missing: Error { var sku: String }
}
