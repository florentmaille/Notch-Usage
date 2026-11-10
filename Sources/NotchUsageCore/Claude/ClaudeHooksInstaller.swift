import Foundation

/// Entrées de l'app dans `~/.claude/settings.json` (017, contrat hooks.md). Travaille sur les octets du fichier,
/// sans schéma : tout ce qui n'est pas à nous est réécrit tel quel (à l'ordre des clés près, trié). Le marqueur de
/// propriété est la commande qui appelle notre script ; `remove(install(x)) == encode(x)`.
public enum ClaudeHooksInstaller {
    public enum Status: Sendable, Equatable { case absent, installed, partial, unreadable }
    public enum Failure: Error, Equatable { case unreadable }

    /// Dans l'ordre du contrat ; `SessionStart` en dernier (facultatif pour le signal).
    public static let events = ["PermissionRequest", "PostToolUse", "PostToolUseFailure", "Stop", "UserPromptSubmit", "SessionEnd", "SessionStart"]
    public static let timeout = 5

    /// Commande écrite dans le fichier. Claude Code la passe à un shell (`-c`) :
    /// - le chemin est entre apostrophes, il contient une espace (`Application Support`) ;
    /// - script absent (app désinstallée, entrées restées) : rien ne s'exécute, aucune erreur de hook ;
    /// - `exec` remplace le shell de la commande : le `$PPID` du script est le processus qui a lancé le hook, pas
    ///   un shell déjà terminé quand l'app vérifie que la session vit encore.
    public static func command(for scriptPath: String) -> String {
        let quoted = "'" + scriptPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "[ ! -x \(quoted) ] || exec \(quoted)"
    }

    public static func install(into data: Data, scriptPath: String) throws -> Data {
        var root = try parse(data)
        var hooks = try hooksSection(of: root)
        let current = command(for: scriptPath)
        for event in events {
            // Les entrées au chemin brut (0.5.4 à 0.6.1) n'ont jamais pu s'exécuter : elles sont remplacées.
            var groups = strip(try eventGroups(hooks[event]), commands: [scriptPath])
            if !groups.contains(where: { calls($0, commands: [current]) }) {
                groups.append(["matcher": "", "hooks": [["type": "command", "command": current, "timeout": timeout]]])
            }
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try encode(root)
    }

    public static func remove(from data: Data, scriptPath: String) throws -> Data {
        var root = try parse(data)
        // Forme inattendue : rien de nous à retirer, le fichier ressort tel quel.
        if var hooks = root["hooks"] as? [String: Any] {
            for (event, value) in hooks {
                guard let groups = value as? [[String: Any]] else { continue }
                let kept = strip(groups, commands: ours(scriptPath))
                if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
            }
            root["hooks"] = hooks.isEmpty ? nil : hooks
        }
        return try encode(root)
    }

    /// `installed` : les sept événements appellent la commande actuelle et aucune entrée au chemin brut ne reste.
    public static func status(of data: Data, scriptPath: String) -> Status {
        guard let root = try? parse(data) else { return .unreadable }
        let hooks = root["hooks"] as? [String: Any] ?? [:]
        let current = command(for: scriptPath)
        let present = events.filter { event in
            (hooks[event] as? [[String: Any]])?.contains { calls($0, commands: [current]) } == true
        }.count
        let legacy = hasLegacyEntries(in: hooks, scriptPath: scriptPath)
        switch present {
        case 0 where !legacy: return .absent
        case events.count where !legacy: return .installed
        default: return .partial
        }
    }

    /// Vrai si le fichier porte encore des entrées au chemin brut des versions 0.5.4 à 0.6.1 : l'app les remplace
    /// au lancement, sans attendre un clic sur « Réparer ».
    public static func hasLegacyEntries(in data: Data, scriptPath: String) -> Bool {
        guard let root = try? parse(data), let hooks = root["hooks"] as? [String: Any] else { return false }
        return hasLegacyEntries(in: hooks, scriptPath: scriptPath)
    }

    /// Un groupe est à nous si l'un de ses hooks appelle notre script, par la commande actuelle ou le chemin brut.
    public static func owns(_ group: [String: Any], scriptPath: String) -> Bool {
        calls(group, commands: ours(scriptPath))
    }

    private static func ours(_ scriptPath: String) -> [String] { [command(for: scriptPath), scriptPath] }

    private static func hasLegacyEntries(in hooks: [String: Any], scriptPath: String) -> Bool {
        hooks.values.contains { ($0 as? [[String: Any]])?.contains { calls($0, commands: [scriptPath]) } == true }
    }

    private static func calls(_ group: [String: Any], commands: [String]) -> Bool {
        (group["hooks"] as? [[String: Any]])?.contains { isCall($0, commands: commands) } == true
    }

    private static func isCall(_ hook: [String: Any], commands: [String]) -> Bool {
        (hook["command"] as? String).map { commands.contains($0) } == true
    }

    /// Retire les hooks qui appellent l'une des commandes ; un groupe vidé disparaît, un groupe que l'utilisateur
    /// partage avec ses propres hooks garde les siens.
    private static func strip(_ groups: [[String: Any]], commands: [String]) -> [[String: Any]] {
        groups.compactMap { group in
            guard let hooks = group["hooks"] as? [[String: Any]], hooks.contains(where: { isCall($0, commands: commands) }) else { return group }
            let kept = hooks.filter { !isCall($0, commands: commands) }
            guard !kept.isEmpty else { return nil }
            var copy = group
            copy["hooks"] = kept
            return copy
        }
    }

    /// Une forme inattendue n'est jamais écrasée à l'installation : le fichier est tenu pour illisible et laissé
    /// tel quel.
    private static func hooksSection(of root: [String: Any]) throws -> [String: Any] {
        guard let value = root["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else { throw Failure.unreadable }
        return hooks
    }

    private static func eventGroups(_ value: Any?) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let groups = value as? [[String: Any]] else { throw Failure.unreadable }
        return groups
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
