# Implementation Plan: Interface en français

**Branch**: `002-french-localization` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-french-localization/spec.md`

## Summary

Afficher l'interface en français quand la langue du système est le français, en anglais sinon. Les textes
SwiftUI sont déjà localisables : le travail consiste à remplir le catalogue `Localizable.xcstrings` (anglais
source, français), à rendre les durées du core indépendantes de l'anglais via une table de libellés par langue
(research R1), et à ajouter un contrôle automatique des traductions manquantes en CI (R4).

## Technical Context

**Language/Version**: Swift 6, Xcode 16+ (développement sous Xcode 27.2)

**Primary Dependencies**: SwiftUI, AppKit, Foundation ; aucune dépendance externe

**Storage**: N/A (catalogue de textes compilé dans l'app)

**Testing**: Swift Testing pour `NotchUsageCore` ; script de contrôle du catalogue ; quickstart manuel

**Target Platform**: macOS 14+

**Project Type**: desktop app (agent) + package Swift

**Performance Goals**: aucun impact mesurable (libellés résolus à l'affichage)

**Constraints**: core Foundation seul ; anglais strictement identique à 0.1.0 (FR-007)

**Scale/Scope**: ~60 textes d'interface, 8 libellés de durée, 2 langues

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Local-first et vie privée | Aucun réseau, aucune donnée ; seulement des textes | PASS |
| II. Sobriété | Aucun timer ni traitement ajouté | PASS |
| III. Tests d'abord | Tests des durées en anglais et en français écrits avant la table ; contrôle catalogue en CI | PASS |
| IV. YAGNI | Choix de langue appliqué au redémarrage via la préférence par app de macOS (pas de bascule à chaud), deux langues seulement, table simple sans framework | PASS |
| Contraintes techniques | Core Foundation seul (table en Swift), pas de dépendance SPM | PASS |

Re-check après conception : PASS, aucun écart.

## Project Structure

### Documentation (this feature)

```text
specs/002-french-localization/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── time-labels.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/NotchUsageCore/Display/
├── RelativeTimeFormatter.swift   # langue en paramètre
└── TimeLabels.swift              # libellés anglais et français
Tests/NotchUsageCoreTests/
└── RelativeTimeFormatterTests.swift
App/NotchUsage/
├── Resources/Localizable.xcstrings   # anglais source + français
├── System/AppLanguage.swift           # langue de l'interface
└── Views/*.swift                      # appels au formateur avec la langue
scripts/check-localizations.sh
.github/workflows/ci.yml               # étape de contrôle du catalogue
```

**Structure Decision**: structure existante de la feature 001 ; un fichier ajouté au core, un à l'app, un script.

## Complexity Tracking

Aucun écart à justifier.
