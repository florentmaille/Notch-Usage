# Quickstart : vérifier l'écran sans encoche

## Prérequis

- Build Debug (mode démo et crochets `com.notchusage.debug.*`).
- Un MacBook à encoche et un écran externe d'au moins 1700 pt (essai réel), ou le mode démo `nonotch`.

## Tests automatiques

```
swift test --filter "ScreenRolesTests|BarContentTests|MenuBarIconModeTests|NotchGeometryTests"
```

Attendu : vert. Les cas couvrent les configurations de SC-001, chaque ligne du tableau « Contenu par état » et la migration du réglage.

## Essais manuels

| # | Configuration | Action | Attendu |
|---|---|---|---|
| 1 | MacBook + externe, externe principal | Regarder les deux écrans | Île sur le MacBook ; rien de noir en haut de l'externe (US2) |
| 2 | Capot fermé | Regarder la barre de l'externe | Item enrichi ; ni île ni pilule |
| 3 | Rouvrir le capot | Attendre 2 s | Île revenue sur le MacBook (SC-002) |
| 4 | MacBook + externe | Cliquer dans une fenêtre du MacBook, puis de l'externe | Item compact, puis enrichi en moins d'1 s (FR-022) |
| 5 | Démo `near`, `imminent`, `claude approval3` | Regarder l'item | Ambre « 2:05 », rouge battant « 8′ », main violette « 3 » |
| 6 | Fond d'écran clair | Regarder l'item | Monochrome noir, violet #A43BD6 |
| 7 | Item | Clic gauche, Échap ; clic droit | Popover = panneau de l'île, fermé par Échap ; menu Actualiser · Réglages · Quitter |
| 8 | Pastille activée, externe 1920 pt | Survoler la capsule | Carte 6 pt sous la barre, même contenu ; fermée à la sortie |
| 9 | Pastille activée, écran 1440 pt | Regarder | Aucune pastille ; item présent |
| 10 | Pastille activée, app en plein écran sur l'externe, démo `claude approval` | Regarder | Point violet centré |
| 11 | Réglage Icône sur Jamais, Toujours, Automatique | Brancher / débrancher l'externe | Visibilité conforme à FR-018 |
| 12 | VoiceOver sur l'item et la pastille | Écouter | Même annonce que l'île (FR-019) |

## Budgets

Moniteur d'activité, 10 min au repos, item et pastille affichés : CPU moyen < 1 %, mémoire < 60 Mo (SC-004).

## Limite connue

Pastille avec l'icône réglée sur « Jamais » : l'apparence de la barre est approchée par celle du système (R6).
