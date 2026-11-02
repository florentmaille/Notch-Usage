# Implementation Plan: Encoche prédictive

**Branch**: `003-predictive-notch` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-predictive-notch/spec.md`

## Summary

Refondre l'encoche repliée selon la maquette `docs/design/notch-v8-d1.png` : à gauche la prévision
(coche + réinitialisation, sablier + blocage prévu, flèche + retour, wifi barré, cadenas), à droite le
pourcentage en pastille inversée dès qu'un seuil est franchi. La prévision est une régression linéaire
sur les relevés des 60 dernières minutes (R1), stabilisée par une hystérésis de deux relevés (R2),
limitée à la fenêtre de 5 h (R7), calculée dans le core sans réseau et persistée deux heures avec le
cache existant (R3). Le contenu de l'encoche devient une valeur pure du core, `CompactStrip`, que la
vue se contente de dessiner (contrat compact-strip.md), ce qui rend chaque état testable.

## Technical Context

**Language/Version**: Swift 6, Xcode 16+ (développement sous Xcode 27.2)

**Primary Dependencies**: SwiftUI, AppKit, Foundation ; aucune dépendance externe

**Storage**: `history.json` dans `~/Library/Application Support/NotchUsage/`, à côté de `snapshot.json`

**Testing**: Swift Testing pour `NotchUsageCore` (fixtures de séries de relevés) ; captures en mode démo ;
quickstart manuel

**Target Platform**: macOS 14+

**Project Type**: desktop app (agent) + package Swift

**Performance Goals**: aucune requête ajoutée ; calcul O(n) sur au plus 20 relevés par limite à chaque
relevé et à chaque tick de 30 s ; CPU < 1 %, empreinte inchangée à 2 Mo près

**Constraints**: core Foundation seul ; textes du core fournis par l'app ; aucune animation nouvelle ;
anglais et français ; pilule sans troncature

**Scale/Scope**: 3 limites, 120 relevés d'historique au plus, 8 états d'encoche, ~12 textes nouveaux

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Local-first et vie privée | Aucune connexion nouvelle (FR-014) ; l'historique reste dans le conteneur, effacé à la déconnexion (FR-013) ; aucun secret | PASS |
| II. Sobriété | Pas de timer ni de requête ajoutés ; calcul linéaire sur 20 points ; captures Instruments avant release (SC-004, SC-005) | PASS |
| III. Tests d'abord | `PaceForecaster`, `ForecastDebouncer`, `UsageHistory`, `CompactStrip`, formats de durée : tests écrits avant le code, sur fixtures ; aucune logique dans les vues | PASS |
| IV. YAGNI | Régression linéaire sans bibliothèque ; prévision limitée à la fenêtre de 5 h ; pas de modèle hebdomadaire ; une seule nouvelle valeur persistée | PASS |
| Contraintes techniques | Core sans SwiftUI/AppKit ; pas de dépendance SPM ; entitlements inchangés | PASS |

Re-check après conception : PASS. Un écart assumé, noté ci-dessous : `CompactStrip` reçoit ses textes
localisés de l'app pour rester sans dépendance au catalogue.

## Project Structure

### Documentation (this feature)

```text
specs/003-predictive-notch/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── forecast.md
│   └── compact-strip.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/NotchUsageCore/
├── Models/
│   ├── UsageHistory.swift          # Reading, UsageHistory (nouveau)
│   └── Forecast.swift              # Forecast, ForecastDebouncer (nouveau)
├── Forecast/
│   └── PaceForecaster.swift        # régression et projection (nouveau)
├── Display/
│   ├── CompactStrip.swift          # contenu de l'encoche repliée (nouveau)
│   ├── DisplayState.swift          # forecasts, fetchFailed
│   ├── DisplayStateReducer.swift   # headline par blocage le plus proche
│   ├── RelativeTimeFormatter.swift # duration, blockLabel
│   └── TimeLabels.swift            # libellés de durée nue
└── Credentials/CredentialStore.swift   # SnapshotStore : loadHistory, saveHistory
Tests/NotchUsageCoreTests/
├── PaceForecasterTests.swift
├── ForecastDebouncerTests.swift
├── UsageHistoryTests.swift
├── CompactStripTests.swift
├── DisplayStateReducerTests.swift  # headline
└── RelativeTimeFormatterTests.swift
App/NotchUsage/
├── AppModel.swift                  # historique, prévisions, démo étendue
├── System/FileSnapshotStore.swift  # history.json
├── Views/CompactView.swift         # dessine CompactStrip, pastille, pilule
├── Views/ExpandedView.swift        # ligne « À ce rythme »
└── Resources/Localizable.xcstrings
scripts/demo.swift                  # états de démo et captures (nouveau)
docs/design/notch-v8-d1.png         # maquette de référence
```

**Structure Decision**: structure des features 001 et 002 ; un dossier `Forecast/` dans le core pour
isoler le calcul ; la vue compacte devient une projection d'une valeur testée.

## Complexity Tracking

| Écart | Pourquoi | Alternative rejetée |
|---|---|---|
| `CompactStrip` prend les textes localisés en paramètre | Garder le core sans catalogue de textes ni `Bundle` | Localiser dans le core : dépendance au bundle de l'app, tests moins simples |
