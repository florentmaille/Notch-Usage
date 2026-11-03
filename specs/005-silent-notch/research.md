# Research: Encoche silencieuse et liseré d'échéance

## R1. Où décider du silence

- **Decision**: une valeur pure du core, `NotchSignal.make(display:now:language:strings:)`, qui
  renvoie un contenu (silence, bande complète, donnée unique, épuisement, seuil) et un palier de
  liseré. `DisplayState` et `CompactStrip` ne changent pas ; le signal les lit. Le survol et
  l'épinglage (`display.isExpanded`) forcent la bande complète.
- **Rationale**: même règle que la 003 : la vue dessine, elle ne décide pas. Le silence dépend de
  quatre sources (prévision, seuils, fraîcheur, session) et d'un réglage (limite épinglée) : la
  combinaison se teste en core sur fixtures, pas dans SwiftUI.
- **Alternatives considered**: calculer dans `CompactView` (non testable) ; étendre `CompactStrip`
  (voir Complexity Tracking du plan).

## R2. Zone de survol en état calme

- **Decision**: en silence, le panneau prend la largeur de l'encoche physique (`layout.width`) au
  lieu de `layout.width + 2 × 72`. La zone de suivi (`.inVisibleRect`) et les clics suivent
  d'eux-mêmes. Quand un texte apparaît, le panneau s'élargit d'abord (contenu à opacité 0), puis
  le fondu joue ; au retour au silence, le fondu joue puis le panneau rétrécit après 600 ms
  (`DispatchWorkItem` annulable si l'état rebascule).
- **Rationale**: un panneau transparent de 364 pt au-dessus de la barre des menus absorberait les
  clics sur les éléments de statut situés sous les anciennes oreilles, sans rien montrer : une zone
  morte invisible. Réduire la fenêtre à l'encoche est déterministe et satisfait SC-001 par
  construction. En pilule, la même règle donne une zone de 150 × 28 pt, invisible mais sans
  élément de menu dessous.
- **Alternatives considered**: garder 364 pt et limiter la zone de suivi par un rectangle
  (clics toujours absorbés) ; compter sur le passage des clics à travers les pixels transparents
  d'une fenêtre non opaque (comportement non garanti pour le survol, à ne pas prendre comme base).

## R3. Paliers du liseré

- **Decision**: quatre paliers dérivés du temps avant le blocage prévu, calculés dans le core :
  lointain (≥ 60 min) ambre 2 pt ; proche (< 60 min) orange 2,5 pt ; imminent (< 30 min) rouge
  3 pt avec halo ; épuisé rouge 3 pt avec halo. Couleurs : ambre `#FF9F0A`, orange `#FF6A1A`,
  rouge `#FF453A` (teintes système en apparence sombre). Le format du texte change au même
  seuil que la 003 (durée à 60 min et plus, heure en dessous), ce qui distingue lointain et proche
  sans la couleur (FR-016). Le halo est une ombre portée de 6 pt sous le trait, statique.
- **Rationale**: trois teintes et trois épaisseurs suffisent à lire l'urgence de loin ; une
  variation continue de la teinte n'ajoute rien de lisible et complique la vérification. Les seuils
  60/30 min s'alignent sur l'hystérésis et les formats existants.
- **Alternatives considered**: teinte continue par interpolation (illisible entre deux paliers) ;
  épaisseur seule (invisible en périphérie) ; pulsation (interdite par le budget CPU).

## R4. Dessin du liseré

- **Decision** (corrigée après essai sur machine) : dans l'encoche, le trait est tracé **à l'extérieur**
  de la forme noire : un contour arrondi dont le bord intérieur coïncide avec l'encoche physique,
  tout autour (flancs, arrondis, bas ; le haut est le bord de l'écran), et le panneau déborde de l'épaisseur du trait (plus 8 pt de halo
  pour imminent et épuisé). Rien de ce qui est dessiné sous le cutout physique n'est visible : un trait
  intérieur n'apparaît que dans les captures, jamais à l'œil. En pilule, entièrement visible, le trait
  reste à l'intérieur, tout autour. Le halo est un `shadow` statique.
- **Rationale**: le liseré doit être visible sans oreilles, donc hors de l'encoche ; un contour
  arrondi offset donne les coins « qui glissent » de la planche sans chemin dessiné à la main.
- **Alternatives considered**: `border-bottom` à la main avec deux arcs (fragile aux changements
  de rayon) ; `Rectangle` de 2 pt sous la forme (coins carrés, contraire à la planche).

## R5. Fondu d'entrée et de sortie

- **Decision**: `.transition(.opacity)` avec `.animation(.easeOut(duration: 0.6))` sur l'ensemble
  oreilles + textes + liseré, déclenché par le changement de `signal.isSilent`. En mode réduit
  d'animations (`accessibilityReduceMotion`), durée 0. Aucune autre animation : le changement de
  palier (ambre → orange) est instantané.
- **Rationale**: une seule transition, un seul paramètre, rendue par le compositeur ; le
  changement de palier sans animation évite les allers-retours visibles autour d'un seuil.
- **Alternatives considered**: pulsation à chaque palier (CPU, et bruit) ; glissement vertical
  des oreilles (attire l'œil sur la forme plutôt que sur la couleur).

## R6. Priorité prévision / seuil pour la fenêtre de 5 h

- **Decision** (clarification du 2026-11-03) : pour la fenêtre de 5 h, `holdsUntilReset` →
  silence quel que soit le pourcentage ; `blockAt` → palier d'échéance ; `unavailable` ou aucune
  entrée → repli sur les seuils (ambre au seuil d'attention, rouge au critique). Les limites
  hebdomadaires n'ont que les seuils. Une limite épuisée est toujours « épuisé ».
- **Rationale**: le seuil statique se trompe la moitié du temps ; le rythme ne se trompe que
  quand il manque, et c'est précisément le cas où le seuil reprend la main.
- **Alternatives considered**: seuil toujours prioritaire (rejeté par l'utilisateur) ; seuil et
  prévision cumulés (deux signaux, retour au défaut de la 003).

## R7. Limite affichée et limite épinglée

- **Decision**: le signal porte sur `display.headline` (déjà choisie par la règle 004 :
  Automatique ou épinglée). Rien d'autre n'entre dans le signal : une limite non affichée qui
  franchit un seuil reste visible dans le panneau seulement.
- **Rationale**: FR-012 ; un seul endroit décide de la limite, et il existe déjà.
- **Alternatives considered**: signal par limite avec cumul (contredit « un seul sens, une seule
  donnée »).

## R8. Accessibilité en silence

- **Decision**: la vue compacte reste dans la hiérarchie à opacité 0 (pas retirée), avec
  `accessibilityElement(children: .ignore)` et le libellé de la bande complète ; en silence,
  `accessibilityHidden(false)` explicite. Le quickstart vérifie que VoiceOver atteint l'élément.
- **Rationale**: FR-015 ; retirer la vue retirerait l'élément d'accessibilité.
- **Alternatives considered**: élément d'accessibilité séparé (duplication du libellé).

## R9. Plein écran

- **Decision**: la bande masquée de 2 pt (`hiddenStripHeight`) prend la couleur du palier quand
  un liseré est actif ; le point d'alerte garde son comportement (seuils). Sans liseré, la bande
  reste transparente.
- **Rationale**: FR-014 ; la bande masquée est déjà un liseré, autant lui donner la couleur.
- **Alternatives considered**: ne rien changer en plein écran (le signal principal disparaîtrait
  là où l'utilisateur travaille le plus).

## R10. Mode démo

- **Decision**: trois états ajoutés à `scripts/demo.swift` et `AppModel.applyDemo` : `far`
  (blocage prévu dans 2 h 05, 55 %), `near` (40 min, 78 %), `imminent` (8 min, 92 %), via
  `demoForecasts` comme `critical`. `normal` devient silencieux ; `pace` est conservé (équivalent
  à `far`) pour les scénarios de la 003. Les captures sur fond clair utilisent `layout=notch` et un
  fond d'écran de test, hors script.
- **Rationale**: FR-018 ; chaque ligne de la planche a son état.
