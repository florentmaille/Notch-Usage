# Tasks: Encoche silencieuse et liseré d'échéance

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/notch-signal.md](contracts/notch-signal.md), [quickstart.md](quickstart.md)

Tests d'abord (constitution III) : chaque tâche de test précède son implémentation et doit échouer avant.

## Phase 1: Setup

- [x] T001 Ajouter les états `far` (blocage prévu dans 2 h 05, 55 %), `near` (40 min, 78 %) et `imminent` (8 min, 92 %) à la liste de `scripts/demo.swift` et à `applyDemo` dans `App/NotchUsage/AppModel.swift` via `demoForecasts` ; documenter en tête du script

## Phase 2: Foundational (core)

- [x] T002 Test de `CompactStrip.Strings.shortLabel` dans `Tests/NotchUsageCoreTests/CompactStripTests.swift` : « 5h » pour `rollingFiveHour`, « 7d » pour `weeklyAll`, nom du modèle pour `weeklyModel` (stub de l'app en test) ; il échoue
- [x] T003 Champ `shortLabel: (UsageLimit) -> String` dans `CompactStrip.Strings` (`Sources/NotchUsageCore/Display/CompactStrip.swift`) et dans `extension CompactStrip.Strings.app` de `App/NotchUsage/Views/CompactView.swift` (« 5h » / « 5 h », « 7d » / « 7 j ») ; T002 vert

## Phase 3: US1 - Ne rien voir quand tout va bien (P1)

**Objectif** : silence en état calme, bande complète au survol, jamais d'oreilles sans texte. **Test indépendant** : quickstart 1 à 5, 15 ; captures fond clair et sombre.

- [x] T004 [US1] Tests de `NotchSignal.make(display:now:language:strings:)` dans `Tests/NotchUsageCoreTests/NotchSignalTests.swift`, cas de la table « Contenu par état » du contrat sans liseré : `silent` (relevé frais, `holdsUntilReset` ou prévision absente sous le seuil) ; `band` sur `isExpanded` (survol, épinglé), bannière (relevé ancien, en échec), session expirée, non connecté, non pris en charge, aucune donnée ; `accessibility` = celle de `CompactStrip` même en silence ; `isSilent` ; ils échouent
- [x] T005 [US1] Créer `Sources/NotchUsageCore/Display/NotchSignal.swift` : `Content { silent, band(CompactStrip), deadline(String), exhausted(full:back:), threshold(label:percent:) }`, `Edge { far, near, imminent, exhausted }` (vide pour l'instant), `make(...)` couvrant les cas de T004 ; T004 vert
- [x] T006 [US1] `App/NotchUsage/AppModel.swift` : propriété `signal: NotchSignal` recalculée dans `recompute()` après `display` ; `panel?.apply(display, silent: signal.isSilent)`
- [x] T007 [US1] `App/NotchUsage/Notch/NotchPanelController.swift` : `apply(_:silent:)` ; largeur `layout.width` quand `silent` et repliée, `layout.width + 2 × wingWidth` sinon ; élargissement immédiat au passage au signal ; rétrécissement différé de 600 ms au passage au silence par `DispatchWorkItem` annulable ; `handleClick` inchangé (la zone suit le cadre)
- [x] T008 [US1] `App/NotchUsage/Views/NotchRootView.swift` et `CompactView.swift` : la vue compacte dessine `signal.content` ; `silent` → forme noire et textes à opacité 0, `accessibilityHidden(false)` avec le libellé de la bande ; `band` → `CompactStrip` comme aujourd'hui ; `NotchShape` n'est dessinée que hors silence ; transition `.opacity` 0,6 s sur `signal.isSilent`, durée 0 si `accessibilityReduceMotion`
- [x] T009 [US1] Captures quickstart 1 (fond sombre et clair), 2, 15 ; vérifier 3, 4, 5 à la main ; résultats dans `specs/005-silent-notch/quickstart.md`

## Phase 4: US2 - Voir venir le blocage du coin de l'œil (P2)

**Objectif** : liseré par palier et donnée unique ; prévision prioritaire sur le seuil pour la 5 h. **Test indépendant** : démo `far`, `near`, `imminent`, `blocked`, `warning` ; quickstart 6 à 11, 17.

- [x] T010 [P] [US2] Tests de `NotchSignal.Edge.tier(blockAt:now:)` (≥ 60 min → `far`, < 60 → `near`, < 30 → `imminent`) et `tier(alertLevel:)` (`warning` → `far`, `critical` → `imminent`, `none` → nil) dans `NotchSignalTests.swift` ; ils échouent
- [x] T011 [P] [US2] Tests de `NotchSignal.make` pour les contenus signalants dans `NotchSignalTests.swift` : `deadline(blockLabel)` + palier sur `blockAt` ; `exhausted` + `edge = .exhausted` sur limite épuisée ; `threshold(shortLabel, percent)` + palier sur seuil sans prévision (hebdo, et 5 h avec prévision `unavailable`) ; `silent` sur 5 h à 97 % avec `holdsUntilReset` (FR-007a) ; `silent` avec alertes désactivées et seuil (le `deadline` reste) ; signal sur `headline` seule (limite épinglée, autre limite en seuil → `silent`) ; `band` en gris éteint le liseré ; ils échouent
- [x] T012 [US2] Implémenter `Edge.tier(...)` et les branches `deadline`, `exhausted`, `threshold` de `make` dans `Sources/NotchUsageCore/Display/NotchSignal.swift` ; T010 et T011 verts
- [x] T013 [US2] `App/NotchUsage/Views/CompactView.swift` : dessin de `deadline` (aile gauche vide, sablier + texte teinté à droite), `exhausted` (pastille « Full » à gauche, `arrow.clockwise` + durée rouge à droite), `threshold` (libellé court gris à gauche, pastille à droite) ; constantes de palier (teintes `#FF9F0A`, `#FF6A1A`, `#FF453A`, épaisseurs 2 / 2,5 / 3 pt, halo 6 pt) dans une `extension NotchSignal.Edge`
- [x] T014 [US2] `App/NotchUsage/Views/NotchRootView.swift` : liseré = `overlay` du contour de `NotchShape` avec l'épaisseur du palier, masqué à la moitié inférieure, `shadow` pour `imminent` et `exhausted` ; aucune animation au changement de palier
- [x] T015 [US2] `App/NotchUsage/AppModel.swift` : démo `warning` = 5 h à 83 % sans prévision ; `critical` garde son `blockAt` à 50 min (palier `near`) ; `normal` silencieux ; `pace` conservé
- [x] T016 [US2] Captures quickstart 6, 7, 8, 17 ; vérifier 9, 10, 11 à la main ; résultats dans quickstart.md

## Phase 5: US3 - Même comportement partout, y compris sans regarder (P3)

**Objectif** : pilule, plein écran, VoiceOver. **Test indépendant** : `layout=pill` pour chaque état ; plein écran + `imminent` ; VoiceOver.

- [x] T017 [US3] `App/NotchUsage/Views/CompactView.swift` : mode pilule pour `deadline` (« ⌛ 10:06 » seul), `exhausted` (« Full · ↻ 1h 02m »), `threshold` (« 7d · [97 %] ») avec `ViewThatFits` ; `NotchRootView` : pilule absente en silence, liseré sur la capsule
- [x] T018 [US3] `App/NotchUsage/Views/AlertDotView.swift` : la bande masquée de 2 pt prend la couleur du palier (`signal.edge`) ; point d'alerte inchangé ; passer `edge` depuis `NotchRootView`
- [x] T019 [US3] Quickstart 12, 13, 14, 16 (pilule, plein écran, VoiceOver, animations réduites) ; résultats dans quickstart.md

## Phase 6: Polish

- [x] T020 Catalogue `App/NotchUsage/Resources/Localizable.xcstrings` : « 5h » → « 5 h », « 7d » → « 7 j » et tout texte nouveau ; `scripts/check-localizations.sh .build/DerivedData` vert (SC-007)
- [x] T021 Budget (SC-005, SC-006) : Instruments ou Moniteur d'activité 10 min en `imminent` puis `normal` ; journal `com.notchusage` sur 10 min = 3 relevés ; résultats dans quickstart.md
- [x] T022 [P] Refaire `docs/images/states.png` (silence, far, near, imminent, bloqué, hors ligne) et mettre à jour la section Features et la note de 003 du `README.md`
- [x] T023 Non-régression (FR-019) : rejouer les scénarios d'encoche des quickstarts 001 (survol, épinglage, plein écran), 003 (panneau, prévision) et 004 (limite épinglée) ; résultats dans quickstart.md

## Dependencies

- Phase 2 avant US1 (le signal a besoin de `shortLabel` dès les tests de T004 pour `threshold` ; T003 peut livrer un stub).
- US1 avant US2 : le liseré se dessine dans la forme que US1 rend conditionnelle ; `Edge` existe vide dès T005.
- US2 avant US3 : la pilule et le plein écran reprennent les contenus et le palier de US2.
- Polish après US3.

## Parallel Execution

- Phase 2 : T002 seul (puis T003).
- US2 : T010 et T011 en parallèle (même fichier de tests, fonctions distinctes ; les écrire dans une seule passe), puis T012 ; T013 et T014 en parallèle (fichiers distincts), puis T015.
- Polish : T022 en parallèle de T020 et T021.

## Implementation Strategy

- MVP = Phase 1 à US1 : l'encoche se tait et parle au survol, sans liseré. Livrable seul : il
  supprime déjà les oreilles permanentes.
- US2 apporte la raison d'être de la feature ; US3 étend aux autres surfaces.
- Chaque phase se termine par ses captures et ses lignes de quickstart avant de passer à la suivante.
