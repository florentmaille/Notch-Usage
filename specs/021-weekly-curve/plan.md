# Implementation Plan: Courbe de la semaine

**Branch** : `021-weekly-curve` | **Date** : 2026-11-10 | **Spec** : [spec.md](spec.md) | **Research** : [research.md](research.md) | **Planche** : [weekly-history.png](../../docs/design/weekly-history.png) (C1)

## Summary

Historique d'un relevé par heure sur 8 jours (core, local) ; courbe de la limite hebdomadaire et projection reprise de la 016 (core, pur) ; section repliable « Cette semaine » dans le panneau partagé (app).

## Technical Context

- **Stack** : Swift 6, rien de nouveau.
- **Tests** : `HourlyHistory` et `WeekCurve` en TDD dans le core.
- **Stockage** : `weekly.json`, moins de 20 Ko.
- **Performance** : aucun timer, enrichissement aux relevés existants.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Données locales, effacées par `wipe()`, aucune connexion. | PASS |
| II. Sobriété | Aucun timer, 192 points au plus par limite, aucune animation continue. | PASS |
| III. Tests | Historique et courbe dans le core, tests avant code. | PASS |
| IV. YAGNI | Limite hebdomadaire toutes modèles seulement, pas de base de données, pas de nouveau modèle de prévision. | PASS |

## Project Structure

```text
Sources/NotchUsageCore/Models/HourlyHistory.swift      # NOUVEAU
Sources/NotchUsageCore/Display/WeekCurve.swift          # NOUVEAU
Sources/NotchUsageCore/Credentials/CredentialStore.swift # SnapshotStore : load/saveHourlyHistory
Tests/NotchUsageCoreTests/HourlyHistoryTests.swift, WeekCurveTests.swift  # NOUVEAUX
Tests/NotchUsageCoreTests/Support/Stubs.swift           # MemorySnapshotStore
App/NotchUsage/System/FileSnapshotStore.swift            # weekly.json
App/NotchUsage/AppModel.swift                            # chargement, record, déconnexion, weekCurve
App/NotchUsage/AppModel+Demo.swift                       # semaine fictive
App/NotchUsage/Views/WeekSection.swift                   # NOUVEAU
App/NotchUsage/Views/ExpandedView.swift                  # section sous les limites
App/NotchUsage/Resources/Localizable.xcstrings           # textes EN/FR
```

## Complexity Tracking

Aucune violation.
