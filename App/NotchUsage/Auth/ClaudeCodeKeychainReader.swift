import Foundation
import NotchUsageCore
import LocalAuthentication
import Security

/// Lit l'entrée Trousseau de Claude Code (R1). L'entrée appartient au binaire `claude` :
/// en mode non interactif, macOS refuse sans dialogue (`errSecInteractionNotAllowed`) → `nil`.
final class ClaudeCodeKeychainReader: ClaudeCodeCredentialSource, @unchecked Sendable {
    static let service = "Claude Code-credentials"

    /// Vrai si une entrée existe, sans en lire le contenu ni déclencher de dialogue.
    func entryExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.accountName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: Self.context(interactive: false),
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// File série : `SecKeychainSetUserInteractionAllowed` est global au processus.
    private static let queue = DispatchQueue(label: "com.notchusage.claude-code-keychain", qos: .userInitiated)

    func readRawJSON(interactive: Bool) async throws -> Data? {
        // SecItemCopyMatching bloque pendant le dialogue : hors du main actor.
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                // L'entrée de Claude Code vit dans le trousseau de session (fichier) : LAContext n'y
                // empêche pas le dialogue, seule cette API dépréciée le fait.
                if !interactive { SecKeychainSetUserInteractionAllowed(false) }
                defer { if !interactive { SecKeychainSetUserInteractionAllowed(true) } }
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: Self.service,
                    kSecAttrAccount as String: Self.accountName,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseAuthenticationContext as String: Self.context(interactive: interactive),
                ]
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                switch status {
                case errSecSuccess:
                    continuation.resume(returning: item as? Data)
                case errSecItemNotFound, errSecInteractionNotAllowed, errSecUserCanceled, errSecAuthFailed:
                    Log.auth.info("Claude Code credentials unavailable (status \(status), interactive \(interactive))")
                    continuation.resume(returning: nil)
                default:
                    continuation.resume(throwing: KeychainError(status: status))
                }
            }
        }
    }

    private static func context(interactive: Bool) -> LAContext {
        let ctx = LAContext()
        ctx.interactionNotAllowed = !interactive
        return ctx
    }

    private static var accountName: String {
        let user = NSUserName()
        return user.isEmpty ? (ProcessInfo.processInfo.environment["LOGNAME"] ?? "") : user
    }
}
