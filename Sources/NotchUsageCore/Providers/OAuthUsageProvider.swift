import Foundation

/// Voie 1 : jeton OAuth de Claude Code → api.anthropic.com.
public struct OAuthUsageProvider: UsageProvider {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    public let method: ConnectionMethod = .claudeCode
    private let http: any HTTPClient
    private let credentials: any CredentialStore
    private let now: @Sendable () -> Date

    public init(http: any HTTPClient, credentials: any CredentialStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.http = http
        self.credentials = credentials
        self.now = now
    }

    public func fetch() async throws(FetchError) -> UsageSnapshot {
        guard let token = try? credentials.read(.oauthAccessToken), !token.isEmpty else {
            throw FetchError.credentialsUnavailable
        }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UserAgents.claudeCLI, forHTTPHeaderField: "User-Agent")
        let response = try await ProviderSupport.send(request, via: http)
        return try ProviderSupport.snapshot(from: response, now: now())
    }
}
