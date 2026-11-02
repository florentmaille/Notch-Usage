# Tasks: Limites d'abonnement Claude dans l'encoche

**Input**: Design documents from `/specs/001-claude-usage-notch/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Obligatoires sur la logique métier (constitution III, TDD). Chaque tâche de test
est écrite **avant** l'implémentation qu'elle couvre et doit échouer d'abord. Les vues et le
code AppKit/WebKit ne sont pas testés unitairement : ils passent par les scénarios de
[quickstart.md](quickstart.md).

**Organization**: Phases par user story. Chaque story est livrable et testable seule.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallélisable (fichiers différents, aucune dépendance sur une tâche inachevée)
- **[Story]**: US1, US2, US3
- Chemins exacts dans chaque description

## Path Conventions

- Package SPM : `Package.swift`, `Sources/NotchUsageCore/`, `Tests/NotchUsageCoreTests/`
- App : `App/NotchUsage/`, projet généré par `project.yml` (xcodegen)
- Scripts et CI : `scripts/`, `.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: squelette du dépôt, package SPM, projet Xcode généré, CI.

- [x] T001 Vérifier les prérequis de quickstart.md (Xcode 16+ sélectionné via `xcode-select -p`, `xcodegen --version`) et noter les versions dans `specs/001-claude-usage-notch/quickstart.md` section Prérequis
- [x] T002 Créer `Package.swift` (swift-tools-version 6.0, platforms macOS 14, cible `NotchUsageCore` dans `Sources/NotchUsageCore/`, cible de test `NotchUsageCoreTests` dans `Tests/NotchUsageCoreTests/` avec ressources `Fixtures/`) et un fichier `Sources/NotchUsageCore/NotchUsageCore.swift` vide ; `swift build` passe
- [x] T003 [P] Créer `project.yml` (xcodegen) : cible app `NotchUsage` macOS 14, sources `App/NotchUsage/`, dépendance package local `NotchUsageCore`, `Info.plist` avec `LSUIElement = true` et `LSMinimumSystemVersion = 14.0`, entitlements `App/NotchUsage/Resources/NotchUsage.entitlements` (Hardened Runtime, aucun entitlement), Swift 6 strict concurrency, `SWIFT_EMIT_LOC_STRINGS`
- [x] T004 [P] Créer `App/NotchUsage/NotchUsageApp.swift` (`@main`, `NSApplicationDelegateAdaptor`, `AppDelegate` qui met `NSApp.setActivationPolicy(.accessory)`) et `App/NotchUsage/Resources/Assets.xcassets` (icône placeholder) ; `xcodegen generate && xcodebuild build` passe, l'app démarre sans Dock ni fenêtre
- [x] T005 [P] Créer `App/NotchUsage/Resources/Localizable.xcstrings` (base `en`) et la convention : toute chaîne UI passe par `String(localized:)` (FR-016a)
- [x] T006 [P] Créer `.github/workflows/ci.yml` : `swift test` puis `xcodegen generate` + `xcodebuild -scheme NotchUsage build` sur `macos-15`, sans secret
- [x] T007 [P] Mettre à jour `.gitignore` (`*.xcodeproj`, `.build/`, `DerivedData/`) et créer `README.md` avec : but, capture à venir, prérequis, **note de risque** CGU (endpoints non documentés, aucune donnée ne quitte la machine, User-Agent `claude-cli` imité), licence MIT

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: modèles partagés, parseur, fournisseurs, scheduler, Trousseau, fenêtre d'encoche. Tout ce dont US1, US2 et US3 dépendent.

**⚠️ CRITICAL**: aucune story ne commence avant la fin de cette phase.

### Tests (écrits d'abord, doivent échouer)

