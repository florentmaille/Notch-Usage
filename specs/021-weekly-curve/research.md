# Research : Courbe de la semaine

## R1 - Historique horaire

- **Décision** : nouveau type `HourlyHistory`, à côté de `UsageHistory` (2 h, prévision de la fenêtre de 5 h). Il garde au plus un relevé par heure et par limite : un relevé de la même heure remplace le précédent. Rétention de 8 jours. Les relevés d'une autre période de la même limite (`isSamePeriod`, règle existante) sont écartés.
- **Stockage** : `weekly.json` dans le dossier de l'app, via `SnapshotStore` (`loadHourlyHistory` / `saveHourlyHistory`). `wipe()` supprime déjà tout le dossier : effacé à la déconnexion (FR-002).
- **Taille** : 8 × 24 = 192 relevés au plus par limite, environ 90 octets chacun en JSON, soit moins de 20 Ko pour 3 limites (SC-003).
- **Alternatives** : allonger la rétention de `UsageHistory` (la prévision de 5 h lirait des milliers de points inutiles) ; une base SQLite (YAGNI).

## R2 - Courbe et projection

- **Décision** : fonction pure `WeekCurve.make(limit:history:forecast:now:)`. Elle ne concerne que la limite `weeklyAll` dotée d'une heure de reset. La semaine va de `reset - 7 j` à `reset`. Chaque point est placé à la fraction 0…1 de la semaine écoulée.
- **Points** : les relevés de la période en cours, plus le point « maintenant » (usage actuel). Moins de 2 points : état `notEnough` (FR-007).
- **Projection** : reprise de la prévision de la 016 passée par le modèle (FR-005, SC-002).
  - `blockAt(d)` : la projection va jusqu'à 100 % à la fraction de `d`, avec la teinte `Edge.tier(blockAt: d)` (FR-006).
  - `holdsUntilReset` : la projection va jusqu'au reset, avec la valeur `usage × semaine / écoulé`, la même formule que la 016.
  - `unavailable` (moins de 12 h écoulées) : pas de projection.
- **Jours** : les minuits locaux de la semaine, en fractions, calculés avec le calendrier courant (cas limite du fuseau horaire).

## R3 - Affichage

- **Décision** : une section `WeekSection` dans `ExpandedView`, sous les limites, donc présente dans l'île, la carte de la pastille et le popover, qui partagent ce panneau. Elle est tracée avec `Canvas` sur la largeur disponible et 70 pt de haut.
- **Repli** : réglage local `weekSectionCollapsed` (défaut : dépliée).
- **Redessin** : seulement quand le modèle recalcule. Aucun timer (FR-011).

## R4 - Démo

- **Décision** : les états de démo génèrent une semaine fictive (journées de travail, nuits plates) cohérente avec leur usage hebdomadaire. Les captures et les essais n'ont donc pas besoin d'une vraie semaine d'historique.
