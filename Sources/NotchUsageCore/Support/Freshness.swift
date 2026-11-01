import Foundation

public enum FreshnessLevel: Sendable, Equatable {
    case fresh
    case aging
    case stale
}

public enum Freshness {
    public static let staleAfter: TimeInterval = 30 * 60

    /// `fresh` < 2 cycles ; `aging` ≥ 2 cycles (FR-010) ; `stale` ≥ 30 min, prioritaire.
    public static func of(_ snapshot: UsageSnapshot, now: Date, interval: Duration) -> FreshnessLevel {
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        if age >= staleAfter { return .stale }
        if age >= 2 * interval.timeInterval { return .aging }
        return .fresh
    }
}
