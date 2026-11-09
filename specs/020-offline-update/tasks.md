# Tasks: Mise à jour sans réseau

- [x] T001 [P] Écrire les tests de `Tests/NotchUsageCoreTests/UpdateRouteTests.swift`, qui doivent échouer d'abord :
  - Décision :
    - app dans `/Applications` avec `/opt/homebrew/Caskroom/notch-usage` → Homebrew, préfixe `/opt/homebrew` ;
    - même cas avec `/usr/local` → préfixe `/usr/local` ;
    - app ailleurs (`~/Downloads`, DerivedData) → releases, même si le Caskroom existe ;
    - aucun Caskroom → releases.
  - Script : il commence par `#!/bin/zsh`, ajoute le préfixe au `PATH`, enchaîne `brew update && brew upgrade --cask notch-usage`, puis relance l'app par son chemin, entre guillemets.
  - L'URL des releases vaut `https://github.com/florentmaille/Notch-Usage/releases/latest`.
- [x] T002 Créer `Sources/NotchUsageCore/Update/UpdateRoute.swift`, pour faire passer T001 au vert.
- [x] T003 Créer `App/NotchUsage/System/UpdateLauncher.swift` :
  - `launch()` lit l'existence des deux Caskroom et décide de la route.
  - Route Homebrew : il écrit `notch-usage-update.command` en droits 700 dans le dossier temporaire, puis l'ouvre avec `NSWorkspace`.
  - Route releases : il ouvre l'URL.
  - `isHomebrew` sert à la note des Réglages.
- [x] T004 Modifier `App/NotchUsage/Views/SettingsView.swift`, au-dessus du pied :
  - « Version 0.5.7 » à gauche, bouton « Check for updates » à droite ;
  - sans Homebrew, une note : « Installed without Homebrew: download the latest version from the releases page ».
- [x] T005 Modifier `App/NotchUsage/Notch/StatusItemController.swift` : ajouter « Check for Updates… » entre « Settings » et « Quit ».
- [x] T006 Ajouter les textes en anglais et en français dans `Localizable.xcstrings` ; `scripts/check-localizations.sh` doit rendre 0.
- [ ] T007 Validation :
  - `swift test` et `xcodebuild test` passent ;
  - essai réel : le clic ouvre le Terminal, le script tourne, l'app est relancée ;
  - aucune demande de permission ;
  - avec une build Debug lancée ailleurs que dans `/Applications`, la page des releases s'ouvre.

## Dépendances

T002 dépend de T001 ; T003 de T002 ; T004 et T005 de T003 ; T006 se fait à la fin.

## Validation (2026-11-09)

- T001 à T006 faits.
  - Tests : core 311 (7 nouveaux), app 13.
  - Catalogue : 129 textes, aucun sans traduction.
  - README : paragraphe « Updating ».
- T007, reste à faire en réel :
  - le chemin Homebrew ne s'exerce qu'avec l'app installée dans `/Applications` par le cask, donc à partir de la release qui le contiendra ;
  - la build Debug, qui tourne depuis DerivedData, prend le chemin « page des releases ».
