# Data Model: Encoche silencieuse et liseré d'échéance

Tout vit dans `NotchUsageCore` (Foundation seul). Rien n'est persisté.

## NotchSignal (nouveau, Equatable)

Ce que l'encoche repliée montre sans survol, dérivé de `DisplayState` à chaque recalcul.

| Champ | Type | Règle |
|---|---|---|
| `content` | `Content` | voir ci-dessous |
| `edge` | `Edge?` | palier du liseré ; `nil` = pas de liseré |
| `accessibility` | String | toujours l'annonce de la bande complète (`CompactStrip.accessibility`) |

`isSilent` : `content == .silent`.

### Content

| Cas | Données | Quand |
|---|---|---|
| `silent` | aucune | relevé frais, session valide, prévision tenable ou (indisponible et sous le seuil), limite non épuisée |
| `band(CompactStrip)` | la bande 003 | survol ou épinglage (`display.isExpanded`) ; relevé ancien ou en échec ; session expirée ; non connecté ; abonnement non pris en charge ; aucune donnée |
| `deadline(String)` | texte du blocage (« 2h 05m » / « 10:06 ») | `blockAt` sur la limite affichée, non épuisée |
| `exhausted(full: String, back: String)` | « Full » / « Bloqué » ; temps avant retour | limite affichée épuisée |
| `threshold(label: String, percent: String)` | libellé court (« 7d », « 5h ») ; « 97 % » | limite affichée au-dessus d'un seuil, sans prévision disponible |

Invariant : `band` est le seul contenu à deux ailes pleines ; `deadline` n'occupe que l'aile
droite ; `silent` n'a ni oreille ni texte.

### Edge (palier)

| Cas | Condition | Teinte | Épaisseur | Halo |
|---|---|---|---|---|
| `far` | blocage prévu dans 60 min ou plus, ou seuil d'attention sans prévision | ambre | 2 pt | non |
| `near` | blocage prévu dans moins de 60 min | orange | 2,5 pt | non |
| `imminent` | blocage prévu dans moins de 30 min, ou seuil critique sans prévision | rouge | 3 pt | oui |
| `exhausted` | limite épuisée | rouge | 3 pt | oui |

`Edge.tier(blockAt:now:)` calcule le palier d'échéance ; `Edge.tier(alertLevel:)` le palier de
seuil (`.warning` → `far`, `.critical` → `imminent`). Teintes et épaisseurs sont des constantes
de l'app, pas du core.

### Dérivation (`NotchSignal.make`)

```text
isExpanded ──────────────────────────────▶ band
content ≠ limits, banner ≠ nil, fetchFailed ▶ band (gris, cadenas, compte : contenus 003)
headline épuisée ────────────────────────▶ exhausted, edge = exhausted
forecast[headline] = blockAt(d) ─────────▶ deadline(blockLabel(d)), edge = tier(d)
forecast[headline] = holdsUntilReset ────▶ silent
sinon, alertLevel = none ────────────────▶ silent
sinon (seuil, pas de prévision) ─────────▶ threshold(shortLabel, percent), edge = tier(alertLevel)
```

`alertLevel` est celui de `DisplayState`, déjà calculé pour la limite affichée (feature 004).

## CompactStrip.Strings (modifié)

| Champ ajouté | Type | Rôle |
|---|---|---|
| `shortLabel` | `(UsageLimit) -> String` | « 5h » / « 5 h », « 7d » / « 7 j », nom du modèle pour une limite de modèle |

## État de l'app (modifié)

- `AppModel.signal: NotchSignal`, recalculé dans `recompute()` après `display`.
- `NotchPanelController.apply(_ display:, silent: Bool)` : largeur `layout.width` en silence,
  `layout.width + 2 × 72` sinon ; rétrécissement différé de 600 ms au passage au silence.

## Transitions du signal

```text
silent ──(blockAt, ou seuil sans prévision, ou épuisé)──▶ signalant   (fondu 600 ms)
signalant ──(holds, ou sous le seuil, ou relevé ancien)──▶ silent / band   (fondu 600 ms)
tout ──(survol, épinglage)──▶ band   (immédiat, comme aujourd'hui)
palier ──(échéance qui change)──▶ palier   (sans animation)
```
