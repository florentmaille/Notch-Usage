# Tasks: Dette d'architecture

- [x] T001 Tests `Tests/NotchUsageCoreTests/BeatCounterTests.swift`, puis `Sources/NotchUsageCore/Display/BeatCounter.swift` ; `AppModel.tick()` l'utilise
- [x] T002 `NotchSignal.collapsesToNotch(in:)` ; `AppModel`, `NotchRootView`, `CompactView` l'appellent
- [x] T003 `ExpandedView.LimitRow.color` via `AlertEvaluator.level(for:settings:)`
- [x] T004 `AppModel` : `OSAllocatedUnfairLock<AlertSettings>` lu par le hook ; `saveAlertSettings` sans redémarrage
- [x] T005 `AppModel` : `pausedReasons`, tick inerte en pause ; `now = Date()` dans `recompute`
- [x] T006 Code mort : `CompactView` ailes réduites à la bande, `RefreshSettings.launchAtLogin`, `AlertEvaluator.level(for snapshot:)` ; tests adaptés
- [x] T007 `App/NotchUsage/AppModel+Demo.swift` ; observateurs retirés dans `stop()` ; `stop()` sans Task orphelin
- [x] T008 `specs/004-limit-shown/spec.md` rétroactive ; constitution 1.1.1 (plancher 60 s)
- [x] T009 `swift test`, build, captures de non-régression (far, imminent, blocked, offline, survol) comparées à la 0.4.1

## Validation (2026-11-03, build Debug)

- 211 tests, 32 suites ; build Debug ; 90 textes, 0 changement de catalogue.
- `AppModel.swift` : 547 → 486 lignes (+ 80 dans `AppModel+Demo.swift`).
- Captures : `far` 458 × 86 px, trait r245 g177 b75 (identique) ; `imminent` et `blocked` 526 × 120 px (débord de halo de la 006, pas de la 009) ; survol : panneau 880 × 560 ; `tick` × 2 en `imminent` : trait éclairci aux deux battements.
- Non rejoué : écran verrouillé (tick inerte), changement de seuil sans redémarrage (journal).
