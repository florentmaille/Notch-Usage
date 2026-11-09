import AppKit
import NotchUsageCore

/// Bouton « Rechercher les mises à jour » (020) : aucune connexion depuis l'app, aucune permission. Homebrew : un
/// script `.command` ouvert par macOS dans le Terminal (pas d'AppleScript, donc pas de demande d'Automatisation) ;
/// sinon, la page des releases dans le navigateur.
@MainActor
enum UpdateLauncher {
    static var route: UpdateRoute {
        let existing = Set(UpdateRoute.caskroomCandidates.filter { FileManager.default.fileExists(atPath: $0) })
        return UpdateRoute.decide(appPath: Bundle.main.bundlePath, existingCaskrooms: existing)
    }

    static var isHomebrew: Bool {
        if case .homebrew = route { return true }
        return false
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static func launch() {
        switch route {
        case .releasesPage:
            NSWorkspace.shared.open(UpdateRoute.releasesURL)
            Log.app.notice("update: releases page")
        case .homebrew(let prefix):
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("notch-usage-update.command")
            do {
                try UpdateRoute.script(prefix: prefix, appPath: Bundle.main.bundlePath).write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
                NSWorkspace.shared.open(url)
                Log.app.notice("update: homebrew script opened")
            } catch {
                // Script impossible à écrire : la page des releases reste un chemin valable.
                Log.app.error("update: script not written, opening releases page")
                NSWorkspace.shared.open(UpdateRoute.releasesURL)
            }
        }
    }
}
