import Foundation

/// Seuils d'alerte (FR-017, FR-018). Invariant : 1 ≤ warning < critical ≤ 100.
public struct AlertSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public private(set) var warningThreshold: Int
    public private(set) var criticalThreshold: Int

    public init(enabled: Bool = true, warningThreshold: Int = 80, criticalThreshold: Int = 95) {
        self.enabled = enabled
        let (w, c) = Self.normalize(warning: warningThreshold, critical: criticalThreshold)
        self.warningThreshold = w
        self.criticalThreshold = c
    }

    public mutating func setWarning(_ value: Int) {
        (warningThreshold, criticalThreshold) = Self.normalize(warning: value, critical: max(criticalThreshold, value + 1))
    }

    public mutating func setCritical(_ value: Int) {
        (warningThreshold, criticalThreshold) = Self.normalize(warning: min(warningThreshold, value - 1), critical: value)
    }

    static func normalize(warning: Int, critical: Int) -> (Int, Int) {
        var c = min(100, max(2, critical))
        var w = min(99, max(1, warning))
        if w >= c {
            // Priorité au critique : on abaisse l'avertissement juste en dessous.
            w = max(1, c - 1)
            if w >= c { c = min(100, w + 1) }
        }
        return (w, c)
    }
}
