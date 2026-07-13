import Foundation
import Security

enum KeychainError: Error { case notFound, unreadable }

enum KeychainReader {
    static func read(service: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw status == errSecItemNotFound ? KeychainError.notFound : KeychainError.unreadable
        }
        return data
    }

    /// Update the value of the existing item in place, preserving its other
    /// attributes (notably the account, e.g. "sangho") so the Claude Code CLI keeps
    /// finding the same item after we rotate the token. Falls back to `write` only if
    /// the item somehow doesn't exist yet.
    @discardableResult
    static func update(service: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            write(service: service, data: data)
            return true
        }
        return status == errSecSuccess
    }

    static func write(service: String, data: Data) {
        delete(service: service)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
