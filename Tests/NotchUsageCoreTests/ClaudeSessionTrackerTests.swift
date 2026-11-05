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
}
