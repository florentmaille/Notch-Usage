# Contrat : contenu de l'encoche repliée

Fonction pure du core : `CompactStrip.make(display, now, language)` renvoie l'aile gauche, l'aile
droite et la teinte. Les vues ne décident rien : elles dessinent.

## Aile gauche

| État | Glyphe | Texte | Couleur |
|---|---|---|---|
| Rythme tenable ou prévision indisponible | coche | durée avant réinitialisation (« 2 h 14 » / « 2h 14m ») | gris |
| Blocage prévu à 1 h ou plus | sablier | durée avant blocage (« 1 h 10 ») | orange, rouge si critique |
| Blocage prévu à moins d'1 h | sablier | heure du blocage (« 16:40 » / « 4:40 PM ») | orange, rouge si critique |
| Limite épuisée | flèche circulaire | durée avant retour (« 1 h 02 ») | rouge |
| Dernier relevé en échec | wifi barré | durée avant réinitialisation | gris |
| Session expirée | cadenas | aucun | orange |
| Non connecté | compte | aucun | gris |
| Abonnement non pris en charge / aucune donnée | point d'interrogation / wifi barré | aucun | gris |

Réinitialisation passée (« reset pending ») : texte « imminent » / « pending », gris.

## Aile droite

| État | Contenu | Forme |
|---|---|---|
| Niveau d'alerte aucun | « 42 % » | texte blanc, gris si relevé ancien ou en échec |
| Niveau attention | « 83 % » | pastille orange, texte sombre |
| Niveau critique | « 97 % » | pastille rouge, texte sombre |
| Limite épuisée | « Bloqué » / « Full » | pastille rouge |
| Session expirée | « Connexion » / « Sign in » | texte orange, bouton, sans soulignement |
| Non connecté | « Connexion » / « Connect » | texte gris |
| Non pris en charge / aucune donnée | « — » | texte gris |

Invariant : au plus une pastille ; le relevé ancien ou en échec désature tout en gris, sauf la pastille
« Bloqué » qui reste rouge (l'information vient du dernier relevé connu).

## Pilule (écran sans encoche)

Une ligne : `gauche · droite`, séparateur point médian. Priorité d'ajustement : avec glyphe, puis sans
glyphe. Jamais de troncature. Les états sans texte à gauche (cadenas, compte) n'affichent que la droite
précédée du glyphe.

## Annonce d'accessibilité

« {limite}, {n} pour cent, réinitialisation {durée}[, à ce rythme bloqué à {heure}] » ; en anglais
« {limit}, {n} percent, resets {duration}[, at this pace blocked at {time}] ». États sans limite :
textes existants de la feature 001 (« Notch Usage, reconnect required », …).

## Table de validation (mode démo)

| Mode démo | Gauche | Droite |
|---|---|---|
| `normal` | ✓ 2 h 14 | 42 % |
| `pace` | ⌛ 1 h 10 (orange) | 55 % |
| `warning` | ✓ 2 h 14 | [83 %] orange |
| `critical` | ⌛ 16:40 (rouge) | [97 %] rouge |
| `blocked` | ↻ 1 h 02 (rouge) | [Bloqué] rouge |
| `offline` | wifi barré 1 h 49 (gris) | 42 % gris |
| `reauth` | cadenas (orange) | Connexion (orange) |
| `off` | état réel | état réel |
