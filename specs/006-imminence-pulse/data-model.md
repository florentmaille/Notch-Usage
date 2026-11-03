# Data Model: Battement d'imminence

Tout vit dans `NotchUsageCore` (Foundation seul) sauf les compteurs de cadence, dans l'app.
Rien n'est persisté.

## NotchSignal.Pulse (nouveau, dans le core)

Rythme du battement du halo, dérivé en même temps que le signal.

| Cas | Quand |
|---|---|
| `none` | tout contenu autre que `deadline` ; `deadline` avec `edge` ≠ `imminent` |
| `everyMinute` | `deadline`, `edge == .imminent`, blocage prévu dans 10 min ou plus (et moins de 30 min, par définition du palier) |
| `everyHalfMinute` | `deadline`, `edge == .imminent`, blocage prévu dans moins de 10 min |

Règles :

- Calcul : `remaining = blockAt - now` ; `remaining < 600` → `everyHalfMinute` ; sinon `everyMinute` si le palier est `imminent` ; sinon `none`.
- `band` (survol, épinglage, gris, session, compte), `exhausted`, `threshold`, `silent` → toujours `none`.
- Le rythme porte sur la limite affichée, comme le palier (004, 005).

## NotchSignal (modifié)

| Champ | Type | Règle |
|---|---|---|
| `content` | `Content` | inchangé (005) |
| `edge` | `Edge?` | inchangé (005) |
| `pulse` | `Pulse` | nouveau, voir ci-dessus |
| `accessibility` | String | inchangé |

Invariant : `pulse != .none` implique `edge == .imminent` et `content` est `deadline`.

## Cadence (app, `AppModel`)

| Champ | Type | Règle |
|---|---|---|
| `tickCount` | Int, privé | +1 à chaque tick de 30 s |
| `beat` | Int, `private(set)` | +1 à un tick quand le signal **avant** le recalcul du tick avait `pulse == .everyHalfMinute`, ou `pulse == .everyMinute` et `tickCount` pair ; sinon inchangé |

La vue observe `beat` ; chaque incrément déclenche un battement. `beat` n'est jamais remis à zéro.

## Rendu (app, `NotchShape`)

| Entrée | Effet |
|---|---|
| `beat` change | double battement en 1 s : opacité 0,6 → 1 → 0,7 → 1 → 0,6, rayon 6 → 14 pt et trait éclairci de 45 % sur la montée |
| `reduceMotion` | opacité fixe à 0,6, rayon 6 pt, aucune animation |
| `edge` sans halo (`far`, `near`) ou `nil` | aucun halo, `beat` sans effet |

## Démo (Debug)

| Élément | Valeur |
|---|---|
| état `imminent25` | 5 h à 85 %, réinitialisation dans 60 min, `blockAt` dans 25 min → `everyMinute` |
| état `imminent` (existant) | 5 h à 92 %, `blockAt` dans 8 min → `everyHalfMinute` |
| commande `tick` | exécute un tick : `now = Date()`, `recompute()`, comptage du battement |
