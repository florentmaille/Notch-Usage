# Feature Specification: Claude attend une action

**Feature Branch**: `017-claude-attention`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Claude attend une action (017-claude-attention). Planche validée : docs/design/claude-attention.png, version « Recommandée : glyphe à droite, libellé à l'arrivée » ; l'avatar est écarté. Quand une session Claude Code demande une approbation, pose une question ou finit un tour sans question, l'île le dit dans la grammaire de la 012 […]. Sources : les hooks de Claude Code […]. Transport : hook de type command qui ajoute une ligne JSON à un fichier dans le conteneur de l'app, lu sans polling ; aucun serveur local, aucune connexion réseau. L'app installe et retire ses entrées dans ~/.claude/settings.json par un réglage « Suivre Claude Code » […]. Rendu : à l'arrivée, l'oreille droite s'ouvre en fondu 0,3 s avec glyphe + un mot pendant 4 s, puis se replie sur le glyphe seul, qui persiste jusqu'à l'action ; rien ne bat. Teinte violet (#BF5AF2) pour approbation et question ; blanc pour terminé ; jamais ambre, orange ni rouge. […] Règle de priorité face à la limite […]. Survol : une section « Claude Code » […]. Plein écran […]. Pilule […]. Notification macOS en option, off par défaut. Accessibilité […]. Anglais et français. Budget CPU < 1 % inchangé, aucun polling. Fiabilité […]. Ordre : US1 le signal dans l'île depuis les hooks, US2 priorité face à la limite, compteur et plein écran, US3 survol et clic vers la session, US4 réglage d'installation des hooks et notification optionnelle, accessibilité, README et captures. Spike préalable : vérifier que PermissionRequest et Stop sont émis depuis les sessions de l'app desktop Claude, sinon se rabattre sur Notification."

**Planche de référence** : [docs/design/claude-attention.png](../../docs/design/claude-attention.png), section « Recommandée : glyphe à droite, libellé à l'arrivée ». Les variantes A (avatar), B (avatar + libellé), C (bandeau texte) et D (notification seule) sont écartées.

**Spike** : [spike-hooks.md](spike-hooks.md), fait le 2026-11-05 : les sessions de l'app desktop émettent bien les hooks, à chaud ; une question passe par `PermissionRequest` ; la fin de tour par `Stop`.

**S'appuie sur** : l'île de la [012](../012-notch-island/spec.md) (oreilles, fondu, pilule, point plein écran), le battement de la 006, la règle de la limite portée (008), les notifications (008). Rien de ces features ne change pour les états sans session en attente.

## Clarifications

### Session 2026-11-05

- Q : les hooks transmettent le titre de la session desktop en plus du dossier ; que montre la ligne du panneau ? → A : le titre quand il existe (sessions desktop), sinon le nom du dossier (CLI).

## Contexte

L'utilisateur mène plusieurs sessions Claude Code en parallèle (terminal et app Claude). Une session qui
attend une approbation, une réponse à une question ou simplement un prochain prompt reste invisible tant
qu'il ne revient pas dans sa fenêtre. L'île est toujours sous ses yeux : elle doit porter ce signal, de
façon persistante jusqu'à l'action, sans concurrencer le signal de limite qui est sa raison d'être.

Claude Code sait prévenir : il exécute des **hooks** à chaque événement de session (demande de
permission, question posée, fin de tour, prompt envoyé, fin de session), chacun avec l'identifiant de la
session et son dossier de travail. L'app s'y abonne et n'a rien à interroger.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Voir qu'une session attend, et quoi (Priority: P1)

L'utilisateur travaille dans une autre fenêtre. Une session Claude Code demande une approbation.
L'oreille droite de l'île s'ouvre avec une main levée violette et le mot « Approbation », puis, quatre
secondes plus tard, se replie sur la main seule. Elle y reste jusqu'à ce qu'il réponde dans la session.
Même mécanique pour une question (bulle « ? », violet) et pour une réponse terminée sans question
(coche blanche). La jauge d'usage reste à gauche, inchangée.

**Why this priority**: c'est la valeur de la feature : ne plus laisser une session bloquée sans le
savoir. Sans les autres histoires, ce seul signal suffit déjà.

**Independent Test**: en mode démo, chaque état de la table « Contenu par état » ci-dessous ; en
réel, une session Claude Code qui demande une permission, pose une question, finit un tour : l'île
change dans la seconde, et revient au calme quand l'utilisateur répond.

**Acceptance Scenarios**:

1. **Given** une île au calme, **When** une session demande une approbation, **Then** en moins d'une seconde l'oreille droite s'ouvre en fondu avec le glyphe main levée et « Approbation » en violet ; après 4 s, le mot disparaît et le glyphe reste.
2. **Given** une session en attente d'approbation, **When** l'utilisateur accorde ou refuse dans la session, **Then** l'oreille droite se replie en fondu et l'île revient à son contenu 012.
3. **Given** une île au calme, **When** une session pose une question, **Then** glyphe bulle « ? » violet, mot « Question » 4 s, puis glyphe seul jusqu'au prompt suivant de cette session.
4. **Given** une île au calme, **When** une session termine un tour sans question, **Then** coche blanche, mot « Terminé » 4 s, puis coche seule jusqu'au prompt suivant, à la fermeture de la session, ou à un clic sur l'île.
5. **Given** une session en attente, **When** 60 s passent sans réponse, **Then** rien ne change : le signal ne bat pas, ne clignote pas, ne grossit pas.
6. **Given** une session qui attend, **When** la session se termine (fermeture, fin de session), **Then** le signal disparaît.
7. **Given** une session qui travaille (outils en cours), **Then** aucun signal : une session qui travaille ne se montre pas.
8. **Given** l'app fermée pendant qu'une session demande une approbation, **When** l'app se lance, **Then** le signal apparaît s'il est encore d'actualité (pas de prompt ni de fin de session depuis).
9. **Given** la réduction des animations activée, **Then** l'oreille apparaît et disparaît sans fondu ; le mot est affiché 4 s de la même façon.

---

### User Story 2 - Priorité face à la limite, plusieurs sessions, plein écran (Priority: P2)

Quand la limite d'usage est imminente ou épuisée, elle garde l'oreille droite et son battement ; la
session en attente se réduit à un point violet au coin de la jauge. Au-dessus de 30 min, la session
prend l'oreille droite et la jauge garde la couleur de son palier. Quand plusieurs sessions attendent,
l'île montre le glyphe du cas le plus pressant et le nombre de sessions. En plein écran, le point prend
la teinte du signal.

**Why this priority**: l'île n'a qu'une oreille droite ; sans règle, les deux signaux se chassent.
Plusieurs sessions en parallèle sont le cas courant de l'utilisateur.

**Independent Test**: démos `imminent` + attente, `blocked` + attente, `far` + attente, trois sessions
mixtes, plein écran : contenu, couleur et battement conformes à la planche.

**Acceptance Scenarios**:

1. **Given** un blocage prévu dans 8 min et une session en attente d'approbation, **Then** jauge rouge qui bat, « 8′ » à droite, et un point violet au coin de la jauge ; aucun glyphe Claude à droite.
2. **Given** la limite épuisée et une session en attente, **Then** jauge pleine rouge, « ↻ » + retour à droite, point violet au coin de la jauge.
3. **Given** un blocage prévu dans 2 h 05 et une question posée, **Then** jauge ambre (palier inchangé), bulle « ? » violette à droite à la place de « 2:05 » ; « 2:05 » revient dès que la question est traitée.
4. **Given** une limite au seuil sans prévision (hebdo à 97 %) et une session en attente, **Then** la jauge garde sa couleur de seuil et la session prend l'oreille droite (le seuil n'est ni imminent ni épuisé).
5. **Given** deux sessions en attente d'approbation et une terminée, **Then** main levée violette et « 3 » à droite ; quand les deux approbations sont données, coche blanche seule.
6. **Given** une approbation et une question en attente, **Then** le glyphe est la main levée (approbation > question > terminé) et le compteur « 2 ».
7. **Given** une app en plein écran et une session en attente, **Then** le point est violet ; une session terminée seule : point blanc ; limite imminente : le point reste rouge et bat, comme en 012.
8. **Given** un écran sans encoche, **Then** la pilule montre jauge puis glyphe (et compteur) sur une ligne, mêmes règles.

