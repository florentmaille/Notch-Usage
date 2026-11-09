import Foundation

/// Mise à jour sans réseau (020) : l'app ne se connecte à rien (constitution, principe I). Installée par Homebrew,
/// elle confie la mise à jour à un script Terminal ; sinon, elle ouvre la page des releases dans le navigateur.
public enum UpdateRoute: Sendable, Equatable {
    case homebrew(prefix: String)
    case releasesPage

    public static let installedAppPath = "/Applications/NotchUsage.app"
    /// Apple Silicon, puis Intel : le cask crée ce dossier à l'installation.
    public static let homebrewPrefixes = ["/opt/homebrew", "/usr/local"]
    public static var caskroomCandidates: [String] { homebrewPrefixes.map { "\($0)/Caskroom/notch-usage" } }
    public static let releasesURL = URL(string: "https://github.com/florentmaille/Notch-Usage/releases/latest")!

    /// Homebrew ne gère que la copie installée dans le dossier Applications ; toute autre copie va aux releases.
    public static func decide(appPath: String, existingCaskrooms: Set<String>) -> UpdateRoute {
        guard appPath == installedAppPath else { return .releasesPage }
        for prefix in homebrewPrefixes where existingCaskrooms.contains("\(prefix)/Caskroom/notch-usage") {
            return .homebrew(prefix: prefix)
        }
        return .releasesPage
    }

    /// Script ouvert dans le Terminal. `brew update` d'abord : sans lui, `brew upgrade` croit la dernière version
    /// installée (vu à la sortie de la 0.5.7). Le cask arrête l'app avant de la remplacer ; la dernière ligne la relance.
    public static func script(prefix: String, appPath: String) -> String {
        """
        #!/bin/zsh
        export PATH="\(prefix)/bin:$PATH"
        echo "Notch Usage: checking for updates…"
        echo
        brew update && brew upgrade --cask notch-usage || exit $?
        echo
        open "\(appPath)"
        echo "Done. You can close this window."

        """
    }
}
