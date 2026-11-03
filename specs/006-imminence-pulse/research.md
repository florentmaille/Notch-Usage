# Research: Battement d'imminence

## R1. Où décider du rythme

- **Decision**: dans le core, sur `NotchSignal` : un champ `pulse: Pulse` (`none`,
  `everyMinute`, `everyHalfMinute`) calculé dans `make(display:now:…)` à partir du palier et de
  `blockAt - now`. `everyHalfMinute` sous 10 min, `everyMinute` sous 30 min, `none` sinon et pour
  tout contenu autre que `deadline` (bande, épuisé, seuil).
- **Rationale**: même règle que la 005 : la vue dessine, elle ne décide pas. Les exclusions
  (survol, épinglé, seuil sans prévision, épuisé) tombent d'elles-mêmes : ces contenus ne sont pas
  `deadline`. Testable sur fixtures sans SwiftUI.
- **Alternatives considered**: décider dans `NotchShape` à partir de `display.forecasts` (non
  testable, duplique la lecture de la prévision) ; un palier `Edge.critical` supplémentaire (mélange
  teinte et cadence).

## R2. Quelle horloge

- **Decision**: le tick existant de `AppModel` (`tickTask`, `Task.sleep(for: .seconds(30),
  tolerance: .seconds(5))`), qui met déjà `now` à jour et recalcule l'affichage. Un compteur
  `tickCount` et un compteur `beat` : à chaque tick, après `recompute()`, `beat += 1` si le rythme
  est `everyHalfMinute`, ou si le rythme est `everyMinute` et `tickCount` est pair. La vue observe
  `beat`.
- **Rationale**: FR-008 ; le tick est déjà la cadence de l'app repliée (comptes à rebours). La
  spec parlait d'un « tick minute » : le tick réel est de 30 s, ce qui donne le rythme de 30 s sans
  horloge supplémentaire et le rythme d'une minute par parité. La tolérance de 5 s du tick devient
  celle du battement (SC-001 ajusté à ± 5 s).
- **Alternatives considered**: `TimelineView(.periodic)` dans la vue (deuxième horloge, tourne
  même sans liseré) ; `Timer` dédié (contraire à FR-008) ; `alertPulse` existant (il ne bat qu'à
  l'envoi d'une alerte, pas périodiquement).

## R3. Premier battement et changements d'état

- **Decision**: le battement n'est compté que si le signal **avant** le `recompute()` du tick
  avait déjà un rythme non nul. Le tick qui fait entrer l'état imminent ne bat pas ; le premier
  battement vient au tick suivant (30 s ou 60 s plus tard). Un changement de rythme (minute →
  30 s) s'applique au tick suivant sans animation. Survol, épinglage et retour au calme donnent un
  signal sans rythme : le compteur ne bouge plus, l'animation en cours finit ses 600 ms.
- **Rationale**: pas de battement superposé au fondu d'entrée de la 005 (600 ms) ; pas de
  battement coupé net ; aucune hystérésis propre (celle de la prévision, 003, suffit).
- **Alternatives considered**: battre dès l'entrée (double animation avec le fondu) ; annuler
  l'animation en cours à la sortie (saccade visible).

## R4. Animation du halo

- **Decision**: dans `NotchShape`, le `shadow` du trait (le halo) suit un
  `phaseAnimator([0.6, 1.0, 0.7, 1.0], trigger: beat)` avec `.easeInOut(duration: 0.2)` par phase :
  double battement de cœur en 1 s, opacité 0,6 → 1 → 0,7 → 1 → 0,6 et rayon du halo 6 → 14 pt sur
  la montée (retour utilisateur : plus marqué, puisque rare). Aucun autre paramètre n'est animé :
  trait, épaisseur, cadre du panneau restent fixes ; `haloPad` passe à 16 pt pour que le halo au
  sommet ne soit pas coupé par le cadre. Même modificateur pour la pilule.
  Avec `accessibilityReduceMotion`, le modificateur n'est pas appliqué : opacité fixe à 0,6.
- **Rationale**: `phaseAnimator` (macOS 14) revient de lui-même à la phase initiale après le
  déclenchement : pas d'état `isBeating` à gérer. Animer l'opacité d'une ombre est rendu par le
  compositeur ; aucun relayout, donc aucun risque sur la largeur du panneau (FR-003).
- **Alternatives considered**: `withAnimation` + état booléen remis à zéro par `asyncAfter`
  (état à gérer, risque de fuite si la vue disparaît) ; `symbolEffect` (réservé aux symboles) ;
  scale du halo (change la taille perçue, contraire à FR-003).

## R5. Mode démo

- **Decision**: un état `imminent25` dans `applyDemo` et `scripts/demo.swift` : 5 h à 85 %,
  réinitialisation dans 1 h, `blockAt` dans 25 min. Une commande brute `tick` (hook
  `com.notchusage.debug.tick`) qui exécute le corps du tick (now, recompute, comptage du
  battement) : `swift scripts/demo.swift imminent tick tick wait=0.3 snapshot` capture un
  battement à mi-course. Les hooks debug restent sous `#if DEBUG`.
- **Rationale**: FR-011 ; la validation du rythme ne doit pas coûter 3 min par essai, et SC-003
  demande une capture pendant le battement.
- **Alternatives considered**: réduire le tick en Debug (change le comportement mesuré) ;
  attendre (3 min par scénario).

## R6. Pilule et plein écran

- **Decision**: la pilule partage `NotchShape` et le même modificateur : rien à faire de plus.
  En plein écran, la bande masquée (`AlertDotView`) ne bat pas (hors champ, spec).
- **Rationale**: FR-007 par construction ; FR-003 identique.
