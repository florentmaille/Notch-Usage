# Contrat : prévision de blocage

Fonction pure du core, sans réseau ni horloge : `forecast(readings, resetsAt, now)`.

## Entrées

| Nom | Type | Rôle |
|---|---|---|
| `readings` | liste de relevés `{ at, utilization }` d'une même limite, triés par date | historique, au plus deux heures |
| `resetsAt` | date ou absente | heure de réinitialisation de la limite |
| `now` | date | instant du calcul |

## Sortie

| Valeur | Sens |
|---|---|
| `unavailable` | historique insuffisant ou inexploitable |
| `holdsUntilReset` | au rythme observé, 100 % n'est pas atteint avant `resetsAt` |
| `blockAt(date)` | au rythme observé, 100 % est atteint à `date`, avant `resetsAt` |

## Règles

1. Fenêtre d'observation : relevés avec `now - 60 min ≤ at ≤ now`.
2. Recevabilité, dans l'ordre : au moins deux relevés ; écart entre le premier et le dernier ≥ 10 min ;
   aucun écart entre relevés consécutifs > 30 min. Sinon `unavailable`.
3. Pente : régression linéaire de `utilization` sur `at`, en points par seconde.
4. Pente ≤ 0 → `holdsUntilReset`.
5. Projection : `t = now + (100 - dernière utilisation) / pente`.
6. `resetsAt` absente → `holdsUntilReset` (rien à comparer). Sinon `t < resetsAt` → `blockAt(t)`,
   sinon `holdsUntilReset`.
7. Dernière utilisation ≥ 100 → `unavailable` (la limite est épuisée, l'affichage suit un autre état).

L'appelant écarte avant l'appel les relevés d'une autre période de réinitialisation (tolérance de
10 min sur `resetsAt`, comme le registre d'alertes).

## Exemples (fixtures de tests)

| Cas | Relevés (min avant `now` → %) | `resetsAt` | Résultat |
|---|---|---|---|
| Rythme constant | 40→29, 30→36, 20→42, 10→49, 0→55 | +4 h | `blockAt(+1 h 09 environ)` |
| Rythme lent | 40→40, 20→42, 0→44 | +2 h 14 | `holdsUntilReset` (100 % en ~9 h) |
| Plat | 30→42, 15→42, 0→42 | +2 h | `holdsUntilReset` |
| Décroissant (bruit) | 30→43, 15→42, 0→42 | +2 h | `holdsUntilReset` |
| Un seul relevé | 0→55 | +4 h | `unavailable` |
| Trop rapprochés | 5→50, 0→55 | +4 h | `unavailable` |
| Trou de veille | 70→30, 0→55 | +4 h | `unavailable` (hors fenêtre, un seul relevé restant) |
| Trou dans la fenêtre | 40→30, 5→52, 0→55 | +4 h | `unavailable` (écart de 35 min) |
| Blocage après reset | 30→80, 0→82 | +30 min | `holdsUntilReset` |
| Sans heure de reset | 30→40, 0→55 | absente | `holdsUntilReset` |
| Déjà bloquée | 30→90, 0→100 | +1 h | `unavailable` |

## Stabilisation (hystérésis)

`ForecastDebouncer.push(candidate) -> displayed` :

- `unavailable` s'affiche immédiatement et réinitialise le compteur.
- Un passage `holdsUntilReset` ↔ `blockAt` ne s'affiche qu'au deuxième candidat consécutif de même
  nature ; la date de `blockAt` affichée est toujours la plus récente.
- Séquence de test : `holds, block(16:40), block(16:42)` → affichés `holds, holds, block(16:42)`.
