# Data Model: Encoche prédictive

Tout vit dans `NotchUsageCore` (Foundation seul), sauf le stockage fichier déjà dans l'app.

## Reading (nouveau, Codable)

Un point de l'historique, par limite.

| Champ | Type | Règle |
|---|---|---|
| `limitID` | String | identifiant de `UsageLimit` |
| `at` | Date | `fetchedAt` de l'instantané |
| `utilization` | Double | 0…100 |
| `resetsAt` | Date? | période de réinitialisation du relevé |

## UsageHistory (nouveau, Codable)

| Champ | Type | Règle |
|---|---|---|
| `readings` | [Reading] | triés par `at`, au plus 2 h avant le dernier relevé |

Opérations :

- `appending(snapshot)` : ajoute un `Reading` par limite de l'instantané, écarte pour chaque limite les
  relevés d'une autre période (`resetsAt` différent de plus de 10 min du nouveau), tronque à 2 h.
- `readings(for limitID)` : liste triée pour une limite.
- Persistance : `history.json` via `SnapshotStore` (`loadHistory()`, `saveHistory(_:)` ajoutés au
  protocole, implémentés par `FileSnapshotStore` ; le store de test en mémoire aussi). `wipe()` le
  supprime avec le reste.

## Forecast (nouveau, Equatable)

`unavailable` | `holdsUntilReset` | `blockAt(Date)`. Jamais persisté, recalculé à chaque relevé et à
chaque tick de 30 s (l'heure de blocage ne bouge pas, seul son libellé relatif change).

## PaceForecaster (nouveau, fonctions pures)

- `forecast(readings:resetsAt:now:) -> Forecast` : contrat [forecast.md](contracts/forecast.md).
- `forecasts(history:snapshot:now:) -> [String: Forecast]` : une entrée par limite de kind
  `rollingFiveHour` (R7) ; les autres limites n'ont pas d'entrée.

## ForecastDebouncer (nouveau, struct à valeur)

| Champ | Type |
|---|---|
| `displayed` | [String: Forecast] |
| `pending` | [String: Forecast] |

`push(_ candidates: [String: Forecast]) -> [String: Forecast]` applique l'hystérésis par limite
(contrat forecast.md, section Stabilisation). Conservé en mémoire par `AppModel`, réinitialisé à la
déconnexion.

## DisplayState (modifié)

| Champ ajouté | Type | Rôle |
|---|---|---|
| `forecasts` | [String: Forecast] | par limite, pour le panneau et VoiceOver |
| `fetchFailed` | Bool | dernier relevé en échec (bandeau « unavailable »), pour le glyphe wifi barré |

`headline` : choisi par `DisplayStateReducer` parmi les limites, d'abord la date `blockAt` la plus
proche, sinon `mostConstraining` (R6). Nouveau paramètre `forecasts` du réducteur.

## CompactStrip (nouveau, Equatable)

Contenu de l'encoche repliée, dérivé de `DisplayState` : contrat
[compact-strip.md](contracts/compact-strip.md).

| Champ | Type |
|---|---|
| `left` | `Left` : `.holds(String)`, `.blockIn(String)`, `.blockedFor(String)`, `.offline(String)`, `.locked`, `.connect`, `.unsupported`, `.unavailable` |
| `right` | `Right` : `.percent(String)`, `.pill(String)`, `.signIn(String)`, `.connect(String)`, `.dash` |
| `tone` | `Tone` : `.normal`, `.muted`, `.warning`, `.critical` |
| `accessibility` | String |

`make(display:now:language:)` ; les textes « Bloqué », « Connexion », « Sign in » sont passés par
l'app (catalogue de textes) via un petit `Strings` d'entrée pour garder le core sans localisation.

## RelativeTimeFormatter (modifié)

- `duration(until:now:language:)` : durée nue sans préfixe (« 2 h 14 », « 2h 14m », « 3 j 5 h »).
- `blockLabel(_ date: Date, now:language:)` : heure courte si moins d'une heure, sinon `duration`.

## Transitions de l'aile gauche

```text
indisponible ──(2 relevés ≥ 10 min, pente ≤ 0 ou projection ≥ reset)──▶ tenable
indisponible ──(2 relevés ≥ 10 min, projection < reset, ×2 consécutifs)──▶ blocage prévu
tenable ◀──(projection ≥ reset ×2)── blocage prévu
toute prévision ──(utilisation ≥ 100)──▶ épuisée (↻)
toute prévision ──(trou > 30 min, nouvelle période, déconnexion)──▶ indisponible
```
