import CoreGraphics
import Foundation
import Testing
@testable import InvoiceKit

@Suite struct InvoiceTests {
    /// The app's arithmetic matches the total printed on every example invoice.
    @Test(arguments: ExampleInvoice.all.map(\.number))
    func totalsMatchTheExamples(_ number: String) throws {
        let example = ExampleInvoice.all.first { $0.number == number }!
        let doc = try example.document(catalog: Repo.catalog(), business: Repo.business(), withImages: false)
        #expect(doc.total == Money(cents: example.printedTotal))
    }

    @Test func discountComesOffEachButton() {
        let line = InvoiceDocument.Line(sku: "26MBLW", description: "Mushroom, Blue / White", quantity: 106,
                                        unitPrice: Money(cents: 800), discount: Money(cents: 400))
        #expect(line.subtotal == Money(cents: 42400))
    }

    @Test func formatsTheDateLikeExcel() {
        let d = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        #expect(InvoiceDocument.formatDate(d) == "3-Sep-26")
    }

    @Test func namesTheFile() {
        #expect(InvoicePDF.fileName(prefix: "Daphné Verley Invoice - AOB", number: "0260903")
                == "Daphné Verley Invoice - AOB 0260903.pdf")
    }

    @Test func paginatesLikeTheTemplate() throws {
        let catalog = try Repo.catalog(), business = Repo.business()
        let short = try ExampleInvoice.all.first { $0.number == "0260903" }!.document(catalog: catalog, business: business, withImages: false)
        #expect(InvoicePDF.pageCount(short) == 1)
        // Ten buttons: nine fit on page 1, as in Excel's printout of 0260812.
        let long = try ExampleInvoice.all.first { $0.number == "0260812" }!.document(catalog: catalog, business: business, withImages: false)
        let plan = InvoicePDF.layout(long)
        #expect(plan.pages == 2)
        #expect(plan.itemTops.filter { $0.page == 0 }.count == 9)
        // Forty buttons: 9 on page 1, then 12 a page under a repeated column header.
        var huge = long
        huge.lines = Array(repeating: long.lines[0], count: 40)
        #expect(InvoicePDF.pageCount(huge) == 4)
        #expect(CGPDFDocument(CGDataProvider(data: InvoicePDF.render(huge) as CFData)!)?.numberOfPages == 4)
    }

    /// Renders every example invoice to build/sample-pdfs, plus a PNG of each first page,
    /// for side-by-side comparison with the Excel PDFs (`make sample-pdfs`).
    @Test func rendersTheExamples() throws {
        let catalog = try Repo.catalog(), business = Repo.business()
        try FileManager.default.createDirectory(at: Repo.output, withIntermediateDirectories: true)
        for example in ExampleInvoice.all {
            let doc = try example.document(catalog: catalog, business: business, withImages: true)
            let data = InvoicePDF.render(doc)
            let pdf = CGPDFDocument(CGDataProvider(data: data as CFData)!)
            #expect(pdf?.numberOfPages == InvoicePDF.pageCount(doc))
            let name = InvoicePDF.fileName(prefix: business.fileNamePrefix, number: example.number)
            try data.write(to: Repo.output.appendingPathComponent(name))
            if let page = pdf?.page(at: 1), let png = Self.rasterize(page, scale: 2).flatMap(ImageTools.pngData) {
                try png.write(to: Repo.output.appendingPathComponent(name.replacingOccurrences(of: ".pdf", with: ".png")))
            }
        }
    }

    static func rasterize(_ page: CGPDFPage, scale: CGFloat) -> CGImage? {
        let box = page.getBoxRect(.mediaBox)
        guard let ctx = ImageTools.rgbaContext(width: Int(box.width * scale), height: Int(box.height * scale)) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: box.width * scale, height: box.height * scale))
        ctx.scaleBy(x: scale, y: scale)
        ctx.drawPDFPage(page)
        return ctx.makeImage()
    }
}
