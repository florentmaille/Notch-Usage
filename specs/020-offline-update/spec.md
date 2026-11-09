# Feature Specification: Mise à jour sans réseau

**Feature Branch**: `020-offline-update`

**Created**: 2026-11-09

**Status**: Draft

**Input**: User description: "Mise à jour sans réseau (020). Dans les Réglages, une ligne « Version 0.5.7 » avec un bouton « Rechercher les mises à jour » qui ne fait aucune connexion depuis l'app (constitution, principe I : seuls les serveurs d'Anthropic). Si l'app a été installée par Homebrew, le bouton ouvre le Terminal et y lance `brew update && brew upgrade --cask notch-usage` ; sinon il ouvre la page des releases GitHub dans le navigateur. Le menu de la barre de menus propose la même commande. Pas de vérification automatique, pas de badge. La commande Terminal se termine par la relance de l'app. Textes EN/FR."

**Décision de cadrage (2026-11-09)** : Florent a choisi le bouton sans réseau plutôt qu'une vérification automatique sur GitHub. La vérification automatique aurait exigé d'amender le principe I de la constitution (seuls les serveurs d'Anthropic).

## Contexte

Mettre à jour Notch Usage demande aujourd'hui de savoir qu'une version existe et de connaître la commande. Avec Homebrew, il faut aussi penser à rafraîchir le tap (`brew update`), sans quoi `brew upgrade` répond que la dernière version est déjà installée. C'est arrivé à la sortie de la 0.5.7. Sans Homebrew, il faut retrouver la page des releases.

L'app ne peut pas savoir seule qu'une version est disponible sans se connecter à un serveur autre qu'Anthropic, ce que la constitution interdit. La feature réduit donc la mise à jour à un clic, en confiant le travail réseau à Homebrew ou au navigateur, qui agissent à la demande explicite de l'utilisateur.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Mettre à jour en un clic avec Homebrew (Priority: P1)

L'utilisateur a installé l'app avec Homebrew. Il ouvre les Réglages, voit sa version, clique sur « Rechercher les mises à jour ». Le Terminal s'ouvre et enchaîne le rafraîchissement du tap, la mise à jour de l'app et sa relance.

**Why this priority** : c'est le cas de la plupart des utilisateurs (le README propose Homebrew en premier), et c'est celui où la commande actuelle échoue sans `brew update`.

**Independent Test** : sur une machine où l'app vient de Homebrew, cliquer sur le bouton ; le Terminal affiche la commande et son résultat, et l'app redémarre à la fin si une version plus récente existait.

**Acceptance Scenarios** :

1. **Given** l'app installée par Homebrew, **When** l'utilisateur ouvre les Réglages, **Then** une ligne affiche « Version 0.5.7 » (la version installée) et un bouton « Rechercher les mises à jour ».
2. **Given** l'app installée par Homebrew, **When** l'utilisateur clique sur le bouton, **Then** une fenêtre du Terminal s'ouvre et lance le rafraîchissement du tap puis la mise à jour de l'app ; l'utilisateur voit chaque étape et confirme si Homebrew le demande.
3. **Given** une version plus récente disponible, **When** la mise à jour se termine, **Then** l'app redémarre d'elle-même dans sa nouvelle version, sans autre action.
4. **Given** aucune version plus récente, **When** la commande se termine, **Then** le Terminal affiche que l'app est à jour, et l'app en cours d'exécution est simplement remise au premier plan.
5. **Given** l'utilisateur clique sur le bouton, **Then** l'app elle-même n'ouvre aucune connexion réseau, et macOS ne demande aucune permission nouvelle (ni contrôle d'une autre app, ni accès à des données).

---

### User Story 2 - Trouver la nouvelle version sans Homebrew (Priority: P2)

L'utilisateur a installé l'app à la main, depuis le zip. Le même bouton ouvre la page des releases dans son navigateur, où il télécharge la dernière version.

**Why this priority** : le second mode d'installation documenté ; moins fréquent, mais sans ce cas le bouton n'aurait de sens que pour une partie des utilisateurs.

**Independent Test** : sur une machine sans Homebrew, ou avec une app copiée à la main, cliquer sur le bouton ; la page des releases s'ouvre dans le navigateur par défaut.

**Acceptance Scenarios** :

1. **Given** l'app non installée par Homebrew, **When** l'utilisateur clique sur « Rechercher les mises à jour », **Then** la page des releases du projet s'ouvre dans le navigateur par défaut.
2. **Given** ce cas, **Then** une note sous le bouton indique « Installée sans Homebrew : télécharge la dernière version sur la page des releases ».

