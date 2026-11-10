import Foundation

public enum AlertLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case none
    case warning
    case critical

    public static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public struct AlertEvent: Sendable, Equatable {
    public let limitID: String
    public let level: AlertLevel
    public init(limitID: String, level: AlertLevel) {
        self.limitID = limitID
        self.level = level
    }
}

/// Seuils déjà signalés, par limite et par période (FR-019).
public struct AlertLedger: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var periodKey: Date?
        public var firedLevels: Set<AlertLevel>
        public init(periodKey: Date?, firedLevels: Set<AlertLevel> = []) {
            self.periodKey = periodKey
            self.firedLevels = firedLevels
        }

        /// Même période si les heures de reset diffèrent de moins de 10 min : l'API fait varier les
        /// fractions de seconde, alors qu'une nouvelle période décale le reset de 5 h ou 7 j.
        public func isSamePeriod(as resetsAt: Date?) -> Bool {
            switch (periodKey, resetsAt) {
            case (nil, nil): return true
            case let (a?, b?): return abs(a.timeIntervalSince(b)) < AlertLedger.periodTolerance
            default: return false
            }
        }
    }

    /// Écart en dessous duquel deux heures de reset désignent la même période (aussi pour `NotificationGate`).
    public static let periodTolerance: TimeInterval = 600

    public var entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) { self.entries = entries }
}
