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

    /// Seller, bill-to and bank details from the template, if `make seed` bundled them.
    static func bundledBusinessProfile() -> BusinessProfile? {
        guard let url = Bundle.main.url(forResource: "Seed", withExtension: nil)?.appendingPathComponent("business.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BusinessProfile.self, from: data)
    }
}
