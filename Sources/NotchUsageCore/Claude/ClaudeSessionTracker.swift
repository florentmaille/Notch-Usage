import Foundation

/// Ce qu'une session attend de l'utilisateur (017). L'ordre est l'urgence : approbation, question, puis terminé.
public enum ClaudeWaitingKind: Int, Sendable, Comparable, CaseIterable {
    case approval, question, done

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    /// Approbation et question bloquent la session ; « terminé » informe.
    public var isBlocking: Bool { self != .done }
}

/// Une session Claude Code connue par ses événements (017, data-model.md).
public struct ClaudeSession: Sendable, Equatable, Identifiable {
    public struct Waiting: Sendable, Equatable {
        public let kind: ClaudeWaitingKind
        public let since: Date
        public let toolName: String?
        public let promptID: String?

        public init(kind: ClaudeWaitingKind, since: Date, toolName: String?, promptID: String?) {
            self.kind = kind
            self.since = since
            self.toolName = toolName
            self.promptID = promptID
        }
    }

    public let id: String
    public var cwd: String
    /// Titre transmis par l'app Claude avec le prompt ; absent en CLI.
    public var title: String?
    public var originPID: Int32?
    /// Identifiant de bundle de l'application d'où vient la session, résolu par l'app.
    public var originApp: String?
    public var waiting: Waiting?
    public var lastEventAt: Date

    /// Titre, sinon dernier composant du dossier, sinon « Session » + 4 caractères de l'identifiant (R8).
    public func displayName(fallback: String) -> String {
        if let title, !title.isEmpty { return title }
        let folder = URL(fileURLWithPath: cwd).lastPathComponent
        if !folder.isEmpty, folder != "/", !cwd.isEmpty { return folder }
        return "\(fallback) \(id.prefix(4))"
    }
}

/// État des sessions suivies, valeur immuable réduite événement par événement.
public struct ClaudeSessionTracker: Sendable, Equatable {
    /// Sans processus connu, une session disparaît après ce délai sans événement.
    public static let expiry: TimeInterval = 8 * 3600

    public private(set) var sessions: [String: ClaudeSession]

    public init() { sessions = [:] }

    public var isEmpty: Bool { sessions.isEmpty }

    public func reduce(_ e: ClaudeHookEvent) -> Self {
        guard e.kind != .other else { return self }
        var copy = self
        if e.kind == .sessionEnd {
            copy.sessions[e.sessionID] = nil
            return copy
        }
        var s = sessions[e.sessionID] ?? ClaudeSession(id: e.sessionID, cwd: e.cwd, title: nil, originPID: nil, originApp: nil,
                                                       waiting: nil, lastEventAt: e.receivedAt)
        if !e.cwd.isEmpty { s.cwd = e.cwd }
        if let pid = e.pid { s.originPID = pid }
        if let title = e.sessionTitle, !title.isEmpty { s.title = title }
        s.lastEventAt = e.receivedAt
        switch e.kind {
        case .permissionRequest:
            s.waiting = .init(kind: e.isQuestion ? .question : .approval, since: e.receivedAt, toolName: e.toolName, promptID: e.promptID)
        case .stop:
            s.waiting = .init(kind: .done, since: e.receivedAt, toolName: nil, promptID: e.promptID)
        case .postToolUse, .postToolUseFailure:
            if let w = s.waiting, w.kind.isBlocking, w.toolName == e.toolName { s.waiting = nil }
        case .userPromptSubmit:
            s.waiting = nil
        case .sessionStart, .sessionEnd, .other:
            break
        }
        copy.sessions[e.sessionID] = s
        return copy
    }

    public func apply(_ events: [ClaudeHookEvent]) -> Self {
        events.reduce(self) { $0.reduce($1) }
    }

    /// Retire les sessions dont le processus n'existe plus et, sans processus connu, celles sans événement depuis 8 h.
    public func expire(now: Date, alive: (Int32) -> Bool) -> Self {
        var copy = self
        for (id, s) in sessions {
            if let pid = s.originPID {
                if !alive(pid) { copy.sessions[id] = nil }
            } else if now.timeIntervalSince(s.lastEventAt) > Self.expiry {
                copy.sessions[id] = nil
            }
        }
        return copy
    }

    /// Clic sur l'île : les « terminé » s'effacent, les attentes bloquantes restent.
    public func clearDone() -> Self {
        var copy = self
        for (id, s) in sessions where s.waiting?.kind == .done {
            copy.sessions[id]?.waiting = nil
        }
        return copy
    }

    public func settingOrigin(app: String?, for id: String) -> Self {
        var copy = self
        copy.sessions[id]?.originApp = app
        return copy
    }

    /// Sessions en attente : approbations, questions, puis terminées ; dans chaque groupe la plus ancienne d'abord.
    public var waiting: [ClaudeSession] {
        sessions.values.filter { $0.waiting != nil }.sorted { a, b in
            let (wa, wb) = (a.waiting!, b.waiting!)
            if wa.kind != wb.kind { return wa.kind < wb.kind }
            if wa.since != wb.since { return wa.since < wb.since }
            return a.id < b.id
        }
    }

    /// Résumé pour l'île : cas le plus pressant, nombre, dernière arrivée, et la liste pour VoiceOver.
    public func attention(now: Date) -> NotchSignal.Attention? {
        let list = waiting
        guard let first = list.first else { return nil }
        return NotchSignal.Attention(kind: first.waiting!.kind, count: list.count,
                                     arrivedAt: list.map { $0.waiting!.since }.max() ?? now,
                                     entries: list.map { .init(name: $0.displayName(fallback: "Session"), kind: $0.waiting!.kind) })
    }
}
