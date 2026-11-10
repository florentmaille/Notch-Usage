import Foundation

/// Un relevé par heure et par limite sur 8 jours (021) : source de la courbe de la semaine. Distinct de `UsageHistory`
/// (2 h, prévision de la fenêtre de 5 h). Persisté localement, effacé avec le reste à la déconnexion.
public struct HourlyHistory: Codable, Sendable, Equatable {
    public static let retention: TimeInterval = 8 * 24 * 3600

    public private(set) var readings: [Reading]

    public init(readings: [Reading] = []) {
        self.readings = readings.sorted { $0.at < $1.at }
    }

    /// Même heure : le relevé remplace le précédent ; une autre période de la limite efface ses anciens relevés.
    public func appending(_ snapshot: UsageSnapshot) -> HourlyHistory {
        var kept = readings
        let hour = Self.hour(of: snapshot.fetchedAt)
        for limit in snapshot.limits {
            kept.removeAll { $0.limitID == limit.id && (!$0.isSamePeriod(as: limit.resetsAt) || Self.hour(of: $0.at) == hour) }
            kept.append(Reading(limitID: limit.id, at: snapshot.fetchedAt, utilization: limit.utilization, resetsAt: limit.resetsAt))
        }
        let newest = kept.map(\.at).max() ?? snapshot.fetchedAt
        kept.removeAll { $0.at < newest.addingTimeInterval(-Self.retention) }
        return HourlyHistory(readings: kept)
    }

    public func readings(for limitID: String) -> [Reading] {
        readings.filter { $0.limitID == limitID }
    }

    private static func hour(of date: Date) -> Int {
        Int((date.timeIntervalSinceReferenceDate / 3600).rounded(.down))
    }
}
