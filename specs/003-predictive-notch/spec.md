# Feature Specification: Encoche prédictive

**Feature Branch**: `003-predictive-notch`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Encoche prédictive : refonte de la vue compacte de Notch Usage. Aujourd'hui l'encoche montre une icône de limite à gauche et une mini-barre plus un pourcentage à droite ; l'alerte ne change que la couleur ; le temps avant réinitialisation n'apparaît pas ; l'encoche change de limite en silence. Nouveau design (maquette validée : docs/design/notch-v8-d1.png). Aile gauche = prévision […] Aile droite = pourcentage […] en pastille inversée […]. La prévision est calculée localement à partir des relevés des deux dernières heures […] sans aucune requête supplémentaire […]. Le panneau déplié gagne une ligne par limite […]. VoiceOver annonce la prévision […]. Pilule 150 × 28 pt […]. Anglais et français. Ordre : US1 la nouvelle encoche sans nouvelle donnée, US2 la prévision, US3 panneau déplié et VoiceOver."

**Maquette de référence** : [docs/design/notch-v8-d1.png](../../docs/design/notch-v8-d1.png)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Lire l'encoche en un coup d'œil (Priority: P1)

Un utilisateur regarde l'encoche sans la survoler. À gauche, il lit quand la limite se
réinitialise ; à droite, combien il en a consommé. Quand un seuil est franchi, le pourcentage
passe en pastille colorée : la forme change, pas seulement la couleur. Quand la limite est
épuisée, la pastille dit « Bloqué » et la gauche dit dans combien de temps ça revient.

**Why this priority**: c'est l'écran vu des dizaines de fois par jour. Il doit répondre à
« combien » et « quand » sans survol, et signaler l'urgence même à quelqu'un qui ne distingue
pas l'orange du rouge. Cette story ne demande aucune donnée nouvelle.

**Independent Test**: en mode démo, passer par les états normal, attention, critique, bloqué,
hors ligne, reconnexion ; comparer chaque capture à la maquette ; vérifier en niveaux de gris que
les états restent distincts.

**Acceptance Scenarios**:

1. **Given** un compte connecté, la limite la plus contrainte à 42 % et 2 h 14 avant sa réinitialisation, aucun seuil franchi, **When** l'encoche est repliée, **Then** l'aile gauche montre une coche et « 2 h 14 » en gris, l'aile droite « 42 % » en blanc, sans pastille ni barre.
2. **Given** la même limite à 83 %, seuil d'attention à 80 %, **When** l'encoche est repliée, **Then** le pourcentage s'affiche en pastille orange à texte sombre et l'aile gauche reste inchangée.
3. **Given** la même limite à 97 %, seuil critique à 95 %, **When** l'encoche est repliée, **Then** la pastille est rouge.
4. **Given** une limite épuisée, **When** l'encoche est repliée, **Then** la pastille rouge dit « Bloqué » (« Full » en anglais) et l'aile gauche montre une flèche circulaire et le temps avant le retour, en rouge.
5. **Given** le dernier relevé a échoué (hors ligne), **When** l'encoche est repliée, **Then** les deux ailes passent en gris, l'icône wifi barré remplace la coche, et le compte à rebours continue de s'écouler.
6. **Given** une session expirée, **When** l'encoche est repliée, **Then** l'aile gauche montre un cadenas orange, l'aile droite « Connexion » (« Sign in ») en orange sans soulignement, et un clic ouvre la reconnexion.
7. **Given** un écran sans encoche, **When** la pilule s'affiche, **Then** elle contient la prévision puis le pourcentage (« ✓ 2 h 14 · 42 % ») sans troncature.
8. **Given** un Mac en anglais, **When** chaque état s'affiche, **Then** la mise en page est identique, avec « Full » et « Sign in ».

---

### User Story 2 - Être prévenu avant le seuil (Priority: P2)

