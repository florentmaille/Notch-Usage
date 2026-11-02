import Foundation

public enum CredentialKey: String, Sendable, Hashable, CaseIterable {
    case oauthAccessToken = "oauth-access-token"
    case webSessionKey = "web-session-key"
}

/// Stockage des secrets de l'app. L'implémentation réelle vit dans le Trousseau (côté app).
public protocol CredentialStore: Sendable {
    func read(_ key: CredentialKey) throws -> String?
    func write(_ value: String, for key: CredentialKey) throws
    func delete(_ key: CredentialKey) throws
}

/// Lecture de l'entrée Trousseau de Claude Code. `interactive == false` ⇒ aucun dialogue système.
public protocol ClaudeCodeCredentialSource: Sendable {
    func readRawJSON(interactive: Bool) async throws -> Data?
}

/// Dernier relevé et registre d'alertes.
public protocol SnapshotStore: Sendable {
    func loadSnapshot() throws -> UsageSnapshot?
    func saveSnapshot(_ snapshot: UsageSnapshot) throws
    func loadLedger() throws -> AlertLedger?
    func saveLedger(_ ledger: AlertLedger) throws
    /// Relevés des deux dernières heures (003), supprimés par `wipe()`.
    func loadHistory() throws -> UsageHistory?
    func saveHistory(_ history: UsageHistory) throws
    func wipe() throws
}
