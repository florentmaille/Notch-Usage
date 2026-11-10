import Foundation

/// Deux heures de reset désignent la même période si elles diffèrent de moins de 10 min : l'API fait varier les
/// fractions de seconde d'un relevé à l'autre, alors qu'une nouvelle période décale le reset de 5 h ou 7 j.
enum ResetPeriod {
    static let tolerance: TimeInterval = 600

    static func isSame(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?): return abs(a.timeIntervalSince(b)) < tolerance
        default: return false
        }
    }
}
