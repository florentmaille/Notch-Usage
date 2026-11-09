# Tasks: Écran sans encoche

Même format que la 017 : une ligne par tâche, les tests d'abord (constitution III), chaque fichier nommé. `[P]` marque une tâche parallélisable : fichiers distincts, aucune dépendance en attente.

Références :
- contrat : [surfaces.md](contracts/surfaces.md)
- modèle : [data-model.md](data-model.md)
- décisions : [research.md](research.md), R1 à R9
- validation : [quickstart.md](quickstart.md)
- planche : [external-screen.png](../../docs/design/external-screen.png)

Ne pas confondre : `CompactStrip.Right.pill` désigne la puce de texte de l'oreille, elle reste. Seul `DisplayMode.pill` (la forme qui imite une encoche) disparaît.

## Phase 1: Spike

- [x] T001 Spike de la barre active : la fenêtre de l'item suit la barre active, et `didChangeScreen` arrive moins de 0,1 s après chaque bascule. Voir [spike-statusitem.md](spike-statusitem.md), qui confirme R4.

## Phase 2: Fondations (core, bloque toutes les histoires)

- [x] T002 [P] Tests dans `Tests/NotchUsageCoreTests/ScreenRolesTests.swift`. Ils doivent échouer avant T003. Cas à couvrir :
  - MacBook seul : île, `plain` vide.
  - MacBook + externe principal 1920 : île sur le MacBook (non principal), `plain = [externe, capsuleEligible: true]`.
  - MacBook + externe secondaire 1440 : `capsuleEligible: false`.
  - Capot fermé (externe seul) : `island == nil`.
  - Mac sans encoche avec deux écrans : `island == nil`, deux `plain` dans l'ordre reçu.
  - Deux écrans à encoche : l'île va sur celui qui est principal (`isMain`), sinon sur le premier (FR-003).
  - Seuil exact : `width >= 1700` donne éligible, 1699 non.
  - `hasPlainScreen`.
  - Règle « à encoche » : `safeAreaTop > 0` et les deux zones auxiliaires présentes, avec une largeur restante positive.
- [x] T003 Créer `Sources/NotchUsageCore/Display/ScreenRoles.swift`. T002 passe au vert.
  - `struct ScreenDescriptor` (`id: String`, `width`, `safeAreaTop`, `auxLeftWidth?`, `auxRightWidth?`, `isMain: Bool`).
  - `struct ScreenRoles` (`island: (id, layout: NotchLayout)?` exposé par une struct `IslandScreen`, `plain: [PlainScreen]`, `hasPlainScreen`).
  - `static let capsuleMinWidth: CGFloat = 1700`.
  - `static func assign(_ screens: [ScreenDescriptor]) -> ScreenRoles`.
  - Tous les types sont `Sendable` et `Equatable`.
- [x] T004 [P] Adapter `Tests/NotchUsageCoreTests/NotchGeometryTests.swift` : `layout(...)` rend `nil` sans encoche, et aucun cas `.pill`. Adapter `Tests/NotchUsageCoreTests/DisplayStateReducerTests.swift` : construire avec un `NotchLayout` d'encoche, sans `.pill`. Les tests échouent à la compilation.
- [x] T005 Modifier `Sources/NotchUsageCore/Display/NotchGeometry.swift` et `Sources/NotchUsageCore/Display/DisplayState.swift`. T004 passe au vert.
  - Supprimer `DisplayMode` et `pillSize`.
  - `layout(...)` rend `NotchLayout?`.
  - Retirer `NotchLayout.mode` et `DisplayState.mode`.
  - `ScreenRoles` utilise `NotchGeometry.layout` pour décider si un écran est « à encoche ».
  - `DisplayState.layout` reste non optionnel : sans île, `AppModel` n'appelle pas le réducteur pour le panneau (R1).
- [x] T006 [P] Tests dans `Tests/NotchUsageCoreTests/MenuBarIconModeTests.swift`. Ils doivent échouer avant T007.
  - Migration : `migrate(legacy: true) == .always`, `migrate(legacy: false) == .automatic`, `migrate(legacy: nil) == .automatic`.
  - `isVisible(roles:)` : `always` donne vrai, `never` donne faux, `automatic` donne `roles.hasPlainScreen`.
  - `rawValue` stables : "automatic", "always", "never".
