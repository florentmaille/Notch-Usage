# Implementation Plan: Limites d'abonnement Claude dans l'encoche

**Branch**: `001-claude-usage-notch` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-claude-usage-notch/spec.md`

## Summary

App macOS sans Dock qui affiche dans l'encoche (ou dans une pilule en haut de l'écran) le
pourcentage utilisé des limites de l'abonnement Claude Pro/Max : fenêtre de 5 h, limite
hebdomadaire, limites hebdomadaires par modèle (Fable…), avec l'heure de réinitialisation et
des alertes à 80 % et 95 %. Deux voies de connexion : réutilisation du jeton de Claude Code
(lu dans le Trousseau, jamais rafraîchi par l'app) ou connexion dans une WKWebView qui capture
le cookie `sessionKey`. Les deux voies interrogent des endpoints Anthropic non documentés qui
renvoient le même format, traité par un parseur unique tolérant. Logique métier dans un package
SPM `NotchUsageCore` testé avec Swift Testing sur fixtures ; app SwiftUI + AppKit (`NSPanel`)
générée par xcodegen. Détails : [research.md](research.md).

## Technical Context

**Language/Version**: Swift 6 (mode strict concurrency), toolchain Xcode 16+

**Primary Dependencies**: Foundation, SwiftUI, AppKit, WebKit, Security, ServiceManagement.
Aucune dépendance SPM externe. Outil de dev : xcodegen (génère le `.xcodeproj`).

**Storage**: Trousseau (secrets, `SecItem`), `UserDefaults` (réglages), fichiers JSON dans
`Application Support/NotchUsage/` (dernier relevé, registre d'alertes)

**Testing**: Swift Testing (`swift test` sur `NotchUsageCore`), fixtures JSON versionnées,
aucun appel réseau en CI. Instruments (Energy, Allocations) avant release.

**Target Platform**: macOS 14+, Apple Silicon et Intel, écran avec ou sans encoche

**Project Type**: desktop-app (agent `LSUIElement`, sans fenêtre principale)

**Performance Goals**: panneau ouvert < 200 ms après survol (SC-003) ; relevé affiché
< 5 s après réveil ; repositionnement < 2 s après changement d'écrans

**Constraints**: CPU au repos < 1 %, RSS < 60 Mo (constitution II) ; polling 180 s par défaut,
plancher 60 s, backoff plafonné 15 min (R4) ; aucune API privée ; aucune permission TCC
(ni Accessibilité ni Accès complet au disque) ; secrets uniquement dans le Trousseau

**Scale/Scope**: un compte, 3 à 6 limites, ~6 vues, 2 fournisseurs de données,
~2 500 lignes Swift estimées

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Vérification | Avant recherche | Après design |
|---|---|---|---|
| I. Local-first | Hôtes réseau : `api.anthropic.com`, `claude.ai` seulement (R1, R2). WKWebView ne charge que `claude.ai`. Secrets : Trousseau de l'app (R9) ; jeton Claude Code copié, jamais journalisé. Pas de télémétrie. Dernier relevé effaçable à la déconnexion (FR-003) | PASS | PASS |
| II. Sobriété | 180 s par défaut ≥ 60 s ; pause veille / verrou / économie d'énergie (R7) ; pas de moniteur global `mouseMoved` (R5) ; animations seulement panneau ouvert ; vérification Instruments en tâche de release | PASS | PASS |
| III. Tests d'abord | `NotchUsageCore` sans SwiftUI ni AppKit ; parseur, scheduler, évaluateur d'alertes, fraîcheur, géométrie d'encoche (pure, à partir de valeurs) testés sur fixtures ; `swift test` en CI | PASS | PASS |
| IV. Simplicité | 0 dépendance SPM ; 1 package + 1 cible app ; pas de couche d'injection : protocoles `UsageProvider`, `CredentialStore`, `Clock` injectés par init. xcodegen = outil de dev, justifié ci-dessous | PASS | PASS (1 point tracé) |
| Workflow | Branche `001-claude-usage-notch`, PR vers `main`, CI build + test | PASS | PASS |

**Écart signalé** : R4 contredit FR-007 / FR-009 (cadence). Le plan suit R4 ; l'amendement
de la spec a été appliqué le 2026-11-01 (FR-007, FR-009).

## Project Structure

### Documentation (this feature)

```text
specs/001-claude-usage-notch/
├── plan.md              # Ce fichier
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   ├── usage-api.md     # Endpoints externes, formats, erreurs
│   └── core-interfaces.md  # Protocoles publics de NotchUsageCore
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
Package.swift                        # NotchUsageCore + tests (SPM)
project.yml                          # xcodegen → NotchUsage.xcodeproj (non versionné)

