import Foundation
import Testing
@testable import NotchUsageCore

/// Réduction des événements en sessions suivies (017, data-model.md : table des transitions).
@Suite("ClaudeSessionTracker (017)")
struct ClaudeSessionTrackerTests {
    let t0 = Date.iso("2026-11-05T17:00:00Z")

    func event(_ kind: ClaudeHookEvent.Kind, session: String = "s1", cwd: String = "/Users/f/Projects/Notch-Usage",
               title: String? = nil, tool: String? = nil, prompt: String? = "p1", pid: Int32? = 100, at: TimeInterval = 0) -> ClaudeHookEvent {
        ClaudeHookEvent(kind: kind, sessionID: session, cwd: cwd, sessionTitle: title, toolName: tool, promptID: prompt, pid: pid,
                        receivedAt: t0.addingTimeInterval(at))
    }

    var approval: ClaudeHookEvent { event(.permissionRequest, tool: "Bash") }
    var question: ClaudeHookEvent { event(.permissionRequest, tool: ClaudeHookEvent.questionTool) }

    // MARK: Transitions

    @Test func permissionRequestCreatesAnApprovalOrAQuestion() {
        let a = ClaudeSessionTracker().reduce(approval)
        #expect(a.sessions["s1"]?.waiting == .init(kind: .approval, since: t0, toolName: "Bash", promptID: "p1"))
        let q = ClaudeSessionTracker().reduce(question)
        #expect(q.sessions["s1"]?.waiting?.kind == .question)
        #expect(a.sessions["s1"]?.originPID == 100 && a.sessions["s1"]?.cwd == "/Users/f/Projects/Notch-Usage")
    }

    @Test func stopMarksTheSessionDone() {
        let t = ClaudeSessionTracker().reduce(event(.stop, at: 5))
        #expect(t.sessions["s1"]?.waiting == .init(kind: .done, since: t0.addingTimeInterval(5), toolName: nil, promptID: "p1"))
    }

    @Test func postToolUseClearsTheMatchingApproval() {
        var t = ClaudeSessionTracker().reduce(approval)
        t = t.reduce(event(.postToolUse, tool: "Edit", at: 1))      // autre outil : l'approbation reste
        #expect(t.sessions["s1"]?.waiting?.kind == .approval)
        t = t.reduce(event(.postToolUseFailure, tool: "Bash", at: 2))
        #expect(t.sessions["s1"]?.waiting == nil)
        var q = ClaudeSessionTracker().reduce(question)
        q = q.reduce(event(.postToolUse, tool: ClaudeHookEvent.questionTool, at: 1))
        #expect(q.sessions["s1"]?.waiting == nil)
    }

    @Test func userPromptSubmitClearsAndKeepsTheTitle() {
        var t = ClaudeSessionTracker().reduce(event(.stop))
        t = t.reduce(event(.userPromptSubmit, title: "Limites Fable", at: 3))
        #expect(t.sessions["s1"]?.waiting == nil && t.sessions["s1"]?.title == "Limites Fable")
        t = t.reduce(event(.userPromptSubmit, title: nil, at: 4))   // sans titre : l'ancien reste
        #expect(t.sessions["s1"]?.title == "Limites Fable")
        t = t.reduce(event(.userPromptSubmit, title: "", at: 5))    // vide : idem
        #expect(t.sessions["s1"]?.title == "Limites Fable")
    }

    @Test func sessionEndRemovesTheSessionAndSessionStartCreatesItIdle() {
        var t = ClaudeSessionTracker().reduce(event(.sessionStart, at: -10))
        #expect(t.sessions["s1"]?.waiting == nil && t.sessions.count == 1)
        t = t.reduce(approval).reduce(event(.sessionEnd, at: 9))
        #expect(t.sessions["s1"] == nil && t.isEmpty)
    }

    @Test func otherEventsAreIgnored() {
        let t = ClaudeSessionTracker().reduce(event(.other))
        #expect(t.isEmpty)
    }

    @Test func aNewArrivalReplacesTheWaitAndRestartsSince() {
        var t = ClaudeSessionTracker().reduce(question)
        t = t.reduce(event(.permissionRequest, tool: "Bash", prompt: "p2", at: 2))
        #expect(t.sessions["s1"]?.waiting == .init(kind: .approval, since: t0.addingTimeInterval(2), toolName: "Bash", promptID: "p2"))
    }

