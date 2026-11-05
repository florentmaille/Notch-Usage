import Foundation

/// Textes des sessions Claude en attente (017), injectés par l'app comme `CompactStrip.Strings`.
public struct ClaudeStrings: Sendable {
    /// Mot de l'oreille droite à l'arrivée : « Approval », « Question », « Done ».
    public var arrival: @Sendable (ClaudeWaitingKind) -> String
    /// Ligne du panneau : « approval needed », « question pending », « finished ».
    public var rowLabel: @Sendable (ClaudeWaitingKind) -> String
    /// Début de l'annonce VoiceOver, deux-points et espace compris : « 2 Claude sessions are waiting: ».
    public var waitingAnnouncement: @Sendable (Int) -> String
    /// Ce qu'une session attend, dans l'annonce : « an approval », « a question », « finished ».
    public var kindAnnouncement: @Sendable (ClaudeWaitingKind) -> String
    /// Nom de repli d'une session sans titre ni dossier lisible.
    public var sessionFallback: String

    public init(arrival: @escaping @Sendable (ClaudeWaitingKind) -> String, rowLabel: @escaping @Sendable (ClaudeWaitingKind) -> String,
                waitingAnnouncement: @escaping @Sendable (Int) -> String, kindAnnouncement: @escaping @Sendable (ClaudeWaitingKind) -> String,
                sessionFallback: String) {
        self.arrival = arrival
        self.rowLabel = rowLabel
        self.waitingAnnouncement = waitingAnnouncement
        self.kindAnnouncement = kindAnnouncement
        self.sessionFallback = sessionFallback
    }

    public static let english = ClaudeStrings(
        arrival: { switch $0 { case .approval: "Approval"; case .question: "Question"; case .done: "Done" } },
        rowLabel: { switch $0 { case .approval: "approval needed"; case .question: "question pending"; case .done: "finished" } },
        waitingAnnouncement: { $0 == 1 ? "1 Claude session is waiting: " : "\($0) Claude sessions are waiting: " },
        kindAnnouncement: { switch $0 { case .approval: "an approval"; case .question: "a question"; case .done: "finished" } },
        sessionFallback: "Session")
}

/// Formats de l'attention Claude (017) : libellé d'arrivée, compteur, durée écoulée.
public enum AttentionFormat {
    /// Le mot reste affiché ce temps après l'arrivée, puis le glyphe seul.
    public static let arrivalDuration: TimeInterval = 4

    public static func showsArrival(arrivedAt: Date, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(arrivedAt)
        return elapsed >= 0 && elapsed < arrivalDuration
    }

    /// Rien sous 2 sessions, « 9+ » à partir de 10.
    public static func count(_ n: Int) -> String {
        if n < 2 { return "" }
        return n >= 10 ? "9+" : "\(n)"
    }

    /// Durée depuis l'événement : « 45 s », « 2 min », « 1h 10m » / « 1 h 10 ».
    public static func since(_ from: Date, now: Date, language: InterfaceLanguage) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(from)))
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let (h, m) = (minutes / 60, minutes % 60)
        switch language {
        case .english: return m == 0 ? "\(h)h" : "\(h)h \(String(format: "%02d", m))m"
        case .french: return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
        }
    }
}
