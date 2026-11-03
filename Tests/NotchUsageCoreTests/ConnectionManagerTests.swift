import Foundation
import Testing
@testable import NotchUsageCore

@MainActor
@Suite("ConnectionManager (010)")
struct ConnectionManagerTests {
    /// Avant l'expiration du jeton de la fixture (2025-11-01T14:00Z).
    let now = Date.iso("2025-11-01T10:00:00Z")
    let org = "22222222-2222-2222-2222-222222222222"

    func defaults() -> UserDefaults {
        let name = "notchusage.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func credentialsJSON(token: String = "sk-ant-oat01-FIXTURE-ACCESS-TOKEN") -> Data {
        let raw = String(decoding: Fixture.data("claude-code-credentials.json"), as: UTF8.self)
        return Data(raw.replacingOccurrences(of: "sk-ant-oat01-FIXTURE-ACCESS-TOKEN", with: token).utf8)
    }

    func manager(source: StubClaudeCodeSource, http: StubHTTPClient, creds: MemoryCredentialStore = MemoryCredentialStore(),
                 snapshots: MemorySnapshotStore = MemorySnapshotStore(), defaults: UserDefaults? = nil, at date: Date? = nil) -> ConnectionManager {
        let t = date ?? now
        return ConnectionManager(credentials: creds, claudeCode: source, http: http, snapshots: snapshots,
                                 defaults: defaults ?? self.defaults(), now: { t })
    }

    // MARK: Voie 1

    @Test func claudeCodeConnectStoresTheTokenAndCachesTheReading() async throws {
        let creds = MemoryCredentialStore(), snapshots = MemorySnapshotStore()
        let http = StubHTTPClient([.success(.ok(Fixture.data("usage-limits-fable.json")))])
        let account = try await manager(source: StubClaudeCodeSource(json: credentialsJSON()), http: http, creds: creds, snapshots: snapshots).connectWithClaudeCode()
        #expect(account.connectionMethod == .claudeCode && account.status == .connected)
        #expect(try creds.read(.oauthAccessToken) == "sk-ant-oat01-FIXTURE-ACCESS-TOKEN")
        #expect(snapshots.snapshot != nil)
    }

    @Test func claudeCodeErrorsAreTyped() async {
        let http = StubHTTPClient([])
        await #expect(throws: ConnectionError.claudeCodeUnavailable) {
            try await manager(source: StubClaudeCodeSource(json: nil), http: http).connectWithClaudeCode()
        }
        await #expect(throws: ConnectionError.claudeCodeMalformed) {
            try await manager(source: StubClaudeCodeSource(json: Data("{}".utf8)), http: http).connectWithClaudeCode()
        }
        await #expect(throws: ConnectionError.claudeCodeExpired(.max)) {
            try await manager(source: StubClaudeCodeSource(json: credentialsJSON()), http: http, at: Date.iso("2026-01-01T00:00:00Z")).connectWithClaudeCode()
        }
    }

    @Test func rejectedTokenIsDeletedAndReportedAsExpired() async throws {
        let creds = MemoryCredentialStore()
        let http = StubHTTPClient([.success(.status(401))])
        await #expect(throws: ConnectionError.claudeCodeExpired(.max)) {
            try await manager(source: StubClaudeCodeSource(json: credentialsJSON()), http: http, creds: creds).connectWithClaudeCode()
        }
        #expect(try creds.read(.oauthAccessToken) == nil)
    }

    @Test func recoveryReadsSilentlyAndOnlyAcceptsANewToken() async throws {
        let creds = MemoryCredentialStore([.oauthAccessToken: "sk-ant-oat01-OLD"])
        let source = StubClaudeCodeSource(json: credentialsJSON(token: "sk-ant-oat01-NEW"))
        let m = manager(source: source, http: StubHTTPClient([]), creds: creds)
        #expect(await m.recoverClaudeCodeToken())
        #expect(try creds.read(.oauthAccessToken) == "sk-ant-oat01-NEW")
        #expect(source.reads == [false])
        // Le garde-fou limite les relectures rapprochées.
        #expect(await m.recoverClaudeCodeToken() == false)
    }

    @Test func recoveryIgnoresTheSameToken() async {
        let creds = MemoryCredentialStore([.oauthAccessToken: "sk-ant-oat01-FIXTURE-ACCESS-TOKEN"])
        let m = manager(source: StubClaudeCodeSource(json: credentialsJSON()), http: StubHTTPClient([]), creds: creds)
        #expect(await m.recoverClaudeCodeToken() == false)
    }

    // MARK: Voie 2

    @Test func sessionKeyConnectRemembersTheOrganization() async throws {
        let d = defaults(), creds = MemoryCredentialStore()
        let http = StubHTTPClient([.success(.ok(Fixture.data("organizations.json"))), .success(.ok(Fixture.data("usage-limits-fable.json")))])
        let m = manager(source: StubClaudeCodeSource(json: nil), http: http, creds: creds, defaults: d)
        let account = try await m.connectWithSessionKey("  sk-ant-sid02-" + String(repeating: "a", count: 40) + "\n")
        #expect(account.connectionMethod == .browser)
        #expect(d.string(forKey: ConnectionManager.organizationKey) == org)
        #expect(try creds.read(.webSessionKey) == "sk-ant-sid02-" + String(repeating: "a", count: 40))
    }

    @Test func invalidOrRejectedSessionKeyLeavesNothingBehind() async throws {
        let creds = MemoryCredentialStore()
        let m = manager(source: StubClaudeCodeSource(json: nil), http: StubHTTPClient([.success(.status(403))]), creds: creds)
        await #expect(throws: ConnectionError.invalidSessionKey) { try await m.connectWithSessionKey("sk-ant-sid02-short") }
        await #expect(throws: ConnectionError.fetch(.unauthorized)) {
            try await m.connectWithSessionKey("sk-ant-sid02-" + String(repeating: "b", count: 40))
        }
        #expect(try creds.read(.webSessionKey) == nil)
    }

    // MARK: Déconnexion

    @Test func signOutWipesCredentialsOrganizationAndCache() throws {
        let d = defaults(); d.set(org, forKey: ConnectionManager.organizationKey)
        let creds = MemoryCredentialStore([.oauthAccessToken: "a", .webSessionKey: "b"])
        let snapshots = MemorySnapshotStore()
        let m = manager(source: StubClaudeCodeSource(json: nil), http: StubHTTPClient([]), creds: creds, snapshots: snapshots, defaults: d)
        m.signOut()
        #expect(try creds.read(.oauthAccessToken) == nil && creds.read(.webSessionKey) == nil)
        #expect(d.string(forKey: ConnectionManager.organizationKey) == nil && snapshots.wiped)
    }

    @Test func providerFollowsTheConnectionMethod() {
        let m = manager(source: StubClaudeCodeSource(json: nil, exists: false), http: StubHTTPClient([]))
        let account = Account(connectionMethod: .browser, subscriptionType: .max, status: .connected, credentialRef: "", connectedAt: now)
        #expect(m.makeProvider(for: account).method == .browser)
        #expect(!m.isClaudeCodeAvailable)
    }
}
