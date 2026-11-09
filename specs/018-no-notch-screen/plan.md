# Implementation Plan: Écran sans encoche

**Branch**: `018-no-notch-screen` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md) | **Spike**: [spike-statusitem.md](spike-statusitem.md) | **Planche**: [external-screen.png](../../docs/design/external-screen.png)

## Summary

L'île ne s'affiche plus que sur l'écran à encoche ; la pilule disparaît. Sur les écrans sans encoche, deux surfaces rendent le même contenu, dérivé de `NotchSignal` : l'**item de barre de menus** enrichi (socle, présent sur chaque barre, compact quand la barre active est celle de l'écran à encoche) et, en option, une **pastille centrée** dans la barre de chaque écran d'au moins 1700 pt. Le clic sur l'item ouvre un popover ; le survol de la pastille ouvre une carte. Les deux hébergent la vue de contenu du panneau de l'île, extraite pour être partagée.

Le core porte la décision : rôle des écrans (`ScreenRoles`), contenu de barre (`BarContent`), mode d'icône (`MenuBarIconMode`). L'app ajoute le rendu de l'item, le popover, les panneaux de pastille et l'observation de la barre active.

## Technical Context

**Language/Version** : Swift 6, concurrence stricte. **Dependencies** : Foundation, SwiftUI, AppKit ; rien de nouveau (constitution IV). **Storage** : `UserDefaults` : `menuBarIconMode` (remplace `showsMenuBarIcon`, migré), `showsCenterCapsule`. **Testing** : Swift Testing ; `NotchUsageCoreTests` en TDD (`ScreenRoles`, `BarContent`, `MenuBarIconMode`, `NotchGeometry` sans pilule) ; `NotchUsageAppTests` pour le dessin de l'item (tailles, variantes claire et sombre). **Target** : macOS 14+, app non sandboxée, entitlements inchangés. **Performance** : aucun timer nouveau ; l'image de l'item et la pastille ne changent que si `BarContent` change ; battement sur le `beat` existant. **Constraints** : CPU < 1 %, empreinte < 60 Mo (une fenêtre par pastille, 1 à 2 en pratique), pas de permission Accessibilité. **Scope** : ~4 fichiers core, ~6 fichiers app, 2 réglages, ~6 textes, mise à jour README.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Aucune connexion réseau, aucune donnée nouvelle. Aucune permission (Accessibilité refusée par choix, R4 et spec). | PASS |
| II. Sobriété | Événementiel : changement d'écran, changement de barre active, changement de `BarContent`. Aucun polling, aucun timer ; le battement réutilise celui de la 006. Panneaux de pastille créés seulement si l'option est active et l'écran éligible. | PASS |
| III. Tests | Rôle des écrans, contenu de barre (états du tableau « Contenu par état »), migration du réglage : core, tests avant code. | PASS |
| IV. YAGNI | Pas d'abstraction « surface » générique : deux rendus concrets d'un même `BarContent`. Pas de lecture des menus des apps. La pilule est supprimée, pas gardée en option. | PASS |
| Entitlements | Inchangés. | PASS |

Re-vérifié après la phase 1 : inchangé.

## Research

Voir [research.md](research.md) : R1 rôle des écrans et retrait de la pilule ; R2 `BarContent` partagé ; R3 image à `drawingHandler` pour l'item ; R4 item compact selon la barre active (spike confirmé) ; R5 popover et clic droit ; R6 pastille et carte ; R7 plein écran par écran ; R8 réglage à trois valeurs et migration ; R9 mode démo.

## Project Structure

### Documentation (this feature)

```text
specs/018-no-notch-screen/
├── plan.md, research.md, data-model.md, quickstart.md
├── spike-statusitem.md, spike-statusitem/main.swift
├── contracts/surfaces.md      # rendu de l'item, de la pastille, du popover et de la carte par état
└── tasks.md                   # /speckit-tasks
```

### Source Code

```text
Sources/NotchUsageCore/
├── Display/ScreenRoles.swift        # NOUVEAU : écran de l'île, écrans sans encoche, éligibilité pastille
├── Display/BarContent.swift         # NOUVEAU : jauge, texte, attente Claude, variante compacte, depuis NotchSignal
├── Display/NotchGeometry.swift      # layout -> NotchLayout? ; DisplayMode.pill supprimé
├── Display/DisplayState.swift       # layout optionnel (pas d'île sans écran à encoche)
└── Models/MenuBarIconMode.swift     # NOUVEAU : automatic | always | never, migration, visibilité

App/NotchUsage/
├── Notch/ScreenObserver.swift       # publie ScreenRoles au lieu de screens.first
├── Notch/StatusItemController.swift # longueur variable, image BarContent, popover, clic droit, barre active (R4)
├── Notch/BarContentImage.swift      # NOUVEAU : dessin de l'item (anneau, texte, glyphe) selon l'apparence
├── Notch/CapsulePanelController.swift # NOUVEAU : pastille + carte par écran éligible, survol
├── Notch/FullscreenObserver.swift   # plusieurs écrans -> ensemble des écrans couverts
├── Notch/NotchPanelController.swift # branche pilule retirée
├── Views/PanelContentView.swift     # NOUVEAU : contenu extrait de NotchRootView (connexion, limites, réglages)
├── Views/CapsuleView.swift          # NOUVEAU : rendu SwiftUI de la pastille et du point plein écran
├── Views/NotchRootView.swift        # utilise PanelContentView ; NotchShape sans pilule
├── Views/SettingsView.swift         # sélecteur Icône (Automatique, Toujours, Jamais) + bascule Pastille centrée
├── AppModel.swift                   # rôles d'écran, île optionnelle, item, pastilles, exclusion popover / île
├── AppModel+Demo.swift              # "nonotch", menubar notch|external (R9)
└── Resources/Localizable.xcstrings  # textes nouveaux EN/FR

Tests/NotchUsageCoreTests/
├── ScreenRolesTests.swift, BarContentTests.swift, MenuBarIconModeTests.swift   # NOUVEAUX
└── NotchGeometryTests.swift, DisplayStateReducerTests.swift                    # sans pilule
Tests/NotchUsageAppTests/AppPresentationTests.swift   # tailles de l'item, variantes d'apparence
```

**Structure Decision** : structure existante (core sans AppKit + app), aucun module nouveau.

## Ordre de réalisation

1. ~~T001 spike manuel~~ : fait, notification confirmée (R4).
2. **US2 + socle core** : `ScreenRoles`, `NotchGeometry` sans pilule, île optionnelle. L'app reste utilisable : l'item 014 existant couvre l'externe.
3. **US1** : `BarContent`, image enrichie, popover, clic droit, compact selon la barre active, `MenuBarIconMode`.
4. **US3** : pastille, carte, plein écran par écran.
5. **US4** : réglages, VoiceOver, traductions, README et captures (planche et captures réelles).

## Risques

| Risque | Effet | Parade |
|---|---|---|
| Apparence de la barre mal devinée pour la pastille sans item | Voile peu contrasté | R6 : appearance de l'item quand il existe ; limite documentée |
| Menus d'app qui dépassent le centre sur un écran ≥ 1700 pt | Chevauchement | Accepté (spec) ; seuil ajustable après essais |
| Niveau de fenêtre de la pastille sous la barre de menus | Pastille invisible | Même niveau que `NotchPanel` (`mainMenu + 3`), déjà éprouvé par la pilule |

## Complexity Tracking

Aucune violation.
