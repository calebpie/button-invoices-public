import Foundation
import InvoiceKit
import SwiftData

/// Loads the starting catalog (App/Resources/Seed, from the Excel template) the first time
/// the app runs. Never runs again, so buttons she deletes stay deleted.
enum Seeder {
    static let seededKey = "seededCatalogFrom"

    static func seedCatalogIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: seededKey) == nil,
              (try? context.fetchCount(FetchDescriptor<ButtonVariant>())) == 0,
              let folder = Bundle.main.url(forResource: "Seed", withExtension: nil),
              let data = try? Data(contentsOf: folder.appendingPathComponent("catalog.json")),
              let catalog = try? JSONDecoder().decode(SeedCatalog.self, from: data)
        else { return }

        var designs: [String: ButtonDesign] = [:]
        for seed in catalog.variants {
            let design = designs[seed.design] ?? {
                let d = ButtonDesign(name: seed.design, code: SKURules.designCode(for: seed.design))
                context.insert(d)
                designs[seed.design] = d
                return d
            }()
            let photo = seed.photo.flatMap { try? Data(contentsOf: folder.appendingPathComponent("Photos/\($0)")) }
            let variant = ButtonVariant(design: design, colors: seed.colors, size: seed.size, sku: seed.sku,
                                        price: Money(cents: seed.priceCents ?? 0), photo: photo)
            context.insert(variant)
        }
        try? context.save()
        defaults.set(catalog.source, forKey: seededKey)
    }

    static let invoicesKey = "seededInvoicesFrom"

    /// Loads the invoices sent before the app (Seed/invoices.json) as paid invoices, once.
    /// Each is finished the way the app finishes an invoice: lines take the catalog's name,
    /// SKU and photo (spelling as corrected in the catalog), with the price, discount and
    /// quantity that were invoiced; the business details and the PDF are stored with it.
    /// Invoice numbers already in the app are skipped.
    static func seedSentInvoicesIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: invoicesKey) == nil,
              let url = Bundle.main.url(forResource: "Seed", withExtension: nil)?.appendingPathComponent("invoices.json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedInvoices.self, from: data)
        else { return }
        let variants = Catalog.allVariants(context)
        let bySKU = Dictionary(variants.map { ($0.sku, $0) }, uniquingKeysWith: { a, _ in a })
        let existing = Set(((try? context.fetch(FetchDescriptor<Invoice>())) ?? []).map(\.number))
        let profile = bundledBusinessProfile() ?? BusinessProfile()
        let snapshot = try? JSONEncoder().encode(profile)

        for sent in seed.invoices where !existing.contains(sent.number) {
            guard let date = sent.day else { continue }
            let invoice = Invoice(number: sent.number, date: date)
            invoice.numberIsCustom = true
            invoice.createdAt = date
            context.insert(invoice)
            for (i, s) in sent.lines.enumerated() {
                let line: InvoiceLine
                if let variant = bySKU[s.sku] {
                    line = InvoiceLine(position: i, variant: variant, quantity: s.quantity,
                                       unitPrice: Money(cents: s.unitPriceCents))
                    if (variant.lastUsedAt ?? .distantPast) < date { variant.lastUsedAt = date }
                } else {
                    line = InvoiceLine(position: i, sku: s.sku, description: s.description, quantity: s.quantity,
                                       unitPrice: Money(cents: s.unitPriceCents))
                }
                line.discountCents = s.discountCents
                context.insert(line)
                line.invoice = invoice
            }
            for (i, cents) in sent.shippingCents.enumerated() {
                let charge = ShippingCharge(position: i, amount: Money(cents: cents), note: "")
                context.insert(charge)
                charge.invoice = invoice
            }
            invoice.noShipping = sent.shippingCents.isEmpty
            invoice.businessSnapshot = snapshot
            invoice.finishedPDF = InvoiceExport.render(invoice, profile: profile)
            invoice.status = .paid
            invoice.finalizedAt = date
        }
        try? context.save()
        defaults.set(seed.invoices.map(\.source).joined(separator: ", "), forKey: invoicesKey)
    }

    /// Seller, bill-to and bank details from the template, if `make seed` bundled them.
    static func bundledBusinessProfile() -> BusinessProfile? {
        guard let url = Bundle.main.url(forResource: "Seed", withExtension: nil)?.appendingPathComponent("business.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BusinessProfile.self, from: data)
    }
}
