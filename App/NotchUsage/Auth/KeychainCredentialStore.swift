import Foundation
import NotchUsageCore
import Security

struct KeychainError: Error, CustomStringConvertible {
    let status: OSStatus
    var description: String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
    }
}

/// Secrets de l'app : entrées génériques du Trousseau, service `com.notchusage.credentials` (R9).
final class KeychainCredentialStore: CredentialStore {
    static let service = "com.notchusage.credentials"

    func read(_ key: CredentialKey) throws -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    func write(_ value: String, for key: CredentialKey) throws {
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(key) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError(status: status) }
        var add = baseQuery(key)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Notch Usage (\(key.rawValue))"
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else { throw KeychainError(status: addStatus) }
    }

    func delete(_ key: CredentialKey) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(_ key: CredentialKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}

/// Le jeton de Claude Code reste en mémoire : sa source est l'entrée Trousseau de Claude Code.
/// Le recopier dans l'entrée de l'app ajoutait un dialogue Trousseau à chaque nouvelle signature.
final class AppCredentialStore: CredentialStore, @unchecked Sendable {
    private let keychain = KeychainCredentialStore()
    private let lock = NSLock()
    private var oauthToken: String?

    func read(_ key: CredentialKey) throws -> String? {
        if key == .oauthAccessToken { return lock.withLock { oauthToken } }
        return try keychain.read(key)
    }

    func write(_ value: String, for key: CredentialKey) throws {
        if key == .oauthAccessToken { lock.withLock { oauthToken = value }; return }
        try keychain.write(value, for: key)
    }

    /// Supprime aussi une éventuelle copie laissée par une version précédente.
    func delete(_ key: CredentialKey) throws {
        if key == .oauthAccessToken { lock.withLock { oauthToken = nil } }
        try keychain.delete(key)
    }
}
