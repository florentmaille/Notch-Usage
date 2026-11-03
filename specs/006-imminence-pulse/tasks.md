# Tasks: Battement d'imminence

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/pulse.md](contracts/pulse.md), [quickstart.md](quickstart.md)

Tests d'abord (constitution III) : chaque tâche de test précède son implémentation et doit échouer avant.

## Phase 1: Setup

- [x] T001 Ajouter l'état `imminent25` (5 h à 85 %, réinitialisation dans 60 min, `blockAt` dans 25 min via `demoForecasts`) à `applyDemo` dans `App/NotchUsage/AppModel.swift` et à la liste `states` de `scripts/demo.swift` ; documenter en tête du script
- [x] T002 Hook debug `com.notchusage.debug.tick` dans `App/NotchUsage/AppModel.swift` (sous `#if DEBUG`, à côté des autres observateurs) qui exécute le corps d'un tick ; commande brute `tick` reconnue par `scripts/demo.swift` (elle passe déjà par le préfixe générique, vérifier et documenter)

## Phase 2: Foundational

Aucune : la feature tient dans une user story.

## Phase 3: US1 - Être rattrapé du coin de l'œil quand le blocage est imminent (P1)

**Objectif** : halo qui respire 1 fois par minute sous 30 min, toutes les 30 s sous 10 min, jamais ailleurs. **Test indépendant** : quickstart 1 à 10, 14.

### Core (rythme)

- [x] T003 [US1] Tests de `NotchSignal.pulse` dans `Tests/NotchUsageCoreTests/NotchSignalTests.swift`, table « Rythme par état » du contrat : `everyMinute` pour `blockAt` à 25 min et à 10 min 00 ; `everyHalfMinute` à 9 min 59 et à 8 min ; `none` à 40 min (`near`), 2 h (`far`), limite épuisée, seuil critique sans prévision, seuil d'attention, `isExpanded` (survol, épinglé), bannière grise, session expirée, silence ; invariant `pulse != .none ⇒ edge == .imminent` ; ils échouent
- [x] T004 [US1] `Sources/NotchUsageCore/Display/NotchSignal.swift` : `enum Pulse: Sendable, Equatable { none, everyMinute, everyHalfMinute }`, champ `public let pulse: Pulse` (valeur `.none` par défaut dans les constructeurs existants), calcul dans la branche `deadline` de `make` à partir de `blockAt - now` et du palier ; T003 vert

### App (cadence)

- [x] T005 [US1] `App/NotchUsage/AppModel.swift` : `private var tickCount = 0`, `private(set) var beat = 0` ; méthode privée `tick()` = `now = Date()`, lecture de `signal.pulse` **avant** `recompute()`, `recompute()`, `tickCount += 1`, puis `beat += 1` si le rythme lu était `everyHalfMinute`, ou `everyMinute` avec `tickCount` pair ; `tickTask` et le hook `tick` (T002) appellent `tick()` ; `recoverIfExpired` reste dans la boucle du `tickTask`

### Vue (rendu)

- [x] T006 [US1] `App/NotchUsage/Views/NotchRootView.swift` : `NotchShape` reçoit `beat: Int` ; le `shadow` du trait (encoche et pilule) prend son opacité d'un `phaseAnimator([0.6, 1.0], trigger: beat)` avec `.easeInOut(duration: 0.3)` par phase quand `edge.hasHalo` ; avec `accessibilityReduceMotion`, opacité fixe 0,6 sans modificateur ; rien d'autre n'est animé (trait, rayon, cadre, `edgePad`)
- [x] T007 [US1] `NotchRootView` passe `model.beat` à `NotchShape` ; vérifier qu'aucune `.animation(value:)` existante ne capture `beat` (le fondu de silence et l'ouverture du panneau restent sur leurs propres valeurs)

### Validation

- [x] T008 [US1] Captures quickstart 3 (`imminent snapshot` vs `imminent tick tick wait=0.3 snapshot`) : mêmes dimensions, trait identique au pixel, halo plus dense ; scénario 10 (25 → 8 min) ; résultats dans `specs/006-imminence-pulse/quickstart.md`
- [x] T009 [US1] Observation quickstart 1, 2, 4 à 8 et 14 (3 min chacun ou `tick` × n), dont pilule (`layout=pill`), survol, épinglé, réduire les animations ; résultats dans quickstart.md

## Phase 4: Polish

- [x] T010 [P] `scripts/check-localizations.sh .build/DerivedData` : 87 textes, 0 sans traduction (quickstart 11)
- [x] T011 [P] Budget : CPU et empreinte sur 10 min en `imminent` (quickstart 12), compteur de requêtes (13) ; archive Release : `strings … | grep -c com.notchusage.debug` = 0 (15) ; résultats dans quickstart.md
- [x] T012 [P] `README.md` : une phrase dans « How it reads » (ligne « A block is coming ») et dans Features (« Warned before the wall » ou « Forecast ») sur la respiration du halo sous 30 min ; `docs/release-notes/` : entrée pour la prochaine version
- [x] T013 Relire `specs/006-imminence-pulse/contracts/pulse.md` et `data-model.md` contre le code ; noter tout écart dans quickstart.md

## Dependencies

- T001, T002 → T005 (le hook `tick` appelle `tick()`), T008, T009
- T003 → T004 → T005 → T006 → T007 → T008 → T009
- T010, T011, T012 après T009 ; T013 en dernier

## Parallel Execution

- T001 et T002 touchent le même fichier (`AppModel.swift`) : en séquence.
- T010, T011, T012 : parallèles (fichiers distincts).

## Implementation Strategy

Une seule story, donc un seul incrément : core (T003-T004) vert avant tout code d'app ; la
cadence (T005) se valide avec `tick` × n et un `print` temporaire de `beat` avant même la vue ;
la vue (T006-T007) se valide par capture à mi-battement. MVP = T001 à T008.
