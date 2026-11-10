import Foundation
import Testing
@testable import NotchUsageCore

/// Fusion et retrait des entrées de l'app dans `~/.claude/settings.json` (017, contrat hooks.md) : les hooks de
/// l'utilisateur restent identiques, à l'octet près une fois réencodés avec les mêmes options.
@Suite("ClaudeHooksInstaller (017)")
struct ClaudeHooksInstallerTests {
    let script = "/Users/f/Library/Application Support/NotchUsage/claude-hook.sh"

    func object(_ data: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:] }
    func hooks(_ data: Data) -> [String: [[String: Any]]] { object(data)["hooks"] as? [String: [[String: Any]]] ?? [:] }

    @Test func installAddsTheSevenGroupsAndLeavesTheRestAlone() throws {
        for fixture in ["claude-settings-0.json", "claude-settings-1.json", "claude-settings-8.json"] {
            let original = Fixture.data(fixture)
            let installed = try ClaudeHooksInstaller.install(into: original, scriptPath: script)
            let before = object(original), after = object(installed)
            for key in before.keys where key != "hooks" {
                #expect(NSDictionary(dictionary: [key: before[key]!]) == NSDictionary(dictionary: [key: after[key]!]), Comment(rawValue: "\(fixture) \(key)"))
            }
            let groups = hooks(installed)
            for event in ClaudeHooksInstaller.events {
                let mine = groups[event]?.filter { ClaudeHooksInstaller.owns($0, scriptPath: script) } ?? []
                #expect(mine.count == 1, Comment(rawValue: "\(fixture) \(event)"))
                let hook = (mine.first?["hooks"] as? [[String: Any]])?.first
                #expect(hook?["type"] as? String == "command" && hook?["command"] as? String == "'\(script)'" && hook?["timeout"] as? Int == 5)
            }
            // Les groupes de l'utilisateur sont là, avant les nôtres, inchangés.
            let userBefore = hooks(original), userAfter = groups.mapValues { $0.filter { !ClaudeHooksInstaller.owns($0, scriptPath: script) } }
            #expect(NSDictionary(dictionary: userBefore) == NSDictionary(dictionary: userAfter.filter { !$0.value.isEmpty }), Comment(rawValue: fixture))
            #expect(ClaudeHooksInstaller.status(of: installed, scriptPath: script) == .installed)
        }
    }

    @Test func removeAfterInstallGivesTheOriginalBackByteForByte() throws {
        for fixture in ["claude-settings-0.json", "claude-settings-1.json", "claude-settings-8.json"] {
            let original = Fixture.data(fixture)
            let roundTrip = try ClaudeHooksInstaller.remove(from: try ClaudeHooksInstaller.install(into: original, scriptPath: script), scriptPath: script)
            let reencoded = try ClaudeHooksInstaller.encode(object(original))
            #expect(roundTrip == reencoded, Comment(rawValue: fixture))
            #expect(ClaudeHooksInstaller.status(of: roundTrip, scriptPath: script) == .absent)
        }
    }

    /// Claude Code passe la commande à `/bin/sh -c` : le chemin réel contient une espace (`Application Support`).
    /// Écrit brut, il était coupé à l'espace et le script ne tournait jamais (code 127 à chaque événement).
    @Test func installedCommandRunsThroughTheShell() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notch usage d'essai \(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let hook = dir.appending(path: "claude-hook.sh"), marker = dir.appending(path: "ran")
        try "#!/bin/sh\n: > \"$(dirname \"$0\")/ran\"\n".write(to: hook, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)

        let installed = try ClaudeHooksInstaller.install(into: Data(), scriptPath: hook.path)
        let command = (hooks(installed)["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", try #require(command)]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(fm.fileExists(atPath: marker.path))
    }

    @Test func commandIsQuotedForTheShell() {
        #expect(ClaudeHooksInstaller.command(for: script) == "'/Users/f/Library/Application Support/NotchUsage/claude-hook.sh'")
        #expect(ClaudeHooksInstaller.command(for: "/Users/o'neil/hook.sh") == "'/Users/o'\\''neil/hook.sh'")
    }

    /// Fichier laissé par les versions 0.5.4 à 0.6.1 : sept groupes au chemin brut, ajoutés à ceux de l'utilisateur.
    func withLegacyEntries(_ fixture: String) throws -> Data {
        var obj = object(Fixture.data(fixture))
        var groups = obj["hooks"] as? [String: Any] ?? [:]
        for event in ClaudeHooksInstaller.events {
            let legacy: [String: Any] = ["matcher": "", "hooks": [["type": "command", "command": script, "timeout": 5]]]
            groups[event] = (groups[event] as? [[String: Any]] ?? []) + [legacy]
        }
        obj["hooks"] = groups
        return try ClaudeHooksInstaller.encode(obj)
    }

    @Test func legacyUnquotedEntriesAreReplacedOnInstall() throws {
        for fixture in ["claude-settings-0.json", "claude-settings-8.json"] {
            let legacy = try withLegacyEntries(fixture)
            #expect(ClaudeHooksInstaller.hasLegacyEntries(in: legacy, scriptPath: script))
            // Jamais « installé » : ces entrées ne s'exécutent pas, l'app doit les remplacer.
            #expect(ClaudeHooksInstaller.status(of: legacy, scriptPath: script) == .partial)

            let migrated = try ClaudeHooksInstaller.install(into: legacy, scriptPath: script)
            #expect(!ClaudeHooksInstaller.hasLegacyEntries(in: migrated, scriptPath: script))
            #expect(ClaudeHooksInstaller.status(of: migrated, scriptPath: script) == .installed)
            // Même résultat qu'une installation neuve : rien ne reste des anciennes entrées, rien ne double.
            #expect(migrated == (try ClaudeHooksInstaller.install(into: Fixture.data(fixture), scriptPath: script)), Comment(rawValue: fixture))
        }
    }

    @Test func removeAlsoCleansLegacyEntries() throws {
        let legacy = try withLegacyEntries("claude-settings-8.json")
        let removed = try ClaudeHooksInstaller.remove(from: legacy, scriptPath: script)
        #expect(removed == (try ClaudeHooksInstaller.encode(object(Fixture.data("claude-settings-8.json")))))
        #expect(ClaudeHooksInstaller.status(of: removed, scriptPath: script) == .absent)
    }

    /// Un groupe où l'utilisateur a rangé son propre hook à côté du nôtre garde le sien.
    @Test func removeKeepsTheUsersHookInASharedGroup() throws {
        let mine: [String: Any] = ["type": "command", "command": ClaudeHooksInstaller.command(for: script), "timeout": 5]
        let theirs: [String: Any] = ["type": "command", "command": "~/bin/notify.sh"]
        let shared = try ClaudeHooksInstaller.encode(["hooks": ["Stop": [["matcher": "", "hooks": [theirs, mine]]]]])
        let removed = try ClaudeHooksInstaller.remove(from: shared, scriptPath: script)
        let kept = hooks(removed)["Stop"]?.first?["hooks"] as? [[String: Any]]
        #expect(kept?.count == 1 && kept?.first?["command"] as? String == "~/bin/notify.sh")
    }

    /// Une forme que l'app ne comprend pas n'est jamais écrasée à l'installation, et le retrait la laisse intacte.
    @Test func unexpectedShapesAreLeftAlone() throws {
        let odd = try ClaudeHooksInstaller.encode(["hooks": ["Stop": "echo done"], "model": "opus"])
        #expect(throws: ClaudeHooksInstaller.Failure.unreadable) {
            try ClaudeHooksInstaller.install(into: odd, scriptPath: script)
        }
        #expect(try ClaudeHooksInstaller.remove(from: odd, scriptPath: script) == odd)
        let list = try ClaudeHooksInstaller.encode(["hooks": ["echo done"]])
        #expect(throws: ClaudeHooksInstaller.Failure.unreadable) {
            try ClaudeHooksInstaller.install(into: list, scriptPath: script)
        }
        #expect(try ClaudeHooksInstaller.remove(from: list, scriptPath: script) == list)
    }

    @Test func installIsIdempotent() throws {
        let once = try ClaudeHooksInstaller.install(into: Fixture.data("claude-settings-8.json"), scriptPath: script)
        let twice = try ClaudeHooksInstaller.install(into: once, scriptPath: script)
        #expect(once == twice)
    }

    @Test func removeOnlyTouchesOurGroupsAndDropsEmptyEvents() throws {
        let data = Fixture.data("claude-settings-1.json")
        let removed = try ClaudeHooksInstaller.remove(from: data, scriptPath: script)
        #expect(NSDictionary(dictionary: hooks(removed)) == NSDictionary(dictionary: hooks(data)))
        let installed = try ClaudeHooksInstaller.install(into: Fixture.data("claude-settings-0.json"), scriptPath: script)
        let cleaned = try ClaudeHooksInstaller.remove(from: installed, scriptPath: script)
        #expect(object(cleaned)["hooks"] == nil)   // plus aucun événement : la clé disparaît
    }

    @Test func statusDistinguishesPartialAndUnreadable() throws {
        let installed = try ClaudeHooksInstaller.install(into: Fixture.data("claude-settings-8.json"), scriptPath: script)
        var obj = object(installed)
        var groups = obj["hooks"] as! [String: [[String: Any]]]
        for event in ["Stop", "SessionEnd", "UserPromptSubmit"] {
            groups[event] = groups[event]?.filter { !ClaudeHooksInstaller.owns($0, scriptPath: script) }
        }
        obj["hooks"] = groups
        let partial = try ClaudeHooksInstaller.encode(obj)
        #expect(ClaudeHooksInstaller.status(of: partial, scriptPath: script) == .partial)
        #expect(ClaudeHooksInstaller.status(of: Fixture.data("claude-settings-broken.json"), scriptPath: script) == .unreadable)
        #expect(ClaudeHooksInstaller.status(of: Fixture.data("claude-settings-8.json"), scriptPath: script) == .absent)
        // Réparer = réinstaller : les groupes manquants reviennent, les présents ne doublent pas.
        let repaired = try ClaudeHooksInstaller.install(into: partial, scriptPath: script)
        #expect(ClaudeHooksInstaller.status(of: repaired, scriptPath: script) == .installed)
        #expect(hooks(repaired)["Stop"]?.filter { ClaudeHooksInstaller.owns($0, scriptPath: script) }.count == 1)
    }

    @Test func brokenJSONIsNeverRewritten() {
        #expect(throws: ClaudeHooksInstaller.Failure.unreadable) {
            try ClaudeHooksInstaller.install(into: Fixture.data("claude-settings-broken.json"), scriptPath: script)
        }
        #expect(throws: ClaudeHooksInstaller.Failure.unreadable) {
            try ClaudeHooksInstaller.remove(from: Fixture.data("claude-settings-broken.json"), scriptPath: script)
        }
    }

    @Test func emptyFileBecomesAHooksOnlyDocument() throws {
        let installed = try ClaudeHooksInstaller.install(into: Data(), scriptPath: script)
        #expect(Set(object(installed).keys) == ["hooks"])
        #expect(ClaudeHooksInstaller.status(of: Data(), scriptPath: script) == .absent)
    }

    @Test func encodingIsStableAndReadable() throws {
        let data = try ClaudeHooksInstaller.encode(["b": 1, "a": ["url": "http://x/y"]])
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasSuffix("\n") && !text.contains("\\/"))
        #expect(text.range(of: "\"a\"")!.lowerBound < text.range(of: "\"b\"")!.lowerBound)
    }
}
