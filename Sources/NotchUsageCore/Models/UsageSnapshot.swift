import Foundation

/// L'ensemble des limites obtenues à un instant donné.
public struct UsageSnapshot: Codable, Sendable, Equatable {
    /// Triées dans l'ordre d'affichage.
    public let limits: [UsageLimit]
    public let fetchedAt: Date

    public init(limits: [UsageLimit], fetchedAt: Date) {
        self.limits = limits.sorted(by: UsageLimit.displayOrder)
        self.fetchedAt = fetchedAt
    }

    /// Plus haute utilisation ; égalité → ordre d'affichage.
    public var mostConstraining: UsageLimit? {
        limits.reduce(nil) { best, l in
            guard let best else { return l }
            return l.utilization > best.utilization ? l : best
        }
    }
}
