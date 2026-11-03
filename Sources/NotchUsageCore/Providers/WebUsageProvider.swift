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

    /// Choix de l'org : `preferred` (cookie `lastActiveOrg`) si elle est dans la liste, sinon une org
    /// Pro ou Max, sinon une org Team ou Enterprise (capacités et tier relevés sur compte réel variables).
    @discardableResult
    public func resolveOrganization(preferred: String? = nil) async throws(FetchError) -> String {
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
        func markers(_ org: [String: Any]) -> [String] {
            ((org["capabilities"] as? [String]) ?? []) + [(org["rate_limit_tier"] as? String) ?? ""]
        }
        let personal: ([String: Any]) -> Bool = { org in
            markers(org).contains { $0 == "claude_pro" || $0.hasPrefix("claude_max") || $0.contains("claude_pro") }
        }
        let business: ([String: Any]) -> Bool = { org in
            markers(org).contains { m in ["team", "enterprise", "raven"].contains { m.contains($0) } }
        }
        let match = orgs.first { ($0["uuid"] as? String) == preferred && preferred != nil }
            ?? orgs.first(where: personal)
            ?? orgs.first(where: business)
        // Un UUID strict : la valeur vient du serveur et finit dans un chemin d'URL (007).
        guard let uuid = match?["uuid"] as? String, UUID(uuidString: uuid) != nil else { throw FetchError.unsupported }
        organizationID = uuid
        return uuid
    }

    public func fetch() async throws(FetchError) -> UsageSnapshot {
        let org: String
        if let organizationID, UUID(uuidString: organizationID) != nil { org = organizationID } else { org = try await resolveOrganization() }
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
