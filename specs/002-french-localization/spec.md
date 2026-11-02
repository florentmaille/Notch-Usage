# Feature Specification: Interface en français

**Feature Branch**: `002-french-localization`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Interface de Notch Usage en français. L'app affiche aujourd'hui tous ses textes en anglais (panneau, encoche, réglages, connexion, bandeaux, messages d'erreur, annonces VoiceOver, fenêtre de connexion). Ajouter le français : l'app suit la langue du système (français si le Mac est en français, anglais sinon), sans réglage dans l'app. Les dates et durées (« dans 2 h 14 min », jours de la semaine) suivent aussi la langue. Le README et les notes de version restent en anglais."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Lire ses limites en français (Priority: P1)

Une utilisatrice francophone, dont le Mac est réglé en français, survole l'encoche. Le panneau,
les libellés des limites, les durées avant réinitialisation et les jours de la semaine s'affichent
en français, sans rien configurer.

**Why this priority**: c'est l'écran consulté plusieurs fois par jour ; un mélange d'anglais et de
français y nuit à la lecture d'un coup d'œil, raison d'être de l'app.

**Independent Test**: Mac en français, compte connecté : ouvrir le panneau et vérifier qu'aucun mot
anglais ne subsiste dans l'encoche, le panneau déplié et son pied.

**Acceptance Scenarios**:

1. **Given** un Mac en français et un compte connecté, **When** l'utilisatrice survole l'encoche, **Then** elle lit « Fenêtre de 5 h », « Hebdomadaire, tous modèles », « Hebdomadaire · Fable », « Réinitialisation dans 2 h 14 min » et un jour abrégé en français (« jeu. 17:34 »).
2. **Given** un Mac en anglais, **When** l'utilisateur ouvre le panneau, **Then** tout reste en anglais, à l'identique de la version actuelle.
3. **Given** une limite épuisée, **When** le panneau s'affiche en français, **Then** l'encoche montre l'équivalent français de « FULL » et la ligne indique « Bloqué, réinitialisation dans … ».

---

### User Story 2 - Se connecter et régler l'app en français (Priority: P2)

Lors de la première connexion, de la reconnexion ou dans les réglages, tous les textes (boutons,
explications, note de risque, messages d'erreur, bandeaux d'état, titre de la fenêtre de connexion)
sont en français.

**Why this priority**: parcours ponctuels mais critiques ; un message d'erreur incompris bloque l'usage.

**Independent Test**: Mac en français, se déconnecter, parcourir l'écran de connexion, provoquer une
erreur (clé de session invalide collée dans les réglages), ouvrir les réglages : tout est en français.

**Acceptance Scenarios**:

1. **Given** l'app déconnectée sur un Mac en français, **When** l'utilisateur ouvre le panneau, **Then** le titre, les deux boutons de connexion, leurs explications et la note de risque sont en français.
2. **Given** une clé de session invalide collée dans les réglages, **When** l'utilisateur valide, **Then** le message d'erreur est en français.
3. **Given** des données hors ligne ou anciennes, **When** le panneau s'affiche, **Then** les bandeaux (« Données indisponibles… », « Dernier relevé il y a plus de 30 minutes ») et l'ancienneté (« il y a 12 min ») sont en français.

---

### User Story 3 - VoiceOver en français (Priority: P3)

Avec VoiceOver et un Mac en français, chaque limite est annoncée en une phrase française
(« Hebdomadaire · Fable, 83 pour cent, réinitialisation dans 3 j 5 h »), ainsi que l'état de
l'encoche et les boutons.

**Why this priority**: l'accessibilité fait partie des exigences de la feature 001 (FR-016) ; elle doit
suivre la langue.

**Independent Test**: VoiceOver actif, Mac en français : parcourir l'encoche et le panneau.

**Acceptance Scenarios**:

1. **Given** VoiceOver actif sur un Mac en français, **When** le focus arrive sur une limite, **Then** l'annonce est entièrement en français.

### Edge Cases

- Langue système ni française ni anglaise (allemand, espagnol…) : l'app s'affiche en anglais.
- Français régional (fr-CA, fr-BE, fr-CH) : l'app s'affiche en français ; formats de date et d'heure de la région.
- Nom de modèle renvoyé par le service (« Fable ») : jamais traduit.
- Pourcentages et seuils : notation française avec espace avant « % » si la langue le prévoit, chiffres inchangés.
- Changement de langue système pendant que l'app tourne : la nouvelle langue s'applique au prochain lancement (comportement standard macOS).
- Pluriels : « 1 min », « 2 min » ; « 1 j », « 2 j » ; aucune forme incorrecte du type « 1 jours ».

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'app MUST afficher tous ses textes d'interface en français lorsque la langue préférée du système est le français, et en anglais dans tous les autres cas.
- **FR-002**: L'app MUST NOT proposer de réglage de langue interne ; elle suit la préférence système (Réglages Système → Général → Langue et région, y compris le choix de langue par app).
- **FR-003**: Les textes couverts MUST inclure : vue compacte de l'encoche, panneau déplié, écran de connexion, écran de reconnexion, réglages, bandeaux d'état, messages d'erreur de connexion, fenêtre de connexion au navigateur, annonces d'accessibilité.
- **FR-004**: Les durées avant réinitialisation et l'ancienneté du relevé MUST être formulées dans la langue affichée (ex. « dans 2 h 14 min », « il y a 12 min », « à l'instant », « réinitialisation imminente »).
- **FR-005**: Les dates et heures (jour de la semaine, heure) MUST suivre la langue et la région du système.
- **FR-006**: Les noms de modèles fournis par le service MUST rester tels quels.
- **FR-007**: L'anglais MUST rester strictement identique à la version 0.1.0 (aucune régression de texte).
- **FR-008**: Un texte ajouté à l'interface sans traduction française MUST être détectable avant publication (contrôle automatique).
- **FR-009**: Le README, les notes de version et les journaux techniques MUST rester en anglais.

### Key Entities

- **Catalogue de textes**: l'ensemble des textes d'interface, chacun avec sa version anglaise (source) et française, y compris les variantes de pluriel.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Sur un Mac en français, 100 % des textes visibles dans les 6 écrans de l'app (encoche, panneau, connexion, reconnexion, réglages, fenêtre navigateur) sont en français, hors noms de modèles et noms propres (Claude, Claude Code, claude.ai).
- **SC-002**: Sur un Mac en anglais, 0 différence de texte avec la version 0.1.0.
- **SC-003**: 100 % des textes du catalogue ont une traduction française au moment de la publication, vérifié automatiquement.
- **SC-004**: Les durées et anciennetés en français sont correctes pour 100 % des cas testés (minutes, heures, jours, singulier et pluriel).

## Assumptions

- Les textes de l'interface sont déjà écrits de façon localisable ; le travail porte sur le catalogue de traductions et sur les durées aujourd'hui figées en anglais.
- Seuls l'anglais (source) et le français sont visés ; d'autres langues pourront suivre sans changement de structure.
- Les abréviations françaises suivent l'usage courant : « h » pour heure, « min » pour minute, « j » pour jour.
- La note de risque est traduite fidèlement, sans en atténuer la portée.
- Aucun changement de comportement, de réseau ni de stockage : la feature ne touche que les textes.
- Seule exception à FR-007, corrigée volontairement : une limite dont l'heure de réinitialisation est passée affichait « Resets reset pending » ; elle affiche désormais « Reset pending » (« Réinitialisation imminente »).
- Typographie française : espace insécable avant « % » et « : », apostrophe typographique.
