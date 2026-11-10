import Foundation

/// Une notification par limite, par motif et par période de réinitialisation (008). Valeur pure, en mémoire :
/// un redémarrage peut renvoyer une notification déjà vue, jamais deux dans la même session.
public struct NotificationGate: Sendable, Equatable {
    public enum Reason: String, Sendable, Codable { case imminent, critical, exhausted }

    private struct Key: Hashable, Sendable {
        let limitID: String
        let reason: Reason
    }

    /// Dernière période signalée, et période inconnue (`resets_at` absent) signalée ou non.
    private struct Fired: Sendable, Equatable {
        var latest: Date?
        var unknown = false
    }

    private var fired: [Key: Fired] = [:]

    public init() {}

    /// Vrai une seule fois par (limite, motif, période) ; `resetsAt` identifie la période. L'API fait varier ses
    /// fractions de seconde d'un relevé à l'autre : une période n'est nouvelle que si elle dépasse la dernière
    /// signalée de `AlertLedger.periodTolerance`. Une période plus ancienne ne se signale jamais.
    public mutating func shouldNotify(limitID: String, reason: Reason, resetsAt: Date?) -> Bool {
        let key = Key(limitID: limitID, reason: reason)
        var entry = fired[key] ?? Fired()
        defer { fired[key] = entry }
        guard let resetsAt else {
            if entry.unknown { return false }
            entry.unknown = true
            return true
        }
        if let latest = entry.latest, resetsAt.timeIntervalSince(latest) < AlertLedger.periodTolerance { return false }
        entry.latest = resetsAt
        return true
    }
}
