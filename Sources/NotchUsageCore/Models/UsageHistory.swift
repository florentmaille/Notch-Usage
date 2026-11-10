import Foundation

/// Un point de l'historique de consommation, par limite (feature 003).
public struct Reading: Codable, Sendable, Equatable {
    public let limitID: String
    public let at: Date
    public let utilization: Double
    public let resetsAt: Date?

    public init(limitID: String, at: Date, utilization: Double, resetsAt: Date?) {
        self.limitID = limitID
        self.at = at
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    /// Même période si les heures de reset diffèrent de moins de 10 min (même règle que le registre d'alertes).
    func isSamePeriod(as other: Date?) -> Bool {
        switch (resetsAt, other) {
        case (nil, nil): return true
        case let (a?, b?): return abs(a.timeIntervalSince(b)) < 600
        default: return false
        }
    }
}

/// Relevés des deux dernières heures, source de la prévision. Persisté avec le cache de relevés.
public struct UsageHistory: Codable, Sendable, Equatable {
    public static let retention: TimeInterval = 2 * 3600

    public private(set) var readings: [Reading]

    public init(readings: [Reading] = []) {
        self.readings = readings.sorted { $0.at < $1.at }
    }

    /// Un relevé par limite ; pour chaque limite, les relevés d'une autre période sont écartés ; troncature à deux heures.
    /// Le même relevé ajouté deux fois ne compte qu'une fois : le cache est republié à chaque lancement.
    public func appending(_ snapshot: UsageSnapshot) -> UsageHistory {
        var kept = readings
        for limit in snapshot.limits {
            kept.removeAll {
                $0.limitID == limit.id && (!$0.isSamePeriod(as: limit.resetsAt) || abs($0.at.timeIntervalSince(snapshot.fetchedAt)) < 1)
            }
            kept.append(Reading(limitID: limit.id, at: snapshot.fetchedAt, utilization: limit.utilization, resetsAt: limit.resetsAt))
        }
        let newest = kept.map(\.at).max() ?? snapshot.fetchedAt
        kept.removeAll { $0.at < newest.addingTimeInterval(-Self.retention) }
        return UsageHistory(readings: kept)
    }

    public func readings(for limitID: String) -> [Reading] {
        readings.filter { $0.limitID == limitID }
    }
}
