import Foundation
import Testing
@testable import NotchUsageCore

/// Décodage d'une ligne du fichier d'événements (017, contrat hooks.md) : l'enveloppe du script, puis le
/// payload du hook, dont on ne garde que le type, la session, le dossier, le titre, l'outil et le prompt.
@Suite("ClaudeHookEvent (017)")
struct ClaudeHookEventTests {
    let readAt = Date.iso("2026-11-05T17:00:00Z")

    func decode(_ fixture: String) -> ClaudeHookEvent? {
        let line = Fixture.string(fixture).split(separator: "\n").first ?? ""
        return ClaudeHookEvent.decode(line: line, readAt: readAt)
    }

    @Test func permissionRequestForBashIsAnApproval() throws {
        let e = try #require(decode("claude-hooks-permission-bash.json"))
        #expect(e.kind == .permissionRequest)
        #expect(e.sessionID == "7c508fcf-bbad-478b-8b54-b285a4107998")
        #expect(e.cwd == "/Users/florent/Projects/Notch-Usage")
        #expect(e.toolName == "Bash")
        #expect(e.promptID == "6e91493d-7358-4f50-ade9-6386134ec7b5")
        #expect(e.pid == 9019)
        #expect(e.receivedAt == Date(timeIntervalSince1970: 1_762_360_000))
        #expect(e.sessionTitle == nil)
        #expect(!e.isQuestion)
    }

    @Test func permissionRequestForAskUserQuestionIsAQuestion() throws {
        let e = try #require(decode("claude-hooks-permission-ask.json"))
        #expect(e.kind == .permissionRequest && e.toolName == ClaudeHookEvent.questionTool && e.isQuestion)
    }

    @Test func otherEventsDecodeTheirKind() throws {
        #expect(try #require(decode("claude-hooks-post-tool-use-ask.json")).kind == .postToolUse)
        #expect(try #require(decode("claude-hooks-stop.json")).kind == .stop)
        #expect(try #require(decode("claude-hooks-session-start.json")).kind == .sessionStart)
        #expect(try #require(decode("claude-hooks-session-end.json")).kind == .sessionEnd)
        let prompt = try #require(decode("claude-hooks-user-prompt-submit-title.json"))
        #expect(prompt.kind == .userPromptSubmit && prompt.sessionTitle == "Limites Fable en mode replié")
    }

    @Test func unknownHookNameIsOther() throws {
        #expect(try #require(decode("claude-hooks-notification.json")).kind == .other)
    }

    @Test func unknownFieldsAreIgnoredAndTheTranscriptIsNotKept() throws {
        // `tool_input`, `last_assistant_message`, `prompt`, `transcript_path` : décodés nulle part.
        let e = try #require(decode("claude-hooks-stop.json"))
        #expect(String(describing: e).contains("PR ouverte") == false)
    }

    @Test func linesWithoutSessionOrUnreadableAreDropped() {
        let lines = Fixture.string("claude-hooks-malformed.txt").split(separator: "\n", omittingEmptySubsequences: false)
        #expect(ClaudeHookEvent.decode(line: lines[0], readAt: readAt) == nil)   // sans session_id
        #expect(ClaudeHookEvent.decode(line: lines[1], readAt: readAt) == nil)   // JSON tronqué
        #expect(ClaudeHookEvent.decode(line: "", readAt: readAt) == nil)
        #expect(ClaudeHookEvent.decode(line: "   ", readAt: readAt) == nil)
    }

    @Test func barePayloadWithoutEnvelopeStillDecodes() throws {
        // Ligne écrite sans l'enveloppe du script (ancien script, test à la main) : pid absent, heure de lecture.
        let e = try #require(ClaudeHookEvent.decode(line: #"{"session_id":"s1","cwd":"/p/app","hook_event_name":"Stop"}"#, readAt: readAt))
        #expect(e.kind == .stop && e.pid == nil && e.receivedAt == readAt && e.cwd == "/p/app")
    }

    /// Heure d'enveloppe aberrante (ligne écrite à la main ou abîmée) : l'heure de lecture la remplace.
    @Test func implausibleEnvelopeTimeFallsBackToTheReadTime() {
        let readAt = Date.iso("2026-11-05T18:00:00Z")
        let line = #"{"ppid":4242,"ts":1e300,"event":{"hook_event_name":"Stop","session_id":"abc"}}"#
        let event = ClaudeHookEvent.decode(line: Substring(line), readAt: readAt)
        #expect(event?.receivedAt == readAt && event?.pid == 4242)
        let sane = #"{"ppid":4242,"ts":1762365600,"event":{"hook_event_name":"Stop","session_id":"abc"}}"#
        #expect(ClaudeHookEvent.decode(line: Substring(sane), readAt: readAt)?.receivedAt == Date(timeIntervalSince1970: 1_762_365_600))
    }
}