- [x] T008 [P] Créer les fixtures listées dans contracts/usage-api.md dans `Tests/NotchUsageCoreTests/Fixtures/` : `usage-limits-fable.json`, `usage-limits-two-models.json`, `usage-legacy.json`, `usage-both-forms.json`, `usage-fraction.json`, `usage-epoch-ms.json`, `usage-no-limits.json`, `usage-malformed.json`, `usage-cloudflare.html`, `usage-429.json`, `organizations.json`, `claude-code-credentials.json`, `claude-code-credentials-mcp-only.json` + helper `Tests/NotchUsageCoreTests/Support/Fixture.swift` (`Fixture.data("…")`)
- [x] T009 [P] Écrire `Tests/NotchUsageCoreTests/ResetDateParserTests.swift` : ISO 8601 avec `Z`, avec offset, avec fraction ; epoch secondes (< 10¹¹) ; epoch ms ; chaîne vide et `null` → `nil`
- [x] T010 [P] Écrire `Tests/NotchUsageCoreTests/UsageResponseParserTests.swift` : forme `limits[]` avec Fable → 3 `UsageLimit` dans l'ordre `rollingFiveHour`, `weeklyAll`, `weeklyModel("Fable")` ; forme legacy → `seven_day_sonnet` mappé, `seven_day_opus: null` absent ; `limits[]` + clés plates → aucun doublon ; `utilization` 0…1 partout → ×100 ; valeur 140 → bornée 100 ; `seven_day_cowork` ignoré ; `usage-no-limits.json` → `ParseError.noLimits` ; `usage-malformed.json` → `ParseError.invalidJSON`
- [x] T011 [P] Écrire `Tests/NotchUsageCoreTests/ClaudeCodeCredentialReaderTests.swift` : fixture complète → `accessToken`, `subscriptionType == .max`, `expiresAt` depuis ms float ; fixture `mcp-only` → `CredentialError.missingOAuthSection` ; JSON invalide → `.invalidJSON` ; le `refreshToken` n'apparaît pas dans `ClaudeCodeToken`
- [x] T012 [P] Écrire `Tests/NotchUsageCoreTests/RefreshPolicyTests.swift` : succès → `interval` ; `interval` en dessous de 60 s → ramené à 60 s ; au-dessus de 15 min → 15 min ; 429 sans `Retry-After` → ×2 depuis le délai précédent ; 429 avec `Retry-After: 471` → 471 s ; plafond 15 min ; 5xx et `network` → ×2 ; `unauthorized` → pas de backoff (arrêt)
- [x] T013 [P] Écrire `Tests/NotchUsageCoreTests/FreshnessTests.swift` : `< 2×interval` → `fresh` ; `≥ 2×interval` → `aging` ; `≥ 30 min` → `stale` (prioritaire sur `aging`)
- [x] T014 [P] Écrire `Tests/NotchUsageCoreTests/OAuthUsageProviderTests.swift` avec un `HTTPClient` stub : requête vers `https://api.anthropic.com/api/oauth/usage` avec `Authorization: Bearer`, `anthropic-beta: oauth-2025-04-20`, `User-Agent` commençant par `claude-cli/` ; 200 fixture Fable → snapshot ; 204 → `.emptyBody` ; 401 → `.unauthorized` ; 429 + `Retry-After` → `.rateLimited(retryAfter: 471 s)` ; 503 → `.server(503)` ; `URLError.notConnectedToInternet` → `.network` ; jeton absent du `CredentialStore` → `.credentialsUnavailable`
- [x] T015 [P] Écrire `Tests/NotchUsageCoreTests/WebUsageProviderTests.swift` : `resolveOrganization()` choisit l'org avec `claude_max_5x` même si une org Team est première ; aucune org Pro/Max → `.unsupported` ; requête usage avec `Cookie: sessionKey=…`, `anthropic-client-platform: web_claude_ai`, `Origin`, `Referer` ; 200 `text/html` → `.challenge` ; en-tête `cf-mitigated: challenge` → `.challenge` ; 403 → `.unauthorized`
- [x] T016 [P] Écrire `Tests/NotchUsageCoreTests/RefreshCoordinatorTests.swift` avec `Clock` et `UsageProvider` factices : `start()` émet `loading` puis `idle` ; échec → `failed(reason, previous)` avec le relevé précédent conservé ; `pause(.sleep)` → aucune requête pendant la pause ; `resume()` après plus d'un intervalle → requête immédiate ; `resume()` + `refreshNow()` à moins de 60 s → une seule requête ; `unauthorized` → `reauthRequired` et arrêt de la boucle ; `ParseError.noLimits` → `unsupported`
- [x] T017 [P] Écrire `Tests/NotchUsageCoreTests/NotchGeometryTests.swift` : `safeAreaTop 32`, aux gauche 600, aux droite 600, largeur 1512 → `.notch`, largeur 312, hauteur 32, `originX 600` ; `safeAreaTop 0` → `.pill` 150 × 28 centrée ; aux `nil` avec `safeAreaTop > 0` → `.pill`

