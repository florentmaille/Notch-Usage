import Foundation

public struct HTTPResponse: Sendable, Equatable {
    public let status: Int
    /// Clés en minuscules.
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String], body: Data) {
        self.status = status
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        self.body = body
    }

    public func header(_ name: String) -> String? { headers[name.lowercased()] }

    var isHTML: Bool { header("content-type")?.lowercased().contains("text/html") == true }
    var isChallenge: Bool { header("cf-mitigated")?.lowercased() == "challenge" }
    var retryAfter: Duration? {
        guard let raw = header("retry-after"), let s = Double(raw.trimmingCharacters(in: .whitespaces)), s > 0 else { return nil }
        return .seconds(s)
    }
}

public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

/// Redirections : même hôte et HTTPS seulement. Les requêtes portent le jeton ou le cookie de session, et
/// URLSession recopie l'en-tête `Cookie` vers la cible ; les suivre ailleurs les enverrait hors des hôtes
/// d'Anthropic (constitution, principe I). Refusée, la redirection ressort comme une réponse 3xx ordinaire.
final class RedirectPolicy: NSObject, URLSessionTaskDelegate {
    static func allows(from original: URL?, to target: URL?) -> Bool {
        guard let from = original?.host?.lowercased(), let to = target?.host?.lowercased() else { return false }
        return from == to && target?.scheme?.lowercased() == "https"
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(Self.allows(from: task.originalRequest?.url, to: request.url) ? request : nil)
    }
}

/// Implémentation URLSession : session dédiée, attend la connectivité, timeout 15 s.
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: RedirectPolicy(), delegateQueue: nil)
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let k = k as? String, let v = v as? String { headers[k] = v }
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
