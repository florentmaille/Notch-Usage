# Research : Mise à jour sans réseau

## R1 - Détecter une installation Homebrew, sans réseau

- **Décision** : fonction pure `UpdateRoute.decide(appPath:existingCaskrooms:)` dans le core. Elle renvoie Homebrew si l'app tourne depuis `/Applications/NotchUsage.app` et si un dossier `<préfixe>/Caskroom/notch-usage` existe, avec le préfixe `/opt/homebrew` (Apple Silicon) ou `/usr/local` (Intel). Sinon, elle renvoie la page des releases. L'app lit seulement l'existence de ces dossiers.
- **Rationale** : c'est le cask qui crée `Caskroom/notch-usage` à l'installation. Une copie lancée depuis un autre dossier (zip, build) n'est pas gérée par Homebrew.
- **Alternatives** : lancer `brew list --cask` (lent, dépend du `PATH`) ; poser un marqueur au premier lancement (faux si l'app est déplacée).

## R2 - Ouvrir le Terminal sans permission nouvelle

- **Décision** : écrire un script `.command` (droits 700) dans le dossier temporaire de l'app, puis l'ouvrir avec `NSWorkspace.open`. macOS le confie à l'app associée aux scripts de terminal (Terminal par défaut).
- **Rationale** : faire piloter le Terminal par AppleScript déclencherait la demande « contrôler Terminal » (Automatisation), contraire à FR-007. Ouvrir un fichier ne demande rien.
- **Script** : `PATH` complété par le préfixe Homebrew, puis `brew update && brew upgrade --cask notch-usage`, puis `open -a "<chemin de l'app>"`. Le cask arrête l'app avant de la remplacer (`uninstall quit`), et la dernière ligne la relance. Si l'app est déjà à jour, elle revient simplement au premier plan. Si `brew update` échoue, l'app n'est pas touchée.
- **Alternatives** : `Process` sans fenêtre (l'utilisateur ne voit ni la progression ni la confirmation demandée par Homebrew) ; AppleScript `do script` (demande de permission).

## R3 - Page des releases

- **Décision** : `NSWorkspace.open(URL("https://github.com/florentmaille/Notch-Usage/releases/latest"))`. C'est le navigateur qui se connecte, à la demande explicite de l'utilisateur ; l'app n'ouvre aucune connexion (principe I).

## R4 - Version affichée

- **Décision** : `CFBundleShortVersionString`, déjà renseignée par `project.yml`, affichée sous la forme « Version 0.5.7 » dans le pied des Réglages, à côté du bouton.
