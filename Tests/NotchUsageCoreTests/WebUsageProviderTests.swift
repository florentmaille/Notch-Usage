import Foundation
import Testing
@testable import NotchUsageCore

@Suite("WebUsageProvider")
struct WebUsageProviderTests {
    func makeProvider(_ responses: [Result<HTTPResponse, Error>], cookie: String? = "sk-ant-sid01-cookie", organizationID: String? = nil) -> (WebUsageProvider, StubHTTPClient) {
        let http = StubHTTPClient(responses)
        let creds = MemoryCredentialStore(cookie.map { [.webSessionKey: $0] } ?? [:])
        return (WebUsageProvider(http: http, credentials: creds, organizationID: organizationID), http)
    }

    @Test func resolveOrganizationPicksProOrMaxEvenIfTeamIsFirst() async throws {
        let (p, http) = makeProvider([.success(.ok(Fixture.data("organizations.json")))])
        let id = try await p.resolveOrganization()
        #expect(id == "22222222-2222-2222-2222-222222222222")
        let r = try #require(await http.lastRequest())
        #expect(r.url?.absoluteString == "https://claude.ai/api/organizations")
        #expect(r.value(forHTTPHeaderField: "Cookie") == "sessionKey=sk-ant-sid01-cookie")
    }

    /// Compte Team relevé le 2026-11-02 : aucune capacité claude_pro/claude_max.
    @Test func resolveOrganizationFallsBackToTeam() async throws {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("organizations-team-only.json")))])
        #expect(try await p.resolveOrganization() == "55555555-5555-5555-5555-555555555555")
    }

    @Test func preferredOrganizationWins() async throws {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("organizations.json")))])
        #expect(try await p.resolveOrganization(preferred: "11111111-1111-1111-1111-111111111111") == "11111111-1111-1111-1111-111111111111")
    }

    @Test func unknownPreferredOrganizationIgnored() async throws {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("organizations.json")))])
        #expect(try await p.resolveOrganization(preferred: "99999999-9999-9999-9999-999999999999") == "22222222-2222-2222-2222-222222222222")
    }

    @Test func resolveOrganizationWithoutProOrMaxIsUnsupported() async {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("organizations-free.json")))])
        await #expect(throws: FetchError.unsupported) { try await p.resolveOrganization() }
    }

    @Test func fetchResolvesOrganizationFirstThenUsesIt() async throws {
        let (p, http) = makeProvider([
            .success(.ok(Fixture.data("organizations.json"))),
            .success(.ok(Fixture.data("usage-limits-fable.json"))),
            .success(.ok(Fixture.data("usage-limits-fable.json"))),
        ])
        _ = try await p.fetch()
        _ = try await p.fetch()
        let urls = await http.requests.compactMap { $0.url?.absoluteString }
        #expect(urls == [
            "https://claude.ai/api/organizations",
            "https://claude.ai/api/organizations/22222222-2222-2222-2222-222222222222/usage",
            "https://claude.ai/api/organizations/22222222-2222-2222-2222-222222222222/usage",
        ])
        #expect(p.method == .browser)
    }

    @Test func usageRequestHeaders() async throws {
        let (p, http) = makeProvider([.success(.ok(Fixture.data("usage-limits-fable.json")))], organizationID: "org-1")
        _ = try await p.fetch()
        let r = try #require(await http.lastRequest())
        #expect(r.value(forHTTPHeaderField: "Cookie") == "sessionKey=sk-ant-sid01-cookie")
        #expect(r.value(forHTTPHeaderField: "anthropic-client-platform") == "web_claude_ai")
        #expect(r.value(forHTTPHeaderField: "Origin") == "https://claude.ai")
        #expect(r.value(forHTTPHeaderField: "Referer") == "https://claude.ai/settings/usage")
        #expect(r.value(forHTTPHeaderField: "Sec-Fetch-Site") == "same-origin")
        #expect(r.value(forHTTPHeaderField: "User-Agent")?.contains("Chrome") == true)
    }

    @Test func htmlBodyIsChallenge() async {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("usage-cloudflare.html"), contentType: "text/html; charset=utf-8"))], organizationID: "org-1")
        await #expect(throws: FetchError.challenge) { try await p.fetch() }
    }

    @Test func cfMitigatedHeaderIsChallenge() async {
        let (p, _) = makeProvider([.success(.status(403, body: Data(), headers: ["cf-mitigated": "challenge"]))], organizationID: "org-1")
        await #expect(throws: FetchError.challenge) { try await p.fetch() }
    }

    @Test func forbiddenIsUnauthorized() async {
        let (p, _) = makeProvider([.success(.status(403, body: Data("{}".utf8)))], organizationID: "org-1")
        await #expect(throws: FetchError.unauthorized) { try await p.fetch() }
    }

    @Test func missingCookie() async {
        let (p, http) = makeProvider([], cookie: nil, organizationID: "org-1")
        await #expect(throws: FetchError.credentialsUnavailable) { try await p.fetch() }
        #expect(await http.requests.isEmpty)
    }
}