L'utilisateur travaille vite. À 55 % de sa fenêtre de 5 h, aucun seuil n'est franchi, mais à ce
rythme il sera bloqué dans 1 h 10, bien avant la réinitialisation. L'aile gauche le lui dit, avec
un sablier. Quand le blocage est prévu dans moins d'une heure, elle affiche l'heure du blocage.
Si le rythme ralentit et tient jusqu'à la réinitialisation, la coche revient.

**Why this priority**: « 83 % » ne dit rien ; « bloqué à 16:40 » déclenche une décision, finir
maintenant ou attendre. C'est la raison d'être de la refonte, mais elle repose sur US1.

**Independent Test**: rejouer des séries de relevés (fixtures) à rythme constant, croissant,
nul, et vérifier l'état de l'aile gauche après chaque relevé ; vérifier qu'aucune requête
supplémentaire n'est faite.

**Acceptance Scenarios**:

1. **Given** des relevés sur 40 min montrant la fenêtre de 5 h passer de 40 % à 55 %, avec 4 h avant la réinitialisation, **When** la projection de ce rythme atteint 100 % en 1 h 10, **Then** l'aile gauche montre un sablier et « 1 h 10 » en orange, l'aile droite « 55 % » en blanc sans pastille.
2. **Given** un blocage prévu dans moins d'une heure, **When** l'encoche est repliée, **Then** l'aile gauche montre l'heure prévue du blocage (« 16:40 ») au format de l'utilisateur, en rouge si le seuil critique est franchi, en orange sinon.
3. **Given** moins de deux relevés espacés d'au moins 10 min (premier lancement, retour de veille), **When** l'encoche est repliée, **Then** aucune prévision n'est affichée : coche et compte à rebours.
4. **Given** une consommation stable ou décroissante sur la fenêtre d'observation, **When** l'encoche est repliée, **Then** la coche est affichée.
5. **Given** une projection qui oscille d'un relevé à l'autre autour de l'heure de réinitialisation, **When** les relevés se succèdent, **Then** l'aile gauche ne change d'état qu'après deux relevés consécutifs concordants.
6. **Given** la limite hebdomadaire à 60 % et la fenêtre de 5 h à 55 % avec un blocage prévu, **When** l'encoche choisit la limite à afficher, **Then** elle montre la fenêtre de 5 h : un blocage prévu prime sur le pourcentage le plus élevé.
7. **Given** l'app relancée, **When** elle redémarre, **Then** les relevés des deux dernières heures sont conservés et la prévision est disponible dès le premier relevé si l'historique le permet.
8. **Given** une déconnexion depuis l'app, **When** elle est confirmée, **Then** l'historique des relevés est effacé.

---

### User Story 3 - Comprendre le rythme dans le panneau et avec VoiceOver (Priority: P3)

Dans le panneau déplié, chaque limite dotée d'une prévision gagne une ligne : « À ce rythme :
bloqué à 16:40 » ou « À ce rythme : tient jusqu'au reset ». VoiceOver annonce la prévision après
le pourcentage, dans l'encoche comme dans le panneau.

**Why this priority**: le panneau explique ce que l'encoche résume ; l'accessibilité suit les
exigences des features 001 (FR-016) et 002 (US3).

**Independent Test**: VoiceOver actif, parcourir l'encoche et le panneau avec une prévision
active puis sans.

**Acceptance Scenarios**:

1. **Given** une prévision de blocage pour la fenêtre de 5 h, **When** le panneau est déplié, **Then** la ligne de cette limite indique « À ce rythme : bloqué à 16:40 » ; sans prévision possible, aucune ligne supplémentaire.
2. **Given** VoiceOver actif et une prévision, **When** le focus arrive sur la limite, **Then** l'annonce est « Fenêtre de 5 h, 55 pour cent, réinitialisation dans 3 h 50, à ce rythme bloqué à 16:40 ».
3. **Given** VoiceOver actif, **When** le focus arrive sur l'encoche repliée, **Then** l'annonce comprend le pourcentage, la réinitialisation et la prévision.

### Edge Cases

