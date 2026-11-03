import Foundation

/// Échecs de connexion, sans texte : l'app les traduit (`ConnectionError+Messages.swift`).
public enum ConnectionError: Error, Sendable, Equatable {
    case claudeCodeUnavailable
    case claudeCodeMalformed
    /// Claude Code ne renouvelle son jeton que lorsqu'on l'utilise ; l'app ne le rafraîchit jamais (R1).
    case claudeCodeExpired(SubscriptionType)
    case invalidSessionKey
    case fetch(FetchError)
}

/// Les deux voies de connexion (FR-001, FR-002, FR-002a), la reprise silencieuse et la déconnexion (010 : dans le
/// core pour être testée). Horloge, journal et préférences sont injectés ; le journal ne reçoit que des textes fixes.
@MainActor
public final class ConnectionManager {
    private let credentials: any CredentialStore
    private let claudeCode: any ClaudeCodeCredentialSource
    private let http: any HTTPClient
    private let snapshots: any SnapshotStore
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let log: (String) -> Void

    static let organizationKey = "webOrganizationID"
    private var recoveryGate = RecoveryGate()

    public init(credentials: any CredentialStore, claudeCode: any ClaudeCodeCredentialSource, http: any HTTPClient,
                snapshots: any SnapshotStore, defaults: UserDefaults,
                now: @escaping @Sendable () -> Date = { Date() }, log: @escaping (String) -> Void = { _ in }) {
        self.credentials = credentials
        self.claudeCode = claudeCode
        self.http = http
        self.snapshots = snapshots
        self.defaults = defaults
        self.now = now
        self.log = log
    }

    public var isClaudeCodeAvailable: Bool { claudeCode.entryExists() }

    // MARK: Voie 1

    public func connectWithClaudeCode() async throws(ConnectionError) -> Account {
        let json: Data?
        do { json = try await claudeCode.readRawJSON(interactive: true) } catch { throw .claudeCodeUnavailable }
        guard let json else { throw .claudeCodeUnavailable }
        let token: ClaudeCodeToken
        do { token = try ClaudeCodeCredentialReader.accessToken(from: json) } catch { throw .claudeCodeMalformed }
        guard !token.isExpired(at: now()) else {
            log("Claude Code token expired, waiting for renewal")
            throw .claudeCodeExpired(token.subscriptionType)
        }
        do { try credentials.write(token.accessToken, for: .oauthAccessToken) } catch { throw .claudeCodeUnavailable }
        let provider = OAuthUsageProvider(http: http, credentials: credentials, now: now)
        // Le relevé de validation sert de cache : le coordinateur n'en refait pas un aussitôt (FR-009).
        let snapshot: UsageSnapshot
        do { snapshot = try await provider.fetch() } catch {
            try? credentials.delete(.oauthAccessToken)
            if error == .unauthorized { throw .claudeCodeExpired(token.subscriptionType) }
            throw .fetch(error)
        }
        try? snapshots.saveSnapshot(snapshot)
        log("connected via Claude Code session")
        return Account(connectionMethod: .claudeCode, subscriptionType: token.subscriptionType, status: .connected,
                       credentialRef: CredentialKey.oauthAccessToken.rawValue, connectedAt: now())
    }

    /// Après un 401 : relit l'entrée de Claude Code sans dialogue. Vrai si un nouveau jeton a été repris.
    public func recoverClaudeCodeToken() async -> Bool {
        guard recoveryGate.allow(at: now()) else { return false }
        guard let json = try? await claudeCode.readRawJSON(interactive: false),
              let token = try? ClaudeCodeCredentialReader.accessToken(from: json),
              !token.isExpired(at: now()) else { return false }
        let current = try? credentials.read(.oauthAccessToken)
        guard token.accessToken != current else { return false }
        guard (try? credentials.write(token.accessToken, for: .oauthAccessToken)) != nil else { return false }
        log("recovered a Claude Code token")
        return true
    }

    // MARK: Voie 2

    public func connectWithSessionKey(_ raw: String, preferredOrganization: String? = nil) async throws(ConnectionError) -> Account {
        let key = SessionKeyFormat.normalized(raw)
        guard SessionKeyFormat.isValid(key) else { throw .invalidSessionKey }
        do { try credentials.write(key, for: .webSessionKey) } catch { throw .invalidSessionKey }
        let provider = WebUsageProvider(http: http, credentials: credentials, now: now)
        do {
            let org = try await provider.resolveOrganization(preferred: preferredOrganization)
            defaults.set(org, forKey: Self.organizationKey)
            let snapshot = try await provider.fetch()
            try? snapshots.saveSnapshot(snapshot)
        } catch {
            try? credentials.delete(.webSessionKey)
            throw .fetch(error)
        }
        log("connected via browser session")
        return Account(connectionMethod: .browser, subscriptionType: .max, status: .connected,
                       credentialRef: CredentialKey.webSessionKey.rawValue, connectedAt: now())
    }

    // MARK: Fournisseur et déconnexion

    public func makeProvider(for account: Account) -> any UsageProvider {
        switch account.connectionMethod {
        case .claudeCode:
            return OAuthUsageProvider(http: http, credentials: credentials, now: now)
        case .browser:
            return WebUsageProvider(http: http, credentials: credentials, organizationID: defaults.string(forKey: Self.organizationKey), now: now)
        }
    }

    /// FR-003 : identifiants et dernières valeurs supprimés.
    public func signOut() {
        for key in CredentialKey.allCases { try? credentials.delete(key) }
        defaults.removeObject(forKey: Self.organizationKey)
        try? snapshots.wipe()
        log("signed out, credentials and cache wiped")
    }
}
