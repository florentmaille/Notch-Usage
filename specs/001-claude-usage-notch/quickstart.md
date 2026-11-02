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

Attendu sur 10 min au repos, panneau replié : CPU moyen < 1 %, empreinte mémoire < 60 Mo
(colonne « Mémoire » d'Activity Monitor, `vmmap --summary`), au plus 4 requêtes réseau (180 s).
Aucun réveil de timer plus fréquent que l'intervalle. Le RSS brut n'est pas retenu : il compte les
pages partagées des frameworks système (SwiftUI, AppKit), communes à toutes les apps.

Chaque relevé écrit une ligne `reading ok|failed` (catégorie `refresh`) : compter les requêtes avec

```bash
/usr/bin/log show --predicate 'subsystem == "com.notchusage" AND category == "refresh"' --last 10m --info | grep -c reading
```

## Vie privée (constitution I)

```bash
grep -rn "api.anthropic.com\|claude.ai" Sources App | grep -v "^.*//"
```

Attendu : appels réseau uniquement dans `OAuthUsageProvider`, `WebUsageProvider`,
`BrowserLoginWindow`. Les autres occurrences (`ConnectionManager`, vues) sont des textes
d'interface ou la vérification du préfixe `sk-ant-sid`. Les logs (`Logger`, sous-système
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

## Crochets de test (build Debug uniquement)

Pour vérifier le panneau sans permission Accessibilité ni Enregistrement d'écran, la build Debug
écoute des notifications distribuées (`DistributedNotificationCenter`) :

| Notification | Objet | Effet |
|---|---|---|
| `com.notchusage.debug.hover` | `"1"` / `"0"` | Survol entrant / sortant (sans la temporisation de 150 ms) |
| `com.notchusage.debug.click` | `"x,y"` (pt depuis le coin haut gauche du panneau) | Clic gauche via la file d'événements de l'app |
| `com.notchusage.debug.escape` | - | Touche Échap |
| `com.notchusage.debug.snapshot` | - | Rendu PNG du panneau dans `$TMPDIR/notchusage-snapshot.png` |

## Résultats 2026-11-02 (MacBook, encoche 220 pt, compte Team)

| # | Résultat | Vérifié par |
|---|---|---|
| 1, 2 | OK | Utilisateur |
| 4 | OK, survol et clic réels confirmés par l'utilisateur. Ouverture ≈ 180 ms (150 ms de temporisation + 30 ms), fermeture ≈ 110 ms, clic épingle, clic sur la bande désépingle, Échap ferme. Non simulé : clic hors du panneau | Crochets Debug |
| 5 | OK : lignes 5 h, hebdo et « Weekly · Fable » avec % et reset | Capture du panneau |
| 6, 7 | OK : avertissement (orange) et critique (rouge) distincts, une alerte par seuil et par période, y compris après redémarrage | Seuils 10/15 %, journaux, capture |
| Énergie | OK : CPU moyen 0,17 % (Debug, 10 min), 3 requêtes en 10 min, empreinte 19,7 Mo (Release) | `ps`, journaux, `vmmap` |
| Vie privée | OK : aucun `sk-ant` dans les journaux du processus, hôtes limités dans le code | `log show`, grep |
| 10 | OK : pilule centrée sur l'écran externe devenu principal, survol, retour dans l'encoche | Utilisateur |
| 11 | OK : vue masquée en plein écran (Chrome), réapparition au survol, retour sans clic à la sortie | Utilisateur, journaux |
| 14 | OK : « Notch Usage » listé dans Ouverture et extensions, sans approbation requise | Utilisateur |
| 3 | OK : fenêtre fermée seule, organisation active reprise du cookie `lastActiveOrg`, valeurs identiques à la voie 1 | Utilisateur, journaux |
| 8 | OK : bandeau « Data unavailable » maintenu pendant les nouvelles tentatives, relevé au retour du réseau. Bandeau « stale » (30 min) couvert par les tests | Utilisateur, journaux |
| 12 | OK : aucune requête entre la veille (11:13:59) et le réveil (11:16:56), relevé 1 s après | `pmset -g log`, journaux |
| 13 | OK : entrées Trousseau `com.notchusage.credentials` et dossier de cache supprimés | `security`, `ls` |
| 15 | OK : chaque limite annoncée en une phrase, boutons annoncés | Utilisateur |
| 9 | OK : session révoquée (11:37:52) → « Reconnect required » sans chiffre, reconnexion par Claude Code (11:38:08) | Utilisateur, journaux |

Défauts trouvés et corrigés pendant la validation : panneau décalé de 39 pt sous la barre de menus,
panneau au niveau 3 (sous la barre de menus, niveau 24) qui ne recevait ni survol ni clic, zone de
survol jamais créée, plein écran mal détecté sur écran à encoche (fenêtres sous l'encoche,
fenêtres multiples de Chrome, sortie détectée seulement au clic suivant), bandeau hors ligne masqué à chaque nouvelle
tentative, texte des boutons sans bordure non cliquable, clés `sk-ant-sid02-` refusées, plan Team
non reconnu par la voie navigateur, contrôles natifs invisibles (apparence claire sur fond noir),
boutons inertes au premier clic, épinglage par clic inopérant, boucle de dialogues Trousseau,
jeton Claude Code expiré mal signalé, double requête à la connexion, alertes répétées à chaque
relevé, jauge compacte illisible.

CI GitHub verte le 2026-11-02 sur `macos-15-intel` (exécution 41435937650) : `swift test` 1 min 56 s,
`xcodebuild` 3 min 10 s. Les runners macOS arm64 étaient saturés (jobs annulés faute de machine).

