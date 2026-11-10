import Foundation
import NotchUsageCore

/// Sessions Claude Code suivies, écrites à chaque changement dans le dossier de l'app (017) : une attente en cours
/// survit au redémarrage de l'app (mise à jour, relance), au lieu de ne réapparaître qu'au prochain événement de la
/// session. Même contenu que ce que l'app garde en mémoire : identifiant de session, dossier, titre, outil, jamais le
/// texte des conversations. Droits 600 ; le fichier disparaît dès que plus rien n'est suivi.
enum ClaudeSessionsFile {
    static var defaultURL: URL { ClaudeHookScript.directory.appending(path: "claude-sessions.json") }

    static func load(from url: URL = defaultURL) -> ClaudeSessionTracker? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClaudeSessionTracker.self, from: data)
    }

    static func save(_ tracker: ClaudeSessionTracker, to url: URL = defaultURL) {
        let fm = FileManager.default
        guard !tracker.isEmpty else {
            try? fm.removeItem(at: url)
            return
        }
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(tracker).write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            Log.app.error("claude sessions: \(error.localizedDescription, privacy: .public)")
        }
    }
}
