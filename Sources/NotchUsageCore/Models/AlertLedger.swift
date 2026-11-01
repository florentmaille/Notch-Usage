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
    }

    public var entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) { self.entries = entries }
}
