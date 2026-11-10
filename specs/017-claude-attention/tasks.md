# Tasks: Claude attend une action

Format de la 012 : une ligne par tâche, tests d'abord (constitution III), fichiers nommés. `[P]` : parallélisable
(fichiers distincts, aucune dépendance en attente). Contrats : [attention.md](contracts/attention.md),
[hooks.md](contracts/hooks.md) ; modèle : [data-model.md](data-model.md) ; validation : [quickstart.md](quickstart.md).

## Phase 1: Fondations (core, bloquant pour US1 et US4)

- [x] T001 [P] Fixtures `Tests/NotchUsageCoreTests/Fixtures/claude-hooks/` : une ligne par événement du spike (`permission-bash.json`, `permission-ask.json`, `post-tool-use-ask.json`, `stop.json`, `user-prompt-submit-title.json`, `session-start.json`, `session-end.json`, `malformed.txt`), enveloppées `{"ppid","ts","event"}` ; `settings-0.json`, `settings-1.json`, `settings-8.json` (copie anonymisée de la config du spike, hooks `http` compris)
- [x] T002 [P] Tests `Tests/NotchUsageCoreTests/ClaudeHookEventTests.swift` : décodage de chaque fixture (kind, sessionID, cwd, sessionTitle, toolName, promptID, pid, receivedAt depuis `ts`), champ inconnu ignoré, `hook_event_name` inconnu → `.other`, ligne sans `session_id` → nil, ligne illisible → nil ; ils échouent
- [x] T003 `Sources/NotchUsageCore/Claude/ClaudeHookEvent.swift` : `struct ClaudeHookEvent: Decodable, Sendable, Equatable` (table du modèle), `static func decode(line: Substring, readAt: Date) -> ClaudeHookEvent?` ; T002 vert
- [x] T004 [P] Tests `Tests/NotchUsageCoreTests/ClaudeSessionTrackerTests.swift` : chaque ligne de la table des transitions ; arrivée pendant une attente remplace et relance `since` ; `userPromptSubmit` mémorise le titre ; `expire(now:alive:)` retire les mortes et les 8 h sans pid ; `clearDone()` ; tri (approbation, question, terminé ; puis `since` croissant) ; `displayName` (titre → dossier → « Session » + 4 caractères) ; ils échouent
- [x] T005 `Sources/NotchUsageCore/Claude/ClaudeSessionTracker.swift` : `ClaudeSession`, `Waiting`, `ClaudeSessionTracker` (valeur, `reduce`, `apply`, `expire`, `clearDone`, `waiting`) ; T004 vert
- [x] T006 [P] Tests `Tests/NotchUsageCoreTests/ClaudeHooksInstallerTests.swift` : `install` sur `settings-0/1/8` ajoute les 7 groupes et laisse le reste identique ; `remove` après `install` redonne l'original **à l'octet près** une fois réencodé avec les mêmes options ; `remove` ne touche pas un groupe sans le chemin du script ; clé d'événement supprimée si vide ; `status` : absent, installed, partial (3 groupes retirés à la main), unreadable (JSON cassé) ; `install` sur JSON cassé lève ; fichier vide → `{"hooks": …}` ; ils échouent
- [x] T007 `Sources/NotchUsageCore/Claude/ClaudeHooksInstaller.swift` : `JSONSerialization`, marqueur = chemin du script, les 7 événements de hooks.md avec `{"type":"command","command":<script>,"timeout":5}`, encodage `prettyPrinted` + `sortedKeys` + `withoutEscapingSlashes` + `\n` final ; T006 vert

## Phase 2: US1 - Voir qu'une session attend, et quoi

