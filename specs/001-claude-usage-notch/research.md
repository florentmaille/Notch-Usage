# Research: Limites d'abonnement Claude dans l'encoche

**Feature**: `001-claude-usage-notch` | **Date**: 2026-11-01

Sources : code de CodexBar, ClaudeBar, usagi, ClaudeUsageMonitor, usage4claude, openusage,
AgentsMonitor, NotchDrop, boring.notch, MacroVisionKit, docs Apple, issues anthropics/claude-code.
Aucun des endpoints d'usage n'est documenté par Anthropic : ils peuvent changer sans préavis.

## R1. Source des données : session Claude Code (voie 1)

**Decision** : lire l'`accessToken` de Claude Code dans le Trousseau (service
`Claude Code-credentials`, compte = login macOS, JSON `claudeAiOauth.accessToken`), puis
appeler `GET https://api.anthropic.com/api/oauth/usage` avec `Authorization: Bearer`,
`anthropic-beta: oauth-2025-04-20`, `User-Agent: claude-cli/<version> (external, cli)`.
Ne jamais rafraîchir le jeton nous-mêmes. Relire le Trousseau à chaque cycle : Claude Code
réécrit l'entrée quand il rafraîchit. Sur 401 → état `reauthRequired` avec le message
« ouvrez Claude Code pour renouveler la session ».

**Rationale** : les refresh tokens sont rotatifs et à usage unique. Un rafraîchissement
depuis notre app déconnecte le CLI (issues #31637, #54443). Tous les outils stables (ClaudeBar,
AgentsMonitor, CodexBar) lisent seulement l'accessToken. Le User-Agent `claude-cli/…` évite le
bucket « agressivement limité » constaté par AgentsMonitor. Risque assumé : il imite le client
officiel ; documenté dans le README.

**Alternatives rejetées** :
- Refresh avec le `client_id` de Claude Code → casse la session du CLI.
- Flux OAuth PKCE propre (ClaudeBar « self-contained ») → l'écran de consentement affiche
  « Claude Code », et les CGU réservent cet OAuth à Claude Code. Trop exposé pour un MVP.
- Lecture du JSON statusline de Claude Code (`rate_limits.*`, v2.1.80+) → zéro réseau, mais
  seulement quand une session Claude Code tourne. À garder pour une feature ultérieure.

**Gotcha Trousseau** : l'entrée appartient au binaire `claude`. Toute lecture par un autre
exécutable déclenche un dialogue macOS, et « Toujours autoriser » est lié à la signature du
lecteur : build ad hoc = dialogue à chaque rebuild, et chaque rotation du jeton le fait
revenir. Mitigation (CodexBar, AgentsMonitor) : `kSecUseAuthenticationUI = .skip` en arrière-plan
(échec propre, sans dialogue), dialogue seulement sur action utilisateur (bouton « Connecter »),
signature Developer ID stable. L'app copie ensuite le jeton dans **sa propre** entrée Trousseau
et ne relit celle de Claude Code que quand la sienne renvoie 401.

## R2. Source des données : session navigateur (voie 2)

**Decision** : fenêtre `WKWebView` dédiée qui charge `https://claude.ai/login`. Observer
`WKHTTPCookieStore` (`cookiesDidChange` + relecture à `didFinish`) jusqu'à voir le cookie
`sessionKey` (préfixe `sk-ant-sid01-`). Le stocker dans le Trousseau de l'app, fermer la
fenêtre, puis appeler `GET https://claude.ai/api/organizations` (prendre l'org dont
`capabilities` contient `claude_pro` / `claude_max*`, pas forcément `[0]`) et
`GET https://claude.ai/api/organizations/{uuid}/usage` avec `Cookie: sessionKey=…` et les
en-têtes d'usage4claude (`anthropic-client-platform: web_claude_ai`, `origin`, `referer`,
`sec-fetch-*`, UA Chrome macOS).

**Rationale** : aucune permission Accès complet au disque, aucun déchiffrement de cookies
Chrome/Safari, compatible sandbox, connexion Google/Apple possible dans la WKWebView. C'est
l'approche d'usagi et de ClaudeUsageMonitor. Le `sessionKey` vit des semaines, contre ~8 h
pour le jeton OAuth.

**Alternatives rejetées** :
- Lecture des cookies des navigateurs (CodexBar / SweetCookieKit) → FDA, dialogues Trousseau
  « Chrome Safe Storage », CVE-2026-43625. Contraire au principe I.
- Collage manuel du `sessionKey` → gardé en **secours** (champ dans les réglages) si la
  WKWebView tombe sur un challenge Cloudflare.

**Cloudflare** : détecter `cf-mitigated: challenge`, 403, ou 200 `text/html` → état
`failed(.challenge)` qui propose de rouvrir la fenêtre de connexion.

