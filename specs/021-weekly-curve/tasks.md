# Tasks: Courbe de la semaine

- [x] T001 [P] Écrire les tests de `HourlyHistoryTests`, qui doivent échouer d'abord :
  - un relevé par heure : la même heure remplace, l'heure suivante ajoute ;
  - un changement de période écarte les anciens relevés de cette limite ;
  - la rétention est de 8 jours ;
  - les relevés sont rangés par limite.
- [x] T002 Créer `HourlyHistory` pour faire passer T001 au vert.
- [x] T003 [P] Écrire les tests de `WeekCurveTests`, qui doivent échouer d'abord :
  - la courbe ne concerne que `weeklyAll` avec un reset ;
  - points en fractions de semaine, plus le point « maintenant » ;
  - moins de 2 points donne `notEnough` ;
  - projection `holds` au reset, avec la même formule que la 016 ;
  - `blocks` à 100 %, à la fraction de la date, avec la teinte du palier ;
  - `unavailable` sans projection ;
  - jours aux minuits locaux ;
  - les relevés d'une autre période sont ignorés.
- [x] T004 Créer `WeekCurve` pour faire passer T003 au vert.
- [x] T005 Persister l'historique :
  - `SnapshotStore` gagne `loadHourlyHistory` et `saveHourlyHistory` ;
  - `FileSnapshotStore` les écrit dans `weekly.json` ;
  - `MemorySnapshotStore` les implémente pour les tests.
- [x] T006 Modifier `AppModel` :
  - `hourlyHistory` est chargé au démarrage, enrichi dans `record` et vidé à la déconnexion ;
  - `weekCurve` est calculée dans `recompute()` à partir de la limite hebdomadaire et de sa prévision.
- [x] T007 Ajouter à `AppModel+Demo` une semaine fictive cohérente avec chaque état de démo.
- [x] T008 Créer `WeekSection` :
  - en-tête « This week · 43 % projected at reset » ou « blocked Thu 14:10 », repliable via `@AppStorage` ;
  - courbe tracée avec `Canvas`, avec la ligne des 100 %, le point « maintenant », la projection en pointillés et les jours ;
  - teinte du palier en cas de blocage ;
  - « Not enough readings yet » s'il manque des données ;
  - une phrase pour VoiceOver.
- [x] T009 Ajouter la section dans `ExpandedView`, sous les limites.
- [x] T010 Ajouter les textes en anglais et en français ; `check-localizations` doit rendre 0.
- [x] T011 Validation :
  - `swift test` et `xcodebuild test` passent ;
  - captures de démo (`normal`, `far`, `near`, `imminent`), en déplié et en replié.

## Validation (2026-11-10)

- Tests : core 325 (13 nouveaux : `HourlyHistory` 5, `WeekCurve` 8), app 13. Catalogue : 138 textes, aucun sans traduction.
- Captures de démo (build Debug, mode `notchonly`) :
  - `normal` : courbe blanche, « 50 % projected at reset », jour courant en gras ;
  - `weekblock` (70 % après 3,8 jours) : courbe ambre, « blocked Wed 23:19 », projection arrêtée à 100 %.
- Reste à vérifier en réel : la première semaine se construit à partir de l'installation, donc la courbe sera partielle au début.
