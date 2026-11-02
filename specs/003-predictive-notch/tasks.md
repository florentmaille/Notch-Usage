# Tasks: Encoche prédictive

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/forecast.md](contracts/forecast.md), [contracts/compact-strip.md](contracts/compact-strip.md), [quickstart.md](quickstart.md)

Tests d'abord (constitution III) : chaque tâche de test précède son implémentation et doit échouer avant.

## Phase 1: Setup

- [ ] T001 Créer `scripts/demo.swift` : envoie `com.notchusage.debug.demo` (état), `hover`, `snapshot` avec attente, remplace les scripts temporaires de la session ; documenter l'usage en tête de fichier

## Phase 2: Foundational (core)

- [ ] T002 [P] Tests de `RelativeTimeFormatter.duration(until:now:language:)` (« 2 h 14 » / « 2h 14m », « 3 j 5 h » / « 3d 5h », « 1 min » / « 1m ») et `blockLabel(_:now:language:)` (moins d'1 h → heure courte du système, sinon durée) dans `Tests/NotchUsageCoreTests/RelativeTimeFormatterTests.swift` ; ils échouent
- [ ] T003 [P] Tests de `UsageHistory` dans `Tests/NotchUsageCoreTests/UsageHistoryTests.swift` : `appending(snapshot)` ajoute un `Reading` par limite ; troncature à 2 h après le dernier relevé ; relevés d'une autre période écartés (`resetsAt` différent de plus de 10 min) ; `readings(for:)` trié par `at` ; `Codable` aller-retour ; ils échouent
- [ ] T004 Libellés de durée nue dans `Sources/NotchUsageCore/Display/TimeLabels.swift` et `duration`, `blockLabel` dans `Sources/NotchUsageCore/Display/RelativeTimeFormatter.swift` ; T002 vert, tests existants inchangés
- [ ] T005 Créer `Sources/NotchUsageCore/Models/UsageHistory.swift` (`Reading { limitID, at, utilization 0…100, resetsAt? }`, `UsageHistory { readings }`) ; T003 vert
- [ ] T006 Créer `Sources/NotchUsageCore/Models/Forecast.swift` : `enum Forecast { unavailable, holdsUntilReset, blockAt(Date) }`, `Equatable`
- [ ] T007 `SnapshotStore` : `loadHistory() throws -> UsageHistory?` et `saveHistory(_:) throws` dans `Sources/NotchUsageCore/Credentials/CredentialStore.swift` ; `history.json` dans `App/NotchUsage/System/FileSnapshotStore.swift` ; store mémoire des tests dans `Tests/NotchUsageCoreTests/Support/` ; `wipe()` couvre le fichier
- [ ] T008 `DisplayState` : champs `forecasts: [String: Forecast]` et `fetchFailed: Bool` dans `Sources/NotchUsageCore/Display/DisplayState.swift` ; `DisplayStateReducer` renseigne `fetchFailed` sur `.failed` ; test dans `Tests/NotchUsageCoreTests/DisplayStateReducerTests.swift`

## Phase 3: US1 - Lire l'encoche en un coup d'œil (P1)

**Objectif** : nouvelle encoche repliée sans donnée nouvelle. **Test indépendant** : démo `normal`, `warning`, `critical`, `blocked`, `offline`, `reauth`, captures conformes à la maquette en fr et en en, distinctes en niveaux de gris.

- [ ] T009 [US1] Tests de `CompactStrip.make(display:now:language:strings:)` dans `Tests/NotchUsageCoreTests/CompactStripTests.swift`, une fonction par ligne des tables « Aile gauche » et « Aile droite » du contrat compact-strip.md (hors blocage prévu) : `left`, `right`, `tone`, `accessibility`, invariant « au plus une pastille », pastille « Bloqué » rouge même en gris ; ils échouent
- [ ] T010 [US1] Créer `Sources/NotchUsageCore/Display/CompactStrip.swift` (`Left`, `Right`, `Tone`, `Strings` d'entrée pour « Bloqué », « Connexion », « Sign in », « — ») ; T009 vert
- [ ] T011 [US1] Réécrire `App/NotchUsage/Views/CompactView.swift` : dessine `CompactStrip` ; glyphes SF (`checkmark`, `hourglass`, `arrow.clockwise`, `wifi.slash`, `lock`, `person.crop.circle.badge.plus`) ; pastille capsule texte sombre ; « Sign in » sans soulignement avec trait bouton ; pilule `ViewThatFits` avec puis sans glyphe ; supprimer la mini-barre de l'encoche (`UsageBar` reste pour le panneau)
- [ ] T012 [US1] Catalogue `App/NotchUsage/Resources/Localizable.xcstrings` : « Full » → « Bloqué », retirer « FULL » / « PLEIN », synchroniser depuis la build (`xcstringstool sync`), `scripts/check-localizations.sh` vert
- [ ] T013 [US1] Mode démo dans `App/NotchUsage/AppModel.swift` : états `blocked` (fenêtre à 100 %, reset dans 1 h 02) et `offline` (`.failed(.network, previous:)` relevé de 25 min) en plus des existants ; `scripts/demo.swift` les accepte
- [ ] T014 [US1] Captures fr et en des 6 états (quickstart 1, 2, 3, 5, 6, 7, 14) comparées à `docs/design/notch-v8-d1.png` ; corriger jusqu'à conformité ; noter les écarts assumés dans quickstart.md

## Phase 4: US2 - Être prévenu avant le seuil (P2)

**Objectif** : prévision de blocage de la fenêtre de 5 h. **Test indépendant** : fixtures du contrat forecast.md ; démo `pace` ; aucune requête ajoutée.

- [ ] T015 [P] [US2] Tests de `PaceForecaster.forecast(readings:resetsAt:now:)` dans `Tests/NotchUsageCoreTests/PaceForecasterTests.swift`, les 10 cas du contrat forecast.md, plus `forecasts(history:snapshot:now:)` limité aux limites `rollingFiveHour` ; ils échouent
- [ ] T016 [P] [US2] Tests de `ForecastDebouncer.push(_:)` dans `Tests/NotchUsageCoreTests/ForecastDebouncerTests.swift` : séquence `holds, block(16:40), block(16:42)` → `holds, holds, block(16:42)` ; `unavailable` immédiat ; par limite ; ils échouent
- [ ] T017 [US2] Créer `Sources/NotchUsageCore/Forecast/PaceForecaster.swift` : fenêtre 60 min, recevabilité (≥ 2 relevés, écart ≥ 10 min, aucun trou > 30 min), régression linéaire, projection, comparaison au reset, `unavailable` si utilisation ≥ 100 ; T015 vert
- [ ] T018 [US2] `ForecastDebouncer { displayed, pending }` dans `Sources/NotchUsageCore/Models/Forecast.swift` ; T016 vert
- [ ] T019 [US2] Test du réducteur dans `Tests/NotchUsageCoreTests/DisplayStateReducerTests.swift` : `headline` = limite au `blockAt` le plus proche, sinon `mostConstraining` ; `forecasts` recopiés ; il échoue
- [ ] T020 [US2] `DisplayStateReducer.reduce(…, forecasts:)` dans `Sources/NotchUsageCore/Display/DisplayStateReducer.swift` ; T019 vert ; appelants mis à jour
- [ ] T021 [US2] `CompactStrip` : `left = .blockIn(label)` avec `blockLabel`, `tone` orange (ou rouge si critique) ; tests ajoutés à `CompactStripTests.swift` ; glyphe sablier dans `CompactView.swift`
- [ ] T022 [US2] `App/NotchUsage/AppModel.swift` : charger l'historique au démarrage, `appending` à chaque relevé réussi puis `saveHistory`, `PaceForecaster` + `ForecastDebouncer` à chaque relevé, `recompute` au tick de 30 s avec les prévisions, remise à zéro à la déconnexion ; démo `pace` (55 %, historique synthétique 40→55 % sur 40 min, reset dans 4 h)
- [ ] T023 [US2] Quickstart 4, 8, 9, 10, 13 (compte réel, relance, déconnexion, budget réseau) ; résultats dans `specs/003-predictive-notch/quickstart.md`

## Phase 5: US3 - Comprendre le rythme dans le panneau et avec VoiceOver (P3)

**Objectif** : ligne « À ce rythme » et annonces. **Test indépendant** : démo `pace`, panneau déplié, VoiceOver.

- [ ] T024 [US3] `CompactStrip.accessibility` inclut « , à ce rythme bloqué à {heure} » / « , at this pace blocked at {time} » via `Strings` ; tests dans `CompactStripTests.swift` ; il échoue puis vert
- [ ] T025 [US3] `App/NotchUsage/Views/ExpandedView.swift` : sous chaque limite avec prévision, « At this pace: blocked at %@ » ou « At this pace: holds until reset » en `.caption` ; `LimitRow` accessibilité étendue de la même phrase ; aucune ligne sans prévision
- [ ] T026 [US3] Traductions fr des nouveaux textes dans `Localizable.xcstrings` (« À ce rythme : bloqué à %@ », « À ce rythme : tient jusqu'au reset ») ; `scripts/check-localizations.sh` vert
- [ ] T027 [US3] Quickstart 11, 12 (panneau, VoiceOver fr et en) ; résultats dans `specs/003-predictive-notch/quickstart.md`

## Phase 6: Polish

- [ ] T028 Budget (SC-004, SC-005) : 10 min de journal `com.notchusage` = 3 relevés ; CPU et empreinte dans le Moniteur d'activité, comparés à 0.2.1 ; résultats dans quickstart.md
- [ ] T029 [P] Refaire `docs/images/states.png` avec les nouveaux états et ajouter la prévision aux Features du `README.md`
- [ ] T030 Non-régression (FR-020) : rejouer les scénarios d'encoche du quickstart 001 (survol, épinglage, plein écran, pilule) et 002 (langue) ; résultats dans quickstart.md

## Dependencies

- Phase 2 avant tout : T002, T003 en parallèle ; T004 ← T002 ; T005 ← T003 ; T006 libre ; T007 ← T005 ; T008 ← T006.
- US1 : T009 → T010 → T011 ; T012 et T013 après T011 ; T014 en dernier.
- US2 : T015, T016 en parallèle après T006 ; T017 ← T015 ; T018 ← T016 ; T019 → T020 ; T021 ← T010, T017 ; T022 ← T017, T018, T020, T021, T007 ; T023 en dernier.
- US3 : après US2 (T024 ← T021 ; T025 ← T020).
- Polish après US3 ; T029 en parallèle.

## Implementation Strategy

- MVP = Phase 2 + US1 : l'encoche redessinée sans prévision, livrable seule (pastilles, compte à rebours, pilule).
- US2 ajoute la prévision sans toucher aux vues autrement que pour le sablier.
- US3 complète panneau et accessibilité. Une PR par phase ou une PR pour l'ensemble, CI verte à chaque fois.
