import Foundation
import NotchUsageCore

/// `~/.claude/settings.json` (017, R5) : relu juste avant chaque écriture, modifié par `ClaudeHooksInstaller`,
/// écrit en entier dans un fichier temporaire du même dossier puis renommé. Jamais écrit s'il est illisible.
enum ClaudeSettingsFile {
    enum Status: Equatable { case absent, installed, partial, unreadable, claudeMissing }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static var claudeDirectory: URL { FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude", directoryHint: .isDirectory) }
    static var settingsURL: URL { claudeDirectory.appending(path: "settings.json") }

    static func status(scriptPath: String) -> Status {
        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else { return .claudeMissing }
        guard let data = try? read() else { return .unreadable }
        switch ClaudeHooksInstaller.status(of: data, scriptPath: scriptPath) {
        case .absent: return .absent
        case .installed: return .installed
        case .partial: return .partial
        case .unreadable: return .unreadable
        }
    }

    /// Entrées au chemin brut des versions 0.5.4 à 0.6.1 : le shell les coupait à l'espace, aucune ne s'exécutait.
    static func hasLegacyEntries(scriptPath: String) -> Bool {
        guard let data = try? read() else { return false }
        return ClaudeHooksInstaller.hasLegacyEntries(in: data, scriptPath: scriptPath)
    }

    static func install(scriptPath: String) throws {
        try modify { try ClaudeHooksInstaller.install(into: $0, scriptPath: scriptPath) }
    }

    static func remove(scriptPath: String) throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        try modify { try ClaudeHooksInstaller.remove(from: $0, scriptPath: scriptPath) }
    }

    private static func modify(_ change: (Data) throws -> Data) throws {
        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else {
            throw Failure(message: String(localized: "Claude Code was not found on this Mac."))
        }
        let before = try read()
        let after: Data
        do {
            after = try change(before)
        } catch {
            throw Failure(message: String(localized: "~/.claude/settings.json could not be read. Fix it, then try again."))
        }
        guard after != before else { return }
        try write(after)
    }

    private static func read() throws -> Data {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return Data() }
        return try Data(contentsOf: settingsURL)
    }

    private static func write(_ data: Data) throws {
        // `settings.json` est parfois un lien vers un dépôt de dotfiles : on remplace la cible, le lien reste en place.
        let target = settingsURL.resolvingSymlinksInPath()
        let temporary = target.deletingLastPathComponent().appending(path: ".settings.json.notchusage-\(getpid())")
        let fm = FileManager.default
        try data.write(to: temporary, options: .atomic)
        let permissions = (try? fm.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int) ?? 0o600
        try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: temporary.path)
        guard rename(temporary.path, target.path) == 0 else {
            try? fm.removeItem(at: temporary)
            throw Failure(message: String(localized: "~/.claude/settings.json could not be written."))
        }
    }
}
