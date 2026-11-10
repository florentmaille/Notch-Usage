import Foundation

/// Niveau d'une limite d'après les seuils de repli (`AlertEvaluator.level`).
public enum AlertLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case none
    case warning
    case critical

    public static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
