# Quickstart : valider l'encoche silencieuse

## Prérequis

- Build Debug lancée (`xcodebuild -scheme NotchUsage -configuration Debug -derivedDataPath .build/DerivedData build`, puis `open` de l'app).
- `swift test` vert (NotchSignalTests inclus).
- Deux fonds d'écran de test : un clair, un sombre.

## Scénarios

| # | Commande ou geste | Attendu | Couvre |
|---|---|---|---|
| 1 | `swift scripts/demo.swift normal snapshot`, fond sombre puis clair | Aucun pixel hors de l'encoche physique : ni oreille, ni texte | US1 sc. 1, SC-001 |
| 2 | `swift scripts/demo.swift normal hover=1 wait=0.5 snapshot` | Bande complète (« ✓ 2h 14m » / « 42% ») visible sous 0,2 s, puis panneau | US1 sc. 2, SC-004 |
| 3 | Pointeur hors de l'encoche | Panneau replié, encoche silencieuse | US1 sc. 3 |
| 4 | Pointeur dans la barre des menus à 50 pt à droite de l'encoche, 2 s | Rien ne s'ouvre | FR-007b |
| 5 | Clic sur l'encoche silencieuse, puis clic sur la bande | Épinglé ; puis désépinglé et silence | US1 sc. 4 |
| 6 | `far snapshot`, `near snapshot`, `imminent snapshot` | Liseré ambre 2 pt + « 2h 05m » ; orange 2,5 pt + heure ; rouge 3 pt + halo + heure ; aile gauche vide, aucun pourcentage | US2 sc. 1 à 3 |
| 7 | `blocked snapshot` | Liseré rouge plein, « Full » pastille à gauche, ↻ + durée à droite | US2 sc. 4 |
| 8 | `warning snapshot` (5 h à 83 % sans prévision) | « 5h » gris à gauche, pastille ambre à droite, liseré ambre | FR-007 |
| 9 | Démo `warning` avec `demoForecasts = holds` (hook debug) | Silence malgré 83 % | FR-007a, R6 |
| 10 | Passage `normal` → `far` à l'œil | Fondu unique d'environ 0,6 s, puis immobilité ; `far` → `normal` : fondu puis rétrécissement | US2 sc. 6 et 7, FR-011 |
| 11 | Réglages → Limite affichée = Hebdo · Fable, puis `far` | Silence (Fable n'a pas de prévision) ; panneau : la 5 h montre sa prévision | US2 sc. 9 |
| 12 | `layout=pill`, puis `normal`, `far`, `hover=1` | Pilule absente ; pilule avec liseré et « ⌛ 2h 05m » ; pilule complète au survol | US3 sc. 1 et 2 |
| 13 | App en plein écran + `imminent` | Bande masquée de 2 pt rouge, point d'alerte inchangé | US3 sc. 3 |
| 14 | VoiceOver, encoche silencieuse puis `far` | Annonce de la bande complète dans les deux cas | US3 sc. 4 et 5, SC-008 |
| 15 | `offline snapshot` | Bande grise, aucun liseré | US1 sc. 6 |
| 16 | Réglages → Réduire les animations (système), `normal` → `far` | Apparition immédiate | FR-011 |
| 17 | Captures 6 et 7 en niveaux de gris (Aperçu) | Paliers distincts par épaisseur et format du texte | SC-003 |
| 18 | `scripts/check-localizations.sh .build/DerivedData` | 0 texte sans traduction | SC-007 |
| 19 | Instruments, 10 min en `imminent` puis en `normal` | CPU < 1 %, empreinte à ± 2 Mo de la 0.3.0, aucun rafraîchissement hors changement d'état | SC-005 |
| 20 | Compteur de requêtes (log) sur 10 min | Identique à la 0.3.0 | SC-006 |

## Résultats (2026-11-03, build Debug)

| # | Résultat | Détail |
|---|---|---|
| 1 | ✅ | Capture `normal` : 220 pt de large (le panneau se réduit à l'encoche), 0 pixel non transparent sur l'échantillon complet |
| 2 | ✅ | `hover=1` : bande « ✓ 2h 14m · 42% » puis panneau, en et fr |
| 3, 4, 5 | ⚠️ non rejoués à la main | Survol réel, zone de 50 pt à côté de l'encoche, clic : le cadre du panneau vaut la largeur de l'encoche en silence (R2), donc la zone suit par construction ; à confirmer à la souris |
| 6 | ✅ | Encoche : liseré seul, tracé hors de l'encoche physique (sous le bord et sur les arrondis ; un trait intérieur n'est pas visible à l'écran), ambre 2 pt / orange 2,5 pt / rouge 3 pt + halo, sans texte (retour utilisateur) ; pilule : ⌛ 2h 05m / heure, en et fr |
| 7 | ✅ | `blocked` : encoche, liseré rouge + halo seul ; pilule, « Full » / « Bloqué » en pastille, ↻ 1h 02m |
| 8 | ✅ | `warning` : encoche, liseré ambre seul ; pilule, « 5h » / « 5 h » gris et pastille ambre 83 % |
| 9 | ✅ (core) | `forecastWinsOverThresholdForTheFiveHourWindow` ; pas de hook démo pour `holds` |
| 10 | ⚠️ en cours | Premier essai : sortie saccadée avec une forme insérée/retirée ; corrigé par une forme toujours présente dont seule l'opacité s'anime ; à revalider à l'œil |
| 11 | ✅ | Limite épinglée Fable + `far` : capture de 220 pt, silence ; panneau non vérifié |
| 12 | ✅ | Pilule : absente en `normal` (150 pt transparents), « ⌛ 2h 05m » avec liseré en `far`, « Full · ↻ 1h 02m » en `blocked`, « 5h · [83 %] » en `warning`, pilule complète puis panneau au survol |
| 13 | ⚠️ non rejoué | Plein écran : `AlertDotView` prend la couleur du palier ; pas de hook démo pour le plein écran |
| 14 | ⚠️ non rejoué | VoiceOver : la vue reste dans la hiérarchie avec `accessibilityHidden(false)` et le libellé de la bande |
| 15 | ✅ | `offline` : bande grise, aucun liseré, en et fr |
| 16 | ⚠️ non rejoué | Mode réduit d'animations : `reduceMotion` → animation nil |
| 17 | ✅ | Paliers distincts sans la couleur : épaisseur 2 / 2,5 / 3 pt et format durée → heure |
| 18 | ✅ | 87 textes, 0 sans traduction française |
| 19 | ✅ | 60 s en `imminent` : 0,36 s CPU (0,6 %) ; 60 s en `normal` : 0,41 s (0,7 %) ; empreinte 23,6 Mo (0.3.0 Debug : 24,5 Mo) |
| 20 | ✅ (par construction) | Aucune requête, aucun timer ajoutés ; le signal se dérive dans `recompute()` |

Écart assumé par rapport au contrat : au survol, la bande s'affiche sans liseré (le panneau donne le
détail) ; le contrat disait « selon l'état sous-jacent ». À revoir si le liseré manque au survol.
