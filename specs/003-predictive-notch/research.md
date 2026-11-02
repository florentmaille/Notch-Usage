# Research: Encoche prédictive

## R1. Estimation du rythme

- **Decision**: régression linéaire (moindres carrés) sur les relevés des 60 dernières minutes, après
  les contrôles de recevabilité (au moins deux relevés espacés de 10 min, aucun trou de plus de 30 min,
  même période de réinitialisation). Pente en points de pourcentage par seconde. Pente ≤ 0 → tenable.
- **Rationale**: avec un relevé toutes les 3 min, la fenêtre contient jusqu'à 20 points ; les valeurs
  renvoyées par le service sont arrondies et bruitées d'un point. Deux points extrêmes amplifieraient
  ce bruit (±1 pt sur 10 min = ±6 pt/h d'erreur) ; la régression le lisse sans modèle supplémentaire.
- **Alternatives considered**: différence premier/dernier relevé (simple mais bruitée) ; moyenne mobile
  exponentielle (un paramètre de plus à régler, pas de gain lisible) ; modèle journalier (hors périmètre,
  voir R7).

## R2. Stabilité de l'affichage

- **Decision**: l'état affiché (tenable, blocage prévu) ne change qu'après deux prévisions consécutives
  concordantes ; l'heure de blocage affichée est celle de la dernière prévision, actualisée à chaque
  relevé sans attendre. L'état « indisponible » s'applique immédiatement (perte d'historique).
- **Rationale**: un rythme proche du seuil fait osciller la projection autour de l'heure de
  réinitialisation ; une bascule à chaque relevé (toutes les 3 min) rendrait l'encoche nerveuse. Deux
  relevés = 6 min de délai au pire, acceptable pour une alerte qui porte sur plus d'une heure.
- **Alternatives considered**: marge de temps (projection à plus de 10 min avant le reset) : règle
  moins lisible et dépendante de la cadence ; aucune hystérésis : rejeté pour la nervosité.

## R3. Persistance de l'historique

- **Decision**: fichier `history.json` à côté de `snapshot.json` dans le conteneur de l'app, écrit à
  chaque relevé réussi, tronqué à deux heures, supprimé par `wipe()` à la déconnexion. Format : une liste
  de relevés `{ limitID, at, utilization, resetsAt }`.
- **Rationale**: réutilise le `SnapshotStore` existant (JSON, écriture atomique, même dossier), ce qui
  satisfait le principe I sans nouveau mécanisme. Deux heures × 3 limites à 3 min = 120 entrées,
  moins de 20 Ko.
- **Alternatives considered**: mémoire seule (perd la prévision à chaque relance, alors que la relance
  après build ou mise à jour est fréquente) ; stocker les instantanés complets (plus lourd, sans besoin).

## R4. Heure du blocage

- **Decision**: blocage à moins d'une heure → heure locale au format court du système via Foundation
  (`Date.FormatStyle` `.hour().minute()`), soit « 16:40 » en fr-FR et « 4:40 PM » en en-US. À une heure
  ou plus → durée nue « 1 h 10 » / « 1h 10m » via les libellés existants de `TimeLabels`.
- **Rationale**: en dessous d'une heure, l'heure absolue se mémorise mieux qu'un décompte qui change ;
  au-delà, la durée se compare d'un coup d'œil au compte à rebours de la réinitialisation. Le format
  système respecte la région (feature 002, FR-005).
- **Alternatives considered**: toujours une durée (perd le repère absolu) ; toujours une heure (« 14:52 »
  pour un blocage dans 3 h ne se compare pas au « 2 h 14 » du reset).

## R5. Pilule sans encoche

- **Decision**: une seule ligne « prévision · pourcentage » composée avec `ViewThatFits` : d'abord avec
  l'icône, puis sans icône, jamais de troncature ; polices et tailles de la feature 001.
- **Rationale**: 150 pt de large, 11 pt semi-gras : « ✓ 2 h 14 · 42 % » mesure environ 95 pt, « ⌛ 16:40 ·
  97 % » environ 90 pt, « ↻ 1 h 02 · Bloqué » environ 105 pt ; en anglais « 4:40 PM » est plus long,
  d'où la variante sans icône.
- **Alternatives considered**: deux lignes (28 pt de haut ne le permettent pas lisiblement) ; masquer la
  prévision dans la pilule (perd la raison d'être de la feature sur ces écrans).

## R6. Choix de la limite affichée

- **Decision**: parmi les limites, celle dont le blocage prévu est le plus proche ; à défaut la plus
  contrainte (règle de la feature 001). Les alertes de seuil et le panneau ne changent pas.
- **Rationale**: le scénario clé (fenêtre de 5 h à 55 % qui file vers 100 % pendant que la limite
  hebdomadaire plafonne à 60 %) n'est visible que si la prévision prime. Cas rare en pratique puisque
  seule la fenêtre de 5 h est prédite (R7), mais nécessaire pour la cohérence.
- **Alternatives considered**: toujours la plus contrainte (le sablier concernerait alors parfois une
  autre limite que le pourcentage affiché : incohérent).

## R7. Périmètre de la prévision

- **Decision**: fenêtre de 5 h uniquement. Les limites hebdomadaires affichent coche et compte à
  rebours ; leur ligne de panneau n'a pas de prévision.
- **Rationale**: une pente mesurée sur une heure projetée sur trois jours suppose un travail continu
  24 h/24 ; les faux « blocage prévu » seraient la règle. Un modèle hebdomadaire demande un historique
  de plusieurs jours et un profil d'usage : une autre feature, si l'usage le justifie.
- **Alternatives considered**: même pente pour toutes les limites (faux positifs) ; moyenne sur 24 h
  (historique de 24 h à conserver, hors périmètre de la demande « deux dernières heures »).

## R8. Pastille et accessibilité

- **Decision**: pastille = capsule pleine (orange ou rouge) avec texte sombre en semi-gras ; le
  pourcentage garde la même taille qu'en blanc pour ne pas faire sauter la mise en page. Les glyphes
  (coche, sablier, flèche, cadenas, wifi barré) sont des symboles SF, avec la même configuration de
  poids que le texte.
- **Rationale**: la forme (capsule) distingue l'alerte sans la couleur (FR-005) ; les symboles SF se
  localisent et s'annoncent naturellement avec VoiceOver.
- **Alternatives considered**: texte en gras seulement (trop discret) ; icône triangle (actuelle,
  masque la limite concernée).
