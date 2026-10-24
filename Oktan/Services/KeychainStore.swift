import Foundation
import Security

/// Minimal Keychain wrapper for storing small Codable values.
/// Used for data that shouldn't live in UserDefaults (e.g. the signed-in user).
enum KeychainStore {

    private static let service = "com.oktan.keychain"

    #if DEBUG
    private static var inMemoryTestStore: [String: Data]?

    /// Explicitly enabled by unit tests because an unsigned XCTest host has no
    /// Keychain entitlement. Release builds do not contain this backend.
    static func useInMemoryStoreForTesting() {
        inMemoryTestStore = [:]
    }
    #endif

    @discardableResult
    static func save(_ data: Data, forKey key: String) -> Bool {
        #if DEBUG
        if inMemoryTestStore != nil {
            inMemoryTestStore?[key] = data
            return true
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        // Profile credentials never need background or cross-device access.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func load(forKey key: String) -> Data? {
        #if DEBUG
        if let inMemoryTestStore { return inMemoryTestStore[key] }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        #if DEBUG
        if inMemoryTestStore != nil {
            inMemoryTestStore?.removeValue(forKey: key)
            return true
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func save<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return save(data, forKey: key)
    }

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = load(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
