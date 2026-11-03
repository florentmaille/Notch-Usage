# Implementation Plan: Battement d'imminence

**Branch**: `006-imminence-pulse` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-imminence-pulse/spec.md`

## Summary

Faire respirer le halo du liseré quand le blocage est imminent (moins de 30 min), une fois par
minute, puis toutes les 30 s sous 10 min. Le core gagne un champ `pulse` sur `NotchSignal`
(`none` / `everyMinute` / `everyHalfMinute`), dérivé du palier et du temps restant. L'app compte
les battements sur le tick de 30 s qui existe déjà dans `AppModel` (`tickTask`) : un compteur
`beat` s'incrémente à chaque tick quand le rythme est 30 s, un tick sur deux quand il est 60 s,
et jamais sur le tick qui vient de faire entrer l'état (R3). La vue anime l'opacité du halo sur
`beat` avec un `phaseAnimator` (0,6 → 1 → 0,6, 600 ms), neutralisé par `reduceMotion`. Aucun
timer, aucune requête, aucun texte.

## Technical Context

**Language/Version**: Swift 6, Xcode 16+ (développement sous Xcode 27.2)

**Primary Dependencies**: SwiftUI, AppKit, Foundation ; aucune dépendance externe

**Storage**: aucun ajout ; le rythme est dérivé, jamais persisté

**Testing**: Swift Testing pour `NotchUsageCore` (`NotchSignalTests` : rythme par palier et
temps restant, exclusions) ; mode démo (`imminent25`, `imminent`) avec une commande `tick` pour
forcer un battement et le capturer ; quickstart manuel (observation 3 min, survol, réduire les
animations, Instruments)

**Target Platform**: macOS 14+ (`phaseAnimator` est disponible depuis macOS 14)

**Project Type**: desktop app (agent) + package Swift

**Performance Goals**: aucune cadence ajoutée : le tick de 30 s existe (`Task.sleep(for: 30 s,
tolerance: 5 s)`) ; un battement = une animation de 600 ms rendue par le compositeur, au plus
deux par minute ; CPU moyen < 1 % en état imminent ; empreinte inchangée

**Constraints**: core Foundation seul ; la vue ne décide pas du rythme ; seule l'opacité du halo
change (ni trait, ni taille, ni largeur du panneau) ; pas de battement au survol, épinglé, en
mode réduit d'animations, ni pendant le fondu d'entrée ; anglais et français sans texte nouveau

**Scale/Scope**: 1 champ dans le core, 1 compteur dans l'app, 1 modificateur de vue, 1 état de
démo et 1 commande de démo

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Local-first et vie privée | Aucune connexion, aucune donnée nouvelle ; rien de persisté | PASS |
| II. Sobriété | Pas de timer : le tick de 30 s existe déjà ; au plus deux animations de 600 ms par minute, uniquement en état imminent, et aucune quand la vue est repliée en silence ; mesure Instruments avant release (SC-005) | PASS |
| III. Tests d'abord | Le rythme (`NotchSignal.pulse`) est une valeur pure du core, testée sur fixtures avant le code ; la vue n'applique que ce que le signal dit | PASS |
| IV. YAGNI | Pas de réglage, pas d'horloge propre, pas d'abstraction : un enum à trois cas et un compteur | PASS |
| Contraintes techniques | Core sans SwiftUI/AppKit ; entitlements inchangés | PASS |

Re-check après conception : PASS. Un écart noté dans Complexity Tracking (commande `tick` de démo).

## Project Structure

### Documentation (this feature)

```text
specs/006-imminence-pulse/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pulse.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/NotchUsageCore/
└── Display/
    └── NotchSignal.swift            # Pulse (rythme), champ pulse, calcul dans make(display:…)
Tests/NotchUsageCoreTests/
└── NotchSignalTests.swift           # rythme par palier et temps restant, exclusions
App/NotchUsage/
├── AppModel.swift                   # beat (compteur), parité du tick, demo imminent25, hook debug tick
└── Views/NotchRootView.swift        # NotchShape : opacité du halo animée sur beat, reduceMotion
scripts/demo.swift                   # état imminent25, commande tick
```

**Structure Decision**: même découpage que la 005 : décision dans le core (`NotchSignal.pulse`),
cadence dans `AppModel` (le seul endroit qui possède le tick), rendu dans `NotchShape`.

## Complexity Tracking

| Écart | Pourquoi | Alternative rejetée |
|---|---|---|
| Commande de démo `tick` (hook `com.notchusage.debug.tick`) qui force un tick | Capturer un battement au milieu de sa course (SC-003) et valider le rythme sans attendre 3 min à chaque essai ; Debug seulement, absent de la build Release comme les autres hooks | Attendre le tick réel (3 min par scénario, capture au hasard) ; un timer de test (horloge supplémentaire, contraire à FR-008) |