Sources/NotchUsageCore/              # Foundation seulement, Sendable, testable
├── Models/
│   ├── Account.swift
│   ├── UsageLimit.swift
│   ├── UsageSnapshot.swift
│   ├── FetchState.swift
│   ├── AlertSettings.swift
│   ├── AlertLedger.swift
│   └── RefreshSettings.swift
├── Parsing/
│   ├── UsageResponseParser.swift    # legacy + limits[] → [UsageLimit]
│   └── ResetDateParser.swift        # ISO 8601 / epoch s / epoch ms
├── Providers/
│   ├── UsageProvider.swift          # protocol
│   ├── OAuthUsageProvider.swift     # api.anthropic.com
│   ├── WebUsageProvider.swift       # claude.ai (orgs + usage)
│   └── HTTPClient.swift             # protocol + URLSession impl, headers
├── Credentials/
│   ├── CredentialStore.swift        # protocol (get/set/delete)
│   └── ClaudeCodeCredentialReader.swift  # parse du JSON Keychain de Claude Code
├── Scheduling/
│   ├── RefreshPolicy.swift          # intervalle, backoff, Retry-After (pure)
│   └── RefreshCoordinator.swift     # actor : boucle, pause/reprise, états
├── Alerts/
│   └── AlertEvaluator.swift         # evaluate(snapshot, settings, ledger)
├── Display/
│   ├── NotchGeometry.swift          # calcul à partir de valeurs (pas de NSScreen)
│   └── DisplayStateReducer.swift
└── Support/
    ├── Clock.swift                  # protocol, SystemClock
    └── Freshness.swift

Tests/NotchUsageCoreTests/
├── Fixtures/
│   ├── usage-legacy.json
│   ├── usage-limits-fable.json
│   ├── usage-empty-204.txt
│   ├── usage-429.json
│   ├── usage-cloudflare.html
│   ├── organizations.json
│   └── claude-code-credentials.json
├── UsageResponseParserTests.swift
├── ResetDateParserTests.swift
├── RefreshPolicyTests.swift
├── RefreshCoordinatorTests.swift
├── AlertEvaluatorTests.swift
├── FreshnessTests.swift
├── NotchGeometryTests.swift
├── OAuthUsageProviderTests.swift     # HTTPClient stub
├── WebUsageProviderTests.swift
└── ClaudeCodeCredentialReaderTests.swift

App/NotchUsage/                       # cible Xcode, SwiftUI + AppKit
├── NotchUsageApp.swift               # @main, LSUIElement, AppDelegate
├── AppModel.swift                    # @Observable, relie Core ↔ UI
├── Notch/
│   ├── NotchPanel.swift              # NSPanel non activant (R5)
│   ├── NotchPanelController.swift    # position, tracking area, pin, Échap
│   ├── ScreenObserver.swift          # didChangeScreenParameters, UUID écrans
│   └── FullscreenObserver.swift      # heuristique CGWindowList (R6)
├── Views/
│   ├── CompactView.swift             # jauge + indicateur de limite
│   ├── ExpandedView.swift            # liste des limites, ancienneté, états
│   ├── ConnectView.swift             # choix voie 1 / voie 2, note de risque
│   ├── SettingsView.swift            # seuils, intervalle, login item, déconnexion
│   └── AlertDotView.swift            # point discret en plein écran
├── Auth/
│   ├── ClaudeCodeKeychainReader.swift  # SecItem sur l'entrée de Claude Code, UI skip/allow
│   ├── BrowserLoginWindow.swift        # WKWebView + WKHTTPCookieStore
│   └── KeychainCredentialStore.swift   # CredentialStore via SecItem (R9)
├── System/
│   ├── PowerObserver.swift           # veille, verrou, low power
│   └── LaunchAtLogin.swift           # SMAppService
└── Resources/
    ├── Info.plist                    # LSUIElement, LSMinimumSystemVersion 14.0
    ├── NotchUsage.entitlements       # Hardened Runtime, aucun entitlement supplémentaire
    ├── Localizable.xcstrings
    └── Assets.xcassets

