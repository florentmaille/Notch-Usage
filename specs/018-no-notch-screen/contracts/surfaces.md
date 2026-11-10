# Contrat : surfaces sans encoche

Référence visuelle : [external-screen.png](../../../docs/design/external-screen.png). Valeurs en points.

## Item de barre de menus (A)

| Élément | Spécification |
|---|---|
| Anneau | 14 × 14, trait 2,2, piste à 30 % (monochrome) ; arc depuis midi, sens horaire |
| Texte | police système 12,5 semibold, chiffres tabulaires ; écart 5 avec l'anneau. **Pas de pourcentage** (retour 2026-11-09) : au calme, l'anneau seul ; texte = échéance d'un palier ou retour d'une limite épuisée |
| Glyphe Claude | SF Symbol de la 017, 15 × 15 ; nombre en mono 12 bold, collé (-3) |
| Mot d'arrivée | 4 s, après le glyphe ; omis si la barre est étroite (cas limite) |
| Monochrome | blanc sur barre sombre, noir sur barre claire, résolu au dessin |
| Teintes | ambre #FF9F0A, orange #FF6A1A, rouge #FF453A ; violet #BF5AF2 (sombre) / #A43BD6 (clair) ; blanc pour « terminé » sur barre sombre, noir sur barre claire |
| Battement | alternance de deux images au rythme de `beat` (006) ; aucune en Réduire les animations |
| Compact | anneau seul (comme la 014) |
| Clic gauche | popover sous l'item, contenu `PanelContentView`, puis Actualiser · Réglages · Quitter |
| Clic droit | menu de la 014 |

## Pastille centrée (C′)

| Élément | Spécification |
|---|---|
| Position | centrée en x sur l'écran et dans la hauteur de la barre ; hauteur **22** ; rayon 11. Zone de survol : toute la hauteur de la barre, largeur de la capsule (pointeur en butée en haut) |
| Fond | **noir 72 %** (85 % au survol) + liseré blanc 12 % (22 % au survol), quelle que soit la barre : le voile de 13 % disparaissait sur une barre teintée par un fond d'écran (retour 2026-11-09). Contenu toujours en palette sombre |
| Imminent | fond rouge sombre + liseré rouge 60 % (seul fond coloré) |
| Contenu | anneau 14 · texte 13,5 semibold · filet 1 × 13 · glyphe 16 + nombre 13 |
| Élargissement | symétrique autour du centre, fondu 0,3 s (aucun en Réduire les animations) |
| Carte | largeur 380, hauteur du contenu, 6 sous la barre, rayon 12 sur les quatre coins, fond noir 94 % ; survol 0,15 s, fermeture 0,10 s après sortie, Échap |
| Plein écran | rien : la pastille n'apparaît pas dans les espaces plein écran (pas de `fullScreenAuxiliary`), comme l'île depuis la 016 |
| Barre active sur l'écran à encoche | détail complet, comme ailleurs (retour 2026-11-10 ; du 2026-11-09 à la 0.6.2 : anneau seul, comme l'item compact) |
| Non affichée si | option désactivée, écran < 1700, barre masquée automatiquement, écran à encoche |

## Contenu par état

Voir le tableau « Contenu par état » de la [spec](../spec.md). Le popover et la carte rendent exactement `PanelContentView` : même contenu que le panneau déplié de l'île (SC-005).

## Textes nouveaux (EN / FR)

| Clé | EN | FR |
|---|---|---|
| Réglage icône | Menu bar icon | Icône de barre de menus |
| Automatique | Automatic | Automatique |
| Toujours | Always | Toujours |
| Jamais | Never | Jamais |
| Aide automatique | Shown when a screen without a notch is connected | Affichée quand un écran sans encoche est branché |
| Pastille | Centered capsule on wide screens | Pastille centrée sur les grands écrans |