---

### User Story 3 - Depuis le menu de la barre de menus (Priority: P3)

Le clic droit sur l'icône de barre de menus propose « Rechercher les mises à jour… », avec le même comportement que le bouton des Réglages.

**Why this priority** : un raccourci ; les Réglages suffisent.

**Independent Test** : clic droit sur l'icône, choisir l'entrée ; même résultat que dans les Réglages.

**Acceptance Scenarios** :

1. **Given** l'icône de barre de menus affichée, **When** l'utilisateur fait un clic droit, **Then** le menu contient « Rechercher les mises à jour… » entre « Réglages » et « Quitter ».
2. **Given** l'entrée choisie, **Then** le comportement est celui des User Stories 1 ou 2, selon le mode d’installation.

---

### Edge Cases

- **Homebrew installé, mais l'app copiée à la main** (ou build de développement lancée ailleurs que dans le dossier Applications) : c'est la page des releases qui s'ouvre, puisque Homebrew ne gère pas cette copie.
- **Homebrew demande une confirmation** : l'utilisateur répond dans le Terminal ; s'il refuse, rien ne change et l'app continue de tourner.
- **Erreur pendant la mise à jour** (pas de réseau, tap inaccessible) : le Terminal affiche l'erreur de Homebrew ; l'app en cours n'est ni arrêtée ni modifiée.
- **Terminal remplacé par une autre app de terminal** : la commande s'ouvre avec l'app que macOS associe aux scripts de terminal.
- **Plusieurs clics rapides** : chaque clic ouvre sa propre fenêtre ; aucun état n'est conservé par l'app.
- **Pas d'icône de barre de menus** (réglage « Jamais ») : le bouton des Réglages reste le seul accès.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** : Les Réglages MUST afficher la version installée de l'app (numéro public, par exemple « 0.5.7 »).
- **FR-002** : Les Réglages MUST proposer un bouton « Rechercher les mises à jour ».
- **FR-003** : L'app MUST déterminer, sans connexion réseau, si la copie en cours d'exécution a été installée par Homebrew (présence du cask Notch Usage dans l'installation Homebrew locale et app lancée depuis le dossier Applications).
- **FR-004** : Installée par Homebrew, le bouton MUST ouvrir une fenêtre de terminal qui rafraîchit le tap, met à jour l'app puis la relance.
- **FR-005** : Sinon, le bouton MUST ouvrir la page des releases du projet dans le navigateur par défaut, et une note MUST l'indiquer sous le bouton.
- **FR-006** : L'app MUST NOT ouvrir elle-même de connexion réseau pour cette feature, ni vérifier automatiquement l'existence d'une version, ni afficher de badge de mise à jour (principe I de la constitution).
- **FR-007** : La feature MUST NOT demander de permission macOS nouvelle (contrôle d'une autre app, accès complet au disque, etc.).
- **FR-008** : Le menu du clic droit de l'icône de barre de menus MUST proposer « Rechercher les mises à jour… » avec le même comportement.
- **FR-009** : Tout texte nouveau MUST exister en anglais et en français.

### Key Entities

- **Mode d'installation** : Homebrew ou manuel, déterminé à chaque clic à partir de l'emplacement de l'app et de l'installation Homebrew locale.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : Avec Homebrew, passer à la dernière version demande un clic et, au plus, une confirmation dans le Terminal, sans connaître aucune commande.
- **SC-002** : L'échec observé à la sortie de la 0.5.7 (« la dernière version est déjà installée » alors qu'elle ne l'était pas) ne se reproduit pas par ce chemin.
- **SC-003** : Pendant et après le clic, l'app n'ouvre aucune connexion vers un autre serveur qu'Anthropic, ce que l'on peut vérifier avec un moniteur réseau.
- **SC-004** : Aucun texte nouveau sans traduction.

## Assumptions

- Homebrew est installé à l'un de ses emplacements standards (Apple Silicon ou Intel).
- Le cask reste nommé `notch-usage` dans le tap `florentmaille/tap`.
- Le cask arrête l'app avant de la remplacer ; la commande la relance à la fin. Si la version est déjà à jour, la relance remet simplement l'app au premier plan.
- Le navigateur et Homebrew se connectent à GitHub à la demande explicite de l'utilisateur : ce n'est pas l'app qui le fait, le principe I reste respecté.
- Hors périmètre : vérification automatique, notification de nouvelle version, mise à jour en arrière-plan, framework de mise à jour tiers.