scripts/
├── build-app.sh                      # xcodegen + xcodebuild archive
├── release.sh                        # codesign, notarytool, stapler, DMG
└── cask/notch-usage.rb               # modèle de cask pour le tap

.github/workflows/ci.yml              # swift test + xcodebuild build
```

**Structure Decision** : un package SPM pour la logique (`Sources/NotchUsageCore`,
`Tests/NotchUsageCoreTests`) et une cible app dans `App/NotchUsage` qui dépend du package
local. La frontière est stricte : `NotchUsageCore` n'importe ni SwiftUI, ni AppKit, ni
WebKit, ni Security. Tout ce qui touche à ces frameworks vit dans `App/` derrière les
protocoles de [contracts/core-interfaces.md](contracts/core-interfaces.md).

## Phase 0 : Research

Terminée : [research.md](research.md). Toutes les inconnues du contexte technique sont levées.
Une décision (R4, cadence) nécessite un amendement de la spec.

## Phase 1 : Design

- [data-model.md](data-model.md) : entités, transitions, persistance, algorithme d'alerte.
- [contracts/usage-api.md](contracts/usage-api.md) : les deux endpoints, en-têtes, formes de
  réponse, mapping des erreurs, fixtures.
- [contracts/core-interfaces.md](contracts/core-interfaces.md) : protocoles publics du package.
- [quickstart.md](quickstart.md) : prérequis, build, tests, scénarios de validation manuelle.

### Flux principaux

**Démarrage** : `AppDelegate` → `AppModel` charge réglages + dernier relevé → `ScreenObserver`
crée `NotchPanel` (mode notch ou pilule) → si `Account.status == connected`,
`RefreshCoordinator.start()`.

**Cycle de relevé** (`RefreshCoordinator`, actor) :
`sleep(interval)` → `provider.fetch()` → `parser` → `snapshot` → `AlertEvaluator` →
publication `(FetchState, AlertEvents)` → `AppModel` met à jour `DisplayState`. Erreurs →
`RefreshPolicy.next(after:)` décide du délai. Pause/reprise pilotées par `PowerObserver`.

**Connexion voie 1** : bouton « Use Claude Code session » → lecture de l'entrée Trousseau
de Claude Code avec UI autorisée (dialogue macOS possible) → parse → copie du jeton dans le
Trousseau de l'app → `OAuthUsageProvider` → premier relevé → `connected`. Sur 401 ultérieur :
relecture silencieuse (`.skip`) de l'entrée Claude Code ; si le jeton a changé, on le reprend,
sinon `reauthRequired`.

**Connexion voie 2** : bouton « Sign in with browser » → `BrowserLoginWindow` → cookie
`sessionKey` capturé → Trousseau → `WebUsageProvider.resolveOrganization()` → premier relevé.

**Affichage** : `DisplayStateReducer(snapshot, settings, screen, fullscreen, hover, pin)` →
`DisplayState` → `CompactView` / `ExpandedView` / `AlertDotView`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Outil de dev xcodegen (hors « Foundation, SwiftUI et AppKit d'abord ») | Produire un `.xcodeproj` reproductible avec entitlements, assets, String Catalog et archive notarisable, sans versionner un `pbxproj` | `.xcodeproj` manuel : diffs illisibles, conflits ; SPM seul : pas d'entitlements ni d'archive propre pour la notarisation (R8). Ce n'est pas une dépendance du binaire |

## Post-Design Constitution Check

Réévalué après la Phase 1 : aucun nouvel hôte réseau, aucune API privée, aucune permission
TCC, aucune dépendance SPM. Le seul point tracé reste xcodegen. **PASS**.

## Next Actions

1. ~~Amendement de cadence (R4)~~ : appliqué.
2. Installer Xcode 16+ et xcodegen (`brew install xcodegen`) : voir
   [quickstart.md](quickstart.md).
3. `/speckit-tasks`.