- [x] T007 [P] Créer `Sources/NotchUsageCore/Models/MenuBarIconMode.swift` : `enum MenuBarIconMode: String, Sendable, CaseIterable { case automatic, always, never }`, `migrate(legacy:)`, `isVisible(roles:)`. T006 passe au vert.
- [x] T008 [P] Tests dans `Tests/NotchUsageCoreTests/BarContentTests.swift`, un test par ligne du tableau « Contenu par état » de la spec. Ils doivent échouer avant T009.
  - Calme 42 % : `gauge.fraction == 0.42`, `tint == .calm`, `text == "42 %"` (format de l'oreille droite), `textEmphasis == .none`, `attention == nil`.
  - Palier, blocage dans 2 h 05 : `tint == .near`, `text == "2:05"`, `.none`.
  - Imminent, 8 min : `tint == .imminent`, `beats == true`, `text == "8′"`, `textEmphasis == .imminent`.
  - Épuisé : `beats == true`.
  - Deux approbations : `attention.kind == .approval`, `count == 2`.
  - Arrivée récente (moins de 4 s) : `arrivalWord != nil`. Après 4 s : `nil`.
  - Imminent avec Claude : `attentionAsBadge == true`, `attention` gardée pour le point.
  - Sans relevé : `gauge == nil`, `text == nil`.
  - `compact` : jauge seule, `text == nil`, `attention == nil`.
  - `accessibility == signal.accessibility`.
  - Égalité : deux calculs du même état sont `==`. FR-021 en dépend : on ne redessine que si la valeur change.
- [x] T009 Créer `Sources/NotchUsageCore/Display/BarContent.swift` : `struct BarContent: Sendable, Equatable` (`Gauge`, `TextEmphasis`, `Attention` locale), `static func make(signal: NotchSignal, display: DisplayState, now: Date, language:) -> BarContent`, et `var compact: BarContent`. T008 passe au vert.
  - Toutes les valeurs sont dérivées de `NotchSignal` : teinte, texte de l'oreille droite, `badge`, attention.
  - Ne pas réécrire la règle de priorité de la 017 ni le format du palier de la 003.

**Point de contrôle** : `swift test --filter "ScreenRolesTests|NotchGeometryTests|DisplayStateReducerTests|MenuBarIconModeTests|BarContentTests"` est vert.

## Phase 3: US2 - L'île sur l'écran à encoche, nulle part ailleurs (P1)

**Objectif** : retirer la pilule ; l'île suit l'écran à encoche. L'item de la 014 couvre encore l'externe en attendant US1.

**Test indépendant** : brancher et débrancher l'externe, le définir comme principal, fermer le capot. L'île suit le MacBook et aucune forme noire n'apparaît.

- [x] T010 [US2] Modifier `App/NotchUsage/Notch/ScreenObserver.swift` :
  - Construire un `ScreenDescriptor` par `NSScreen` : `id` = `NSScreenNumber`, `isMain` = `screen == NSScreen.screens.first`.
  - Publier `ScreenRoles` avec un dictionnaire `id → NSScreen` à la place de `Target`.
  - Signature de changement : concaténer `id@frame@safeAreaTop` de tous les écrans.
  - Supprimer `layout(for:)`.
- [x] T011 [US2] Modifier `App/NotchUsage/AppModel.swift` :
  - `screenRoles: ScreenRoles`.
  - `applyScreen` est remplacé par `applyRoles(_:)` : il crée ou montre le panneau sur l'écran de l'île, ou le ferme quand `island == nil` (capot fermé, Mac sans encoche).
  - `recompute()` n'appelle `panel?.apply` que si l'île existe.
  - Fermer le popover à chaque changement de rôles (FR-010, utilisé en US1).
- [x] T012 [US2] Retirer la branche pilule :
  - `App/NotchUsage/Notch/NotchPanelController.swift` : retirer les tests sur `layout.mode == .notch`.
  - `App/NotchUsage/Views/NotchRootView.swift` : `NotchShape` garde seulement la forme encoche.
  - `App/NotchUsage/Views/CompactView.swift` : retirer la variante pilule sur une ligne de la 017, si elle existe.
- [ ] T013 [US2] Modifier `App/NotchUsage/Notch/FullscreenObserver.swift` : `screens: [NSScreen]` remplace `screen`, et `onChange` reçoit l'ensemble des `id` couverts (`Set<String>`). `FullscreenHeuristic` ne change pas (R7). L'île lit son propre écran dans cet ensemble.
- [x] T014 [US2] Modifier `App/NotchUsage/AppModel+Demo.swift` : `com.notchusage.debug.layout` accepte "nonotch" | "notch". "nonotch" force `ScreenRoles` sans île (tous les écrans passent en `plain`, éligibilité selon la largeur réelle). L'objet "pill" n'existe plus. Mettre à jour le commentaire d'en-tête (R9).

**Point de contrôle** : quickstart, essais 1 à 3 (l'item de la 014 visible si le réglage est actif).

## Phase 4: US1 - Suivre l'usage depuis la barre de menus (P1) 🎯 MVP

**Objectif** : item enrichi sur les barres sans encoche, compact sur celle de l'écran à encoche, popover au clic.

**Test indépendant** : mode démo `nonotch`. Chaque état du tableau « Contenu par état » apparaît dans l'item. Le clic ouvre le popover avec les limites et les sessions Claude.

- [x] T015 [P] [US1] Tests dans `Tests/NotchUsageAppTests/AppPresentationTests.swift`. Ils doivent échouer avant T016.
  - `BarContentImage.size(for:)` : calme « 42 % » ≈ 14 + 5 + largeur du texte. Compact = 18 × 18, comme la 014.
  - La largeur maximale pour jauge + « 2:05 » + glyphe + « 9+ » reste sous la borne fixée (cas limite « Taille de l'item »).
  - `BarContentImage.colors(dark:)` : violet `#BF5AF2` sur barre sombre, `#A43BD6` sur barre claire. Monochrome blanc ou noir. Ambre, orange et rouge identiques dans les deux cas.
- [x] T016 [US1] Créer `App/NotchUsage/Notch/BarContentImage.swift`. T015 passe au vert.
  - `static func image(_ content: BarContent, beatPhase: Bool) -> NSImage`, avec `isTemplate = false` et un `drawingHandler` qui lit `NSAppearance.currentDrawing()` (R3).
  - Anneau : 14 × 14, trait 2,2, piste à 30 %, arc depuis midi dans le sens horaire.
  - Texte : système 12,5 semibold, chiffres tabulaires, écart de 5 avec l'anneau.
  - Glyphe : SF Symbol de la 017, 15 × 15. Nombre en mono 12 bold, collé (écart -3). Mot d'arrivée après le glyphe.
  - `attentionAsBadge` : point violet sur la jauge, comme dans la 017.
  - Battement : `beatPhase` alterne l'opacité de l'anneau. Aucun battement si Réduire les animations est actif.
  - Valeurs exactes : voir [surfaces.md](contracts/surfaces.md).
- [x] T017 [US1] Créer `App/NotchUsage/Views/PanelContentView.swift` :
  - Extraire de `NotchRootView.ExpandedContainer` le choix entre réglages, `ConnectView` et `ExpandedView`, ainsi que la mesure de hauteur.
  - Paramètre `showsMenuFooter: Bool` : ajoute Actualiser, Réglages et Quitter en bas (FR-009).
  - `NotchRootView` utilise `PanelContentView(showsMenuFooter: false)`. Le rendu de l'île ne change pas (SC-005).
- [x] T018 [US1] Modifier `App/NotchUsage/Notch/StatusItemController.swift` :
  - Longueur `NSStatusItem.variableLength`.
  - `update(content: BarContent, beat:)` remplace `update(display:accessibility:)`. Il redessine seulement si `content` ou la phase de battement a changé (FR-021), et règle `button.setAccessibilityLabel(content.accessibility)` (FR-019).
  - `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`. Clic gauche : `NSPopover` (`behavior = .transient`, `NSHostingController(rootView: PanelContentView(showsMenuFooter: true).environment(model))`). Clic droit : le menu actuel via `statusItem.menu` temporaire et `performClick`.
  - `closePopover()` est public.
  - Le menu de la 014 (limites et sessions) reste le contenu du clic droit tant que l'app ne le change pas.
- [x] T019 [US1] Item compact selon la barre active (FR-022, R4), dans `StatusItemController.swift` :
  - Observer `NSWindow.didChangeScreenNotification` sur `statusItem.button?.window`.
  - En secours, `NSWorkspace.didActivateApplicationNotification` relit `button.window?.screen`.
  - `onActiveScreenChange(String?)` remonte l'`id` de l'écran.
  - Aucun timer.
- [x] T020 [US1] Modifier `App/NotchUsage/AppModel.swift` :
  - `activeBarScreenID: String?`.
  - `barContent` est calculé dans `recompute()` par `BarContent.make(...)`. Si `activeBarScreenID` est l'écran de l'île, l'item reçoit `.compact`.
  - Appeler `statusItem?.update(content:beat:)`.
  - Ouvrir le popover met `hover = false` (île fermée). Ouvrir l'île (`hover = true`) appelle `statusItem?.closePopover()` (FR-010).
- [x] T021 [US1] Modifier `App/NotchUsage/AppModel+Demo.swift` : ajouter `com.notchusage.debug.menubar`, objet "notch" | "external", qui force `activeBarScreenID` (R9). Le combiner avec `demo` et `claude` pour les captures : `normal`, `near`, `imminent`, `claude=approval3`, `claude=arrival`, `offline`.

**Point de contrôle** : quickstart, essais 4 à 7. Capture de l'item en barre sombre et en barre claire.

## Phase 5: US3 - Pastille centrée, en option (P2)

**Objectif** : une capsule de 18 pt au centre de la barre de chaque écran sans encoche d'au moins 1700 pt, et une carte au survol.

**Test indépendant** : option activée, mode démo `nonotch`, externe de 1920 pt : chaque état de la section C′ de la planche s'affiche. Sur un écran de 1440 pt, pas de pastille.

- [x] T022 [P] [US3] Créer `App/NotchUsage/Views/CapsuleView.swift`, la vue SwiftUI qui rend un `BarContent` :
  - Anneau 12, texte 12 semibold, filet 1 × 11, glyphe 14 + nombre.
  - Voile : blanc 13 % avec liseré 10 % sur barre sombre, noir 7 % avec liseré 8 % sur barre claire. Au survol : blanc 24 %.
  - Imminent : fond rouge 18 % et liseré rouge 45 %.
  - Élargissement symétrique avec un fondu de 0,3 s, aucun fondu si Réduire les animations est actif.
  - Variante `fullscreenDot` : point de 7, violet si Claude attend, rouge pulsant si imminent, rien au calme (FR-017).
  - `accessibilityLabel(content.accessibility)`.
- [x] T023 [US3] Créer `App/NotchUsage/Notch/CapsulePanelController.swift`, un contrôleur par écran éligible :
  - Un `NSPanel` non activant, avec le même niveau (`mainMenu + 3`) et les mêmes `collectionBehavior` que `NotchPanel`.
  - Hauteur de barre = `screen.frame.maxY - screen.visibleFrame.maxY`. Si elle vaut 0 (barre masquée automatiquement), rien n'est affiché.
  - Capsule centrée en x, `y` = bas de la barre + 3, hauteur 18. La fenêtre est assez large pour l'élargissement maximal, transparente aux clics hors de la capsule.
  - Carte : second panneau de largeur 380, 6 pt sous la barre, rayon 12, matériau sombre, contenu `PanelContentView(showsMenuFooter: false)`.
  - Survol : 0,15 s pour ouvrir, 0,10 s après la sortie de la capsule et de la carte pour fermer, Échap ferme (FR-015). Reprendre la mécanique de `NotchPanelController`.
  - `apply(content:appearance:fullscreen:)`.
- [x] T024 [US3] Modifier `App/NotchUsage/AppModel.swift` :
  - `showsCenterCapsule` dans UserDefaults, clé "showsCenterCapsule", défaut `false` (FR-011).
  - `capsules: [String: CapsulePanelController]`, synchronisé sur `screenRoles.plain.filter(\.capsuleEligible)` à chaque changement de rôles ou de réglage.
  - L'apparence vient de `statusItem.button.effectiveAppearance`, sinon de `NSApp.effectiveAppearance` (R6).
  - `recompute()` pousse `barContent` (jamais `.compact`) aux pastilles.
  - Une seule carte ou un seul popover ouvert à la fois.
- [ ] T025 [US3] Plein écran par écran : `FullscreenObserver.screens` reçoit l'écran de l'île et ceux des pastilles. Une pastille dont l'écran est couvert passe en `fullscreenDot` (FR-017).
- [ ] T026 [US3] Démo et captures : `nonotch`, puis avec la pastille activée : `normal`, `normal claude=arrival`, `near claude=question`, `imminent claude=approval`, survol (carte), barre claire.

**Point de contrôle** : quickstart, essais 8 à 10.

## Phase 6: US4 - Réglages, accessibilité, documentation (P3)

**Objectif** : réglage d'icône à trois valeurs, option pastille, VoiceOver, traductions, README.

**Test indépendant** : changer chaque réglage et constater l'effet immédiat. VoiceOver sur l'item et sur la pastille.

- [x] T027 [US4] Modifier `App/NotchUsage/AppModel.swift` :
  - `menuBarIconMode: MenuBarIconMode`, clé "menuBarIconMode".
  - Au premier lancement, si la clé est absente : `migrate(legacy:)` depuis "showsMenuBarIcon", puis suppression de l'ancienne clé (R8).
  - `setMenuBarIconMode(_:)` remplace `setMenuBarIcon`. L'item est créé ou retiré selon `isVisible(roles:)` à chaque changement de rôles (FR-018).
- [x] T028 [US4] Modifier `App/NotchUsage/Views/SettingsView.swift` :
  - Sélecteur « Menu bar icon » (Automatic, Always, Never) à la place de la bascule de la 014, avec la note d'aide en mode Automatique.
  - Bascule « Centered capsule on wide screens ».
  - Mettre à jour la hauteur mesurée du panneau (013).
- [x] T029 [P] [US4] Ajouter dans `App/NotchUsage/Resources/Localizable.xcstrings` les 6 textes de [surfaces.md](contracts/surfaces.md), en anglais et en français (FR-020). `scripts/check-localizations.sh` doit rendre 0.
- [ ] T030 [US4] Accessibilité : vérifier avec VoiceOver l'item, le popover, la capsule et la carte. L'annonce doit être identique à celle de l'île (FR-019, SC-006). Vérifier le glyphe et le nombre sur une capture en niveaux de gris.
- [ ] T031 [US4] Mettre à jour `README.md`, en anglais et dans la section française :
  - Remplacer la puce « Works everywhere » (ligne de la pilule) et la ligne de dépannage « Nothing shows on an external display ».
  - Ajouter les captures de l'item et de la pastille dans `docs/images/`.
  - Lier la planche `docs/design/external-screen.png`.
  - Documenter la limite connue (R6).

## Phase 7: Validation

- [ ] T032 `swift test` et `xcodebuild test` verts ; `scripts/check-localizations.sh` rend 0.
- [ ] T033 Quickstart, essais 1 à 12, en réel : MacBook et Dell P2425HE de 1920 pt, capot ouvert puis fermé, externe principal puis secondaire. Noter les écarts dans une section « Validation » en bas de ce fichier.
- [ ] T034 Budgets : 10 min au repos, item et pastille affichés. CPU moyen < 1 %, empreinte < 60 Mo (SC-004). Version et notes de release dans `docs/release-notes/` au moment de la sortie.

## Dépendances

- **Phase 2** :
  - T003 dépend de T002, T005 de T004 et T003, T007 de T006, T009 de T008.
  - T002, T004, T006 et T008 peuvent démarrer en parallèle.
  - T006/T007 et T008/T009 sont indépendants de T003 et T005, sauf pour l'utilisation de `ScreenRoles` dans `isVisible`, qui fait dépendre T007 de T003.
- **US2** (dépend de la phase 2) :
  - T010 dépend de T003 et T005.
  - T011 dépend de T010.
  - T012 dépend de T005.
  - T013 et T014 dépendent de T011.
- **US1** (dépend de la phase 2 et de US2, à cause de `ScreenRoles` dans `AppModel`) :
  - T015 et T017 peuvent démarrer en parallèle.
  - T016 dépend de T015 et T009.
  - T018 dépend de T016 et T017.
  - T019 dépend de T018.
  - T020 dépend de T011, T018 et T019.
  - T021 dépend de T020.
- **US3** (dépend de US1, à cause de `PanelContentView`, `barContent` et de l'apparence lue sur l'item) :
  - T022 peut démarrer en parallèle dès T009.
  - T023 dépend de T017 et T022.
  - T024 dépend de T020 et T023.
  - T025 dépend de T013 et T024.
  - T026 dépend de T025.
- **US4** :
  - T027 dépend de T007 et T011.
  - T028 dépend de T027 et T024.
  - T029 peut se faire à tout moment après T028.
  - T030 et T031 se font en fin de parcours.

## Parallélisme

- Phase 2 : T002, T004, T006 et T008 se lancent ensemble. Ensuite T003, T007 et T009 se font en parallèle (fichiers distincts), puis T005.
- US1 : T015 (tests de rendu) et T017 (extraction de `PanelContentView`) se font en parallèle.
- US3 : T022 (`CapsuleView`) peut avancer pendant US1.

## Stratégie

1. **MVP** : phase 2, puis US2 et US1 (T002 à T021).
   - Capot fermé, la pilule est remplacée par l'item enrichi et son popover.
   - MacBook seul, l'île ne change pas.
   - C'est livrable seul (0.6.0-preview).
2. **US3** : la pastille, derrière son option désactivée par défaut, donc sans risque pour qui ne l'active pas.
3. **US4** : réglages et documentation. T027 (migration) peut remonter dans le MVP si l'on veut que « Automatique » s'applique dès la première version : sans lui, l'item n'apparaît qu'aux utilisateurs qui avaient activé l'icône de la 014. **Recommandé : faire T027 dans le MVP.**

## Validation MVP (2026-11-09, build Debug)

- **Fait** : T002 à T012, T014 à T021, T027. Tests : core 298 (5 suites nouvelles ou réécrites), app 13 (4 nouveaux). Catalogue : 124 textes, aucun sans traduction.
- **Écarts au plan** :
  - `NotchSignal.limitTrailing` est ajouté : sans lui, au palier avec Claude, la barre perdait le temps restant (l'île cède son oreille). Le test `tierKeepsRemainingTimeNextToClaude` couvre ce cas.
  - Le pied de menu du popover est inutile : `ExpandedView` porte déjà Actualiser, Réglages et Quitter. `PanelContentView(reportsHeight:)` remplace `showsMenuFooter`.
  - Popover sur fond noir 92 %, `vibrantDark` : sinon le matériau suit la barre et le texte blanc devient illisible.
  - Le battement de l'item est une phase éclairée de 0,4 s à chaque `beat`, pas une alternance continue.
  - Réglages depuis le menu sans île : ouvrent le popover sur les réglages.
- **Partiel** :
  - T013 : `FullscreenObserver` suit l'écran de l'île seulement. Le suivi de plusieurs écrans arrive avec T025.
  - T028 : le sélecteur d'icône (Automatique, Toujours, Jamais) est fait, la bascule de pastille attend US3.
  - T029 : les 5 textes de l'icône sont traduits, celui de la pastille attend US3.
- **Captures démo** (`menubar=external`, rendu en barre sombre et claire) : normal « 42% », far « 2:05 » ambre, near + question « 40′ » orange avec la bulle, imminent + approbation « 8′ » rouge avec le point violet, approval3 « ✋3 », arrival « ✋ Approval », blocked + done « 1:02 » avec un point blanc ou noir, offline « 42% » atténué, reauth anneau vide, compact sur la barre de l'encoche. Le popover reprend le panneau de l'île à l'identique.
- **Pas encore testé en réel** : la bascule compact / enrichi en cliquant d'un écran à l'autre (le spike la valide), le capot fermé, VoiceOver, et Échap dans le popover.
- **Tests app** : `xcodebuild test` échoue au chargement du bundle quand `Config/Local.xcconfig` signe l'app avec une identité Apple Development (Team ID différent du bundle de test). Cela ne vient pas de la 018. Contournement : `xcodebuild test -scheme NotchUsage CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`.

## US3, première passe (2026-11-09)

- T022 à T024 faits : `CapsuleView`, `CapsulePanelController` (capsule + carte au survol, Échap), option « Centered capsule on wide screens » (fr : « Pastille centrée sur les grands écrans »), une pastille par écran éligible.
- La fenêtre épouse la capsule, pour ne pas prendre les clics des menus voisins. L'élargissement est animé sur 0,3 s.
- Plein écran (T025) : la pastille n'apparaît pas dans les espaces plein écran (pas de `fullScreenAuxiliary`). Le point centré de la 006 reste à faire.
- À valider en réel sur le Dell : position verticale dans la barre, contraste en barre claire et sombre, survol, carte.
