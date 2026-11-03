# Tasks: Signal honnête

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1: US1 - La limite la plus menaçante

- [x] T001 [US1] Tests `Tests/NotchUsageCoreTests/HeadlinePickerTests.swift` (6 scénarios + sans 5 h + seuils désactivés) ; ils échouent
- [x] T002 [US1] `Sources/NotchUsageCore/Display/HeadlinePicker.swift` : `severity(of:forecast:settings:now:)`, `pick(in:forecasts:settings:now:)` ; suppression de `HeadlineChoice.swift` et de ses tests
- [x] T003 [US1] `DisplayStateReducer.reduce(..., alertSettings:)` ; tests reducer et `NotchSignalTests` adaptés
- [x] T004 [US1] `App/NotchUsage/AppModel.swift` : picker dans `recompute`, suppression de `headlineChoice`, `headlineKey`, `setHeadlineChoice` ; `SettingsView` sans section Notch ; `LimitLabel.text(forID:)` retiré

## Phase 2: US2 - Notifications

- [x] T005 [US2] Tests `NotificationGateTests.swift` ; `Sources/NotchUsageCore/Alerts/NotificationGate.swift`
- [x] T006 [US2] `AlertSettings.notifications` avec décodage tolérant ; `setNotificationsEnabled` ; interrupteur dans `SettingsView`
- [x] T007 [US2] `App/NotchUsage/Alerts/SignalNotifier.swift` : motif d'après le signal, autorisation à la première notification, textes localisés ; appel dans `recompute`

## Phase 3: US3 - Plein écran et prévision

- [x] T008 [US3] `AlertDotView` : visible dès qu'un liseré existe, couleur du palier, battement sur `beat` ; `NotchRootView` passe `beat`
- [x] T009 [US3] `ExpandedView` : « At this pace (last hour): blocked at %@ » ; catalogue en + fr, clés 004 retirées

## Phase 4: Polish

- [x] T010 `swift test`, build, `check-localizations` ; démo `imminent` : une notification, `tick` × 10 n'en ajoute pas
- [x] T011 `README.md` (features, réglages), `docs/release-notes/0.4.1-preview.md`

## Validation (2026-11-03, build Debug)

- 208 tests, 31 suites ; build Debug ; 90 textes, 0 sans traduction, 0 obsolète (6 clés 004 retirées, « Notch » retirée).
- Démo `imminent` puis `tick` × 3 : une seule demande de notification (l'envoi attend la réponse à la demande d'autorisation macOS, affichée à la première notification) ; démo `blocked` : une notification « Limite atteinte » journalisée.
- Non rejoué : hebdo à 97 % en démo (pas d'état démo dédié ; couvert par `HeadlinePickerTests` et `signalFollowsTheMostThreateningLimit`).
