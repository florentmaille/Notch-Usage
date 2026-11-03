# Contrat : signal de l'encoche repliée

Fonction pure du core : `NotchSignal.make(display, now, language, strings)` renvoie le contenu,
le palier du liseré et l'annonce. La vue dessine ; le contrôleur du panneau lit `isSilent`.

## Contenu par état

Dans l'encoche, seul `band` dessine les ailes ; `deadline`, `exhausted` et `threshold` ne dessinent que le liseré
autour de l'encoche physique (retour du 2026-11-03). Les colonnes « aile » décrivent la pilule et la bande.

| État | Contenu | Aile gauche (pilule) | Aile droite (pilule) | Liseré |
|---|---|---|---|---|
| Calme (prévision tenable, ou indisponible sous le seuil) | `silent` | rien | rien | aucun |
| Survol ou épinglé, quel que soit l'état | `band` | bande 003 | bande 003 | selon l'état sous-jacent |
| Blocage prévu dans 60 min ou plus | `deadline` | vide | sablier + « 2h 05m » ambre | ambre 2 pt |
| Blocage prévu dans moins de 60 min | `deadline` | vide | sablier + « 10:06 » orange | orange 2,5 pt |
| Blocage prévu dans moins de 30 min | `deadline` | vide | sablier + « 9:38 » rouge | rouge 3 pt + halo |
| Limite épuisée | `exhausted` | « Full » / « Bloqué » pastille rouge | flèche + « 1h 02m » rouge | rouge 3 pt + halo |
| Seuil d'attention, sans prévision | `threshold` | « 7d » / « 7 j » gris | « 83 % » pastille ambre | ambre 2 pt |
| Seuil critique, sans prévision | `threshold` | « 7d » gris | « 97 % » pastille rouge | rouge 3 pt + halo |
| Relevé ancien ou en échec | `band` | bande 003 en gris | bande 003 en gris | aucun |
| Session expirée | `band` | cadenas | « Sign in » | aucun |
| Non connecté, non pris en charge, aucune donnée | `band` | bande 003 | bande 003 | aucun |

Règles :

- Fenêtre de 5 h : la prévision prime sur le seuil. `holdsUntilReset` → `silent` même à 97 %.
- Limites hebdomadaires : seuils seulement (pas de prévision).
- Le signal porte sur `display.headline` (règle 004, Automatique ou épinglée) et sur elle seule.
- Alertes désactivées : `threshold` devient `silent` ; `deadline` et `exhausted` restent.
- `band` en gris (relevé ancien) éteint tout liseré.

## Palier → rendu (constantes de l'app)

| Palier | Teinte | Épaisseur | Halo | Texte |
|---|---|---|---|---|
| `far` | ambre `#FF9F0A` | 2 pt | non | durée |
| `near` | orange `#FF6A1A` | 2,5 pt | non | heure |
| `imminent` | rouge `#FF453A` | 3 pt | ombre 6 pt | heure |
| `exhausted` | rouge `#FF453A` | 3 pt | ombre 6 pt | durée avant retour |

## Panneau

| Signal | Largeur du panneau (encoche) | Largeur (pilule) | Zone de survol |
|---|---|---|---|
| `silent`, `deadline`, `exhausted`, `threshold` | largeur de l'encoche physique | 150 pt | la forme seule |
| `band` | encoche + 2 × 72 pt | 150 pt | la forme avec ses oreilles |

Passage au silence : fondu 600 ms, puis rétrécissement. Passage au signal : élargissement, puis
fondu 600 ms. Mode réduit d'animations : pas de fondu.

## Plein écran

| Signal | Bande masquée (2 pt) | Point d'alerte |
|---|---|---|
| liseré actif | couleur du palier | comportement 001 |
| sinon | transparente | comportement 001 |

## Annonce d'accessibilité

Toujours celle de la bande complète (contrat compact-strip.md), silence compris.

## Table de validation (mode démo)

| Mode démo | Contenu | Liseré |
|---|---|---|
| `normal` | silence | aucun |
| `far` (2 h 05, 55 %) | ⌛ 2h 05m ambre | ambre fin |
| `near` (40 min, 78 %) | ⌛ 10:06 orange | orange |
| `imminent` (8 min, 92 %) | ⌛ 9:38 rouge | rouge + halo |
| `pace` (1 h 10, 55 %) | ⌛ 1h 10m ambre | ambre fin |
| `warning` (5 h à 83 %, sans prévision) | 5h · [83 %] ambre | ambre fin |
| `critical` (97 %, blocage à 50 min) | ⌛ heure orange | orange |
| `blocked` | [Full] · ↻ 1h 02m | rouge + halo |
| `offline` | bande grise | aucun |
| `reauth` | cadenas · Sign in | aucun |
| `hover=1` sur n'importe quel état | bande 003 | selon l'état |