    // MARK: Expiration, effacement

    @Test func expireRemovesDeadProcessesAndStaleSessions() {
        var t = ClaudeSessionTracker().reduce(approval)
            .reduce(event(.permissionRequest, session: "s2", tool: "Bash", pid: 200))
            .reduce(event(.permissionRequest, session: "s3", tool: "Bash", pid: nil))
        t = t.expire(now: t0.addingTimeInterval(60), alive: { $0 != 200 })
        #expect(t.sessions["s1"] != nil && t.sessions["s2"] == nil && t.sessions["s3"] != nil)
        // Sans pid, 8 h sans événement suffisent ; avec un pid vivant, la session reste.
        t = t.expire(now: t0.addingTimeInterval(ClaudeSessionTracker.expiry + 1), alive: { _ in true })
        #expect(t.sessions["s1"] != nil && t.sessions["s3"] == nil)
    }

    /// Session tuée sans `SessionEnd`, pid réattribué à un autre processus : démarré après le dernier événement de
    /// la session, il ne la fait plus passer pour vivante. Le processus de la session, démarré avant, la garde.
    @Test func expireRemovesASessionWhosePidWasReused() {
        let t = ClaudeSessionTracker().reduce(approval)
            .reduce(event(.permissionRequest, session: "s2", tool: "Bash", pid: 200, at: 30))
        let starts: [Int32: Date] = [100: t0.addingTimeInterval(3600), 200: t0.addingTimeInterval(-600)]
        let kept = t.expire(now: t0.addingTimeInterval(7200), alive: { _ in true }, startedAt: { starts[$0] })
        #expect(Set(kept.sessions.keys) == ["s2"])
        // Démarrage inconnu, ou dans la marge de l'heure de l'événement (seconde entière) : la session reste.
        #expect(t.expire(now: t0, alive: { _ in true }, startedAt: { _ in nil }).sessions.count == 2)
        #expect(t.expire(now: t0, alive: { _ in true }, startedAt: { _ in self.t0.addingTimeInterval(ClaudeSessionTracker.reuseMargin) }).sessions["s1"] != nil)
        #expect(Set(t.restored(now: t0.addingTimeInterval(7200), bootedAt: .distantPast, alive: { _ in true }, startedAt: { starts[$0] }).sessions.keys) == ["s2"])
    }

    @Test func clearDoneKeepsBlockingWaits() {
        let t = ClaudeSessionTracker().reduce(event(.stop)).reduce(event(.permissionRequest, session: "s2", tool: "Bash")).clearDone()
        #expect(t.sessions["s1"]?.waiting == nil && t.sessions["s2"]?.waiting?.kind == .approval)
    }

    // MARK: Ordre, noms, attention

    @Test func waitingIsSortedByUrgencyThenAge() {
        let t = ClaudeSessionTracker()
            .reduce(event(.stop, session: "done-old", at: 0))
            .reduce(event(.permissionRequest, session: "approval-new", tool: "Bash", at: 30))
            .reduce(event(.permissionRequest, session: "question", tool: ClaudeHookEvent.questionTool, at: 10))
            .reduce(event(.permissionRequest, session: "approval-old", tool: "Bash", at: 20))
            .reduce(event(.sessionStart, session: "idle", at: 40))
        #expect(t.waiting.map(\.id) == ["approval-old", "approval-new", "question", "done-old"])
    }

    @Test func displayNamePrefersTheTitleThenTheFolder() {
        let titled = ClaudeSessionTracker().reduce(event(.userPromptSubmit, title: "Limites Fable en mode replié")).sessions["s1"]!
        #expect(titled.displayName(fallback: "Session") == "Limites Fable en mode replié")
        let folder = ClaudeSessionTracker().reduce(approval).sessions["s1"]!
        #expect(folder.displayName(fallback: "Session") == "Notch-Usage")
        let bare = ClaudeSessionTracker().reduce(event(.permissionRequest, session: "abcdef12-3456", cwd: "/", tool: "Bash")).sessions["abcdef12-3456"]!
        #expect(bare.displayName(fallback: "Session") == "Session abcd")
    }

