# Contrat : battement du halo

`NotchSignal.make(…)` renvoie aussi `pulse`. `AppModel` compte les battements sur son tick de
30 s ; `NotchShape` anime l'opacité du halo à chaque incrément de `beat`.

## Rythme par état

| État de l'encoche | `edge` | `pulse` | Battements par minute |
|---|---|---|---|
| Blocage prévu dans 25 min (`imminent25`) | `imminent` | `everyMinute` | 1 |
| Blocage prévu dans 8 min (`imminent`) | `imminent` | `everyHalfMinute` | 2 |
| Blocage prévu dans 40 min (`near`) | `near` | `none` | 0 |
| Blocage prévu dans 2 h (`far`) | `far` | `none` | 0 |
| Limite épuisée (`blocked`) | `exhausted` | `none` | 0 |
| Seuil critique sans prévision (`critical` du 003 : prévision à 50 min, donc `near`) | `near` | `none` | 0 |
| Seuil d'attention sans prévision (`warning`) | `far` | `none` | 0 |
| Survol ou épinglé, quel que soit l'état | `nil` (bande) | `none` | 0 |
| Relevé ancien, hors ligne, session, compte | `nil` | `none` | 0 |
| Silence | `nil` | `none` | 0 |

## Cadence

| Tick n (30 s ± 5 s) | Signal avant le tick | `beat` |
|---|---|---|
| quelconque | `everyHalfMinute` | +1 |
| pair | `everyMinute` | +1 |
| impair | `everyMinute` | inchangé |
| quelconque | `none` | inchangé |
| le tick qui fait entrer l'état imminent | (`none` avant) | inchangé |

## Rendu

| Condition | Halo |
|---|---|
| `beat` incrémenté, `edge.hasHalo`, animations normales | opacité 0,6 → 1,0 → 0,6 en 600 ms, puis repos |
| `reduceMotion` | 0,6 fixe |
| `edge` sans halo | aucun halo |
| pendant le battement | trait, épaisseur, teinte, rayon, cadre du panneau, `edgePad` : identiques |

## Démo

| Commande | Attendu |
|---|---|
| `swift scripts/demo.swift imminent25` | liseré rouge + halo ; 1 battement par minute, le premier au 2e tick après l'entrée |
| `swift scripts/demo.swift imminent` | 1 battement toutes les 30 s, le premier au tick suivant l'entrée |
| `swift scripts/demo.swift imminent snapshot`, puis `tick snapshot` | capture au repos, puis à mi-battement (le script attend 0,3 s après `tick`) : halo plus dense, même géométrie |
| `… imminent25`, puis `tick snapshot` deux fois | un battement sur les deux captures (un tick sur deux) |