### Implémentation `NotchUsageCore`

- [x] T018 [P] Créer les modèles dans `Sources/NotchUsageCore/Models/` : `Account.swift` (`ConnectionMethod { claudeCode, browser }`, `SubscriptionType { pro, max, unsupported }`, `AccountStatus { connected, expired, disconnected }`, `credentialRef: String`, `connectedAt`), `UsageLimit.swift` (`id`, `LimitKind { rollingFiveHour, weeklyAll, weeklyModel }`, `modelName: String?` nil sauf `weeklyModel`, `label`, `utilization: Double` borné 0…100, `resetsAt: Date?`, `isBlocked`), `UsageSnapshot.swift` (`limits` triées `rollingFiveHour`, `weeklyAll`, puis `weeklyModel` par `modelName` ; `fetchedAt` ; `mostConstraining` = plus haute `utilization`, égalité → ordre d'affichage), `FetchState.swift`, `RefreshSettings.swift` (`interval` défaut 180 s, borné 60 s…15 min ; `launchAtLogin` défaut `false`), `FetchError.swift`, `ParseError`, `CredentialError`. Tous `Sendable`, `Equatable`, `Codable` sauf `FetchState`
- [x] T019 [P] Créer `Sources/NotchUsageCore/Support/Clock.swift` (`protocol Clock`, `SystemClock` avec `Task.sleep(for:tolerance:)`) et `Sources/NotchUsageCore/Support/Freshness.swift` (T013)
- [x] T020 [P] Créer `Sources/NotchUsageCore/Support/HTTPClient.swift` (`protocol HTTPClient`, `HTTPResponse { status, headers, body }`, `URLSessionHTTPClient` avec session dédiée, `waitsForConnectivity = true`, timeout 15 s) et `Sources/NotchUsageCore/Credentials/CredentialStore.swift` (`protocol CredentialStore`, `CredentialKey { oauthAccessToken, webSessionKey }`, `protocol ClaudeCodeCredentialSource`, `protocol SnapshotStore`)
- [x] T021 Implémenter `Sources/NotchUsageCore/Parsing/ResetDateParser.swift` (T009 vert)
- [x] T022 Implémenter `Sources/NotchUsageCore/Parsing/UsageResponseParser.swift` selon contracts/usage-api.md : priorité `limits[]`, mapping des kinds, clés plates legacy, ignorer `seven_day_cowork|oauth_apps|routines`, détection fraction, bornage, `noLimits` (T010 vert)
- [x] T023 [P] Implémenter `Sources/NotchUsageCore/Credentials/ClaudeCodeCredentialReader.swift` : `ClaudeCodeToken { accessToken, subscriptionType, expiresAt? }`, ne jamais extraire `refreshToken` (T011 vert)
- [x] T024 [P] Implémenter `Sources/NotchUsageCore/Scheduling/RefreshPolicy.swift` (T012 vert)
- [x] T025 Implémenter `Sources/NotchUsageCore/Providers/UsageProvider.swift` (protocole) et `Sources/NotchUsageCore/Providers/OAuthUsageProvider.swift` : en-têtes du contrat, mapping HTTP → `FetchError`, `User-Agent` constant `claude-cli/2.1.0 (external, cli)` dans `Sources/NotchUsageCore/Providers/UserAgents.swift` (T014 vert)
- [x] T026 Implémenter `Sources/NotchUsageCore/Providers/WebUsageProvider.swift` : `resolveOrganization()` (capabilities `claude_pro` ou préfixe `claude_max`), en-têtes usage4claude, détection Cloudflare (`Content-Type: text/html` ou `cf-mitigated`), `orgUUID` mémorisé (T015 vert)
- [x] T027 Implémenter `Sources/NotchUsageCore/Scheduling/RefreshCoordinator.swift` (actor) : `AsyncStream<FetchState>`, `AsyncStream<AlertEvent>` (vide pour l'instant, branché en US2), `start/pause/resume/refreshNow/stop`, garantie « jamais deux requêtes à moins de 60 s », persistance via `SnapshotStore` (T016 vert)
- [x] T028 [P] Implémenter `Sources/NotchUsageCore/Display/NotchGeometry.swift` (`NotchLayout { mode, width, height, originX }`, pilule 150 × 28) (T017 vert)
- [x] T029 Vérifier que `Sources/NotchUsageCore/` n'importe que `Foundation` (`grep -rn "^import" Sources/NotchUsageCore | grep -v Foundation` vide) et que `swift test` est vert

### Implémentation app (infrastructure)

- [x] T030 [P] Implémenter `App/NotchUsage/Auth/KeychainCredentialStore.swift` : `CredentialStore` via `SecItemAdd/CopyMatching/Update/Delete`, `kSecClassGenericPassword`, service `com.notchusage.credentials`, comptes `oauth-access-token` / `web-session-key`, `kSecAttrAccessibleAfterFirstUnlock`, gestion `errSecItemNotFound` / `errSecDuplicateItem`
- [x] T031 [P] Implémenter `App/NotchUsage/Auth/ClaudeCodeKeychainReader.swift` : `ClaudeCodeCredentialSource`, service `Claude Code-credentials`, compte `NSUserName()`, `kSecUseAuthenticationUI` `.allow` si `interactive`, `.skip` sinon ; aucune valeur journalisée
- [x] T032 [P] Implémenter `App/NotchUsage/System/FileSnapshotStore.swift` : `SnapshotStore` dans `~/Library/Application Support/NotchUsage/` (`snapshot.json`, `alerts.json`), `wipe()` supprime le dossier
- [x] T033 [P] Implémenter `App/NotchUsage/System/PowerObserver.swift` : `NSWorkspace` `willSleep/didWake/screensDidSleep/screensDidWake`, `DistributedNotificationCenter` `com.apple.screenIsLocked/screenIsUnlocked`, `ProcessInfo.isLowPowerModeEnabled` + `NSProcessInfoPowerStateDidChange` → callbacks `pause(reason)` / `resume()`
- [x] T034 [P] Implémenter `App/NotchUsage/Notch/ScreenObserver.swift` : écran principal, lecture de `safeAreaInsets.top`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`, `frame` → `NotchGeometry.layout(...)` ; `NSApplication.didChangeScreenParametersNotification` avec comparaison des UUID d'écrans (`CGDisplayCreateUUIDFromDisplayID`) pour ignorer les doublons
- [x] T035 Implémenter `App/NotchUsage/Notch/NotchPanel.swift` : `NSPanel` `[.borderless, .nonactivatingPanel]`, `level = .mainMenu + 3`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `isFloatingPanel = true`, fond clair, sans ombre, `canBecomeKey = false`, `orderFrontRegardless()`
- [x] T036 Implémenter `App/NotchUsage/Notch/NotchPanelController.swift` : positionne le panneau sur `screen.frame` (bord haut à `frame.maxY`, centré sur `midX`) selon `NotchLayout`, héberge un `NSHostingView` ; `NSTrackingArea` avec délai d'ouverture 150 ms et de fermeture 100 ms ; clic → `pinned` ; moniteur global `leftMouseDown` actif seulement quand épinglé ; Échap ; reconstruction sur changement d'écrans
- [x] T037 Implémenter `App/NotchUsage/AppModel.swift` (`@Observable`, `@MainActor`) : réglages (`UserDefaults`), `Account`, `FetchState`, `DisplayState`, abonnement aux streams du `RefreshCoordinator`, câblage `PowerObserver` → `pause/resume`
- [x] T038 Implémenter `App/NotchUsage/System/Logging.swift` : `Logger(subsystem: "com.notchusage", …)` et une règle de revue : jamais de `sk-ant-` ni de corps de réponse dans les logs

**Checkpoint**: `swift test` vert, l'app affiche un panneau vide dans l'encoche qui s'ouvre au survol et s'épingle au clic.

---

## Phase 3: User Story 1 - Voir ses limites Claude d'un coup d'œil (Priority: P1) 🎯 MVP

**Goal**: connecter un compte (voie Claude Code ou navigateur), afficher la jauge compacte et le panneau détaillé avec chaque limite, son pourcentage et sa réinitialisation.

**Independent Test**: scénarios 1 à 5, 8 et 9 de quickstart.md. Valeurs à ±1 pt de claude.ai/settings/usage.

### Tests for User Story 1

- [x] T039 [P] [US1] Écrire `Tests/NotchUsageCoreTests/DisplayStateReducerTests.swift` : `idle` + limite à 100 % → `blocked` avec temps restant ; `failed` avec `previous` → valeurs précédentes + `unavailable` ; `reauthRequired` → aucune valeur chiffrée ; `unsupported` ; `aging` → ancienneté affichée ; `stale` → marqué périmé ; `hover` → `hoverOpen`, `pinned` → `pinned`, `fullscreen && !hover` → `fullscreenHidden`
- [x] T040 [P] [US1] Écrire `Tests/NotchUsageCoreTests/RelativeTimeFormatterTests.swift` : `resetsAt` dans 2 h 14 → `"in 2h 14m"` ; dans 45 s → `"in 1m"` ; passé → `"reset pending"` ; `nil` → `"—"`

### Implementation for User Story 1

- [x] T041 [P] [US1] Implémenter `Sources/NotchUsageCore/Display/DisplayStateReducer.swift` et `DisplayState` (T039 vert)
- [x] T042 [P] [US1] Implémenter `Sources/NotchUsageCore/Display/RelativeTimeFormatter.swift` (T040 vert)
- [x] T043 [US1] Implémenter `App/NotchUsage/Auth/ConnectionManager.swift` (`@MainActor`) : voie 1 = `ClaudeCodeKeychainReader.readRawJSON(interactive: true)` → `ClaudeCodeCredentialReader` → copie dans `KeychainCredentialStore` → `OAuthUsageProvider` → `refreshNow()` ; sur `unauthorized` ultérieur, relecture `interactive: false`, reprise si le jeton a changé, sinon `Account.status = .expired` ; `signOut()` = `CredentialStore.delete` ×2 + `SnapshotStore.wipe()` + `Account.status = .disconnected` (FR-003)
- [x] T044 [US1] Implémenter `App/NotchUsage/Auth/BrowserLoginWindow.swift` : `NSWindow` avec `WKWebView` sur `https://claude.ai/login`, `WKWebsiteDataStore.default()`, observer `WKHTTPCookieStore` (`cookiesDidChange` + relecture à `didFinish`), détection `sessionKey` préfixé `sk-ant-sid01-` domaine `claude.ai` → `CredentialStore.write(.webSessionKey)` → fermeture ; fenêtre fermée sans cookie → `ConnectionManager` reste `disconnected` sans erreur bloquante ; la fenêtre ne charge que des URL `claude.ai` (navigation externe bloquée)
- [x] T045 [US1] Brancher la voie 2 dans `App/NotchUsage/Auth/ConnectionManager.swift` : après capture, `WebUsageProvider.resolveOrganization()` puis `refreshNow()` ; `.challenge` → état proposant de rouvrir la fenêtre ; champ de secours « Paste session key » (réglages) qui écrit `.webSessionKey` directement
- [x] T046 [P] [US1] Implémenter `App/NotchUsage/Views/ConnectView.swift` : titre, deux boutons « Use Claude Code session » (affiché seulement si l'entrée Trousseau existe, test non interactif) et « Sign in with browser », note de risque CGU, états `connecting` / erreur ; chaînes dans `Localizable.xcstrings`
- [x] T047 [P] [US1] Implémenter `App/NotchUsage/Views/CompactView.swift` : jauge (anneau ou barre) de `mostConstraining`, pourcentage, pictogramme du type de limite (5 h / semaine / modèle), états `blocked`, `unavailable`, `reauth` ; aucune animation quand replié ; accessibilité : `accessibilityLabel` « <label>, <percent> percent, resets <relative> »
- [x] T048 [P] [US1] Implémenter `App/NotchUsage/Views/ExpandedView.swift` : liste des limites (libellé, pourcentage, barre, réinitialisation en heure locale et relative), ancienneté si `aging`/`stale`, bandeau « reconnect required » / « data unavailable » / « plan not supported », boutons « Refresh now », « Settings », « Sign out » ; aucune ligne pour un modèle absent ; VoiceOver sur chaque ligne (FR-016)
- [x] T049 [US1] Câbler dans `App/NotchUsage/AppModel.swift` et `NotchPanelController.swift` : `ConnectView` si `disconnected`, sinon `CompactView` / `ExpandedView` selon `DisplayState.panel` ; relevé < 5 s après `resume()` (FR-008)
- [x] T050 [US1] Implémenter `App/NotchUsage/Views/SettingsView.swift` (section minimale pour US1) : intervalle 60 s…15 min (stepper, défaut 180 s), « Paste session key », « Sign out » ; accessible depuis `ExpandedView`
- [ ] T051 [US1] Valider manuellement les scénarios 1, 2, 3, 4, 5, 8, 9, 13 de quickstart.md et cocher les résultats dans `specs/001-claude-usage-notch/quickstart.md`

**Checkpoint**: MVP livrable. Un abonné voit ses limites dans l'encoche, par l'une ou l'autre voie.

---

## Phase 4: User Story 2 - Être prévenu avant d'atteindre une limite (Priority: P2)

**Goal**: états visuels « attention » (80 %) et « critique » (95 %), une alerte par seuil, par limite et par période, seuils réglables.

**Independent Test**: scénarios 6 et 7 de quickstart.md.

### Tests for User Story 2

- [x] T052 [P] [US2] Écrire `Tests/NotchUsageCoreTests/AlertEvaluatorTests.swift` : 78 → 81 % émet `warning` une fois ; 93 → 96 % émet `critical` ; oscillation 81 → 79 → 82 n'émet rien de plus ; `resetsAt` qui change → registre réinitialisé, nouvelle alerte possible ; `enabled == false` → rien ; `level(for:)` = max des seuils franchis ; validation `warningThreshold` 1…99 strictement < `criticalThreshold` 2…100
- [x] T053 [P] [US2] Écrire `Tests/NotchUsageCoreTests/AlertLedgerCodableTests.swift` : aller-retour JSON de `AlertLedger` et `AlertSettings` (défauts 80 / 95 / `enabled`)

### Implementation for User Story 2

- [x] T054 [P] [US2] Créer `Sources/NotchUsageCore/Models/AlertSettings.swift` (défauts 80, 95, `enabled = true`, invariant `warning < critical`) et `Sources/NotchUsageCore/Models/AlertLedger.swift` (`entries: [String: AlertEntry]`, `AlertEntry { periodKey: Date?, firedLevels: Set<AlertLevel> }`), `AlertLevel { none, warning, critical }`, `AlertEvent { limitID, level }` (T053 vert)
- [x] T055 [US2] Implémenter `Sources/NotchUsageCore/Alerts/AlertEvaluator.swift` selon l'algorithme de data-model.md (T052 vert)
- [x] T056 [US2] Brancher `AlertEvaluator` dans `Sources/NotchUsageCore/Scheduling/RefreshCoordinator.swift` : après chaque snapshot, `evaluate` → `SnapshotStore.saveLedger` → émission sur `alerts` ; mettre à jour `RefreshCoordinatorTests.swift` (un événement par franchissement)
- [x] T057 [US2] Étendre `Sources/NotchUsageCore/Display/DisplayStateReducer.swift` et ses tests : `alertLevel` dérivé de `AlertEvaluator.level(for:)`
- [x] T058 [P] [US2] Styles « warning » (ambre) et « critical » (rouge) dans `App/NotchUsage/Views/CompactView.swift` et mise en évidence de la limite concernée dans `App/NotchUsage/Views/ExpandedView.swift` ; animation brève (≤ 600 ms) à la réception d'un `AlertEvent`, aucune animation continue
- [x] T059 [US2] Section Alerts dans `App/NotchUsage/Views/SettingsView.swift` : toggle `enabled`, deux steppers avec l'invariant appliqué à la saisie, effet au cycle suivant (US2 scénario 4)
- [x] T060 [US2] Valider les scénarios 6 et 7 de quickstart.md

**Checkpoint**: US1 et US2 fonctionnent indépendamment.

---

## Phase 5: User Story 3 - Fonctionner sur un écran sans encoche (Priority: P3)

**Goal**: pilule en haut de l'écran principal sans encoche, repositionnement sur changement d'écrans, comportement en plein écran.

**Independent Test**: scénarios 10 et 11 de quickstart.md.

### Tests for User Story 3

- [x] T061 [P] [US3] Étendre `Tests/NotchUsageCoreTests/NotchGeometryTests.swift` : écran externe 2560 pt sans encoche → pilule centrée `originX 1205` ; écran interne avec encoche redevenu principal → `.notch`
- [x] T062 [P] [US3] Étendre `Tests/NotchUsageCoreTests/DisplayStateReducerTests.swift` : `fullscreen && !hover && alertLevel != .none` → `fullscreenHidden` avec `showAlertDot == true` ; `fullscreen && hover` → panneau visible

### Implementation for User Story 3

- [x] T063 [US3] Mode pilule dans `App/NotchUsage/Notch/NotchPanelController.swift` : fond sombre arrondi 150 × 28 pt quand `layout.mode == .pill`, même tracking area, même épinglage ; transition notch ↔ pilule sur `ScreenObserver` en < 2 s sans fuite de fenêtre (ancien panneau fermé)
- [x] T064 [P] [US3] Implémenter `App/NotchUsage/Notch/FullscreenObserver.swift` : sur `NSWorkspace.activeSpaceDidChangeNotification` et `didChangeScreenParametersNotification`, `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` filtré sur le PID de `NSWorkspace.shared.frontmostApplication`, couche 0, bounds ≈ `screen.frame` (tolérance 2 pt) → `isFullscreen` ; aucune API privée, aucune permission
- [x] T065 [US3] Comportement plein écran dans `App/NotchUsage/Notch/NotchPanelController.swift` : si `fullscreenHidden`, réduire le panneau à une bande de 2 pt en haut qui conserve la `NSTrackingArea` ; survol → affichage complet ; sortie → masquage
- [x] T066 [P] [US3] Implémenter `App/NotchUsage/Views/AlertDotView.swift` : point de 6 pt (ambre / rouge) affiché dans la bande quand `showAlertDot`
- [x] T067 [US3] Valider les scénarios 10 et 11 de quickstart.md (écran externe, couvercle fermé, Safari plein écran)

**Checkpoint**: les trois stories sont fonctionnelles indépendamment.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T068 [P] Implémenter `App/NotchUsage/System/LaunchAtLogin.swift` (`SMAppService.mainApp.register/unregister`, relecture de `.status` à l'activation, `.requiresApproval` affiché comme information) et le toggle dans `SettingsView.swift`, désactivé par défaut (FR-020)
- [x] T069 [P] Passer le budget énergie de quickstart.md (`xctrace` Energy Log 10 min, Activity Monitor) et consigner CPU moyen, empreinte mémoire et nombre de requêtes dans `specs/001-claude-usage-notch/quickstart.md`
- [x] T070 [P] Passer les vérifications vie privée de quickstart.md (grep des hôtes, absence de `sk-ant-` dans les logs) et VoiceOver (scénario 15)
- [x] T071 [P] Créer `scripts/build-app.sh` (xcodegen + `xcodebuild archive`) et `scripts/release.sh` (codesign Developer ID `--options runtime --timestamp`, `notarytool submit --wait`, `stapler staple`, DMG via `hdiutil`, re-zip `ditto -c -k --keepParent`) + modèle `scripts/cask/notch-usage.rb` (`depends_on macos: ">= :sonoma"`, `zap trash:`)
- [x] T072 [P] Compléter `README.md` : capture d'écran, installation (DMG, tap Homebrew), les deux voies de connexion, cadence et limitation de débit, note de risque, dépannage (dialogue Trousseau, challenge Cloudflare, « open Claude Code to renew »)
- [ ] T073 Revue finale constitution : `grep -rn "^import" Sources/NotchUsageCore` = Foundation seul ; aucune dépendance dans `Package.swift` ; aucun entitlement supplémentaire ; `swift test` et CI verts ; scénario 12 (veille) et 14 (login item) de quickstart.md validés

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : immédiat. T003…T007 parallèles après T002.
- **Foundational (Phase 2)** : après Phase 1. Tests T008…T017 parallèles d'abord ; puis
  modèles T018…T020 parallèles ; T021 → T022 ; T023, T024, T028 parallèles ; T025, T026
  après T020 + T022 ; T027 après T024 + T025 ; T029 ferme le package. App : T030…T034
  parallèles après T020 ; T035 → T036 ; T037 après T027 + T033 + T036 ; T038 n'importe quand.
- **US1 (Phase 3)** : après Phase 2. Bloque US2 et US3 en pratique (ils enrichissent ses vues),
  mais chacune reste testable seule.
- **US2 (Phase 4)** : après Phase 2 ; T057 et T058 touchent des fichiers d'US1, donc après US1.
- **US3 (Phase 5)** : après Phase 2 ; T063 et T065 touchent `NotchPanelController.swift`, donc
  après T036 et de préférence après US1.
- **Polish (Phase 6)** : après les stories retenues.

### Within Each User Story

- Tests écrits et rouges avant l'implémentation (constitution III).
- Core avant app, app avant validation quickstart.

### Parallel Opportunities

- Phase 2 : 10 fichiers de tests en parallèle, puis 3 groupes de modèles, puis 5 fichiers
  d'infrastructure app.
- US1 : T041 + T042 (Core) en parallèle avec T046 + T047 + T048 (vues).
- US2 : T052 + T053, puis T054 ; T058 en parallèle de T059.
- US3 : T061 + T062 ; T064 + T066 en parallèle de T063.
- Polish : T068…T072 tous parallèles.

---

## Parallel Example: Phase 2

```bash
# Tests d'abord, tous en parallèle :
Task: "Écrire Tests/NotchUsageCoreTests/ResetDateParserTests.swift"
Task: "Écrire Tests/NotchUsageCoreTests/UsageResponseParserTests.swift"
Task: "Écrire Tests/NotchUsageCoreTests/RefreshPolicyTests.swift"
Task: "Écrire Tests/NotchUsageCoreTests/OAuthUsageProviderTests.swift"
Task: "Écrire Tests/NotchUsageCoreTests/WebUsageProviderTests.swift"

# Puis les modèles :
Task: "Créer Sources/NotchUsageCore/Models/*.swift"
Task: "Créer Sources/NotchUsageCore/Support/Clock.swift + Freshness.swift"
Task: "Créer Sources/NotchUsageCore/Support/HTTPClient.swift + Credentials/CredentialStore.swift"
```

## Parallel Example: User Story 1

```bash
Task: "Implémenter Sources/NotchUsageCore/Display/DisplayStateReducer.swift"
Task: "Implémenter Sources/NotchUsageCore/Display/RelativeTimeFormatter.swift"
Task: "Implémenter App/NotchUsage/Views/ConnectView.swift"
Task: "Implémenter App/NotchUsage/Views/CompactView.swift"
Task: "Implémenter App/NotchUsage/Views/ExpandedView.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 : Setup (T001…T007).
2. Phase 2 : Foundational (T008…T038).
3. Phase 3 : US1 (T039…T051).
4. **STOP et valider** : scénarios 1 à 5, 8, 9, 13 de quickstart.md.
5. Build Debug utilisable au quotidien par l'auteur.

### Incremental Delivery

1. Setup + Foundational → panneau vide fonctionnel dans l'encoche.
2. US1 → MVP : limites visibles.
3. US2 → alertes.
4. US3 → pilule et plein écran.
5. Polish → login item, release signée, cask.

---

## Notes

- 73 tâches : Setup 7, Foundational 31, US1 13, US2 9, US3 7, Polish 6.
- Les tâches de validation manuelle (T051, T060, T067, T069, T070, T073) exigent un compte
  Pro/Max et une machine avec Xcode : elles ne sont pas automatisables en CI.
- Chaque chaîne visible passe par `Localizable.xcstrings` dès la première écriture : pas de
  passe de localisation après coup.
- Commit après chaque groupe logique, message Conventional Commits avec le scope `001`.
