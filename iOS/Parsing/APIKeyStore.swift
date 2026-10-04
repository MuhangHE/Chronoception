import Foundation
import Security

/// The MiniMax API key lives in this device's Keychain only: never in UserDefaults,
/// iCloud or the repository.
enum APIKeyStore {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(Bundle.main.bundleIdentifier ?? "Chronoception").minimax",
            kSecAttrAccount as String: "api-key",
        ]
    }

    static func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard
            SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else { return nil }
        return key
    }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            // Readable after the first unlock, so waiting sentences can be retried in the background.
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