**Risque CGU** : les Consumer Terms (8 oct. 2025) interdisent l'accès automatisé hors API, et
la page « Legal and compliance » de Claude Code interdit d'intermédier des jetons claude.ai.
Les bannissements connus visent l'inférence par harnais tiers, pas le monitoring local en
lecture seule, mais la zone est grise. Décision : note de risque explicite dans le README et
dans l'écran de connexion, aucune donnée ne quitte la machine, voie 1 proposée en premier.

## R3. Format des réponses et parseur unique

**Decision** : un seul parseur `UsageResponseParser` qui accepte les deux formes et produit
`[UsageLimit]` :

| Forme | Clés | Mapping |
|---|---|---|
| Legacy | `five_hour`, `seven_day` (`utilization` 0-100, `resets_at`) ; `seven_day_<model>` nullable | `rollingFiveHour`, `weeklyAll`, `weeklyModel(modelName: <model>)` |
| Actuelle | `limits[]` avec `kind` ∈ `session`, `weekly_all`, `weekly_scoped` ; `percent` ; `scope.model.display_name` | idem ; `weekly_scoped` → `weeklyModel(modelName: display_name)` |

Règles : si `limits[]` est présent et non vide, il fait foi et les clés plates sont ignorées
(doublons). Toute clé inconnue est ignorée. `resets_at` accepté en ISO 8601, epoch secondes
ou millisecondes. Une fenêtre dont `resets_at` est passé est conservée mais affichée à 0 % si
le service ne l'a pas encore réinitialisée ? **Non** : elle est affichée telle quelle avec
« réinitialisation en attente », pour ne jamais mentir (cas limite « réinitialisation
pendant que l'app tourne » : le cycle suivant corrige). `utilization` hors 0...100 → borné.
Même format sur les deux voies (CodexBar partage le parseur), donc un seul jeu de fixtures.

**Rationale** : les clés plates `seven_day_opus/sonnet` reviennent `null` sur les comptes
récents, et les limites par modèle (Fable…) ne vivent plus que dans `limits[]`.

## R4. Cadence, limitation de débit et repli

**Decision** : intervalle **par défaut 180 s**, **plancher 60 s**, plafond 15 min. Sur 429 ou
5xx : backoff ×2 à partir de l'intervalle courant, plafonné à 15 min, réarmé au premier succès.
`Retry-After` respecté quand présent. Dernier relevé valide conservé et affiché avec son
ancienneté. Pas de retry immédiat.

**Rationale** : le bucket de `oauth/usage` est partagé avec le polling interne de chaque
session Claude Code ; à 60 s, les utilisateurs multi-sessions se font limiter pendant des
heures (issue #31637). ClaudeBar à 60 s rapporte des 429, AgentsMonitor tourne à 180 s,
tyrelh/claude-usage a dû passer de 300 à 600 s. La page d'usage officielle a un `staleTime` de
5 min. Un plancher à 30 s (spec FR-007 actuelle) est néfaste.

**Amendement de spec** (appliqué le 2026-11-01) : FR-007 « 60 s par défaut, réglable entre 30 s et
15 min » → « 180 s par défaut, réglable entre 60 s et 15 min ». FR-009 « jamais plus d'une
fois toutes les 30 s » → « 60 s ». Constitution II (plancher 30 s) : rien à changer, 60 s
respecte « pas plus fréquent que 60 s par défaut », mais le plancher de 30 s y est désormais
théorique.

## R5. Fenêtre d'encoche et géométrie

**Decision** : `NSPanel` non activant, pattern boring.notch :
`styleMask = [.borderless, .nonactivatingPanel]`, `level = .mainMenu + 3`,
`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`,
`hidesOnDeactivate = false`, `isFloatingPanel = true`, fond clair, sans ombre,
`orderFrontRegardless()`. Positionnement sur `screen.frame` (jamais `visibleFrame`), bord
haut collé à `frame.maxY`, centré sur `midX`.

Géométrie : `safeAreaInsets.top > 0` ⇒ encoche ; largeur = `frame.width −
auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width`, hauteur = `safeAreaInsets.top`.
Sans encoche ⇒ mode « pilule » 150 × 28 pt sur l'écran principal (`NSScreen.main`
ou `screens.first`). Reconstruire le panneau sur
`NSApplication.didChangeScreenParametersNotification`, en comparant les UUID d'écrans
(la notification tire plusieurs fois).

Survol : `NSTrackingArea` dans le panneau lui-même (pas de moniteur global `mouseMoved`, trop
coûteux en énergie). Délai d'ouverture 150 ms, de fermeture 100 ms. Clic = épinglage ; Échap
et clic hors panneau (moniteur global `leftMouseDown`, actif seulement quand épinglé) ferment.

**Alternatives rejetées** : `NSWindow` + `.statusBar + 8` (NotchDrop) marche aussi mais exige
`canBecomeKey` ; espace CGS privé pour l'écran verrouillé (boring.notch) → API privée, exclue.

## R6. Plein écran

**Decision** : APIs publiques seulement. Sur `NSWorkspace.activeSpaceDidChangeNotification`
et `didChangeScreenParametersNotification`, heuristique : fenêtre de couche 0 de l'app
frontale (`CGWindowListCopyWindowInfo(.optionOnScreenOnly)`) dont les bounds couvrent
`screen.frame` ⇒ plein écran. Faux négatifs acceptés (barre de menus masquée manuellement).
En plein écran : panneau masqué, sauf une bande de 2 pt en haut qui garde une `NSTrackingArea`
pour la réapparition au survol, et un point de 6 pt si une alerte est active.

**Alternatives rejetées** : `CGSCopyManagedDisplaySpaces` (MacroVisionKit) → privé ;
`kAXFullscreenAttribute` → permission Accessibilité, contraire au principe I.

## R7. Énergie et cycle de vie

| Signal | API | Effet |
|---|---|---|
| Veille / réveil | `NSWorkspace.shared.notificationCenter` : `willSleepNotification`, `didWakeNotification` | pause / reprise + relevé dans les 5 s |
| Écrans éteints | `screensDidSleepNotification` / `screensDidWakeNotification` | pause / reprise |
| Verrouillage | `DistributedNotificationCenter` : `com.apple.screenIsLocked` / `screenIsUnlocked` | pause / reprise |
| Économie d'énergie | `ProcessInfo.isLowPowerModeEnabled` + `NSProcessInfoPowerStateDidChange` | pause (FR-008) |
| Planification | `Task.sleep(for:tolerance:)` avec tolérance 10 % | pas de `Timer` |
| Réseau | `URLSession` dédiée, `waitsForConnectivity = true`, timeout 15 s | |

Animations : `TimelineView` / `withAnimation` seulement quand `panel != .collapsed`.
Vérification Instruments (Energy, Allocations) avant release.

## R8. Structure du projet, build et tests

**Decision** :
- `Package.swift` à la racine avec la cible `NotchUsageCore` (Foundation seulement) et
  `NotchUsageCoreTests` (Swift Testing, fixtures JSON).
- App : cible Xcode `NotchUsage` décrite dans `project.yml` et générée par **xcodegen**
  (outil de dev, pas une dépendance du binaire). Le `.xcodeproj` généré n'est pas versionné.
- Xcode 16+ requis : les Command Line Tools seuls ne chargent ni XCTest ni Swift Testing
  (vérifié sur cette machine : `swift test` échoue, `lib_TestingInterop.dylib` absente).
- Localisation : `Localizable.xcstrings`, base anglaise (FR-016a).
- Aucune dépendance SPM externe au MVP.
- Release : `codesign --options runtime --timestamp`, `notarytool submit --wait`, `stapler`,
  DMG, cask Homebrew dans un tap perso (`florentmaille/homebrew-tap`) tant que l'app n'est
  pas assez connue pour le cask officiel.

**Alternatives rejetées** : `.xcodeproj` à la main → diffs illisibles ; Tuist → trop lourd
pour une cible ; SPM seul + script de bundle → pas d'entitlements, d'assets ni d'archive
propres pour la notarisation.

## R9. Trousseau de l'app

**Decision** : `SecItemAdd/CopyMatching/Update/Delete`, `kSecClassGenericPassword`, service
`com.notchusage.credentials`, comptes `oauth-access-token` et `web-session-key`,
`kSecAttrAccessibleAfterFirstUnlock`. Sans sandbox, aucun entitlement. Pas de wrapper tiers.

## Récapitulatif des inconnues levées

| Inconnue | Réponse |
|---|---|
| Source des limites d'abonnement | `api.anthropic.com/api/oauth/usage` (jeton Claude Code) et `claude.ai/api/organizations/{id}/usage` (cookie) : même format |
| Limites par modèle (Fable) | `limits[].kind == "weekly_scoped"`, `scope.model.display_name` |
| Cadence sûre | 180 s par défaut, plancher 60 s, backoff jusqu'à 15 min |
| Refresh du jeton | Jamais depuis l'app |
| Plein écran sans API privée | Heuristique `CGWindowList` + `activeSpaceDidChange` |
| Outillage | Xcode 16+, xcodegen, Swift Testing |

## Risques résiduels

- Endpoints non documentés : parseur tolérant + fixtures + dégradation en « données
  indisponibles ». Suivre CodexBar et ccusage pour les changements de format.
- CGU : note de risque visible, aucune exfiltration, voie Claude Code en premier.
- Dialogue Trousseau à chaque rotation du jeton tant que l'app n'est pas signée Developer ID.
- `utilization` parfois en fraction 0-1 (cc-pool) : à vérifier en live, borner et journaliser.
