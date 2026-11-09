# Research : Écran sans encoche

## R1 - Rôle des écrans et retrait de la pilule

- **Décision** : une fonction pure `ScreenRoles.assign(screens:)` dans le core reçoit, pour chaque écran, son identifiant, sa largeur, `safeAreaTop`, les zones auxiliaires et s'il porte la barre principale. Elle rend l'écran de l'île (optionnel : le premier écran à encoche, de préférence celui de la barre principale, FR-001, FR-003) et la liste des écrans sans encoche avec leur éligibilité à la pastille (largeur ≥ 1700 pt, FR-012, FR-016). `NotchGeometry.layout` ne rend plus que l'encoche (`NotchLayout?`) ; `DisplayMode.pill` disparaît.
- **Rationale** : la règle est décidable et testable sans AppKit (constitution III). Aujourd'hui `ScreenObserver` prend `NSScreen.screens.first`, ce qui place l'île sur l'écran principal même sans encoche.
- **Alternatives** : garder la pilule comme repli (écartée par la planche) ; un écran « préféré » choisi par l'utilisateur (YAGNI).

## R2 - Contenu partagé entre île, item et pastille

- **Décision** : un type pur `BarContent` dérivé de `NotchSignal` (déjà calculé à chaque `recompute`) : jauge (fraction, teinte, battement), texte (pourcentage ou temps restant, emphase rouge à l'imminence), attente Claude (glyphe, nombre, mot d'arrivée, point violet). L'item et la pastille le rendent chacun à leur façon. Variante `compact` pour FR-022 (jauge seule).
- **Rationale** : une seule règle pour trois surfaces ; la 017 (priorité face à la limite) et la 003 (texte du palier) ne sont pas réécrites.
- **Alternatives** : relire `DisplayState` dans chaque surface (dupliquerait la règle de priorité).

## R3 - Rendu de l'item enrichi

- **Décision** : `NSStatusItem` de longueur variable. Le bouton porte une seule `NSImage` à `drawingHandler`, non-modèle, qui dessine anneau, texte et glyphe (SF Symbol de la 017) avec des couleurs résolues **au moment du dessin** depuis `NSAppearance.currentDrawing()` : blanc ou noir pour le monochrome, teintes de palier, violet #BF5AF2 ou #A43BD6 selon l'apparence (FR-005, FR-008). L'image n'est remplacée que si `BarContent` change (FR-021). Le battement réutilise le `beat` existant du modèle (006) : deux images alternées, aucun timer nouveau.
- **Rationale** : une image modèle ne peut pas porter de couleur ; une image à `drawingHandler` est redessinée par AppKit quand l'apparence de la barre change (fond d'écran clair ou sombre), sans qu'on l'observe.
- **Alternatives** : vue personnalisée dans le bouton (plus de code de mise en page, mêmes résultats) ; `attributedTitle` + image (le texte coloré n'est pas résolu selon l'apparence de la barre).

## R4 - Item compact sur la barre de l'écran à encoche (FR-022)

- **Décision** : observer `NSWindow.didChangeScreenNotification` sur `statusItem.button.window`, avec relecture sur `NSWorkspace.didActivateApplicationNotification` en filet. L'écran trouvé est passé à `ScreenRoles` : à encoche → `compact`, sinon → enrichi.
- **Rationale** : [spike-statusitem.md](spike-statusitem.md) montre que la fenêtre de l'item est sur l'écran de la barre active, pas sur l'écran principal, et que `didChangeScreen` arrive à chaque bascule, moins de 0,1 s après le changement d'app active (T001 fait, 4 allers-retours sans raté).
- **Repli** : non nécessaire (item enrichi partout, prévu par la spec, abandonné).

## R5 - Popover au clic, menu au clic droit

- **Décision** : `NSPopover` (`behavior = .transient`) hébergeant la vue de contenu du panneau, extraite de `NotchRootView` en `PanelContentView` partagée (connexion, limites, sessions Claude, réglages). Le bouton envoie son action sur `leftMouseUp` et `rightMouseUp` ; clic droit → le menu actuel de la 014 (`popUpMenu`). Ouvrir le popover met `hover = false` sur l'île ; ouvrir l'île ferme le popover (cas limite « ouverts en même temps »). Changement de configuration d'écran → fermeture (FR-010).
- **Rationale** : un seul contenu (SC-005) ; `.transient` gère clic extérieur et Échap.
- **Alternatives** : menu enrichi avec `NSMenuItem.view` (pas de survol fiable, hauteur variable mal gérée).

## R6 - Pastille centrée

- **Décision** : un `CapsulePanelController` par écran éligible : `NSPanel` non activant, même niveau et même comportement d'espace que `NotchPanel`, centré en x, `y = screen.frame.maxY - hauteurBarre + 3`, hauteur 18. Hauteur de la barre : `screen.frame.maxY - screen.visibleFrame.maxY` ; si elle est nulle (barre masquée automatiquement), pas de pastille. Fond : voile dessiné en SwiftUI (`white 13 %` ou `black 7 %`) selon l'apparence de la barre, lue sur `statusItem.button.effectiveAppearance` quand l'item existe, sinon `NSApp.effectiveAppearance`. La carte : un second panneau 6 pt sous la barre, mêmes délais de survol que l'île (0,15 s / 0,10 s), contenu `PanelContentView`.
- **Rationale** : réutilise la mécanique de survol de `NotchPanelController` (`HoverView`, délais) sans la fusion île / panneau.
- **Limite connue** : sans item affiché (réglage « Jamais »), l'apparence de la barre est approchée par celle du système ; un fond d'écran clair en mode sombre donnera un voile clair sur barre claire. Accepté, documenté dans le quickstart.
- **Alternatives** : `NSVisualEffectView` (matériau différent de la barre, effet « îlot ») ; dessiner dans la barre via l'item (impossible au centre).

## R7 - Plein écran par écran

- **Décision** : `FullscreenObserver` évalue une liste d'écrans (celui de l'île et ceux des pastilles) et publie l'ensemble des écrans couverts. `FullscreenHeuristic` est inchangée. Sur un écran de pastille couvert : point centré de la 006, sinon rien.
- **Alternatives** : un observateur par écran (abonnements dupliqués).

## R8 - Réglage d'icône à trois valeurs

- **Décision** : `MenuBarIconMode { automatic, always, never }` dans le core, avec `MenuBarIconMode.migrate(legacy: Bool?)` : `true` → `always`, sinon `automatic` (FR-018). Visibilité : `automatic` → visible si `ScreenRoles` compte au moins un écran sans encoche. Clé `menuBarIconMode` ; l'ancienne clé `showsMenuBarIcon` est lue une fois puis supprimée.
- **Alternatives** : garder un booléen et forcer l'item sans encoche (contre-intuitif dans les réglages).

## R9 - Mode démo

- **Décision** : la commande de débogage `com.notchusage.debug.layout "pill"` devient `"nonotch"` : simule l'absence d'écran à encoche (pas d'île, item enrichi, pastille si activée). Nouvelle commande `com.notchusage.debug.menubar "notch" | "external"` pour forcer la barre active en démo (FR-022).
