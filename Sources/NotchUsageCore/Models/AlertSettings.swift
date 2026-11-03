import Foundation

/// Seuils de repli (FR-017, FR-018) et notifications (008). Invariant : 1 ≤ warning < critical ≤ 100.
public struct AlertSettings: Codable, Sendable, Equatable {
    /// Les seuils colorent le liseré et le panneau quand aucune prévision n'existe.
    public var enabled: Bool
    /// Notification système à l'entrée en palier imminent, au seuil critique et à l'épuisement.
    public var notifications: Bool
    public private(set) var warningThreshold: Int
    public private(set) var criticalThreshold: Int

    public init(enabled: Bool = true, notifications: Bool = true, warningThreshold: Int = 80, criticalThreshold: Int = 95) {
        self.enabled = enabled
        self.notifications = notifications
        let (w, c) = Self.normalize(warning: warningThreshold, critical: criticalThreshold)
        self.warningThreshold = w
        self.criticalThreshold = c
    }

    private enum CodingKeys: String, CodingKey { case enabled, notifications, warningThreshold, criticalThreshold }

    /// Réglages enregistrés avant la 008 : pas de clé `notifications`, activées par défaut.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(enabled: try c.decode(Bool.self, forKey: .enabled),
                  notifications: try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? true,
                  warningThreshold: try c.decode(Int.self, forKey: .warningThreshold),
                  criticalThreshold: try c.decode(Int.self, forKey: .criticalThreshold))
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
