import AppKit
import NotchUsageCore

/// Langue réellement retenue pour l'interface (celle du catalogue de textes), transmise au core pour
/// que les durées ne divergent jamais du reste des textes, y compris avec la langue par app du système.
enum AppLanguage {
    static let current = InterfaceLanguage(code: Bundle.main.preferredLocalizations.first)

    /// Choix en vigueur depuis le lancement : un changement n'apparaît qu'après redémarrage.
    static let launchedChoice = storedChoice

    /// Lu dans le domaine de l'app seulement : `UserDefaults.standard` renverrait aussi la liste globale du système.
    static var storedChoice: LanguageChoice {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        return LanguageChoice(appleLanguages: domain?["AppleLanguages"] as? [String])
    }

    static func store(_ choice: LanguageChoice) {
        if let languages = choice.appleLanguages {
            UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// Relance après la fin de ce processus : deux instances simultanées dessineraient deux encoches.
    @MainActor static func relaunch() {
        let script = "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.1; done; open \"$0\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
