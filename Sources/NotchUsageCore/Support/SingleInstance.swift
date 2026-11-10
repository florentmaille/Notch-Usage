import Foundation

/// Une seule instance de l'app : deux copies lancées (zip et Homebrew) dessinent deux îles, doublent la cadence
/// de relevé et se disputent le fil d'événements de Claude Code. La plus récente cède la place.
public enum SingleInstance {
    public struct Process: Sendable, Equatable {
        public let pid: Int32
        public let launchedAt: Date?

        public init(pid: Int32, launchedAt: Date?) {
            self.pid = pid
            self.launchedAt = launchedAt
        }
    }

    /// Vrai si `me` doit s'arrêter : une autre instance a démarré avant (à date égale ou inconnue, le plus petit pid
    /// reste). Les deux côtés tranchent pareil : jamais deux arrêts, même lancées au même instant.
    public static func shouldYield(me: Process, others: [Process]) -> Bool {
        others.contains { other in
            guard other.pid != me.pid else { return false }
            let (mine, theirs) = (me.launchedAt ?? .distantPast, other.launchedAt ?? .distantPast)
            return theirs != mine ? theirs < mine : other.pid < me.pid
        }
    }
}