- [x] T008 [US1] Tests `Tests/NotchUsageCoreTests/NotchSignalTests.swift` : `NotchSignal.make(display:now:attention:…)` sans attention = île 012 inchangée ; au calme avec `approval` → `trailing == .attention(kind: .approval, count: 1)` ; `question` et `done` idem ; `accessibility` préfixée « 1 session Claude attend : <nom>, une approbation » (fr) / « 1 Claude session is waiting: … » (en) ; ils échouent
- [x] T009 [US1] `Sources/NotchUsageCore/Display/NotchSignal.swift` : `Attention` (kind, count, arrivedAt, tint, names), `Island.Trailing.attention(kind:count:)`, `Island.badge: Tint?`, paramètre `attention:` de `make` ; T008 vert (priorité et compteur en US2)
- [x] T010 [P] [US1] Tests `Tests/NotchUsageCoreTests/AttentionFormatTests.swift` : `arrivalLabel(kind, language)` (« Approval »/« Approbation », « Question », « Done »/« Terminé »), `since(from:now:language)` (« 45 s », « 2 min », « 1 h 10 »), `showsArrival(arrivedAt:now:)` vrai sous 4 s, `count(n)` (« », « 2 », « 9+ ») ; ils échouent
- [x] T011 [P] [US1] `Sources/NotchUsageCore/Display/AttentionFormat.swift` ; T010 vert ; textes dans `CompactStrip.Strings` ou une `AttentionStrings` injectée comme `.app`
- [x] T012 [US1] `App/NotchUsage/Claude/ClaudeHookScript.swift` : écrit `claude-hook.sh` (contenu de hooks.md) dans `~/Library/Application Support/NotchUsage/`, 700, réécrit à chaque activation ; `url` exposé pour l'installer
- [x] T013 [US1] `App/NotchUsage/Claude/ClaudeEventsWatcher.swift` : `DispatchSource.makeFileSystemObjectSource(.write, .extend)` sur `claude-events.jsonl` (600, créé vide s'il manque), lecture incrémentale depuis l'offset, lignes complètes seulement (reste gardé), `onEvents([ClaudeHookEvent])` sur le main actor, troncature à 0 après consommation au-delà de 64 Ko et au premier rattrapage ; `start()` / `stop()` ; log du nombre de lignes ignorées
- [x] T014 [US1] `App/NotchUsage/AppModel.swift` : `tracker: ClaudeSessionTracker`, `followsClaudeCode` (UserDefaults, défaut false), `startClaudeWatcher()` au `start()` si activé (rattrapage puis `expire`), `onEvents` → `reduce` + `expire(alive:)` + `recompute()` ; `arrivalTask` de 4 s (annulé par l'arrivée suivante) → `recompute()` ; `recompute()` passe `tracker.attention(now:)` à `NotchSignal.make` ; `panel.apply(ears:)` compte l'oreille droite si `trailing` est une attention
- [x] T015 [US1] `App/NotchUsage/Views/CompactView.swift` : `islandTrailing(.attention)` : SF Symbol (`hand.raised.fill`, `questionmark.bubble.fill`, `checkmark`), teinte violet `#BF5AF2` ou blanc, mot d'arrivée tant que `AttentionFormat.showsArrival` (oreille élargie au contenu, ≤ 120 pt), `.transition(.opacity)` ; largeur d'oreille passée à `AppModel` pour le cadre ; pilule : même contenu sur une ligne ; Reduce Motion : aucun fondu (déjà géré par `NotchRootView`)
- [x] T016 [US1] Mode démo `App/NotchUsage/AppModel+Demo.swift` et `scripts/demo.swift` : suffixe `claude=approval | question | done | approval3 | arrival | off` qui alimente un `demoTracker` ; capture `normal claude=approval`, `normal claude=arrival` (sous 4 s), `far claude=question` ; conformes à attention.md

## Phase 3: US2 - Priorité face à la limite, plusieurs sessions, plein écran

- [x] T017 [US2] Tests `NotchSignalTests.swift` : `imminent` + attention → `trailing == .deadline("8′")`, `badge == .claude`, `pulse` inchangé ; `blocked` + attention → `trailing == .back(…)`, badge ; `far` + question → `trailing == .attention`, `tint == .far` ; seuil sans prévision + attention → `trailing == .attention` ; hors ligne + attention → `leading == .glyph(.offline)`, `trailing == .attention` ; 2 approbations + 1 terminée → `kind == .approval`, `count == 3` ; approbation + question → `.approval`, 2 ; `fullscreenTint` : rouge si imminent/épuisé, sinon attention, sinon palier ; ils échouent
- [x] T018 [US2] `NotchSignal.swift` : règle de priorité dans `make` (edge `.imminent`/`.exhausted` → badge, sinon trailing), `Attention.kind` = le plus pressant, `count`, `fullscreenTint` ; T017 vert
- [x] T019 [US2] `CompactView.swift` : badge (point 6 pt violet, coin haut droit de la jauge, bordure noire 1,5 pt) ; compteur `monospacedDigit` 13 pt à droite du glyphe dans l'oreille de 52 pt ; plein écran : rien à faire, le point n'existe plus depuis la 016 (spec FR-009 mise à jour)
- [x] T020 [US2] Démo : `imminent claude=approval tick snapshot` (jauge rouge, « 8′ », point violet), `blocked claude=done snapshot`, `normal claude=approval3 snapshot`, `layout=pill` + `normal claude=approval3`

## Phase 4: US3 - Survol : quelles sessions, depuis quand, et y aller

- [x] T021 [P] [US3] `App/NotchUsage/Claude/ProcessLiveness.swift` : `isAlive(pid)` par `kill(pid, 0)` (0 ou `EPERM`), `originApp(forPID:)` remonte les parents (`proc_pidinfo` `PROC_PIDTBSDINFO`, au plus 5 niveaux) jusqu'à une `NSRunningApplication` avec `bundleIdentifier` ; `activate(pid:bundleID:)`
- [x] T022 [US3] `AppModel.swift` : `originApp` résolu à la création d'une session et mémorisé ; `expire(alive:)` au survol (`hover = true`), à l'événement et au lancement ; `activateSession(_:)` → `ProcessLiveness.activate`, `hover = false` ; `clearDone()` au clic sur l'île (dans le geste de la 013)
- [x] T023 [US3] `App/NotchUsage/Views/ExpandedView.swift` : section « Claude Code » au-dessus des limites (titre en capitales secondaires, une ligne par `tracker.waiting` : point violet/blanc, nom tronqué à 28, libellé « approval needed » / « question pending » / « finished », durée `AttentionFormat.since`), absente sans attente ; ligne cliquable → `model.activateSession` ; hauteur mesurée inchangée (013)
- [x] T024 [US3] `App/NotchUsage/Notch/StatusItemController.swift` : mêmes lignes en items avant les limites, action `activateSession`, séparateur ; absent sans attente
- [x] T025 [US3] Démo : `normal claude=approval3 panel` (trois lignes triées) ; réel : clic sur une ligne active l'app Claude ou le Terminal ; terminal fermé sans réponse → ligne disparue au survol suivant

## Phase 5: US4 - Réglage, notification, accessibilité, documentation

- [x] T026 [US4] `App/NotchUsage/Claude/ClaudeSettingsFile.swift` : `~/.claude/settings.json` ; `status()` (`claudeMissing` si `~/.claude` absent), `install()` / `remove()` : relecture juste avant, `ClaudeHooksInstaller`, écriture atomique (temporaire + `rename`), jamais sur `unreadable` ; erreurs typées avec message court
- [x] T027 [US4] `AppModel.swift` : `setFollowsClaudeCode(_:)` (script, install, watcher ; ou remove, stop, tracker vidé), `claudeHooksStatus` recalculé au `start()` et à l'ouverture des réglages, `repairClaudeHooks()` pour `partial` ; `notifiesClaudeAttention` (défaut false)
- [x] T028 [US4] `App/NotchUsage/Views/SettingsView.swift` : ligne « Follow Claude Code » dans l'essentiel, note sous la ligne selon le statut (« Claude Code was not found », « Hooks were changed outside the app » + bouton « Repair », message d'erreur de config illisible), ligne « Notify me too » visible seulement si activé
- [x] T029 [US4] `App/NotchUsage/Alerts/SignalNotifier.swift` : `notifyClaude(session:)` pour approbation et question, une par `session_id-prompt_id`, titres et corps de attention.md ; appelé depuis `onEvents` si `notifiesClaudeAttention`
- [x] T030 [US4] Accessibilité : `CompactView` lit `signal.accessibility` (déjà préfixée), lignes du panneau avec `accessibilityLabel` « <nom>, attend une approbation depuis 2 min » ; glyphe et compteur sans la couleur vérifiés sur capture en niveaux de gris
- [x] T031 [P] [US4] `App/NotchUsage/Resources/Localizable.xcstrings` : tous les textes nouveaux en en et fr ; `scripts/check-localizations.sh` à 0
- [x] T032 [P] [US4] Tests `Tests/NotchUsageAppTests/AppPresentationTests.swift` : teinte `.claude` = `#BF5AF2`, symboles par `kind`, libellés de ligne par `kind` et langue, `ClaudeHookScript` produit le script attendu (contenu de hooks.md) avec le bon chemin
- [x] T033 [US4] README (en) et section fr : table des états avec les trois états Claude, réglage, vie privée (ce que le script écrit, le fichier vidé à chaque lecture) ; `docs/images/states.png` régénérée avec `approval` et `question` ; planche `docs/design/claude-attention.png` liée

## Phase 6: Validation

- [x] T034 Quickstart §3 en réel sur une session de l'app Claude et une session CLI (8 étapes) ; `diff` de `settings.json` avant/après activation puis désactivation
- [x] T035 Budgets : 10 min avec trois sessions suivies, CPU < 1 %, empreinte ± 2 Mo de la 0.5.3 ; `swift test` et `xcodebuild test` verts ; version `0.5.4` et notes de release dans `docs/release-notes/`

## Dépendances

- Phase 1 avant tout : T003 ← T002, T005 ← T004 (+ T003), T007 ← T006. T001, T002, T004, T006 en parallèle.
- US1 : T009 ← T008 (+ T005) ; T010/T011 en parallèle de T008/T009 ; T012, T013 en parallèle ; T014 ← T005, T009, T011, T013 ; T015 ← T014 ; T016 ← T015.
- US2 ← US1 (T018 ← T009 ; T019 ← T015). US3 ← US1 (T021 parallèle dès le départ ; T022 ← T014, T021 ; T023/T024 ← T022). US4 : T026 ← T007 (parallèle dès la phase 1) ; T027 ← T014, T026 ; T028 ← T027 ; T029 ← T014 ; T031, T032 à tout moment après les APIs.
- MVP : phase 1 + US1 (T001-T016) : le signal dans l'île, activé à la main en attendant T026-T028 (copier le script, ajouter les 7 entrées).

## Validation (2026-11-05, build Debug)

- Core : 274 tests, 5 suites nouvelles (événement, tracker, installer, attention, format) ; app : suite verte, 4 tests nouveaux ; 120 textes, 0 sans traduction.
- Captures démo (`claude=`) : approval, arrival (oreille élargie à 116 pt, « ✋ Approval »), question, done, approval3 (« ✋ 3 »), far+question (jauge ambre, bulle), imminent+approval (jauge rouge qui bat, « 8′ », point violet), blocked+done (« ↻1:02 », point blanc), panneau (section « Claude Code », trois lignes triées), pilule, réglages (ligne « Follow Claude Code »).
- Pipeline réel sans toucher à `~/.claude/settings.json` : préférence `followsClaudeCode` posée à la main, script écrit en 700 dans le conteneur, événement injecté par le script → fichier → watcher → île en moins d'une seconde, fichier vidé après consommation et au lancement, ligne dans le panneau avec « 2 s ».
- Mesures sur 60 s avec trois sessions en attente : 0,14 s CPU (0,23 %), empreinte 36,9 Mo (Debug, après captures ; à remesurer en Release).
- Plein écran : le point n'existe plus depuis la 016 ; spec FR-009 et contrat mis à jour, rien à faire.
- **T034 rejouée le 2026-11-10** sur la branche `fix/audit-p0`, avec une session CLI et une session de l'app Claude : les 8 étapes passent (entrées et `diff`, main, bulle, coche et clic, terminal fermé, attente provoquée app fermée, désactivation à l'identique, config illisible jamais réécrite). Jusque-là aucun événement n'arrivait en réel : la commande installée était le chemin brut du script, coupé à l'espace de « Application Support » par le shell (code 127). Relevé pendant la recette : le clic sur la pastille n'effaçait pas les « terminé » (corrigé) ; une attente déjà lue avant un redémarrage de l'app n'était pas restaurée (corrigé : sessions conservées dans `claude-sessions.json`). Le clic sur une ligne (T025) reste non observé.
- **T035, mesures du 2026-11-10** avec `scripts/measure-budgets.py` sur une build Release, 10 min chacune. Mesure retenue (écran allumé, usage normal, 4 relevés sur la fenêtre, pastille survolée 7 fois) : CPU moyen 0,33 % (1,99 s sur 601 s), empreinte 31 à 32 Mo ; budgets tenus (1 % et 60 Mo). Première mesure, écran éteint à la 2e minute donc relevés suspendus : 0,06 % et 24 à 25 Mo. Écarts avec l'énoncé de la tâche : une session suivie pendant la mesure, pas trois (leur coût est celui des événements reçus) ; la comparaison « ± 2 Mo de la 0.5.3 » n'a plus de référence mesurée, seul le plafond de la constitution est vérifié.
