# Implementation Plan: Mise à jour sans réseau

**Branch** : `020-offline-update` | **Date** : 2026-11-09 | **Spec** : [spec.md](spec.md) | **Research** : [research.md](research.md)

## Summary

Un bouton « Rechercher les mises à jour » dans les Réglages, et la même entrée dans le menu de l'icône. Si l'app vient de Homebrew, il ouvre un script Terminal (`brew update && brew upgrade --cask notch-usage`, puis relance de l'app). Sinon, il ouvre la page des releases. L'app n'ouvre aucune connexion et ne demande aucune permission.

## Technical Context

- **Stack** : Swift 6, rien de nouveau.
- **Tests** : core en TDD : `UpdateRoute` (décision) et `UpdateScript` (texte du script).
- **Stockage** : un fichier `.command` temporaire, réécrit à chaque clic.
- **Performance** : rien au repos ; quelques vérifications d'existence de fichier au clic.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Aucune connexion depuis l'app. Homebrew et le navigateur agissent à la demande de l'utilisateur. Aucune permission. | PASS |
| II. Sobriété | Rien au repos, aucun timer. | PASS |
| III. Tests | La décision et le script sont dans le core, tests avant code. | PASS |
| IV. YAGNI | Pas de framework de mise à jour, pas de vérification automatique. | PASS |

## Project Structure

```text
Sources/NotchUsageCore/Update/UpdateRoute.swift   # NOUVEAU : décision Homebrew ou releases, texte du script
Tests/NotchUsageCoreTests/UpdateRouteTests.swift  # NOUVEAU
App/NotchUsage/System/UpdateLauncher.swift        # NOUVEAU : lit l'existence des Caskroom, écrit et ouvre le script, ou ouvre l'URL
App/NotchUsage/Views/SettingsView.swift           # pied : « Version x » + bouton + note sans Homebrew
App/NotchUsage/Notch/StatusItemController.swift   # menu : « Check for Updates… »
App/NotchUsage/Resources/Localizable.xcstrings    # textes EN/FR
```

## Complexity Tracking

Aucune violation.
