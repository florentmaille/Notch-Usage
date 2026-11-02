import Foundation

/// Prévision pour une limite, dérivée de l'historique, jamais persistée (feature 003).
public enum Forecast: Sendable, Equatable {
    case unavailable
    case holdsUntilReset
    case blockAt(Date)

    /// « Tenable » et « blocage prévu » sont les deux natures soumises à l'hystérésis.
    var isBlock: Bool {
        if case .blockAt = self { return true }
        return false
    }
}

/// Hystérésis d'affichage (research R2) : un passage tenable ↔ blocage prévu attend deux relevés concordants ;
/// `unavailable` et l'heure d'un blocage déjà affiché s'appliquent aussitôt.
public struct ForecastDebouncer: Sendable, Equatable {
    public private(set) var displayed: [String: Forecast] = [:]
    private var pending: [String: Forecast] = [:]

    public init() {}

    public mutating func push(_ candidates: [String: Forecast]) -> [String: Forecast] {
        var next: [String: Forecast] = [:]
        var nextPending: [String: Forecast] = [:]
        for (id, candidate) in candidates {
            let current = displayed[id] ?? .unavailable
            switch (current, candidate) {
            case (_, .unavailable), (.unavailable, _):
                next[id] = candidate
            case _ where current.isBlock == candidate.isBlock:
                next[id] = candidate
            case _ where pending[id].map({ $0.isBlock == candidate.isBlock }) == true:
                next[id] = candidate
            default:
                next[id] = current
                nextPending[id] = candidate
            }
        }
        displayed = next
        pending = nextPending
        return next
    }
}
