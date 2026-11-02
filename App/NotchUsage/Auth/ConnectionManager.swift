import Foundation
import NotchUsageCore

enum ConnectionError: LocalizedError {
    case claudeCodeUnavailable
    case claudeCodeMalformed
    /// Claude Code ne renouvelle son jeton que lorsqu'on l'utilise ; l'app ne le rafraîchit jamais (R1).
    case claudeCodeExpired(SubscriptionType)
    case invalidSessionKey
    case fetch(FetchError)

    var errorDescription: String? {
        switch self {
        case .claudeCodeUnavailable:
            return String(localized: "No Claude Code session found. Sign in to Claude Code first, or use the browser.")
        case .claudeCodeMalformed:
            return String(localized: "The Claude Code credentials could not be read. Open Claude Code once, then retry.")
        case .claudeCodeExpired:
            return String(localized: "Your Claude Code session has expired. Run claude in Terminal once to renew it: Notch Usage reconnects automatically.")
        case .invalidSessionKey:
            return String(localized: "That does not look like a Claude session key (it should start with sk-ant-sid).")
        case .fetch(let e):
            switch e {
            case .unauthorized: return String(localized: "Claude rejected the credentials. Try signing in again.")
            case .unsupported: return String(localized: "This Claude plan does not expose usage limits. Pro, Max or Team is required.")
            case .challenge: return String(localized: "claude.ai asked for a browser check. Open the sign-in window and complete it.")
            case .rateLimited: return String(localized: "Claude is rate-limiting usage requests. Try again in a few minutes.")
            case .network: return String(localized: "No network connection.")
            default: return String(localized: "Could not read usage data. Try again.")
            }
        }
    }
}

/// Les deux voies de connexion (FR-001, FR-002, FR-002a), la reprise silencieuse et la déconnexion.
@MainActor
final class ConnectionManager {
    private let credentials: any CredentialStore
    private let claudeCode: ClaudeCodeKeychainReader
    private let http: any HTTPClient
    private let snapshots: any SnapshotStore
    private let defaults: UserDefaults

    private static let organizationKey = "webOrganizationID"
    private var recoveryGate = RecoveryGate()

    init(credentials: any CredentialStore, claudeCode: ClaudeCodeKeychainReader, http: any HTTPClient, snapshots: any SnapshotStore, defaults: UserDefaults) {
        self.credentials = credentials
        self.claudeCode = claudeCode
        self.http = http
        self.snapshots = snapshots
        self.defaults = defaults
    }

    var isClaudeCodeAvailable: Bool { claudeCode.entryExists() }

    // MARK: Voie 1

    func connectWithClaudeCode() async throws -> Account {
        guard let json = try await claudeCode.readRawJSON(interactive: true) else { throw ConnectionError.claudeCodeUnavailable }
        let token: ClaudeCodeToken
        do { token = try ClaudeCodeCredentialReader.accessToken(from: json) } catch { throw ConnectionError.claudeCodeMalformed }
        guard !token.isExpired(at: Date()) else {
            Log.auth.notice("Claude Code token expired, waiting for renewal")
            throw ConnectionError.claudeCodeExpired(token.subscriptionType)
        }
        try credentials.write(token.accessToken, for: .oauthAccessToken)
        let provider = OAuthUsageProvider(http: http, credentials: credentials)
        // Le relevé de validation sert de cache : le coordinateur n'en refait pas un aussitôt (FR-009).
        let snapshot: UsageSnapshot
        do { snapshot = try await provider.fetch() } catch {
            try? credentials.delete(.oauthAccessToken)
            if error == .unauthorized { throw ConnectionError.claudeCodeExpired(token.subscriptionType) }
            throw ConnectionError.fetch(error)
        }
        try? snapshots.saveSnapshot(snapshot)
        Log.auth.notice("connected via Claude Code session")
        return Account(connectionMethod: .claudeCode, subscriptionType: token.subscriptionType, status: .connected,
                       credentialRef: CredentialKey.oauthAccessToken.rawValue, connectedAt: Date())
    }

    /// Après un 401 : relit l'entrée de Claude Code sans dialogue. Vrai si un nouveau jeton a été repris.
    func recoverClaudeCodeToken() async -> Bool {
        guard recoveryGate.allow(at: Date()) else { return false }
        guard let json = try? await claudeCode.readRawJSON(interactive: false),
              let token = try? ClaudeCodeCredentialReader.accessToken(from: json),
              !token.isExpired(at: Date()) else { return false }
        let current = try? credentials.read(.oauthAccessToken)
        guard token.accessToken != current else { return false }
        guard (try? credentials.write(token.accessToken, for: .oauthAccessToken)) != nil else { return false }
        Log.auth.notice("recovered a Claude Code token")
        return true
    }

    // MARK: Voie 2

    func connectWithSessionKey(_ raw: String, preferredOrganization: String? = nil) async throws -> Account {
        let key = SessionKeyFormat.normalized(raw)
        guard SessionKeyFormat.isValid(key) else { throw ConnectionError.invalidSessionKey }
        try credentials.write(key, for: .webSessionKey)
        let provider = WebUsageProvider(http: http, credentials: credentials)
        do {
            let org = try await provider.resolveOrganization(preferred: preferredOrganization)
            defaults.set(org, forKey: Self.organizationKey)
            let snapshot = try await provider.fetch()
            try? snapshots.saveSnapshot(snapshot)
        } catch {
            try? credentials.delete(.webSessionKey)
            throw ConnectionError.fetch(error)
        }
        Log.auth.notice("connected via browser session")
        return Account(connectionMethod: .browser, subscriptionType: .max, status: .connected,
                       credentialRef: CredentialKey.webSessionKey.rawValue, connectedAt: Date())
    }

    // MARK: Fournisseur et déconnexion

    func makeProvider(for account: Account) -> any UsageProvider {
        switch account.connectionMethod {
        case .claudeCode:
            return OAuthUsageProvider(http: http, credentials: credentials)
        case .browser:
            return WebUsageProvider(http: http, credentials: credentials, organizationID: defaults.string(forKey: Self.organizationKey))
        }
    }

    /// FR-003 : identifiants et dernières valeurs supprimés.
    func signOut() {
        for key in CredentialKey.allCases { try? credentials.delete(key) }
        defaults.removeObject(forKey: Self.organizationKey)
        try? snapshots.wipe()
        Log.auth.notice("signed out, credentials and cache wiped")
    }
}
