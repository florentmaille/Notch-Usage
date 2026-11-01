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
    /// Mapping commun HTTP → FetchError, puis parse du corps.
    static func snapshot(from response: HTTPResponse, now: Date) throws(FetchError) -> UsageSnapshot {
        if response.isChallenge { throw FetchError.challenge }
        switch response.status {
        case 200 where response.isHTML: throw FetchError.challenge
        case 200, 204:
            if response.body.isEmpty { throw FetchError.emptyBody }
        case 401, 403: throw FetchError.unauthorized
        case 429: throw FetchError.rateLimited(retryAfter: response.retryAfter)
        case 500...599: throw FetchError.server(response.status)
        default: throw FetchError.server(response.status)
        }
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
