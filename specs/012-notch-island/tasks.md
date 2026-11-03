# Tasks: Île de chaque côté de l'encoche

## Phase 1: US1 - L'île dans l'encoche

- [x] T001 [US1] Tests `IslandFormat.deadline` et île par état (table du contrat) dans `Tests/NotchUsageCoreTests/NotchSignalTests.swift` ; ils échouent
- [x] T002 [US1] `Sources/NotchUsageCore/Display/NotchSignal.swift` : `Island` (leading, trailing, tint), `IslandFormat`, calcul dans `make` ; T001 vert
- [x] T003 [US1] `NotchPanelController.apply(_:ears:)` : cadre asymétrique, rétrécissement différé 0,3 s ; `AppModel` passe les oreilles
- [x] T004 [US1] `NotchRootView` : forme noire pleine, liseré, cerne et `BeatingStroke` retirés
- [x] T005 [US1] `CompactView` : île (jauge ou glyphe, donnée) ; bande au survol ; constantes du liseré retirées

## Phase 2: US2 - Battement et plein écran

- [x] T006 [US2] Jauge : halo statique en imminent et épuisé, double battement sur `beat`, rien en réduction des animations
- [x] T007 [US2] Point plein écran inchangé (couleur du palier, battement) : vérification

## Phase 3: US3 - Pilule, accessibilité, docs

- [x] T008 [US3] Pilule : jauge + donnée sur une ligne
- [x] T009 [US3] Tests app adaptés ; captures démo (calme, far, near, imminent, blocked, warning, offline, reauth) ; `docs/images/states.png`, `hero.jpg` ; README
- [x] T010 Budget CPU et empreinte ; `check-localizations`

## Validation (2026-11-03, build Debug)

- 233 tests core (7 nouveaux : île par état, format), 5 tests app, build, 98 textes traduits.
- Captures : calme 544 × 76 px (encoche + oreille gauche), avec donnée 648 × 76 px (+ 2 oreilles = 104 pt) ; pilule « jauge + 8′ ».
- Mesures sur lancement neuf, 60 s en `imminent` : 0,33 s CPU (0,55 %), empreinte 25,0 Mo (0.4.1 Debug : 24,5 Mo).
- Ajustements après captures : minute entamée comptée (« 8′ » et non « 7′ ») ; retour d'une limite épuisée au format court « ↻1:02 ».
- Non rejoué : fond orange à l'œil, VoiceOver, plein écran.
