import Foundation

/// Renouvellement du jeton de Claude Code par son propre CLI (011) : l'app ne rafraîchit jamais le jeton
/// elle-même (R1), elle demande à `claude` une réponse minimale, ce qui lui fait renouveler sa session.
public enum ClaudeCLI {
    /// Résultat d'un renouvellement, d'après le code de sortie et la sortie du CLI.
    public enum Outcome: Sendable, Equatable {
        case renewed
        case notFound
        case notLoggedIn
        case timedOut
        case failed
    }

    /// Emplacements essayés dans l'ordre : une app lancée par le Finder n'a pas le PATH du shell.
    public static func candidates(home: String, path: String?) -> [String] {
        let fromPath = (path ?? "").split(separator: ":").map { "\($0)/claude" }
        let known = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude",
                     "/usr/local/bin/claude", "\(home)/.npm-global/bin/claude", "\(home)/.bun/bin/claude"]
        var seen = Set<String>()
        return (known + fromPath).filter { seen.insert($0).inserted }
    }

    public static func locate(home: String, path: String?, isExecutable: (String) -> Bool) -> String? {
        candidates(home: home, path: path).first(where: isExecutable)
    }

    /// Requête la plus légère possible : Haiku, un tour, sans serveurs MCP, sans réglages ni hooks utilisateur,
    /// sans session enregistrée.
    public static let renewalArguments = ["-p", "Reply with OK", "--model", "haiku", "--max-turns", "1",
                                          "--strict-mcp-config", "--setting-sources", "", "--no-session-persistence"]

    /// Environnement minimal : sans `USER`, le CLI ne retrouve pas son entrée Trousseau et se dit déconnecté.
    public static func environment(home: String, user: String) -> [String: String] {
        ["HOME": home, "USER": user, "LOGNAME": user, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
    }

    public static let timeout: TimeInterval = 45

    public static func outcome(exitCode: Int32, output: String) -> Outcome {
        let lower = output.lowercased()
        if lower.contains("not logged in") || lower.contains("/login") { return .notLoggedIn }
        return exitCode == 0 ? .renewed : .failed
    }
}
