import CoreGraphics
import Foundation

/// Everything printed on one invoice, in the order of the Excel template (SPEC.md, "The PDF").
public struct InvoiceDocument: @unchecked Sendable {
    public struct Party: Sendable, Equatable {
        /// Printed in bold.
        public var name: String
        public var lines: [String]

        public init(name: String, lines: [String]) {
            self.name = name
            self.lines = lines
        }
    }

    public struct Line: @unchecked Sendable {
        public var sku: String
        /// "BUTTON", in bold above the description.
        public var productLabel: String
        /// "Nautilus, Black".
        public var description: String
        /// "daphné verley ceramics", below the description.
        public var makerLine: String
        public var quantity: Int
        public var unitPrice: Money
        /// Taken off each button, as in the template: (price − discount) × quantity.
        public var discount: Money
        public var image: CGImage?

        public init(sku: String, productLabel: String = "BUTTON", description: String,
                    makerLine: String = "daphné verley ceramics", quantity: Int, unitPrice: Money,
                    discount: Money = .zero, image: CGImage? = nil) {
            self.sku = sku
            self.productLabel = productLabel
            self.description = description
            self.makerLine = makerLine
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.discount = discount
            self.image = image
        }

        public var subtotal: Money { (unitPrice - discount) * quantity }
    }

    public struct PaymentDetail: Sendable, Equatable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public var number: String
    public var date: Date
    public var seller: Party
    public var billTo: Party
    public var lines: [Line]
    /// One SHIPPING row each; she often ships an order in more than one box.
    public var shipping: [Money]
    /// "Routing:" and "Account:", printed beside the totals.
    public var payment: [PaymentDetail]
    public var logo: CGImage?

    public init(number: String, date: Date, seller: Party, billTo: Party, lines: [Line],
                shipping: [Money], payment: [PaymentDetail], logo: CGImage? = nil) {
        self.number = number
        self.date = date
        self.seller = seller
        self.billTo = billTo
        self.lines = lines
        self.shipping = shipping
        self.payment = payment
        self.logo = logo
    }

    public var buttonsSubtotal: Money { lines.reduce(.zero) { $0 + $1.subtotal } }
    public var shippingTotal: Money { shipping.reduce(.zero, +) }
    public var total: Money { buttonsSubtotal + shippingTotal }

    /// "3-Sep-26", the date format in the template.
    public static func formatDate(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "d-MMM-yy"
        return f.string(from: date)
    }
}
