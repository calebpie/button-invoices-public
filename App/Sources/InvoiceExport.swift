import CoreGraphics
import Foundation
import InvoiceKit

/// Turns a saved invoice into the PDF.
enum InvoiceExport {
    static let logo: CGImage? = Bundle.main.url(forResource: "InvoiceLogo", withExtension: "png")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { ImageTools.uprightImage(from: $0, maxSide: 1000) }

    static func document(_ invoice: Invoice, profile: BusinessProfile) -> InvoiceDocument {
        let lines = invoice.sortedLines.map { line in
            InvoiceDocument.Line(
                sku: line.sku, productLabel: profile.productLabel, description: line.itemDescription,
                makerLine: profile.makerLine, quantity: line.quantity, unitPrice: line.unitPrice,
                discount: line.discount, image: line.photo.flatMap { ImageTools.uprightImage(from: $0, maxSide: 400) })
        }
        return InvoiceDocument(number: invoice.number, date: invoice.date, seller: profile.seller, billTo: profile.billTo,
                               lines: lines, shipping: invoice.sortedShipping.map(\.amount), payment: profile.payment,
                               logo: logo)
    }

    /// Writes the PDF to a temporary file named like the ones she has sent before.
    static func writePDF(_ invoice: Invoice, profile: BusinessProfile) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(InvoicePDF.fileName(prefix: profile.fileNamePrefix, number: invoice.number))
        try InvoicePDF.render(document(invoice, profile: profile)).write(to: url, options: .atomic)
        return url
    }
}
