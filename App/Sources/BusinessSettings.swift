import Foundation
import InvoiceKit
import Observation

/// The details printed on every invoice (Home → Business details), kept in UserDefaults.
@Observable final class BusinessSettings {
    private static let key = "businessProfile"

    var profile: BusinessProfile {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(BusinessProfile.self, from: data) {
            profile = saved
        } else {
            profile = Seeder.bundledBusinessProfile() ?? BusinessProfile()
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