    @Test func aChatReplyFromTheMCPSpikeIsADoneSessionNamedByItsTitle() throws {
        // Ligne écrite par `spike-mcp/notch_chat_mcp.py` : pas de dossier, un titre donné par le modèle.
        let line = #"{"ppid": 7615, "ts": 1793898528, "event": {"hook_event_name": "Stop", "session_id": "chat-recette-de-crêpes", "cwd": "", "session_title": "Recette de crêpes", "source": "claude-chat-mcp"}}"#
        let e = try #require(ClaudeHookEvent.decode(line: Substring(line), readAt: t0))
        let session = try #require(ClaudeSessionTracker().reduce(e).sessions["chat-recette-de-crêpes"])
        #expect(session.waiting?.kind == .done && session.originPID == 7615)
        #expect(session.displayName(fallback: "Session") == "Recette de crêpes")
    }

    @Test func attentionSummarisesTheMostPressingCaseAndTheCount() {
        #expect(ClaudeSessionTracker().attention(now: t0) == nil)
        let idle = ClaudeSessionTracker().reduce(event(.sessionStart))
        #expect(idle.attention(now: t0) == nil)
        let t = ClaudeSessionTracker()
            .reduce(event(.stop, session: "d", at: 0))
            .reduce(event(.permissionRequest, session: "q", tool: ClaudeHookEvent.questionTool, at: 10))
            .reduce(event(.permissionRequest, session: "a", tool: "Bash", at: 20))
        let attention = t.attention(now: t0.addingTimeInterval(21))
        #expect(attention?.kind == .approval && attention?.count == 3)
        #expect(attention?.arrivedAt == t0.addingTimeInterval(20))
        #expect(attention?.entries.map(\.kind) == [.approval, .question, .done])
        let justDone = ClaudeSessionTracker().reduce(event(.stop)).attention(now: t0)
        #expect(justDone?.kind == .done && justDone?.count == 1)
    }

    // MARK: Conservation d'un lancement à l'autre

    /// Les sessions suivies sont écrites sur disque : une attente déjà lue avant un redémarrage de l'app réapparaît
    /// au lancement, au lieu d'attendre le prochain événement de la session.
    @Test func trackerRoundTripsThroughJSON() throws {
        var t = ClaudeSessionTracker().reduce(approval)
        t = t.reduce(event(.stop, session: "s2", cwd: "/tmp/x", title: "Titre", pid: 200, at: 3))
        t = t.settingOrigin(app: "com.apple.Terminal", for: "s1")
        let decoded = try JSONDecoder().decode(ClaudeSessionTracker.self, from: JSONEncoder().encode(t))
        #expect(decoded == t)
        #expect(decoded.waiting.map(\.id) == ["s1", "s2"])
        #expect(decoded.sessions["s1"]?.originApp == "com.apple.Terminal" && decoded.sessions["s2"]?.title == "Titre")
    }

    /// Au lancement, une session ne survit ni à la fin de son processus, ni à un redémarrage du Mac : son pid a pu
    /// être réattribué à un autre processus, qui la ferait passer pour vivante.
    @Test func restoreDropsDeadAndPreBootSessions() {
        var t = ClaudeSessionTracker().reduce(approval)                                           // s1, pid 100, à t0
        t = t.reduce(event(.permissionRequest, session: "s2", tool: "Bash", pid: 200, at: 60))
        t = t.reduce(event(.stop, session: "s3", pid: 300, at: 120))
        let now = t0.addingTimeInterval(600), longAgo = t0.addingTimeInterval(-3600)
        #expect(Set(t.restored(now: now, bootedAt: longAgo, alive: { _ in true }).sessions.keys) == ["s1", "s2", "s3"])
        #expect(Set(t.restored(now: now, bootedAt: longAgo, alive: { $0 != 200 }).sessions.keys) == ["s1", "s3"])
        // Mac redémarré à t0 + 90 s : les sessions d'avant disparaissent même si leur pid répond.
        #expect(Set(t.restored(now: now, bootedAt: t0.addingTimeInterval(90), alive: { _ in true }).sessions.keys) == ["s3"])
        // Les attentes restaurées gardent leur nature et leur ancienneté.
        let kept = t.restored(now: now, bootedAt: longAgo, alive: { _ in true })
        #expect(kept.sessions["s1"]?.waiting == .init(kind: .approval, since: t0, toolName: "Bash", promptID: "p1"))
    }
}
