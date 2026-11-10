# Feature Specification: Réglages simplifiés

**Feature Branch**: `013-simple-settings` | **Created**: 2026-11-04 | **Status**: Draft

**Input**: Demande utilisateur du 2026-11-03 (« possibilité de simplifier le menu settings ? ») et proposition acceptée : trois lignes pour l'essentiel, le reste replié, la clé de session sur l'écran de connexion.

## Clarifications

### Session 2026-11-04

- Q (retour utilisateur) : l'épinglage au clic gêne ; le garder ? → A: non. Le panneau s'ouvre au survol et se referme quand le pointeur sort ; un clic ne le fige plus. En le quittant, il revient aux limites (les réglages ne restent pas ouverts). Échap le referme. Pendant qu'un menu est ouvert (Langue), le panneau reste ouvert.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - L'essentiel en trois lignes (Priority: P1)

À l'ouverture des réglages : « Ouvrir à la connexion », « Me prévenir avant un blocage » (interrupteurs) et la langue (menu). Rien ne défile. « Avancé », replié par défaut, contient la cadence de rafraîchissement et les seuils de repli avec une seule légende. La clé de session n'est plus dans les réglages : elle est sur l'écran de connexion, sous « Autre méthode… ».

**Acceptance Scenarios**:

1. **Given** les réglages ouverts, **Then** trois réglages visibles, « Avancé » replié, le pied « Connecté via … / Se déconnecter » inchangé.
2. **Given** « Avancé » déplié, **Then** cadence (1 à 15 min), interrupteur des seuils, seuils d'attention et critique (grisés si l'interrupteur est coupé), une légende.
3. **Given** l'écran de connexion, **When** « Autre méthode… » est déplié, **Then** le champ de clé de session et son bouton « Utiliser ».

## Requirements *(mandatory)*

- **FR-001**: Réglages visibles par défaut : ouverture à la connexion, notifications, langue.
- **FR-002**: Cadence et seuils dans un groupe « Avancé » replié par défaut.
- **FR-003**: Clé de session sur l'écran de connexion uniquement.
- **FR-004**: Aucun réglage supprimé ; textes anglais et français.
- **FR-005**: Plus d'épinglage : le panneau suit le survol seul ; il ne prend plus le clavier à l'ouverture au survol (amendé le 2026-11-10 : pointeur posé sur l'encoche, la frappe destinée à l'app en cours était perdue), seulement au clic dans le panneau ou à une ouverture demandée (menu de la barre, app rouverte), et le rend en se repliant ; Échap ne referme donc un panneau ouvert au survol qu'après un clic dedans ; un menu ouvert le garde ouvert ; en se repliant il revient aux limites.

## Success Criteria *(mandatory)*

- **SC-001**: 3 contrôles visibles à l'ouverture (contre 9 et 5 légendes en 0.4.2).
- **SC-002**: 0 texte sans traduction, 0 texte obsolète.
