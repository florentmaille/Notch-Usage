import Foundation
import Testing
@testable import NotchUsageCore

@Suite("OAuthUsageProvider")
struct OAuthUsageProviderTests {
    func makeProvider(_ responses: [Result<HTTPResponse, Error>], token: String? = "sk-ant-oat01-x") -> (OAuthUsageProvider, StubHTTPClient) {
        let http = StubHTTPClient(responses)
        let creds = MemoryCredentialStore(token.map { [.oauthAccessToken: $0] } ?? [:])
        return (OAuthUsageProvider(http: http, credentials: creds), http)
    }

    @Test func requestShape() async throws {
        let (p, http) = makeProvider([.success(.ok(Fixture.data("usage-limits-fable.json")))])
        _ = try await p.fetch()
        let r = try #require(await http.lastRequest())
        #expect(r.url?.absoluteString.hasPrefix("https://api.anthropic.com/api/oauth/usage") == true)
        #expect(r.httpMethod == "GET")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer sk-ant-oat01-x")
        #expect(r.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
        #expect(r.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(r.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("claude-cli/") == true)
        #expect(p.method == .claudeCode)
    }

    @Test func successProducesSnapshot() async throws {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("usage-limits-fable.json")))])
        let s = try await p.fetch()
        #expect(s.limits.count == 3)
        #expect(s.limits[2].modelName == "Fable")
    }

    @Test func emptyBody() async {
        let (p, _) = makeProvider([.success(.status(204))])
        await #expect(throws: FetchError.emptyBody) { try await p.fetch() }
    }

    @Test func unauthorized() async {
        let (p, _) = makeProvider([.success(.status(401, body: Data("{}".utf8)))])
        await #expect(throws: FetchError.unauthorized) { try await p.fetch() }
    }

    @Test func rateLimitedWithRetryAfter() async {
        let (p, _) = makeProvider([.success(.status(429, body: Fixture.data("usage-429.json"), headers: ["Retry-After": "471"]))])
        await #expect(throws: FetchError.rateLimited(retryAfter: .seconds(471))) { try await p.fetch() }
    }

    @Test func rateLimitedWithoutRetryAfter() async {
        let (p, _) = makeProvider([.success(.status(429, body: Fixture.data("usage-429.json")))])
        await #expect(throws: FetchError.rateLimited(retryAfter: nil)) { try await p.fetch() }
    }

    @Test func serverError() async {
        let (p, _) = makeProvider([.success(.status(503))])
        await #expect(throws: FetchError.server(503)) { try await p.fetch() }
    }

    @Test func networkError() async {
        let (p, _) = makeProvider([.failure(URLError(.notConnectedToInternet))])
        await #expect(throws: FetchError.network(.notConnectedToInternet)) { try await p.fetch() }
    }

    @Test func malformedBody() async {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("usage-malformed.json")))])
        await #expect(throws: FetchError.malformed) { try await p.fetch() }
    }

    @Test func noLimitsIsUnsupported() async {
        let (p, _) = makeProvider([.success(.ok(Fixture.data("usage-no-limits.json")))])
        await #expect(throws: FetchError.unsupported) { try await p.fetch() }
    }

    @Test func missingTokenDoesNotHitNetwork() async {
        let (p, http) = makeProvider([], token: nil)
        await #expect(throws: FetchError.credentialsUnavailable) { try await p.fetch() }
        #expect(await http.requests.isEmpty)
    }
}
