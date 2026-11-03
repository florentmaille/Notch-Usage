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

## Résultats

À remplir à l'implémentation.
