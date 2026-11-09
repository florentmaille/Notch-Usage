# Spike : l'item de barre de menus suit-il la barre active ?

**Date** : 2026-11-09 · **Machine** : MacBook Pro à encoche (écran principal) + DELL P2425HE 1920 × 1080, placé à gauche.
**Source** : [spike-statusitem/main.swift](spike-statusitem/main.swift)

## Question

FR-022 veut un item compact quand la barre active est celle de l'écran à encoche, enrichi sinon. Depuis Big Sur, macOS montre l'item réel sur la barre active et une réplique ailleurs. Il faut savoir :

1. si la fenêtre de l'item (`statusItem.button.window`) est sur l'écran de la barre active ;
2. si son changement d'écran est notifié, sans polling.

## Résultats

| Essai | Constat |
|---|---|
| Lancement automatique (×2), focus sur le Dell | La fenêtre de l'item est sur le **Dell** (`x = -791`), alors que l'écran principal est le MacBook. Elle est donc sur l'écran de la barre active, pas sur l'écran principal. **Point 1 : confirmé au lancement.** |
| Bascule automatique du focus (fenêtres rendues clés tour à tour) | Non concluant : macOS 14+ refuse qu'une app lancée par script prenne le focus (activation coopérative). L'item n'a pas bougé, faute de bascule réelle. |

| Bascule manuelle, 90 s, 4 allers-retours (Finder sur le MacBook, Claude sur le Dell) | À chaque clic : `didActivateApplication`, puis `didChangeScreen` **< 0,1 s** après, vers le bon écran. Le relevé de contrôle (0,5 s) confirme la position (`x = 1010` MacBook, `x = -782` Dell). Aucune bascule manquée. **Point 2 : confirmé.** |

Extrait du journal :

```
  6.2s NOTIF didActivateApplication Finder
  6.3s NOTIF didChangeScreen -> NOTCH
 15.5s NOTIF didActivateApplication Claude
 15.5s NOTIF didChangeScreen -> EXT(1920)
```

## Décision

FR-022 est retenu tel quel. Mécanisme : `NSWindow.didChangeScreenNotification` sur `statusItem.button.window`, qui suffit seul ; la relecture sur `didActivateApplication` reste en filet (même instant, coût nul). Aucun timer. Le repli « item enrichi partout » n'est pas nécessaire.
