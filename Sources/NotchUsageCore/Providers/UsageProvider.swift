import Foundation

public protocol UsageProvider: Sendable {
    var method: ConnectionMethod { get }
    func fetch() async throws(FetchError) -> UsageSnapshot
}

enum UserAgents {
    /// Évite le bucket de rate-limit agressif réservé aux clients inconnus (R1).
    static let claudeCLI = "claude-cli/2.1.0 (external, cli)"
    static let chromeMac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

enum ProviderSupport {
    /// Mapping commun HTTP → FetchError, pour toute réponse JSON attendue (usage, organisations).
    static func check(_ response: HTTPResponse) throws(FetchError) {
        if response.isChallenge { throw FetchError.challenge }
        switch response.status {
        case 200 where response.isHTML: throw FetchError.challenge
        case 200, 204:
            if response.body.isEmpty { throw FetchError.emptyBody }
        // Blocage Cloudflare sans l'en-tête `cf-mitigated` (pare-feu, VPN) : la page est en HTML, les refus de
        // l'API en JSON. Les identifiants sont bons : nouvel essai, pas de reconnexion.
        case 403 where response.isHTML: throw FetchError.challenge
        case 401, 403: throw FetchError.unauthorized
        case 429: throw FetchError.rateLimited(retryAfter: response.retryAfter)
        default: throw FetchError.server(response.status)
        }
    }

    /// Mapping commun, puis parse du corps d'usage.
    static func snapshot(from response: HTTPResponse, now: Date) throws(FetchError) -> UsageSnapshot {
        try check(response)
        do {
            let limits = try UsageResponseParser.parse(response.body)
            return UsageSnapshot(limits: limits, fetchedAt: now)
        } catch ParseError.noLimits {
            throw FetchError.unsupported
        } catch {
            throw FetchError.malformed
        }
    }

    static func send(_ request: URLRequest, via http: any HTTPClient) async throws(FetchError) -> HTTPResponse {
        do {
            return try await http.send(request)
        } catch let e as URLError {
            throw FetchError.network(e.code)
        } catch {
            throw FetchError.network(.unknown)
        }
    }
}
