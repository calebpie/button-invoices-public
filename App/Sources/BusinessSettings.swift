import Foundation
import InvoiceKit
import Observation
import Security

/// The details printed on every invoice (Settings tab). The bank routing and account numbers
/// are kept in the keychain; everything else in UserDefaults (Privacy, "Store sensitive
/// information in a keychain").
@Observable final class BusinessSettings {
    private static let key = "businessProfile"

    var profile: BusinessProfile {
        didSet { save() }
    }

    init() {
        var loaded: BusinessProfile
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(BusinessProfile.self, from: data) {
            loaded = saved
        } else {
            loaded = Seeder.bundledBusinessProfile() ?? BusinessProfile()
        }
        // Numbers saved before they moved to the keychain stay where they were found until
        // the save below moves them.
        loaded.routing = Keychain.read("routing") ?? loaded.routing
        loaded.account = Keychain.read("account") ?? loaded.account
        profile = loaded
        save()
    }

    private func save() {
        Keychain.write("routing", profile.routing)
        Keychain.write("account", profile.account)
        var stored = profile
        stored.routing = ""
        stored.account = ""
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// Generic-password items for this app, readable only while the device is unlocked.
enum Keychain {
    private static let service = "ButtonInvoices.business"

    static func read(_ name: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: name,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ name: String, _ value: String) {
        let match: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: name]
        SecItemDelete(match as CFDictionary)
        guard !value.isEmpty else { return }
        var add = match
        add[kSecValueData] = Data(value.utf8)
        add[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        SecItemAdd(add as CFDictionary, nil)
    }
}
