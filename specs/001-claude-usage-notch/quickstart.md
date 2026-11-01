# Quickstart: Limites d'abonnement Claude dans l'encoche

**Feature**: `001-claude-usage-notch` | **Date**: 2026-11-01

## Prérequis

| Outil | Version | Pourquoi |
|---|---|---|
| macOS | 14+ | cible minimale ; machine de dev avec encoche recommandée |
| Xcode | 16+ (vérifié : Xcode 27.2, Swift 6.4.2, `swift test` OK le 2026-11-01) | Swift 6, Swift Testing, SwiftUI, archive. **Les Command Line Tools seuls ne suffisent pas** : `swift test` échoue (module `Testing` / `XCTest` introuvables) |
| xcodegen | 2.40+ (vérifié : 2.46.0) | `brew install xcodegen` ; génère `NotchUsage.xcodeproj` depuis `project.yml` |
| Compte Claude | Pro ou Max | validation manuelle |
| Claude Code | connecté | validation de la voie 1 |

Après installation de Xcode :

```bash
sudo xcode-select -s /Applications/Xcode.app
```

## Build et tests

```bash
swift test
```

```bash
xcodegen generate && xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -configuration Debug build
```

```bash
open "$(xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -showBuildSettings | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/NotchUsage.app"
```

Attendu : `swift test` vert sans accès réseau (les fixtures de
[contracts/usage-api.md](contracts/usage-api.md) couvrent tout) ; l'app démarre sans icône
dans le Dock et sans fenêtre.

## Scénarios de validation manuelle

| # | Scénario | Étapes | Attendu |
|---|---|---|---|
| 1 | Premier lancement (US1 sc. 1) | Lancer l'app, cliquer sur l'encoche | Panneau « Connect your Claude account », deux boutons, note de risque, aucune jauge |
| 2 | Voie 1 (US1 sc. 7) | « Use Claude Code session » → accepter le dialogue Trousseau | Jauge compacte < 2 min (SC-001), valeurs à ±1 pt de claude.ai/settings/usage (SC-002) |
| 3 | Voie 2 (US1 sc. 8) | Déconnecter, « Sign in with browser », se connecter | Fenêtre se ferme seule après connexion, mêmes valeurs qu'en 2 |
| 4 | Survol / épinglage (FR-012) | Survoler, éloigner, cliquer, cliquer ailleurs, Échap | Ouverture < 200 ms (SC-003), fermeture < 1 s, épinglage tenu, Échap ferme |
| 5 | Limites par modèle | Compte avec limite Fable | Ligne « Fable · weekly » avec % et réinitialisation ; aucune ligne pour un modèle absent |
| 6 | Alerte attention (US2) | Réglages : seuil attention sous la conso actuelle | État « warning » au cycle suivant, une seule fois ; remettre le seuil au-dessus puis en dessous ne ré-alerte pas |
| 7 | Alerte critique | Idem avec seuil critique | État « critical » distinct |
| 8 | Hors ligne | Couper le Wi-Fi 10 min | Dernières valeurs + « 10 min ago » ; au-delà de 30 min : « stale » ; aucun crash (SC-006) |
| 9 | Session expirée | Révoquer la session (claude.ai → Settings → logout partout) | « Reconnect required », aucun chiffre, bouton de reconnexion |
| 10 | Sans encoche (US3) | Brancher un écran externe en principal, ou couvercle fermé | Pilule centrée en haut < 2 s ; retour sur l'encoche quand l'écran interne redevient principal |
| 11 | Plein écran (FR-012a) | Mettre Safari en plein écran | Vue compacte masquée ; survol du haut la fait réapparaître ; point visible si alerte active |
| 12 | Veille (FR-008) | Fermer le couvercle 5 min, rouvrir | Aucune requête pendant la veille (Console.app, sous-système `com.notchusage`), relevé < 5 s après réveil |
| 13 | Déconnexion (FR-003) | Réglages → Sign out | Entrées Trousseau de l'app supprimées (`security find-generic-password -s com.notchusage.credentials` → not found), `Application Support/NotchUsage/` vide |
| 14 | Lancement à l'ouverture (FR-020) | Activer dans les réglages | Visible dans Réglages Système → Général → Ouverture ; désactivé par défaut |
| 15 | VoiceOver (FR-016) | Activer VoiceOver, naviguer dans le panneau | Chaque limite annoncée « label, percent, resets in » |

## Budget énergie (constitution II)

```bash
xcrun xctrace record --template 'Energy Log' --time-limit 10m --attach NotchUsage --output /tmp/notchusage-energy.trace
```

Attendu sur 10 min au repos, panneau replié : CPU moyen < 1 %, RSS < 60 Mo (Activity Monitor),
au plus 4 requêtes réseau (180 s). Aucun réveil de timer plus fréquent que l'intervalle.

## Vie privée (constitution I)

```bash
grep -rn "api.anthropic.com\|claude.ai" Sources App | grep -v "^.*//"
```

Attendu : appels réseau uniquement dans `OAuthUsageProvider`, `WebUsageProvider`,
`BrowserLoginWindow`. Les autres occurrences (`ConnectionManager`, vues) sont des textes
d'interface ou la vérification du préfixe `sk-ant-sid01-`. Les logs (`Logger`, sous-système
`com.notchusage`) ne contiennent jamais `sk-ant-`.

Vérifié le 2026-11-02 (automatisable) : `Sources/NotchUsageCore` n'importe que Foundation,
`Package.swift` sans dépendance, entitlements vides, aucun `sk-ant` journalisé, 102 tests verts,
archive Release OK. Restent les scénarios manuels (compte Pro/Max requis).

## Release (hors MVP, référence)

```bash
scripts/release.sh 0.1.0
```

Signe (Developer ID, Hardened Runtime), notarise, agrafe, produit le DMG et met à jour le
modèle de cask. Prérequis : certificat Developer ID et profil `notarytool` dans le Trousseau.