- Réinitialisation pendant la fenêtre d'observation : les relevés antérieurs à la réinitialisation sont écartés ; la prévision redevient muette jusqu'à deux nouveaux relevés.
- Trou de plus de 30 min entre deux relevés (veille, écran verrouillé, hors ligne) : les relevés d'avant le trou ne servent plus à la pente.
- Heures de réinitialisation légèrement différentes d'un relevé à l'autre : même période (tolérance existante de 10 min).
- Rythme qui mène à 100 % après la réinitialisation : coche, pas de sablier.
- Limite épuisée : aucune prévision, flèche circulaire et temps avant retour.
- Blocage prévu dans moins d'une minute : l'heure du blocage s'affiche, jamais « 0 min ».
- Alertes désactivées dans les réglages : aucune pastille, pourcentage en blanc ; le sablier reste affiché, c'est une information, pas une alerte.
- Seuils modifiés dans les réglages : les pastilles suivent au prochain calcul.
- Pilule trop étroite pour « sablier + heure + pourcentage » : l'icône est retirée avant tout texte ; aucune troncature.
- Changement de limite affichée : aucun signal supplémentaire ; l'ordre de grandeur du compte à rebours (« 2 h » contre « 3 j ») identifie la limite.
- Relevé ancien de plus de 30 min sans échec réseau : textes en gris, sans icône wifi.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'aile gauche MUST afficher, selon l'état : coche + temps avant la réinitialisation (rythme tenable ou prévision indisponible) ; sablier + temps avant le blocage prévu, ou heure du blocage s'il est à moins d'une heure ; flèche circulaire + temps avant le retour (limite épuisée) ; wifi barré + temps avant la réinitialisation (dernier relevé en échec) ; cadenas (session expirée) ; icône de compte (non connecté).
- **FR-002**: L'aile droite MUST afficher le pourcentage utilisé de la limite affichée ; en pastille inversée (fond coloré, texte sombre) orange dès le seuil d'attention, rouge dès le seuil critique ; « Bloqué » (« Full ») en pastille rouge quand la limite est épuisée ; « Connexion » (« Sign in ») quand la session a expiré ; « Connexion » (« Connect ») quand aucun compte n'est connecté. La mini-barre actuelle disparaît.
- **FR-003**: Un état MUST NOT afficher plus d'une pastille.
- **FR-004**: Les couleurs MUST suivre : blanc par défaut, orange au seuil d'attention ou quand un blocage est prévu, rouge au seuil critique ou quand la limite est épuisée, gris quand le relevé est ancien ou en échec. L'aile gauche adopte la couleur de l'état, la coche et son compte à rebours restant gris.
- **FR-005**: Chaque état d'alerte MUST rester distinguable sans la couleur : pastille, sablier, flèche, cadenas, wifi barré.
- **FR-006**: Les durées MUST utiliser les formats existants des deux langues (« 2 h 14 », « 2h 14m ») ; l'heure de blocage MUST suivre le format d'heure du système (« 16:40 », « 4:40 PM »).
- **FR-007**: Les mentions « Connexion » et « Sign in » de l'encoche MUST NOT être soulignées ; elles restent cliquables et annoncées comme boutons.
- **FR-008**: Sur un écran sans encoche, la pilule de 150 × 28 pt MUST montrer la prévision puis le pourcentage, séparés par un point médian, sans troncature ; l'icône est retirée en premier si la place manque.
- **FR-009**: La prévision MUST être calculée localement à partir des relevés des deux dernières heures : pente de la consommation sur les 30 à 60 dernières minutes, projetée jusqu'à 100 % et comparée à l'heure de réinitialisation. Elle MUST rester indisponible tant qu'il n'y a pas deux relevés espacés d'au moins 10 min dans la même période.
- **FR-010**: La prévision MUST ne concerner que la fenêtre de 5 h dans cette version ; les limites hebdomadaires affichent la coche et le compte à rebours (voir Assumptions).
- **FR-011**: Un changement d'état entre « tenable » et « blocage prévu » MUST exiger deux relevés consécutifs concordants.
- **FR-012**: La limite affichée dans l'encoche MUST être celle dont le blocage prévu est le plus proche ; à défaut, la plus contrainte (règle actuelle).
- **FR-013**: Les relevés servant à la prévision MUST être conservés localement avec le cache existant, limités à deux heures, effacés à la déconnexion, et ne jamais quitter le Mac.
- **FR-014**: La feature MUST NOT ajouter de requête réseau ni modifier la cadence de rafraîchissement.
- **FR-015**: La prévision MUST NOT déclencher d'alerte (rebond, notification) : les alertes de seuil restent inchangées.
- **FR-016**: Le panneau déplié MUST afficher, sous chaque limite disposant d'une prévision, « À ce rythme : bloqué à 16:40 » ou « À ce rythme : tient jusqu'à la réinitialisation » (et leurs équivalents anglais) ; aucune ligne sinon.
- **FR-017**: Les annonces d'accessibilité de l'encoche et des lignes du panneau MUST inclure la prévision après le pourcentage et la réinitialisation.
- **FR-018**: Tous les nouveaux textes MUST exister en anglais et en français, vérifiés par le contrôle automatique existant.
- **FR-019**: Le mode démo MUST permettre de reproduire chaque état de la maquette pour les captures et la validation.
- **FR-020**: Les scénarios validés des features 001 et 002 MUST rester valides.

