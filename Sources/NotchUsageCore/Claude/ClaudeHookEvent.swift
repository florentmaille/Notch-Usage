import Foundation

/// Un événement de Claude Code relayé par le script de hook (017, contrat hooks.md). Une ligne du fichier :
/// `{"ppid": …, "ts": …, "event": {payload du hook}}`. Seuls le type, la session, le dossier, le titre, l'outil
/// et le prompt sont gardés : le texte des conversations (`prompt`, `last_assistant_message`, `tool_input`)
/// n'est jamais décodé.
public struct ClaudeHookEvent: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case permissionRequest = "PermissionRequest"
        case postToolUse = "PostToolUse"
        case postToolUseFailure = "PostToolUseFailure"
        case stop = "Stop"
        case userPromptSubmit = "UserPromptSubmit"
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case other
    }

    /// Outil par lequel Claude pose une question : une demande de permission sur lui est une question, pas une approbation.
    public static let questionTool = "AskUserQuestion"

    public let kind: Kind
    public let sessionID: String
    public let cwd: String
    public let sessionTitle: String?
    public let toolName: String?
    public let promptID: String?
    /// Processus `claude` (ou son shell) qui a lancé le hook : vivacité et application d'origine.
    public let pid: Int32?
    public let receivedAt: Date

    public init(kind: Kind, sessionID: String, cwd: String, sessionTitle: String?, toolName: String?, promptID: String?,
                pid: Int32?, receivedAt: Date) {
        self.kind = kind
        self.sessionID = sessionID
        self.cwd = cwd
        self.sessionTitle = sessionTitle
        self.toolName = toolName
        self.promptID = promptID
        self.pid = pid
        self.receivedAt = receivedAt
    }

    public var isQuestion: Bool { kind == .permissionRequest && toolName == Self.questionTool }

    /// Décode une ligne ; `nil` pour une ligne vide, illisible ou sans `session_id`. Sans enveloppe (ligne écrite à la
    /// main), le payload nu est accepté : pas de pid, heure de lecture.
    public static func decode(line: Substring, readAt: Date) -> ClaudeHookEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return make(envelope.event, pid: envelope.ppid, at: envelope.ts.map { Date(timeIntervalSince1970: $0) } ?? readAt)
        }
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return make(payload, pid: nil, at: readAt)
        }
        return nil
    }

    private static func make(_ p: Payload, pid: Int32?, at: Date) -> ClaudeHookEvent? {
        guard let session = p.sessionID, !session.isEmpty else { return nil }
        return ClaudeHookEvent(kind: p.hookEventName.flatMap(Kind.init(rawValue:)) ?? .other, sessionID: session, cwd: p.cwd ?? "",
                               sessionTitle: p.sessionTitle, toolName: p.toolName, promptID: p.promptID, pid: pid, receivedAt: at)
    }

    private struct Envelope: Decodable {
        let ppid: Int32?
        let ts: Double?
        let event: Payload
    }

    private struct Payload: Decodable {
        let hookEventName: String?
        let sessionID: String?
        let cwd: String?
        let sessionTitle: String?
        let toolName: String?
        let promptID: String?

        enum CodingKeys: String, CodingKey {
            case hookEventName = "hook_event_name", sessionID = "session_id", cwd, sessionTitle = "session_title"
            case toolName = "tool_name", promptID = "prompt_id"
        }
    }
}
