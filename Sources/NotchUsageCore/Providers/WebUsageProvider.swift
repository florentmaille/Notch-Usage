import Foundation

/// Voie 2 : cookie `sessionKey` → claude.ai (organisations puis usage).
public actor WebUsageProvider: UsageProvider {
    public static let organizationsURL = URL(string: "https://claude.ai/api/organizations")!

    public nonisolated let method: ConnectionMethod = .browser
    private let http: any HTTPClient
    private let credentials: any CredentialStore
    private let now: @Sendable () -> Date
    public private(set) var organizationID: String?

    public init(http: any HTTPClient, credentials: any CredentialStore, organizationID: String? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.http = http
        self.credentials = credentials
        self.organizationID = organizationID
        self.now = now
    }

    /// Première org dont `capabilities` contient `claude_pro` ou un préfixe `claude_max`.
    @discardableResult
    public func resolveOrganization() async throws(FetchError) -> String {
        let response = try await ProviderSupport.send(try request(Self.organizationsURL), via: http)
        if response.isChallenge || (response.status == 200 && response.isHTML) { throw FetchError.challenge }
        switch response.status {
        case 200: break
        case 401, 403: throw FetchError.unauthorized
        case 429: throw FetchError.rateLimited(retryAfter: response.retryAfter)
        default: throw FetchError.server(response.status)
        }
        guard let orgs = (try? JSONSerialization.jsonObject(with: response.body)) as? [[String: Any]] else {
            throw FetchError.malformed
        }
        let match = orgs.first { org in
            let caps = (org["capabilities"] as? [String]) ?? []
            return caps.contains("claude_pro") || caps.contains { $0.hasPrefix("claude_max") }
        }
        guard let uuid = match?["uuid"] as? String, !uuid.isEmpty else { throw FetchError.unsupported }
        organizationID = uuid
        return uuid
    }

    public func fetch() async throws(FetchError) -> UsageSnapshot {
        let org: String
        if let organizationID { org = organizationID } else { org = try await resolveOrganization() }
        let url = Self.organizationsURL.appending(path: org).appending(path: "usage")
        let response = try await ProviderSupport.send(try request(url), via: http)
        return try ProviderSupport.snapshot(from: response, now: now())
    }

    private func request(_ url: URL) throws(FetchError) -> URLRequest {
        guard let cookie = try? credentials.read(.webSessionKey), !cookie.isEmpty else {
            throw FetchError.credentialsUnavailable
        }
        var r = URLRequest(url: url)
        r.httpMethod = "GET"
        r.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        r.setValue("*/*", forHTTPHeaderField: "Accept")
        r.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        r.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        r.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        r.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        r.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        r.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        r.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        r.setValue(UserAgents.chromeMac, forHTTPHeaderField: "User-Agent")
        return r
    }
}
