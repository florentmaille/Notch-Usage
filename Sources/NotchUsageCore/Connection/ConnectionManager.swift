import Foundation

/// Échecs de connexion, sans texte : l'app les traduit (`ConnectionError+Messages.swift`).
public enum ConnectionError: Error, Sendable, Equatable {
    case claudeCodeUnavailable
    /// L'entrée existe, mais macOS n'a pas laissé l'app la lire (dialogue du Trousseau décliné).
    case claudeCodeAccessDenied
    case claudeCodeMalformed
    /// Claude Code ne renouvelle son jeton que lorsqu'on l'utilise ; l'app ne le rafraîchit jamais (R1).
    case claudeCodeExpired(SubscriptionType)
    /// Le jeton était expiré et le CLI n'a pas pu le renouveler.
    case claudeCodeRenewalFailed(ClaudeCLI.Outcome)
    case invalidSessionKey
    case fetch(FetchError)
}

/// Relecture silencieuse de l'entrée Trousseau de Claude Code : ce qu'elle a donné, pour proposer le bon remède.
public enum ClaudeCodeRecovery: Sendable, Equatable {
    /// Un nouveau jeton valable a été repris.
    case recovered
    /// Même jeton qu'avant : rien de neuf à essayer.
    case unchanged
    /// Jeton lu, mais expiré : Claude Code doit le renouveler.
    case expired
    /// L'entrée existe, macOS refuse la lecture sans dialogue (Claude Code vient de la réécrire) : il faut l'accord
    /// de l'utilisateur, pas une requête à Claude.
    case accessNeeded
    /// Entrée absente, ou contenu illisible.
    case unavailable
    /// Relecture trop rapprochée de la précédente (`RecoveryGate`).
    case throttled
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
        guard let json else { throw claudeCode.entryExists() ? .claudeCodeAccessDenied : .claudeCodeUnavailable }
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

    /// Après un 401 : relit l'entrée de Claude Code sans dialogue. Le résultat distingue un jeton expiré d'une
    /// lecture refusée : Claude Code réécrit son entrée quand il renouvelle son jeton, et macOS redemande alors
    /// l'accord de l'utilisateur. Le jeton est bon, seul l'accès manque.
    public func recoverClaudeCodeToken() async -> ClaudeCodeRecovery {
        guard recoveryGate.allow(at: now()) else { return .throttled }
        guard let json = try? await claudeCode.readRawJSON(interactive: false) else {
            return claudeCode.entryExists() ? .accessNeeded : .unavailable
        }
        guard let token = try? ClaudeCodeCredentialReader.accessToken(from: json) else { return .unavailable }
        guard !token.isExpired(at: now()) else { return .expired }
        let current = try? credentials.read(.oauthAccessToken)
        guard token.accessToken != current else { return .unchanged }
        guard (try? credentials.write(token.accessToken, for: .oauthAccessToken)) != nil else { return .unavailable }
        log("recovered a Claude Code token")
        return .recovered
    }

    /// Reconnexion sur clic (011) : la lecture avec dialogue d'abord, qui suffit quand seul l'accès manquait. Le CLI
    /// n'est sollicité, ce qui coûte une requête, que si le jeton lu est expiré ou refusé par Claude.
    public func reconnectWithClaudeCode(renew: @MainActor () async -> ClaudeCLI.Outcome) async throws(ConnectionError) -> Account {
        do {
            return try await connectWithClaudeCode()
        } catch {
            guard case .claudeCodeExpired = error else { throw error }
        }
        let outcome = await renew()
        guard outcome == .renewed else { throw .claudeCodeRenewalFailed(outcome) }
        log("Claude Code session renewed by its CLI")
        return try await connectWithClaudeCode()
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
