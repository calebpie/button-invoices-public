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

    static func render(_ invoice: Invoice, profile: BusinessProfile) -> Data {
        InvoicePDF.render(document(invoice, profile: profile))
    }

    /// Writes PDF data to a temporary file named like the ones she has sent before, for
    /// the preview and the share sheet.
    static func write(_ pdf: Data, number: String, profile: BusinessProfile) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(InvoicePDF.fileName(prefix: profile.fileNamePrefix, number: number))
        try pdf.write(to: url, options: .atomic)
        return url
    }

    /// A finished invoice's PDF as a file to share: the one stored when it was finished, or,
    /// for the invoices loaded on first launch, made now from its stored details and kept.
    @MainActor static func storedPDF(_ invoice: Invoice, profile current: BusinessProfile) -> URL? {
        let profile = invoice.businessProfile(current: current)
        if invoice.finishedPDF == nil { invoice.finishedPDF = render(invoice, profile: profile) }
        guard let pdf = invoice.finishedPDF else { return nil }
        return try? write(pdf, number: invoice.number, profile: profile)
    }

    /// The PDF of a draft, with the details it would be finished with.
    static func writePDF(_ invoice: Invoice, profile: BusinessProfile) throws -> URL {
        try write(render(invoice, profile: profile), number: invoice.number, profile: profile)
    }
}
