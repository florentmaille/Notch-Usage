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

    /// Erreur qui arrête la boucle de rafraîchissement : seule une reconnexion la relance. `unsupported` n'en est
    /// pas une, la boucle réessaie à cadence lente (`RefreshPolicy.unsupportedRetry`).
    public var isTerminal: Bool {
        switch self {
        case .unauthorized, .credentialsUnavailable: return true
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
    /// (et son bandeau) jusqu'à son résultat : hors ligne, la tentative dure jusqu'au timeout. De même pour
    /// l'essai horaire d'un plan non pris en charge.
    public func displayed(next: FetchState) -> FetchState {
        guard case .loading = next else { return next }
        switch self {
        case .failed, .unsupported: return self
        default: return next
        }
    }
}
