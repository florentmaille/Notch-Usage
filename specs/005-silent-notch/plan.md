# Implementation Plan: Encoche silencieuse et liseré d'échéance

**Branch**: `005-silent-notch` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-silent-notch/spec.md`

## Summary

Faire taire l'encoche repliée quand il n'y a rien à dire, et la faire parler par un liseré coloré
le long de son bord inférieur quand un blocage approche. Le core gagne une valeur pure,
`NotchSignal`, dérivée de `DisplayState` : silence ; bande complète (survol, épinglage, hors
ligne, session) ; donnée unique avec palier d'échéance ; épuisement ; seuil sans prévision.
L'app dessine ce que le signal dit : oreilles et textes uniquement quand il y a un texte, liseré
par palier, fondu unique de 600 ms, et un panneau réduit à la largeur de l'encoche physique en
état calme pour que la zone de survol soit celle de l'encoche (R2). La bande de la feature 003
(`CompactStrip`) reste intacte pour le survol et l'accessibilité.

## Technical Context

**Language/Version**: Swift 6, Xcode 16+ (développement sous Xcode 27.2)

**Primary Dependencies**: SwiftUI, AppKit, Foundation ; aucune dépendance externe

**Storage**: aucun ajout ; le signal est dérivé, jamais persisté

**Testing**: Swift Testing pour `NotchUsageCore` (`NotchSignalTests`, paliers, priorité prévision/seuil) ;
captures en mode démo sur fond clair et sombre, en encoche et en pilule ; quickstart manuel
(survol, VoiceOver, Instruments)

**Target Platform**: macOS 14+

**Project Type**: desktop app (agent) + package Swift

**Performance Goals**: aucun calcul périodique ajouté (le signal se dérive à chaque `recompute`,
déjà déclenché par le tick de 30 s) ; aucune animation continue ; CPU < 1 % au repos et en état
signalant ; empreinte inchangée à 2 Mo près

**Constraints**: core Foundation seul ; textes du core fournis par l'app ; liseré visible sur fond
clair et sombre ; mode réduit d'animations respecté ; survol limité à l'encoche physique en état
calme ; anglais et français

**Scale/Scope**: 7 contenus de signal, 4 paliers, ~6 textes nouveaux, 3 états de démo nouveaux

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Local-first et vie privée | Aucune connexion, aucune donnée nouvelle (FR-020) ; rien de persisté | PASS |
| II. Sobriété | Pas de timer ni de requête ; liseré statique (un trait, pas de pulsation continue) ; fondu unique de 600 ms, supprimé en mode réduit d'animations ; mesure Instruments avant release (SC-005) | PASS |
| III. Tests d'abord | `NotchSignal` (contenu, palier, priorité prévision/seuil, limite épinglée) testé sur fixtures avant le code ; aucune décision dans les vues | PASS |
| IV. YAGNI | Pas de dépendance ; `CompactStrip` réutilisé tel quel pour la bande ; un seul nouveau type dans le core | PASS |
| Contraintes techniques | Core sans SwiftUI/AppKit ; entitlements inchangés | PASS |

Re-check après conception : PASS. Deux écarts notés dans Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/005-silent-notch/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── notch-signal.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/NotchUsageCore/
└── Display/
    ├── NotchSignal.swift            # NotchSignal, Edge (palier), make(display:…) (nouveau)
    └── CompactStrip.swift           # Strings : shortLabel (libellé court « 7d » / « 5h »)
Tests/NotchUsageCoreTests/
└── NotchSignalTests.swift           # contenus, paliers, priorité prévision/seuil, épinglage
App/NotchUsage/
├── AppModel.swift                   # signal dérivé, demo far/near/imminent, panneau informé du silence
├── Notch/NotchPanelController.swift # largeur = encoche physique en silence, rétrécissement différé
├── Views/NotchRootView.swift        # oreilles conditionnelles, liseré, fondu, accessibilité
├── Views/CompactView.swift          # dessine NotchSignal.Content (bande, donnée unique, épuisé, seuil)
├── Views/AlertDotView.swift         # bande masquée colorée par le palier en plein écran
└── Resources/Localizable.xcstrings
scripts/demo.swift                   # états far, near, imminent
docs/design/notch-pistes-halo.png    # planche de référence
docs/images/states.png               # capture README régénérée
```

**Structure Decision**: structure des features 001 à 004 ; un seul nouveau type dans le core, à
côté de `CompactStrip` dont il réutilise les textes et la bande.

## Complexity Tracking

| Écart | Pourquoi | Alternative rejetée |
|---|---|---|
| `NotchSignal` distinct de `CompactStrip` au lieu d'étendre `CompactStrip` | La bande complète reste exactement celle de la 003 pour le survol, l'épinglage et VoiceOver ; le signal est une couche au-dessus, testée seule | Ajouter des cas à `Left`/`Right` : mélange deux modes d'affichage dans un type, et casse les 14 tests existants |
| Rétrécissement différé du panneau (600 ms) au retour au silence | Le fondu de sortie (FR-011) a besoin que les oreilles existent encore pendant 600 ms ; le panneau ne peut pas rétrécir avant | Rétrécir aussitôt : le fondu de sortie est coupé ; garder le panneau large en permanence : zone de survol et clics invisibles sur la barre des menus (R2) |
