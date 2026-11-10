import Foundation
import NotchUsageCore

/// Script appelé par les hooks de Claude Code (017, contrat hooks.md) et fichier d'événements, dans le conteneur
/// de l'app : le chemin ne change pas d'une mise à jour à l'autre, contrairement au bundle.
enum ClaudeHookScript {
    static let directory: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "NotchUsage", directoryHint: .isDirectory)

    static var scriptURL: URL { directory.appending(path: "claude-hook.sh") }
    static var eventsURL: URL { directory.appending(path: "claude-events.jsonl") }

    /// Au-delà de cette taille, le fichier d'événements repart de zéro : il ne grossit que lorsque l'app, fermée,
    /// ne le vide plus, et seuls les derniers événements comptent à la relance.
    static let eventsFileCap = 1_048_576

    /// Une ligne par événement : enveloppe (pid du lanceur, heure) puis le payload du hook tel quel, sans ses retours
    /// à la ligne. Muet et toujours en succès : Claude Code ne doit jamais voir une erreur de notre fait.
    /// Le script se relance sous `lockf` : deux hooks simultanés (sessions ou outils en parallèle) écrivaient
    /// chacun en trois fois et pouvaient entremêler leurs lignes. Le pid du lanceur passe en argument, le parent du
    /// script relancé étant `lockf`.
    static func contents(eventsPath: String) -> String {
        let quoted = "'" + eventsPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return """
        #!/bin/sh
        # Notch Usage (017) : relaie un événement de Claude Code à l'app, une ligne JSON par événement.
        # L'app ne garde que le type, la session, le dossier, le titre et l'outil ; le fichier est vidé à chaque lecture.
        f=\(quoted)
        umask 077
        [ -d "${f%/*}" ] || exit 0
        if [ "$1" != locked ] && [ -x /usr/bin/lockf ]; then
          /usr/bin/lockf -k -s -t 2 "$f.lock" "$0" locked "$PPID" 2>/dev/null
          exit 0
        fi
        [ "$1" = locked ] && p=$2 || p=$PPID
        [ "$(/usr/bin/stat -f %z "$f" 2>/dev/null || echo 0)" -gt \(eventsFileCap) ] && : > "$f" 2>/dev/null
        printf '{"ppid":%s,"ts":%s,"event":' "$p" "$(date +%s)" >> "$f" 2>/dev/null || exit 0
        tr -d '\\n' >> "$f" 2>/dev/null || true
        printf '}\\n' >> "$f" 2>/dev/null || true
        exit 0

        """
    }

    /// Écrit (ou réécrit) le script en 700 et crée le fichier d'événements en 600 s'il manque.
    static func ensure() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try contents(eventsPath: eventsURL.path).write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        if !fm.fileExists(atPath: eventsURL.path) {
            fm.createFile(atPath: eventsURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
    }
}
