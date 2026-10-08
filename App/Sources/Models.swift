import Foundation
import InvoiceKit
import SwiftData

// SPEC.md, "Data". Shapes follow SwiftData's iCloud rules (every property has a default,
// relationships are optional, nothing marked unique) so sync can be switched on later
// without a migration.

/// A button shape she makes in several colors or sizes: "Nautilus", "Mushroom".
@Model final class ButtonDesign {
    var name: String = ""
    /// Letters for this design in SKUs: "N", "CS" for Cowrie Shell.
    var code: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \ButtonVariant.design) var variants: [ButtonVariant]? = []

    init(name: String, code: String) {
        self.name = name
        self.code = code
    }

    var sortedVariants: [ButtonVariant] {
        (variants ?? []).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var visibleVariants: [ButtonVariant] { sortedVariants.filter { !$0.isHidden } }

    /// The photo shown for the shape: the most recently invoiced color that has one.
    var coverPhoto: Data? {
        visibleVariants.filter { $0.photo != nil }
            .max { ($0.lastUsedAt ?? .distantPast) < ($1.lastUsedAt ?? .distantPast) }?.photo
    }
}

/// One thing she invoices: a shape in one color and size, with its SKU, price and photo.
@Model final class ButtonVariant {
    var sku: String = ""
    /// "Black / White"
    var colorsText: String = ""
    /// "" when the design comes in one size.
    var size: String = ""
    var priceCents: Int = 0
    /// Other words she has used for this button, comma-separated ("olive").
    var aliasesText: String = ""
    /// Square PNG with a transparent background.
    @Attribute(.externalStorage) var photo: Data?
    /// Archived: kept, and still on invoices that have it, but not offered for new lines.
    var isHidden: Bool = false
    var createdAt: Date = Date()
    var lastUsedAt: Date?
    var design: ButtonDesign?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceLine.variant) var invoiceLines: [InvoiceLine]? = []
    @Relationship(deleteRule: .cascade, inverse: \ButtonVersion.variant) var versions: [ButtonVersion]? = []

    init(design: ButtonDesign, colors: [String], size: String, sku: String, price: Money, photo: Data?) {
        self.design = design
        self.colorsText = colors.joined(separator: " / ")
        self.size = size
        self.sku = sku
        self.priceCents = price.cents
        self.photo = photo
    }

    var colors: [String] {
        get { colorsText.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { colorsText = newValue.joined(separator: " / ") }
    }

    var aliases: [String] {
        get { aliasesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { aliasesText = newValue.joined(separator: ", ") }
    }

    var price: Money {
        get { Money(cents: priceCents) }
        set { priceCents = newValue.cents }
    }

    var designName: String { design?.name ?? "" }

    /// As printed on the invoice: "Daisy, Black / White, Large".
    var title: String { Naming.description(design: designName, colors: colors, size: size) }

    var sortedVersions: [ButtonVersion] { (versions ?? []).sorted { $0.savedAt > $1.savedAt } }

    var matchCandidate: MatchCandidate {
        MatchCandidate(id: sku + "|" + title, design: designName, colors: colors, size: size, sku: sku, aliases: aliases)
    }

    var skuEntry: SKUEntry {
        SKUEntry(sku: sku, designCode: design?.code ?? "", colors: colors, size: size)
    }
}

/// How a button looked before an edit (SPEC.md, "Button history"). Invoices keep their own
/// copies of name, SKU, price and photo, so this is a record for her, not something invoices
/// read.
@Model final class ButtonVersion {
    var savedAt: Date = Date()
    var title: String = ""
    var sku: String = ""
    var priceCents: Int = 0
    @Attribute(.externalStorage) var photo: Data?
    var variant: ButtonVariant?

    /// A copy of the button as it is now, taken just before it's changed.
    init(of variant: ButtonVariant) {
        title = variant.title
        sku = variant.sku
        priceCents = variant.priceCents
        photo = variant.photo
    }

    var price: Money { Money(cents: priceCents) }
}

enum InvoiceStatus: String, CaseIterable, Identifiable {
    case draft, finalized, paid
    var id: String { rawValue }
    var label: String {
        switch self {
        case .draft: "Draft"
        case .finalized: "Finished"
        case .paid: "Paid"
        }
    }
}

@Model final class Invoice {
    var number: String = ""
    /// False until she types her own number; until then it follows the date.
    var numberIsCustom: Bool = false
    var date: Date = Date()
    var statusRaw: String = InvoiceStatus.draft.rawValue
    var createdAt: Date = Date()
    var finalizedAt: Date?
    /// She said this order had no shipping (step 2 can't be left empty by accident).
    var noShipping: Bool = false
    /// The business details as they were when she first tapped Finish. Later edits in
    /// Settings don't change this invoice (SPEC.md, "Settings").
    var businessSnapshot: Data?
    /// The PDF made when she tapped Finish. Share sends exactly this file.
    @Attribute(.externalStorage) var finishedPDF: Data?
    @Relationship(deleteRule: .cascade, inverse: \InvoiceLine.invoice) var lines: [InvoiceLine]? = []
    @Relationship(deleteRule: .cascade, inverse: \ShippingCharge.invoice) var shipping: [ShippingCharge]? = []

    init(number: String, date: Date) {
        self.number = number
        self.date = date
    }

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var sortedLines: [InvoiceLine] { (lines ?? []).sorted { $0.position < $1.position } }
    var sortedShipping: [ShippingCharge] { (shipping ?? []).sorted { $0.position < $1.position } }

    var buttonsSubtotal: Money { (lines ?? []).reduce(.zero) { $0 + $1.subtotal } }
    var shippingTotal: Money { (shipping ?? []).reduce(.zero) { $0 + $1.amount } }
    var total: Money { buttonsSubtotal + shippingTotal }
    var buttonCount: Int { (lines ?? []).reduce(0) { $0 + $1.quantity } }

    var isEmpty: Bool { (lines ?? []).isEmpty && (shipping ?? []).isEmpty }

    /// The details to print: the ones it was finished with, or today's for a new draft.
    func businessProfile(current: BusinessProfile) -> BusinessProfile {
        businessSnapshot.flatMap { try? JSONDecoder().decode(BusinessProfile.self, from: $0) } ?? current
    }
}

/// One row of the invoice. The SKU, name and photo are copied from the button when it's
/// added, so later catalog edits don't change finished invoices.
@Model final class InvoiceLine {
    var position: Int = 0
    var sku: String = ""
    var itemDescription: String = ""
    var quantity: Int = 0
    var unitPriceCents: Int = 0
    /// Taken off each button, in dollars; what the PDF prints.
    var discountCents: Int = 0
    /// When she entered the discount as a percentage; `discountCents` follows the price.
    var discountIsPercent: Bool = false
    var discountPercent: Double = 0
    @Attribute(.externalStorage) var photo: Data?
    var variant: ButtonVariant?
    var invoice: Invoice?

    init(position: Int, variant: ButtonVariant, quantity: Int, unitPrice: Money) {
        self.position = position
        self.variant = variant
        self.quantity = quantity
        self.unitPriceCents = unitPrice.cents
        copyDetails(from: variant)
    }

    /// A line whose button isn't in the catalog (a sent invoice with an unknown SKU).
    init(position: Int, sku: String, description: String, quantity: Int, unitPrice: Money) {
        self.position = position
        self.sku = sku
        self.itemDescription = description
        self.quantity = quantity
        self.unitPriceCents = unitPrice.cents
    }

    /// For "Copy" on an invoice: the same button and quantity with the button's current name,
    /// photo and price (or the old line's, if the button has since been deleted).
    init(copying other: InvoiceLine) {
        position = other.position
        quantity = other.quantity
        discountCents = other.discountCents
        discountIsPercent = other.discountIsPercent
        discountPercent = other.discountPercent
        if let variant = other.variant {
            self.variant = variant
            unitPriceCents = variant.price > .zero ? variant.priceCents : other.unitPriceCents
            copyDetails(from: variant)
            if discountIsPercent { discountCents = Money(cents: unitPriceCents).percent(discountPercent).cents }
        } else {
            unitPriceCents = other.unitPriceCents
            sku = other.sku
            itemDescription = other.itemDescription
            photo = other.photo
        }
    }

    func copyDetails(from variant: ButtonVariant) {
        sku = variant.sku
        itemDescription = variant.title
        photo = variant.photo.flatMap { Photos.thumbnailPNG($0, maxSide: 400) }
    }

    var unitPrice: Money {
        get { Money(cents: unitPriceCents) }
        set { unitPriceCents = newValue.cents }
    }

    var discount: Money {
        get { Money(cents: discountCents) }
        set { discountCents = newValue.cents }
    }

    var subtotal: Money { (unitPrice - discount) * quantity }

    /// "10% off" or "$1.00 off each", or nil for no discount.
    var discountText: String? {
        guard discount > .zero else { return nil }
        if discountIsPercent {
            return "\(discountPercent.formatted(.number.precision(.fractionLength(0...2))))% off (\(discount.formatted) each)"
        }
        return "\(discount.formatted) off each"
    }
}

@Model final class ShippingCharge {
    var position: Int = 0
    var amountCents: Int = 0
    /// For her records only; the PDF just says SHIPPING.
    var note: String = ""
    @Attribute(.externalStorage) var receiptPhoto: Data?
    var invoice: Invoice?

    init(position: Int, amount: Money, note: String) {
        self.position = position
        self.amountCents = amount.cents
        self.note = note
    }

    var amount: Money {
        get { Money(cents: amountCents) }
        set { amountCents = newValue.cents }
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        ButtonDesign.self, ButtonVariant.self, ButtonVersion.self, Invoice.self, InvoiceLine.self, ShippingCharge.self,
    ]
}
