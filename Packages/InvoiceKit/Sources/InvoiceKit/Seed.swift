import Foundation

/// The details printed on every invoice, editable in the app's Settings tab.
public struct BusinessProfile: Codable, Sendable, Equatable {
    /// "Hello, Daphné." on the home screen.
    public var greetingName: String = "Daphné"
    public var sellerName: String = "Daphné Verley Ceramics"
    public var sellerLines: [String] = []
    public var billToName: String = "Alix of Bohemia"
    public var billToLines: [String] = []
    public var routing: String = ""
    public var account: String = ""
    /// Above each description: "BUTTON".
    public var productLabel: String = "BUTTON"
    /// Below each description: "daphné verley ceramics".
    public var makerLine: String = "daphné verley ceramics"
    /// PDF names are this plus the invoice number: "Daphné Verley Invoice - AOB 0260903.pdf".
    public var fileNamePrefix: String = "Daphné Verley Invoice - AOB"

    public init() {}

    public var seller: InvoiceDocument.Party { .init(name: sellerName, lines: sellerLines.filter { !$0.isEmpty }) }
    public var billTo: InvoiceDocument.Party { .init(name: billToName, lines: billToLines.filter { !$0.isEmpty }) }

    public var payment: [InvoiceDocument.PaymentDetail] {
        [("Routing:", routing), ("Account:", account)]
            .filter { !$0.1.isEmpty }
            .map { InvoiceDocument.PaymentDetail(label: $0.0, value: $0.1) }
    }

    /// Fields missing from older saved copies take their defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BusinessProfile()
        greetingName = try c.decodeIfPresent(String.self, forKey: .greetingName) ?? d.greetingName
        sellerName = try c.decodeIfPresent(String.self, forKey: .sellerName) ?? d.sellerName
        sellerLines = try c.decodeIfPresent([String].self, forKey: .sellerLines) ?? d.sellerLines
        billToName = try c.decodeIfPresent(String.self, forKey: .billToName) ?? d.billToName
        billToLines = try c.decodeIfPresent([String].self, forKey: .billToLines) ?? d.billToLines
        routing = try c.decodeIfPresent(String.self, forKey: .routing) ?? d.routing
        account = try c.decodeIfPresent(String.self, forKey: .account) ?? d.account
        productLabel = try c.decodeIfPresent(String.self, forKey: .productLabel) ?? d.productLabel
        makerLine = try c.decodeIfPresent(String.self, forKey: .makerLine) ?? d.makerLine
        fileNamePrefix = try c.decodeIfPresent(String.self, forKey: .fileNamePrefix) ?? d.fileNamePrefix
    }
}

/// The starting catalog, bundled with the app and loaded on first launch. Written by
/// Tools/seed/extract_seed.py from the Excel template's Reference sheet.
public struct SeedCatalog: Codable, Sendable {
    public struct Variant: Codable, Sendable {
        public var design: String
        public var colors: [String]
        public var size: String
        public var sku: String
        /// Nil where the template had no price.
        public var priceCents: Int?
        /// File name in the Seed/Photos folder.
        public var photo: String?
    }

    public var source: String
    public var variants: [Variant]
}

/// Invoices already sent before the app, loaded as paid on first launch. Written by
/// Tools/seed/extract_seed.py from the invoice workbooks.
public struct SeedInvoices: Codable, Sendable {
    public struct Line: Codable, Sendable {
        public var sku: String
        /// As it was printed ("Pineaple, Yellow / Brown"); the app uses the catalog's name.
        public var description: String
        public var quantity: Int
        public var unitPriceCents: Int
        public var discountCents: Int
    }

    public struct Invoice: Codable, Sendable {
        public var number: String
        /// "2026-04-25"
        public var date: String
        public var lines: [Line]
        public var shippingCents: [Int]
        public var printedTotalCents: Int
        public var source: String

        /// Noon local time on the invoice date, so the printed day can't shift.
        public var day: Date? {
            let parts = date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
        }

        public var total: Money {
            Money(cents: lines.reduce(0) { $0 + ($1.unitPriceCents - $1.discountCents) * $1.quantity } + shippingCents.reduce(0, +))
        }
    }

    public var invoices: [Invoice]
}
