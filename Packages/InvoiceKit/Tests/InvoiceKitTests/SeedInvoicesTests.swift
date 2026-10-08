import Foundation
import Testing
@testable import InvoiceKit

/// App/Resources/Seed/invoices.json (made by `make seed`, gitignored) holds the same
/// invoices as the hand-entered ExampleInvoice table and the totals printed on their PDFs.
@Suite struct SeedInvoicesTests {
    static let url = Repo.seed.appendingPathComponent("invoices.json")

    @Test(.enabled(if: FileManager.default.fileExists(atPath: url.path), "needs make seed"))
    func matchTheSentInvoices() throws {
        let seed = try JSONDecoder().decode(SeedInvoices.self, from: Data(contentsOf: Self.url))
        #expect(seed.invoices.map(\.number) == ExampleInvoice.all.map(\.number))
        let catalog = Set(try Repo.catalog().variants.map(\.sku))
        for (s, e) in zip(seed.invoices, ExampleInvoice.all) {
            #expect(s.date == e.date, "\(s.number)")
            #expect(s.lines.map(\.sku) == e.lines.map(\.0), "\(s.number)")
            #expect(s.lines.map(\.quantity) == e.lines.map(\.1), "\(s.number)")
            #expect(s.lines.map(\.discountCents) == e.lines.map(\.2), "\(s.number)")
            #expect(s.shippingCents == e.shipping, "\(s.number)")
            #expect(s.total == Money(cents: e.printedTotal) && s.printedTotalCents == e.printedTotal, "\(s.number)")
            #expect(s.day != nil)
            for line in s.lines { #expect(catalog.contains(line.sku), "\(s.number) \(line.sku)") }
        }
    }
}
