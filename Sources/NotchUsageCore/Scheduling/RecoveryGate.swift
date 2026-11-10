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
        // Écart négatif : l'horloge a reculé, la dernière tentative ne compte plus.
        if let lastAttempt, (0..<minimumInterval).contains(now.timeIntervalSince(lastAttempt)) { return false }
        lastAttempt = now
        return true
    }
}
