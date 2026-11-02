import Foundation

public enum FetchError: Error, Sendable, Equatable {
    case unauthorized
    case rateLimited(retryAfter: Duration?)
    case server(Int)
    case network(URLError.Code)
    case challenge
    case emptyBody
    case malformed
    case credentialsUnavailable
    case unsupported

    /// Erreur qui arrête la boucle de rafraîchissement.
    public var isTerminal: Bool {
        switch self {
        case .unauthorized, .credentialsUnavailable, .unsupported: return true
        default: return false
        }
    }
}

public enum ParseError: Error, Sendable, Equatable {
    case invalidJSON
    case noLimits
}

public enum CredentialError: Error, Sendable, Equatable {
    case missingOAuthSection
    case invalidJSON
}

/// État courant du rafraîchissement, non persisté.
public enum FetchState: Sendable, Equatable {
    case idle(UsageSnapshot?)
    case loading(previous: UsageSnapshot?)
    case failed(FetchError, previous: UsageSnapshot?)
    case reauthRequired(previous: UsageSnapshot?)
    case unsupported

    /// Dernier relevé connu, quel que soit l'état.
    public var snapshot: UsageSnapshot? {
        switch self {
        case .idle(let s), .loading(let s), .failed(_, let s), .reauthRequired(let s): return s
        case .unsupported: return nil
        }
    }

    /// État à afficher quand `next` arrive. Une nouvelle tentative après un échec garde l'échec
    /// (et son bandeau) jusqu'à son résultat : hors ligne, la tentative dure jusqu'au timeout.
    public func displayed(next: FetchState) -> FetchState {
        if case .failed = self, case .loading = next { return self }
        return next
    }
}
