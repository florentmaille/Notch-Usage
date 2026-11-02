# Tasks: Interface en français

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/time-labels.md](contracts/time-labels.md)

## Phase 1: Foundational (core)

- [x] T001 Écrire les tests de `RelativeTimeFormatter` en français et de `InterfaceLanguage(code:)` dans `Tests/NotchUsageCoreTests/RelativeTimeFormatterTests.swift` (table du contrat) ; ils échouent
- [x] T002 Créer `Sources/NotchUsageCore/Display/TimeLabels.swift` (`InterfaceLanguage`, libellés anglais et français)
- [x] T003 Adapter `Sources/NotchUsageCore/Display/RelativeTimeFormatter.swift` : paramètre `language`, valeur par défaut `.english` ; tests existants inchangés et verts

## Phase 2: US1 - Lire ses limites en français (P1)

- [x] T004 [US1] Créer `App/NotchUsage/System/AppLanguage.swift` : langue de l'interface depuis `Bundle.main.preferredLocalizations`
- [x] T005 [US1] Passer la langue aux appels du formateur dans `CompactView.swift`, `ExpandedView.swift` (lignes de limites, ancienneté, accessibilité)
- [x] T006 [US1] Synchroniser `App/NotchUsage/Resources/Localizable.xcstrings` depuis les `.stringsdata` de la build (`xcstringstool sync`)
- [x] T007 [US1] Traduire en français les textes de l'encoche et du panneau déplié, y compris « FULL » et le bandeau de limite bloquée

## Phase 3: US2 - Connexion et réglages en français (P2)

- [x] T008 [US2] Traduire les textes de `ConnectView`, `SettingsView`, `ConnectionError`, bandeaux d'état et titre de `BrowserLoginWindow`
- [x] T009 [US2] Traduire fidèlement la note de risque

## Phase 4: US3 - VoiceOver en français (P3)

- [x] T010 [US3] Rendre localisables les annonces d'accessibilité construites par interpolation (`CompactView`, `LimitRow`) et les traduire

## Phase 5: US4 - Choix de la langue (P3)

- [x] T015 [US4] Tests de `LanguageChoice` (valeur ↔ préférence `AppleLanguages`) dans `Tests/NotchUsageCoreTests/LanguageChoiceTests.swift` ; ils échouent
- [x] T016 [US4] Créer `Sources/NotchUsageCore/Display/LanguageChoice.swift`
- [x] T017 [US4] Lecture, écriture du choix et redémarrage dans `App/NotchUsage/System/AppLanguage.swift`
- [x] T018 [US4] Section « Langue » dans `SettingsView.swift` (sélecteur à trois valeurs, bouton « Redémarrer ») et traductions

## Phase 6: Polish

- [x] T011 Créer `scripts/check-localizations.sh` (FR-008) et l'ajouter à `.github/workflows/ci.yml` après la build
- [x] T012 Vérifier l'anglais : aucune valeur anglaise ne change par rapport à 0.1.0 (FR-007, SC-002)
- [x] T013 Captures en français via le mode démo (encoche, panneau, reconnexion, réglages) et relecture
- [x] T014 Quickstart manuel, scénarios 1 à 8 (utilisateur)

## Dependencies

T001 → T002 → T003 → T005. T004 → T005. T006 → T007, T008, T010. T011 après T006. T015 → T016 → T017 → T018.
