import Foundation

/// Décide du délai avant la prochaine requête (R4).
public struct RefreshPolicy: Sendable, Equatable {
    public let settings: RefreshSettings

    public init(settings: RefreshSettings) { self.settings = settings }

    public func delayAfterSuccess() -> Duration { settings.interval }

    /// `nil` ⇒ erreur terminale, on arrête de planifier.
    public func delay(afterFailure error: FetchError, previous: Duration) -> Duration? {
        if error.isTerminal { return nil }
        if case .rateLimited(let retryAfter?) = error {
            return RefreshSettings.clamp(retryAfter)
        }
        return RefreshSettings.clamp(previous * 2)
    }
}
