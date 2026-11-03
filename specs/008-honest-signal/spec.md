# Feature Specification: Signal honnête

**Feature Branch**: `008-honest-signal`

**Created**: 2026-11-03

**Status**: Draft

**Input**: Revue produit du 2026-11-03 (points 1, 2, 3, 6, 7) : l'hebdo au-dessus du seuil restait muette en Automatique ; les « alertes » n'étaient qu'une animation sur des glyphes disparus ; en plein écran le signal se réduisait à une ligne de 2 pt ; la prévision ne disait pas sur quoi elle repose ; « Limite affichée » (004) rendait la seule prévision muette.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - L'encoche porte toujours la limite la plus menaçante (Priority: P1)

L'hebdo est à 97 %, la fenêtre de 5 h tranquille : le liseré rouge apparaît pour l'hebdo. Une prévision imminente sur la 5 h passe devant un seuil d'attention hebdo. Une limite de modèle épuisée ne prend le dessus que si rien d'autre ne menace. Le réglage « Limite affichée » disparaît.

**Independent Test**: `HeadlinePickerTests` ; démo `warning` (5 h à 83 %, hebdo 38 %) → ambre ; démo avec hebdo 97 % → rouge.

**Acceptance Scenarios**:

1. **Given** hebdo 97 %, 5 h 30 % tenable, **When** l'encoche est repliée, **Then** liseré rouge et survol sur l'hebdo.
2. **Given** 5 h avec blocage prévu dans 8 min et hebdo à 83 %, **Then** la 5 h porte le signal (imminent).
3. **Given** 5 h avec blocage prévu dans 3 h et hebdo à 97 %, **Then** l'hebdo porte le signal (critique).
4. **Given** deux limites de même gravité, **Then** la fenêtre de 5 h.
5. **Given** seuils désactivés, **Then** seules prévisions et épuisements comptent.
6. **Given** un réglage « Limite affichée » enregistré par une version antérieure, **Then** il est ignoré.

### User Story 2 - Une notification quand il faut agir (Priority: P1)

Une notification système, une seule par limite et par période, à l'entrée en palier imminent (blocage prévu sous 30 min), au seuil critique sans prévision, et à l'épuisement. Désactivable dans les réglages (« Me notifier… »). L'autorisation macOS est demandée à la première notification.

**Acceptance Scenarios**:

1. **Given** notifications actives et passage en imminent, **Then** une notification « Un blocage approche » avec la limite et l'heure prévue ; aucune seconde notification tant que la période dure.
2. **Given** limite épuisée, **Then** « Limite atteinte » avec le temps avant retour.
3. **Given** notifications désactivées, **Then** aucune notification, le liseré reste.

### User Story 3 - Plein écran et prévision lisibles (Priority: P2)

En plein écran, le point suit le palier du liseré (couleur) et bat avec le halo en imminent. Dans le panneau, la ligne de prévision dit sur quoi elle repose : « À ce rythme (dernière heure) : blocage à 16:40 ».

**Acceptance Scenarios**:

1. **Given** plein écran et blocage prévu dans 8 min, **Then** point rouge qui bat à chaque battement.
2. **Given** panneau déplié avec prévision, **Then** la ligne mentionne « dernière heure ».

### Edge Cases

- Abonnement sans fenêtre de 5 h : la plus utilisée, comme avant.
- Redémarrage de l'app : la garde de notification est en mémoire ; une notification déjà vue peut revenir une fois.
- Autorisation de notification refusée : silencieux, le liseré suffit.

## Requirements *(mandatory)*

- **FR-001**: La limite portée par l'encoche MUST être la plus grave : épuisée (hors modèle) > imminent ou critique > proche > lointain ou attention > rien ; ex æquo → ordre du relevé (5 h d'abord).
- **FR-002**: Le réglage « Limite affichée » MUST être retiré ; la valeur enregistrée est ignorée.
- **FR-003**: Une notification système MUST être émise à l'entrée en imminent, au critique sans prévision et à l'épuisement, une fois par limite et par période.
- **FR-004**: Les notifications MUST être désactivables ; par défaut actives ; les réglages antérieurs se décodent sans la clé.
- **FR-005**: En plein écran, le point MUST prendre la couleur du palier et battre avec le halo ; sans liseré, comportement des seuils inchangé.
- **FR-006**: La ligne de prévision du panneau MUST indiquer « dernière heure ».
- **FR-007**: Anglais et français ; VoiceOver inchangé.

## Success Criteria *(mandatory)*

- **SC-001**: `HeadlinePickerTests` couvrent les 6 scénarios de l'US1 ; 100 % des tests existants adaptés et verts.
- **SC-002**: En démo `imminent`, une notification unique ; `tick` × 10 n'en ajoute aucune.
- **SC-003**: 0 texte sans traduction ; les 6 clés 004 retirées du catalogue.

## Assumptions

- La pondération récente de la prévision (point 4 de la revue) reste hors champ : changement d'algorithme à spécifier séparément.
- L'item de barre des menus (point 6) et Sparkle sont des features à part.
