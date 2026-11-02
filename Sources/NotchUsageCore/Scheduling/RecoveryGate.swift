import Foundation

/// Limite les reprises de jeton à une par intervalle : sans elle, une reprise suivie d'un échec
/// immédiat relance la reprise en boucle (lectures Trousseau, dialogues, requêtes).
public struct RecoveryGate: Sendable {
    public let minimumInterval: TimeInterval
    private var lastAttempt: Date?

    public init(minimumInterval: TimeInterval = 60) {
        self.minimumInterval = minimumInterval
    }

    public mutating func allow(at now: Date) -> Bool {
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < minimumInterval { return false }
        lastAttempt = now
        return true
    }
}
