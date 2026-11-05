import Foundation

/// Entrées de l'app dans `~/.claude/settings.json` (017, contrat hooks.md). Travaille sur les octets du fichier,
/// sans schéma : tout ce qui n'est pas à nous est réécrit tel quel (à l'ordre des clés près, trié). Le marqueur de
/// propriété est le chemin du script ; `remove(install(x)) == encode(x)`.
public enum ClaudeHooksInstaller {
    public enum Status: Sendable, Equatable { case absent, installed, partial, unreadable }
    public enum Failure: Error, Equatable { case unreadable }

    /// Dans l'ordre du contrat ; `SessionStart` en dernier (facultatif pour le signal).
    public static let events = ["PermissionRequest", "PostToolUse", "PostToolUseFailure", "Stop", "UserPromptSubmit", "SessionEnd", "SessionStart"]
    public static let timeout = 5

    public static func install(into data: Data, scriptPath: String) throws -> Data {
        var root = try parse(data)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            if !groups.contains(where: { owns($0, scriptPath: scriptPath) }) {
                groups.append(["matcher": "", "hooks": [["type": "command", "command": scriptPath, "timeout": timeout]]])
            }
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try encode(root)
    }

    public static func remove(from data: Data, scriptPath: String) throws -> Data {
        var root = try parse(data)
        if var hooks = root["hooks"] as? [String: Any] {
            for (event, value) in hooks {
                guard let groups = value as? [[String: Any]] else { continue }
                let kept = groups.filter { !owns($0, scriptPath: scriptPath) }
                if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
            }
            root["hooks"] = hooks.isEmpty ? nil : hooks
        }
        return try encode(root)
    }

    public static func status(of data: Data, scriptPath: String) -> Status {
        guard let root = try? parse(data) else { return .unreadable }
        let hooks = root["hooks"] as? [String: Any] ?? [:]
        let present = events.filter { event in
            (hooks[event] as? [[String: Any]])?.contains { owns($0, scriptPath: scriptPath) } == true
        }.count
        switch present {
        case 0: return .absent
        case events.count: return .installed
        default: return .partial
        }
    }

    /// Un groupe est à nous si l'un de ses hooks appelle notre script.
    public static func owns(_ group: [String: Any], scriptPath: String) -> Bool {
        (group["hooks"] as? [[String: Any]])?.contains { $0["command"] as? String == scriptPath } == true
    }

    static func parse(_ data: Data) throws -> [String: Any] {
        if data.isEmpty || String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else { throw Failure.unreadable }
        return root
    }

    /// Lisible et stable : clés triées, indentation, slashes non échappés, retour à la ligne final.
    static func encode(_ root: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(0x0A)
        return data
    }
}
