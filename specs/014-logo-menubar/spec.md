# Feature Specification: Logo et icône de barre de menus

**Feature Branch**: `014-logo-menubar` | **Created**: 2026-11-04 | **Status**: Draft

**Input**: Demande utilisateur : « un logo + une icône possible dans la barre de menu ». Planche : [docs/design/logo-and-menubar.png](../../docs/design/logo-and-menubar.png), choix A (l'île) + 1 (jauge vivante).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Une icône d'app reconnaissable (Priority: P1)

L'app a une icône : l'île (encoche noire, jauge orange) sur le dégradé du README, version simplifiée sous 64 px. Elle apparaît dans le Finder, Applications, Spotlight, la page GitHub.

### User Story 2 - Une jauge dans la barre de menus, si on la veut (Priority: P2)

Réglage « Afficher dans la barre de menus », désactivé par défaut. Activé, une jauge monochrome (image modèle, teintée par macOS) montre l'usage de la limite portée par l'encoche. Au clic, un menu : chaque limite avec son pourcentage, sa réinitialisation et la prévision ; « Actualiser », « Réglages » (ouvre le panneau de l'encoche sur les réglages), « Quitter ».

**Acceptance Scenarios**:

1. **Given** le réglage activé, **Then** l'icône apparaît aussitôt ; désactivé, elle disparaît.
2. **Given** l'usage passe de 42 % à 55 %, **Then** l'anneau se remplit d'autant au relevé suivant ; sans relevé, piste seule.
3. **Given** un clic, **Then** le menu liste les limites du dernier relevé et les trois actions.

## Requirements *(mandatory)*

- **FR-001**: Icône d'app aux 10 tailles du catalogue ; variantes simplifiées à 16 et 32 px.
- **FR-002**: Icône de barre de menus facultative, désactivée par défaut, persistée.
- **FR-003**: Image modèle de 18 pt redessinée seulement quand le pourcentage arrondi change ; aucun timer ni requête ajoutés.
- **FR-004**: Menu reconstruit à l'ouverture depuis l'état courant ; textes existants réutilisés, un texte nouveau (anglais, français).

## Success Criteria *(mandatory)*

- **SC-001**: Test app : la jauge est une image modèle de 18 × 18 pt pour 0 %, 42 %, 100 % et sans relevé.
- **SC-002**: 0 texte sans traduction.