---

### User Story 3 - Survol : quelles sessions, depuis quand, et y aller (Priority: P3)

Au survol, le panneau ouvre une section « Claude Code » au-dessus des limites : une ligne par session
en attente, avec son nom (le titre de la session s'il existe, sinon le dossier du projet), ce qu'elle
attend et depuis combien de temps. Un clic sur
une ligne amène devant l'application d'où vient la session (l'app Claude ou le terminal).

**Why this priority**: avec plusieurs sessions, le glyphe dit « une session attend » ; le survol dit
laquelle et permet d'y aller sans chercher.

**Independent Test**: démo trois sessions : les lignes sont dans l'ordre pressant puis ancienneté ;
en réel, le clic sur une ligne active l'app Claude ou le terminal qui porte la session.

**Acceptance Scenarios**:

1. **Given** trois sessions en attente, **When** le pointeur survole l'île, **Then** une section « Claude Code » liste trois lignes : point coloré (violet ou blanc), nom de la session (titre, sinon dossier), « attend une approbation » / « attend une réponse » / « a terminé », durée depuis l'événement (« 45 s », « 2 min », « 1 h 10 »).
2. **Given** la section affichée, **Then** les lignes sont triées : approbations, puis questions, puis terminées ; dans chaque groupe, la plus ancienne en premier.
3. **Given** une ligne, **When** l'utilisateur clique dessus, **Then** l'application d'où vient la session passe au premier plan ; le panneau se referme ; le signal de cette session reste tant que l'action n'est pas faite.
4. **Given** aucune session en attente, **Then** la section est absente ; le panneau est celui de la 012.
5. **Given** le menu de la barre des menus (014) actif, **Then** il montre la même section, sous la même forme.

---

### User Story 4 - Réglage, notification optionnelle, accessibilité, documentation (Priority: P4)

Un réglage « Suivre Claude Code » active ou retire l'abonnement de l'app aux événements de Claude Code,
sans toucher aux autres réglages de l'utilisateur. Une notification macOS optionnelle, désactivée par
défaut, double le signal. VoiceOver annonce les sessions en attente. Le README et ses captures montrent
le signal.

**Why this priority**: l'abonnement touche à la configuration personnelle de l'utilisateur ; il doit
être explicite, réversible et propre. Le reste est la finition attendue de chaque feature.

**Independent Test**: activer puis désactiver le réglage sur une configuration qui a déjà d'autres
hooks : avant et après, les hooks de l'utilisateur sont identiques ; les entrées de l'app sont présentes
puis absentes.

**Acceptance Scenarios**:

1. **Given** le réglage désactivé (par défaut au premier lancement), **Then** aucune entrée de l'app dans la configuration de Claude Code, aucun signal.
2. **Given** l'utilisateur active « Suivre Claude Code », **Then** les entrées nécessaires sont ajoutées à sa configuration de Claude Code ; ses hooks existants (y compris ceux de l'app Claude) sont conservés tels quels ; les sessions déjà ouvertes sont suivies dès leur prochain événement.
3. **Given** le réglage activé, **When** l'utilisateur le désactive, **Then** seules les entrées de l'app sont retirées ; la configuration de l'utilisateur est, à l'octet près de ses propres hooks, celle d'avant.
4. **Given** Claude Code absent de la machine, **Then** le réglage reste proposé avec une note « Claude Code n'a pas été trouvé » et ne fait rien d'autre.
5. **Given** la configuration de Claude Code illisible (JSON invalide), **Then** l'app ne l'écrit pas, affiche une erreur courte dans les réglages, et le réglage reste désactivé.
6. **Given** « Notifier aussi » activé (défaut : désactivé), **When** une session demande une approbation ou pose une question, **Then** une notification macOS « Notch-Usage attend une approbation » ; aucune pour une réponse terminée ; une seule par événement.
7. **Given** VoiceOver sur l'île avec deux sessions en attente, **Then** l'annonce commence par « 2 sessions Claude attendent : Notch-Usage, une approbation ; deck-q4, une réponse » puis la bande des limites.
8. **Given** les captures en niveaux de gris, **Then** approbation, question et terminé restent distincts par le glyphe ; le compteur est lisible.
9. **Given** le README, **Then** la table des états et la planche montrent les états Claude ; le réglage est documenté, en anglais et en français.

### Contenu par état

| État | Oreille gauche | Oreille droite | Plein écran |
|---|---|---|---|
| Calme, aucune session en attente | jauge 012 | selon 012 | selon 012 |
| Approbation demandée, arrivée (4 s) | jauge 012 | main levée + « Approbation », violet | violet |
| Approbation demandée, persistant | jauge 012 | main levée, violet | violet |
| Question posée | jauge 012 | bulle « ? », violet | violet |
| Réponse terminée | jauge 012 | coche, blanc | blanc |
| N sessions en attente | jauge 012 | glyphe du cas le plus pressant + N | couleur du cas le plus pressant |
| Blocage prévu ≥ 30 min + session en attente | jauge du palier | glyphe Claude (remplace l'échéance) | couleur Claude |
| Blocage prévu < 30 min ou limite épuisée + session en attente | jauge rouge, bat, point violet au coin | selon 012 (échéance ou retour) | rouge, bat |
| Seuil sans prévision + session en attente | jauge du seuil | glyphe Claude (remplace le libellé) | couleur Claude |
| Hors ligne, session expirée, non connecté + session en attente | glyphe 012 | glyphe Claude | couleur Claude |

Teintes : violet #BF5AF2 pour approbation et question (bloquant), blanc pour terminé (information).
Jamais ambre, orange ni rouge, réservés aux paliers de limite.

### Edge Cases

- Deux événements pour la même session en moins de 4 s (question puis approbation) : le libellé en cours est remplacé, les 4 s repartent.
- Événement d'une session déjà en attente (nouvelle approbation après un refus) : l'état est remplacé, la durée « depuis » repart.
- Fin de session jamais reçue (terminal fermé, processus tué) : la session est retirée dès que son processus n'existe plus, vérifié au prochain événement, au survol et au lancement ; à défaut, elle expire 8 h après son dernier événement.
- Même dossier pour deux sessions : deux lignes, même nom, distinguées par l'heure ; le compteur compte les sessions.
- Dossier sans nom lisible (racine, chemin vide) et sans titre : le nom est « Session » suivi d'un numéro court.
- Titre de session connu seulement au prompt suivant (il arrive avec le prompt) : la ligne montre le dossier puis prend le titre dès qu'il est connu.
- Permission refusée par Esc (le tour s'interrompt sans fin de tour) : l'attente s'efface au prompt suivant ou à la fin de session.
- Fichier d'événements corrompu ou ligne illisible : la ligne est ignorée, le reste est lu, l'app le note dans ses journaux.
- Fichier d'événements volumineux (des jours sans lancement) : rattrapé au lancement puis compacté ; l'app ne garde que l'état courant des sessions.
- Clic sur l'île avec plusieurs sessions : efface les « terminé », épingle le panneau comme en 012 ; les attentes bloquantes ne s'effacent que par l'action dans la session.
- Hooks installés mais app fermée : les scripts restent muets et rapides (ils écrivent une ligne), aucune erreur côté Claude Code.
- L'utilisateur édite sa configuration de Claude Code à la main et retire une entrée de l'app : au prochain lancement, l'app constate l'écart, montre le réglage comme « partiel » et propose de réparer.
- Événements venant de l'app Claude (sessions du Code tab) : suivis comme ceux du terminal si les hooks y sont émis ; à confirmer par le spike ci-dessous.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'app MUST connaître, pour chaque session Claude Code suivie, son état d'attente : aucun, approbation demandée, question posée, réponse terminée ; avec le dossier de travail, le titre de session quand il est connu, l'application d'origine et l'heure de l'événement.
- **FR-002**: L'état MUST venir des événements émis par Claude Code lui-même : demande de permission (approbation, ou question quand l'outil demandé est la question à l'utilisateur), fin de tour ; il MUST être effacé par l'exécution ou l'échec de l'outil demandé, le prompt suivant de la même session, la fin de tour, la fin de la session, ou un clic pour les réponses terminées.
- **FR-003**: L'abonnement MUST passer par un hook de type commande qui ajoute une ligne d'événement à un fichier dans le conteneur de l'app ; l'app MUST lire ce fichier sans polling et sans serveur local ; aucune connexion réseau n'est ajoutée (constitution I).
- **FR-004**: Un réglage « Suivre Claude Code », désactivé par défaut, MUST installer et retirer les entrées de l'app dans la configuration de Claude Code en préservant à l'identique toutes les entrées de l'utilisateur ; le script appelé MUST vivre dans le conteneur de l'app, pas dans le bundle ; une configuration illisible n'est jamais écrite.
- **FR-005**: À l'arrivée d'un événement, l'oreille droite MUST s'ouvrir en fondu 0,3 s avec le glyphe et un mot (« Approbation », « Question », « Terminé »), puis se replier sur le glyphe seul après 4 s ; le glyphe MUST persister jusqu'à l'effacement ; rien ne bat ni ne clignote.
- **FR-006**: Teintes : violet pour approbation et question, blanc pour terminé ; jamais les teintes des paliers de limite. Glyphes : main levée, bulle avec point d'interrogation, coche.
- **FR-007**: Plusieurs sessions : un seul glyphe, celui du cas le plus pressant (approbation > question > terminé), suivi du nombre de sessions en attente.
- **FR-008**: Priorité : si un blocage est prévu sous 30 min ou si la limite portée est épuisée, l'oreille droite et le battement restent ceux de la 012 et la session en attente se signale par un point violet au coin de la jauge ; sinon, la session prend l'oreille droite et la jauge garde sa couleur (palier, seuil ou glyphe 012).
- **FR-009**: Le point du plein écran MUST prendre la couleur du signal Claude quand une session attend, sauf limite imminente ou épuisée où il reste rouge et bat. La pilule MUST montrer le même contenu sur une ligne.
- **FR-010**: Au survol et dans le menu de la barre, une section « Claude Code » MUST lister les sessions en attente (titre de session, sinon nom du dossier ; ce qu'elle attend ; durée depuis l'événement), triées par cas pressant puis ancienneté ; un clic sur une ligne MUST amener devant l'application d'origine de la session ; la section est absente sans session en attente.
- **FR-011**: Une notification macOS optionnelle (« Notifier aussi », désactivée par défaut) MUST être envoyée pour une approbation ou une question, une par événement, jamais pour une réponse terminée.
- **FR-012**: Fiabilité : les événements reçus app fermée MUST être rattrapés au lancement ; une session dont le processus n'existe plus MUST être retirée ; à défaut, expiration 8 h après le dernier événement ; une ligne illisible MUST être ignorée sans bloquer les autres.
- **FR-013**: Accessibilité : glyphe et compteur lisibles sans la couleur ; VoiceOver MUST annoncer le nombre de sessions en attente et chacune (dossier, ce qu'elle attend) avant la bande des limites ; réduction des animations : aucun fondu.
- **FR-014**: Tous les textes nouveaux MUST exister en anglais et en français.
- **FR-015**: Aucune cadence, requête ni rafraîchissement supplémentaires ; budget CPU < 1 % et empreinte mémoire de la constitution inchangés.
- **FR-016**: Spike fait (voir [spike-hooks.md](spike-hooks.md)) : les sessions de l'app Claude (Code tab) émettent les mêmes événements que le terminal, et une entrée ajoutée à la configuration est exécutée par les sessions déjà ouvertes, sans redémarrage. Le plan s'appuie sur ces résultats.

### Key Entities

- **Session suivie** : une session Claude Code connue par ses événements ; identifiant, dossier de travail, titre (facultatif), application d'origine, état d'attente (aucun, approbation, question, terminé), heure du dernier événement.
- **Signal Claude** : ce que l'île ajoute au signal 012 : glyphe (ou aucun), compteur, teinte, libellé d'arrivée encore visible ou non, point au coin de la jauge ; dérivé des sessions suivies et du signal de limite.
- **Abonnement** : l'état des entrées de l'app dans la configuration de Claude Code : absent, installé, partiel (modifié à la main), erreur.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Chaque état de la planche est reproduit en démo, capture à l'appui.
- **SC-002**: En réel, une permission demandée dans une session apparaît dans l'île en moins de 1 s, et disparaît en moins de 1 s après la réponse.
- **SC-003**: Activer puis désactiver le réglage sur une configuration de Claude Code contenant déjà des hooks la laisse identique, à l'octet près sur ses entrées, dans 100 % des cas testés (configurations avec 0, 1 et 8 hooks existants).
- **SC-004**: En niveaux de gris, approbation, question et terminé restent distincts ; le compteur est lisible à 13 pt.
- **SC-005**: CPU moyen < 1 % sur 10 min avec trois sessions suivies qui émettent un événement par seconde ; empreinte à ± 2 Mo de la 0.5.3.
- **SC-006**: 0 texte sans traduction ; annonce VoiceOver complète dans tous les états.
- **SC-007**: Une session dont le terminal a été fermé sans fin de session disparaît de l'île au survol suivant.

## Assumptions

- Les hooks de Claude Code sont émis pour les sessions du terminal et de l'app Claude (Code tab), vérifié par le spike. L'attente prolongée (notification d'inactivité) n'a pas été observée et n'est pas une source retenue.
- Les sessions de l'utilisateur tournent le plus souvent en mode auto, où les demandes de permission sont rares : la question et la fin de tour sont les cas courants, le rendu est le même.
- L'application d'origine est déduite au moment de l'événement (processus parent de la session) et mémorisée avec la session ; le clic active cette application, pas la fenêtre exacte de la session, que macOS ne permet pas de cibler depuis l'extérieur.
- Le nom affiché est le titre de la session quand Claude Code le transmet (app desktop), sinon le dernier composant du dossier de travail.
- Un libellé d'arrivée dure 4 s ; une arrivée pendant les 4 s remplace le libellé et relance la durée.
- Le seuil de priorité de la limite est celui du palier imminent de la 005 (30 min) et l'épuisement ; un seuil sans prévision ne prend pas le pas sur une session en attente.
- Les sessions terminées (coche) ne bloquent rien : elles s'effacent aussi d'un clic sur l'île, et n'émettent pas de notification.
- Le réglage est désactivé par défaut : l'app n'écrit jamais dans la configuration de Claude Code sans un geste de l'utilisateur. Il est proposé dans les réglages simples (013), pas sous « Avancé ».
- Hors champ : suivre d'autres agents que Claude Code ; répondre à l'approbation depuis l'île ; afficher le contenu de la question.
