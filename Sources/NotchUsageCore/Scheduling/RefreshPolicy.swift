import Foundation

/// Décide du délai avant la prochaine requête (R4).
public struct RefreshPolicy: Sendable, Equatable {
    public let settings: RefreshSettings

    public init(settings: RefreshSettings) { self.settings = settings }

    public func delayAfterSuccess() -> Duration { settings.interval }

    /// Abonnement sans limite exploitable : la réponse peut être passagère, ou l'abonnement changer. Un essai par
    /// heure, hors des bornes de l'intervalle réglable.
    public static let unsupportedRetry: Duration = .seconds(3600)

    /// `nil` ⇒ erreur terminale, on arrête de planifier.
    public func delay(afterFailure error: FetchError, previous: Duration) -> Duration? {
        if error.isTerminal { return nil }
        if error == .unsupported { return Self.unsupportedRetry }
        if case .rateLimited(let retryAfter?) = error {
            return RefreshSettings.clamp(retryAfter)
        }
        return RefreshSettings.clamp(previous * 2)
    }
}
