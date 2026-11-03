import Foundation

/// Une notification par limite, par motif et par période de réinitialisation (008). Valeur pure, en mémoire :
/// un redémarrage peut renvoyer une notification déjà vue, jamais deux dans la même session.
public struct NotificationGate: Sendable, Equatable {
    public enum Reason: String, Sendable, Codable { case imminent, critical, exhausted }

    private struct Key: Hashable, Sendable {
        let limitID: String
        let reason: Reason
        let period: Date?
    }

    private var fired: Set<Key> = []

    public init() {}

    /// Vrai une seule fois par (limite, motif, période) ; `resetsAt` identifie la période.
    public mutating func shouldNotify(limitID: String, reason: Reason, resetsAt: Date?) -> Bool {
        fired.insert(Key(limitID: limitID, reason: reason, period: resetsAt)).inserted
    }
}
