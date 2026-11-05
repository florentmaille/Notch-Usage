# Contrat : attention Claude dans l'île, le panneau, le plein écran

Complète le [contrat de l'île 012](../../012-notch-island/contracts/island.md). Teintes : violet
`#BF5AF2` (bloquant), blanc (terminé) ; la jauge garde la couleur de son palier.

## Île repliée

| État de la limite | Sessions en attente | Gauche | Droite | Badge |
|---|---|---|---|---|
| calme | aucune | jauge 012 | aucune | - |
| calme | approbation, arrivée < 4 s | jauge | `hand.raised.fill` + « Approval » / « Approbation », violet | - |
| calme | approbation | jauge | `hand.raised.fill`, violet | - |
| calme | question | jauge | `questionmark.bubble.fill`, violet | - |
| calme | terminé | jauge | `checkmark`, blanc | - |
| calme | 3 sessions (2 approbations, 1 terminée) | jauge | `hand.raised.fill` + « 3 », violet | - |
| blocage prévu ≥ 30 min (ambre, orange) | une ou plus | jauge du palier | glyphe Claude (remplace « 2:05 ») | - |
| blocage prévu < 30 min | une ou plus | jauge rouge, halo, bat | « 8′ » (012) | point violet, coin haut droit de la jauge |
| limite épuisée | une ou plus | jauge pleine rouge | « ↻1:02 » (012) | point violet |
| seuil sans prévision | une ou plus | jauge du seuil | glyphe Claude (remplace le libellé) | - |
| relevé ancien, hors ligne | une ou plus | glyphe 012 | glyphe Claude (remplace le pourcentage) | - |
| session expirée, aucun compte | une ou plus | glyphe 012 | glyphe Claude | - |

Compteur : affiché à partir de 2 ; « 9+ » à partir de 10. Un seul glyphe : approbation > question > terminé.
Largeur de l'oreille droite : 52 pt (glyphe, glyphe + compteur) ; à l'arrivée, glyphe + mot, largeur au
contenu (≤ 120 pt), 4 s, puis retour à 52 pt en fondu 0,3 s. Rien ne bat.

## Pilule

Même contenu sur une ligne : jauge, puis glyphe (+ compteur ou mot à l'arrivée).

## Point plein écran

| Condition | Point |
|---|---|
| limite imminente ou épuisée | rouge, bat (012) |
| sinon, une session bloquante | violet |
| sinon, une session terminée | blanc |
| sinon | couleur du palier (012) |

## Panneau déplié et menu de la barre

Section « Claude Code », au-dessus des limites, absente sans session en attente :

```
CLAUDE CODE
● Notch-Usage              approval needed        2 min
● Limites Fable en mode…   question pending       45 s
○ deck-q4                  finished               6 min
```

- Point : violet (approbation, question), blanc (terminé). Nom : titre, sinon dossier, tronqué à 28 caractères.
- Libellés : « approval needed » / « attend une approbation », « question pending » / « attend une
  réponse », « finished » / « a terminé ». Durée : « 45 s », « 2 min », « 1 h 10 ».
- Tri : approbation, question, terminé ; puis la plus ancienne en premier.
- Clic sur une ligne : active l'application d'origine, ferme le panneau ; l'attente reste.
- Menu de la barre : mêmes lignes, en items ; clic identique.

## Clic sur l'île

Efface les sessions « terminé » ; les attentes bloquantes restent. Le reste du clic est celui de la 013.

## Accessibilité

Annonce de l'île : « 2 sessions Claude attendent : Notch-Usage, une approbation ; deck-q4, a terminé. »
puis la bande des limites. En anglais : « 2 Claude sessions are waiting: … ». Reduce Motion : aucune
transition.

## Notification (option, off)

Approbation ou question seulement, une par `prompt_id` : « Claude is waiting » / « Claude attend » ;
corps « Notch-Usage: approval needed » / « Notch-Usage : attend une approbation ».