### Key Entities

- **Relevé**: une lecture de consommation datée : pour chaque limite, le pourcentage utilisé et l'heure de réinitialisation.
- **Historique des relevés**: les relevés des deux dernières heures, par limite et par période de réinitialisation.
- **Prévision**: pour une limite, l'un de trois états : tenable jusqu'à la réinitialisation ; blocage prévu à une heure donnée ; indisponible. Dérivée de l'historique, jamais stockée.
- **Niveau d'alerte**: existant (aucun, attention, critique), issu des seuils des réglages.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les 10 états de la maquette sont reproductibles en mode démo et leurs captures correspondent à la maquette (disposition, icônes, couleurs, textes), en français et en anglais.
- **SC-002**: En niveaux de gris, 100 % des états normal, attention, critique, bloqué, blocage prévu, hors ligne et reconnexion restent distincts.
- **SC-003**: Sur des séries de relevés simulées à rythme constant, le blocage est annoncé au moins 30 min avant le blocage effectif dans 100 % des cas ; sur un rythme nul ou décroissant, 0 fausse annonce.
- **SC-004**: Le nombre de requêtes réseau par 10 min reste identique à la version 0.2.1 (3 au rythme par défaut).
- **SC-005**: CPU moyen sous 1 % et empreinte mémoire inchangée à 2 Mo près par rapport à la version 0.2.1.
- **SC-006**: 100 % des nouveaux textes ont une traduction française au moment de la publication, vérifié automatiquement.
- **SC-007**: Aucune troncature de texte dans l'encoche ni dans la pilule sur l'ensemble des états, en français comme en anglais.

## Assumptions

- La prévision se limite à la fenêtre de 5 h : une pente mesurée sur une heure, projetée sur plusieurs jours, n'a pas de sens pour les limites hebdomadaires, qui demanderaient un modèle journalier et un historique plus long. Ce sera une feature ultérieure si l'usage le justifie.
- Les seuils d'attention et critique sont ceux des réglages existants (80 % et 95 % par défaut) ; alertes désactivées = aucune pastille.
- Les relevés sont ceux du rafraîchissement existant (toutes les 3 min par défaut) ; la qualité de la prévision dépend de cette cadence.
- L'historique vit dans le conteneur de l'app, avec le cache de relevés existant, conformément à la constitution (principe I).
- Le relevé ancien (plus de 30 min) et le relevé en échec partagent le gris ; seul l'échec montre l'icône wifi barré.
- Le changement de limite affichée ne reçoit pas de signal particulier ; l'ordre de grandeur du compte à rebours suffit à l'identifier.
- Le comportement du survol, de l'épinglage, du plein écran et de la pilule reste celui de la feature 001.
- « FULL » / « PLEIN » est remplacé par « Full » / « Bloqué », en pastille.
- La maquette `docs/design/notch-v8-d1.png` fait foi pour la disposition, à l'échelle réelle des ailes (72 pt).
