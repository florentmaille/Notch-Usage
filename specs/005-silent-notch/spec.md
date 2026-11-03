# Feature Specification: Encoche silencieuse et liseré d'échéance

**Feature Branch**: `005-silent-notch`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Encoche silencieuse et liseré d'échéance : refonte de l'encoche repliée de Notch Usage. Aujourd'hui l'encoche affiche en permanence deux oreilles noires de 72 pt […]. Nouveau comportement (planche validée : docs/design/notch-pistes-halo.png, piste B « silence, puis liseré »). État calme […] : l'app ne dessine rien […]. Règle absolue : l'encoche ne s'élargit jamais sans texte à afficher […]. Survol : la bande complète […] apparaît, puis le panneau se déplie […]. Blocage qui approche : un liseré coloré […] dont la teinte et l'épaisseur suivent l'échéance […] ; à droite une seule donnée […]. Limite hebdomadaire au-dessus du seuil […] : liseré, pastille […]. Hors ligne ou relevé ancien : oreilles et textes gris, aucun liseré. Session expirée : cadenas et « Sign in » […]. Une pulsation unique […], aucune animation continue […]. Le liseré a un seul sens […]. Le réglage « Limite affichée » (feature 004) reste […]. Pilule […] : la pilule disparaît en état calme […]. Anglais et français. VoiceOver […]. Ordre : US1 l'encoche silencieuse, US2 le liseré d'échéance et la donnée unique, US3 pilule, plein écran et accessibilité."

**Planche de référence** : [docs/design/notch-pistes-halo.png](../../docs/design/notch-pistes-halo.png), section B (états 1 à 9) et C1.

## Clarifications

### Session 2026-11-03

- Q (retour sur build) : faut-il un texte à côté du liseré ? → A: non. Dans l'encoche, le liseré seul, sans
  oreilles ni texte, pour tous les états à liseré ; le survol montre les informations. La pilule, sans encoche
  à entourer, garde sa donnée unique.

- Q: Fenêtre de 5 h au-dessus du seuil mais rythme tenable : que montre l'encoche ? → A: la prévision prime ; silence tant que le rythme tient, le seuil ne sert que si la prévision est indisponible.
- Q: En état calme, quelle zone déclenche le survol ? → A: l'encoche physique seule ; les oreilles rejoignent la zone dès qu'elles sont visibles.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ne rien voir quand tout va bien (Priority: P1)

Un utilisateur travaille toute la journée avec l'app lancée. Tant qu'aucun blocage n'approche,
l'encoche de son Mac reste exactement celle du Mac : pas d'oreilles noires, pas de texte, pas de
chiffre. Quand il veut savoir où il en est, il survole l'encoche : la bande complète (prévision à
gauche, pourcentage à droite) apparaît, puis le panneau se déplie comme aujourd'hui. Un clic
épingle, comme aujourd'hui.

**Why this priority**: c'est l'état de l'app 90 % du temps. Aujourd'hui elle élargit l'encoche de
144 pt en permanence pour afficher deux chiffres que personne ne lit en vision périphérique. Ne
rien dessiner coûte zéro et rend l'information d'autant plus visible quand elle arrive.

**Independent Test**: en mode démo, état normal : aucune zone noire ni texte à côté de l'encoche,
sur fond clair comme sur fond sombre ; survol : la bande apparaît sous 0,2 s, puis le panneau ;
sortie du pointeur : tout disparaît.

**Acceptance Scenarios**:

1. **Given** un compte connecté, un relevé frais, aucun blocage prévu et aucune limite au-dessus du seuil d'attention, **When** l'encoche est repliée et non survolée, **Then** rien n'est dessiné : ni oreilles, ni texte, ni liseré.
2. **Given** le même état, **When** le pointeur survole l'encoche, **Then** la bande complète apparaît (coche + temps avant réinitialisation à gauche, pourcentage à droite), puis le panneau se déplie selon le délai existant.
3. **Given** le panneau déplié par survol, **When** le pointeur sort, **Then** le panneau se replie et l'encoche redevient silencieuse.
4. **Given** l'encoche silencieuse, **When** l'utilisateur clique dessus, **Then** le panneau s'épingle comme aujourd'hui ; un second clic sur la bande le désépingle et l'encoche redevient silencieuse.
5. **Given** n'importe quel état, **When** l'app a un texte à montrer, **Then** les oreilles noires apparaissent avec lui ; **When** elle n'a aucun texte à montrer, **Then** aucune oreille n'est dessinée, jamais.
6. **Given** un relevé ancien ou un dernier relevé en échec, **When** l'encoche est repliée, **Then** les oreilles apparaissent avec les textes en gris (wifi barré, compte à rebours, pourcentage) et sans liseré.
7. **Given** une session expirée ou aucun compte connecté, **When** l'encoche est repliée, **Then** l'affichage actuel reste (cadenas + « Sign in » ; compte + « Connect »), sans liseré.

---

### User Story 2 - Voir venir le blocage du coin de l'œil (Priority: P2)

L'utilisateur code, les yeux ailleurs. Au rythme actuel, sa fenêtre de 5 h sera épuisée dans
2 h 05 : un liseré ambre fin apparaît le long du bord inférieur de l'encoche, et une seule donnée
à droite, avec le sablier : « 2h 05m ». À 40 min du blocage, le liseré passe à l'orange, plus
épais, et la donnée devient l'heure du blocage : « 10:06 ». À 8 min, le liseré est rouge avec un
halo. Quand la limite est épuisée, le liseré est rouge plein, « Full » en pastille à gauche, flèche
et temps avant retour à droite. Une limite hebdomadaire qui franchit un seuil obtient aussi son
liseré, avec sa pastille et un libellé court. Dès que le risque disparaît, l'encoche se tait.

**Why this priority**: la couleur en périphérie est le seul signal qui marche sans regarder.
Aujourd'hui la pastille suit un seuil statique, qui se trompe la moitié du temps (83 % à 10 min
du reset n'a aucune importance ; 60 % qui file en 4 h est le vrai danger). Le liseré encode
l'échéance, et c'est elle qui déclenche une décision.

**Independent Test**: en mode démo, états « blocage prévu » à 2 h 05, 40 min et 8 min, bloqué,
hebdo à 97 % : vérifier la couleur, l'épaisseur et le texte de chaque état par rapport à la
planche ; en niveaux de gris, vérifier que les trois paliers restent distincts par l'épaisseur
et le texte.

**Acceptance Scenarios**:

1. **Given** la fenêtre de 5 h à 55 % avec un blocage prévu dans 2 h 05, **When** l'encoche est repliée, **Then** un liseré ambre fin borde le bas de la forme noire, l'aile droite montre un sablier et « 2h 05m » en ambre, l'aile gauche est vide, aucun pourcentage n'est affiché.
2. **Given** un blocage prévu dans 40 min, **When** l'encoche est repliée, **Then** le liseré est orange et plus épais, l'aile droite montre l'heure du blocage (« 10:06 », format du système) en orange.
3. **Given** un blocage prévu dans 8 min, **When** l'encoche est repliée, **Then** le liseré est rouge, plus épais encore, avec un halo, et l'aile droite montre l'heure du blocage en rouge.
4. **Given** la fenêtre de 5 h épuisée, **When** l'encoche est repliée, **Then** le liseré est rouge plein, l'aile gauche montre « Full » (« Bloqué ») en pastille rouge, l'aile droite une flèche circulaire et le temps avant le retour, en rouge.
5. **Given** la limite hebdomadaire à 97 %, seuil critique à 95 %, sans prévision, **When** l'encoche est repliée, **Then** le liseré est rouge, l'aile gauche montre « 7d » (« 7 j ») en gris, l'aile droite « 97 % » en pastille rouge ; à 83 % avec le seuil d'attention à 80 %, liseré et pastille sont ambre.
6. **Given** un état avec liseré qui vient d'apparaître, **When** l'encoche passe de silencieuse à signalante, **Then** les oreilles et le liseré apparaissent en un fondu unique d'environ 600 ms, puis plus rien ne bouge tant que l'état ne change pas.
7. **Given** le rythme ralentit et la prévision repasse à « tenable », **When** l'encoche est repliée, **Then** le liseré et les textes disparaissent et l'encoche redevient silencieuse.
8. **Given** le réglage « Limite affichée » en Automatique, **When** plusieurs limites sont en cause, **Then** le liseré et le texte portent sur la limite la plus susceptible de bloquer, selon la règle existante de la feature 004.
9. **Given** une limite épinglée dans « Limite affichée », **When** une autre limite approche d'un blocage, **Then** le liseré et le texte ne concernent que la limite épinglée ; l'autre reste visible dans le panneau.

---

### User Story 3 - Même comportement partout, y compris sans regarder (Priority: P3)

Sur un écran sans encoche, la pilule disparaît en état calme et réapparaît au survol de sa zone ;
avec un liseré, elle montre la donnée unique. En plein écran, le point d'alerte existant reste et
la fine bande masquée prend la couleur du liseré. VoiceOver trouve l'encoche même silencieuse et
annonce ce que le survol montrerait.

**Why this priority**: la cohérence entre encoche, pilule et plein écran est une exigence des
features 001 et 003 ; l'accessibilité ne doit pas régresser parce que l'app se tait.

**Independent Test**: mode démo en disposition pilule pour chaque état ; plein écran avec un
blocage prévu ; VoiceOver sur l'encoche silencieuse puis signalante.

**Acceptance Scenarios**:

1. **Given** un écran sans encoche en état calme, **When** rien n'est survolé, **Then** aucune pilule n'est dessinée ; **When** le pointeur entre dans la zone de la pilule, **Then** la pilule complète apparaît puis le panneau.
2. **Given** un écran sans encoche avec un blocage prévu dans 40 min, **When** la pilule s'affiche, **Then** elle porte le liseré et la donnée unique (« ⌛ 10:06 »), sans pourcentage.
3. **Given** une app en plein écran et un blocage prévu, **When** l'encoche est masquée, **Then** la fine bande masquée prend la couleur du liseré et le point d'alerte garde son comportement actuel.
4. **Given** VoiceOver actif et l'encoche silencieuse, **When** le focus arrive sur l'encoche, **Then** l'annonce est celle de la bande complète (limite, pourcentage, réinitialisation, prévision).
5. **Given** VoiceOver actif et un liseré, **When** le focus arrive sur l'encoche, **Then** l'annonce comprend la prévision de blocage, comme aujourd'hui.

### Edge Cases

- Prévision indisponible (moins de deux relevés espacés de 10 min) et aucun seuil franchi : état calme, rien n'est dessiné.
- Fenêtre de 5 h au-dessus du seuil d'attention mais rythme « tenable » : silence ; la prévision prime sur le seuil pour la fenêtre de 5 h. Le seuil ne déclenche liseré et pastille que si la prévision est indisponible (moins de deux relevés espacés de 10 min).
- Alertes désactivées dans les réglages : aucun liseré ni pastille de seuil ; le liseré d'échéance (prévision) reste, c'est une information, pas une alerte.
- Blocage prévu dans plus de 5 h : impossible, la prévision est bornée par la réinitialisation de la fenêtre.
- Blocage prévu dans moins d'une minute : l'heure du blocage s'affiche, jamais « 0 min ».
- Prévision qui oscille autour d'un palier (59 min ↔ 61 min) : le texte change de format, la couleur du liseré suit sans animation supplémentaire ; l'hystérésis existante de la prévision limite les allers-retours.
- Limite hebdomadaire épuisée : liseré rouge plein, « Full » et temps avant retour en jours.
- Limite de modèle (Fable) épuisée en Automatique : rien dans l'encoche (règle 004), visible dans le panneau ; épinglée : liseré rouge plein.
- Relevé ancien pendant un état avec liseré : textes en gris, le liseré s'éteint (l'échéance n'est plus sûre).
- Survol pendant un état avec liseré : la bande complète (prévision + pourcentage) remplace la donnée unique, le liseré reste.
- Zone de survol en état calme : la largeur de l'encoche physique seule ; traverser la barre des menus à côté de l'encoche n'ouvre rien. Dès que les oreilles sont visibles, elles font partie de la zone.
- Changement de fond d'écran clair/sombre : le liseré doit rester visible sur les deux ; l'épaisseur minimale est fixée en conséquence.
- Mode réduit d'animations activé dans le système : aucun fondu, apparition immédiate.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'encoche repliée MUST NOT dessiner d'oreilles, de texte ni de liseré quand aucune condition de signalement n'est remplie (état calme) : relevé frais, session valide, aucun blocage prévu, aucune limite au-dessus du seuil d'attention.
- **FR-002**: Les oreilles noires MUST n'exister que pour porter du texte ; l'encoche MUST NOT s'élargir sans texte à afficher, dans aucun état.
- **FR-003**: Le survol de l'encoche MUST faire apparaître la bande complète (aile gauche : prévision ou coche + réinitialisation ; aile droite : pourcentage ou pastille), puis déplier le panneau selon le délai existant ; le clic MUST épingler comme aujourd'hui.
- **FR-004**: Quand un blocage approche, un liseré coloré MUST entourer l'encoche physique (flancs, arrondis et bas, le haut étant le bord de l'écran) ; sa teinte et son épaisseur MUST suivre l'échéance du blocage prévu : ambre fin à 1 h et plus, orange plus épais sous 1 h, rouge épais avec halo sous 30 min, rouge plein quand la limite est épuisée.
- **FR-005**: Dans l'encoche, un état à liseré MUST NOT afficher de texte ni d'oreilles : le liseré borde la seule encoche physique ; les informations (temps avant le blocage, pourcentage) sont celles de la bande complète, au survol. Sur un écran sans encoche, la pilule MUST montrer une seule donnée : sablier + temps avant le blocage (« 2h 05m »), ou heure du blocage sous 1 h (« 10:06 », format du système).
- **FR-006**: Limite épuisée : liseré rouge plein autour de l'encoche ; en pilule, « Full » (« Bloqué ») en pastille rouge puis flèche circulaire + temps avant le retour.
- **FR-007**: Limite au-dessus d'un seuil sans prévision disponible (limites hebdomadaires ; fenêtre de 5 h seulement tant que la prévision est indisponible) : liseré ambre au seuil d'attention, rouge au seuil critique, autour de l'encoche ; en pilule, libellé court de la limite (« 7d » / « 7 j », « 5h » / « 5 h ») puis pastille de pourcentage.
- **FR-007a**: Pour la fenêtre de 5 h, la prévision MUST primer sur le seuil : rythme tenable = silence, quel que soit le pourcentage ; blocage prévu = liseré d'échéance.
- **FR-007b**: En état calme, la zone de survol MUST se limiter à la largeur de l'encoche physique ; les oreilles MUST rejoindre la zone dès qu'elles sont visibles.
- **FR-008**: Le liseré MUST avoir un seul sens, « un blocage approche » ; aucune autre couleur de l'encoche MUST NOT porter ce sens. Cadenas, « Sign in » et textes gris restent sans liseré.
- **FR-009**: Relevé ancien ou dernier relevé en échec : oreilles et textes en gris (wifi barré, compte à rebours, pourcentage), sans liseré.
- **FR-010**: Session expirée et compte non connecté : affichage actuel inchangé, sans liseré.
- **FR-011**: L'entrée dans un état avec liseré MUST se faire par un fondu unique d'environ 600 ms ; aucune animation continue ; le retour au silence MUST se faire par un fondu équivalent ; le mode réduit d'animations du système supprime les fondus.
- **FR-012**: Le réglage « Limite affichée » (feature 004) MUST rester : en Automatique, liseré et donnée unique portent sur la limite la plus susceptible de bloquer ; avec une limite épinglée, ils ne concernent que cette limite.
- **FR-013**: Sur un écran sans encoche, la pilule MUST suivre la même logique : absente en état calme, visible au survol de sa zone, et avec liseré et donnée unique quand un blocage approche.
- **FR-014**: En plein écran, le point d'alerte existant MUST rester ; la fine bande masquée MUST prendre la couleur du liseré quand il est actif.
- **FR-015**: L'encoche MUST rester un élément d'accessibilité même silencieuse ; son annonce MUST être celle de la bande complète, avec la prévision le cas échéant.
- **FR-016**: Chaque palier du liseré MUST rester distinguable sans la couleur : épaisseur et format du texte (durée, puis heure) diffèrent d'un palier à l'autre.
- **FR-017**: Tous les nouveaux textes MUST exister en anglais et en français, vérifiés par le contrôle automatique existant.
- **FR-018**: Le mode démo MUST reproduire chaque état de la planche (section B, 1 à 9) pour les captures et la validation, dans les deux dispositions (encoche, pilule).
- **FR-019**: Les scénarios validés des features 001 à 004 MUST rester valides, sauf ceux que cette spécification remplace explicitement (affichage permanent de la bande).
- **FR-020**: La feature MUST NOT ajouter de requête réseau, de relevé ni de calcul périodique ; le liseré se déduit de la prévision et des seuils existants.

### Key Entities

- **Signal d'encoche**: ce que l'encoche repliée montre sans survol : silence ; liseré d'échéance avec donnée unique ; liseré de seuil avec pastille ; épuisement ; hors ligne ; session expirée ; non connecté. Dérivé de l'état d'affichage existant, jamais stocké.
- **Palier d'échéance**: l'un de quatre niveaux dérivés du temps avant le blocage prévu : lointain (1 h et plus), proche (sous 1 h), imminent (sous 30 min), épuisé. Chaque palier fixe la teinte, l'épaisseur et le format du texte.
- **Bande complète**: l'affichage actuel de la feature 003 (prévision à gauche, pourcentage à droite), désormais réservé au survol, à l'épinglage et à l'accessibilité.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En état calme, 0 pixel dessiné hors de l'encoche physique, vérifié par capture sur fond clair et sur fond sombre.
- **SC-002**: Les 9 états de la section B de la planche sont reproductibles en mode démo, en encoche et en pilule, et leurs captures correspondent à la planche (liseré, teinte, épaisseur, textes), en français et en anglais.
- **SC-003**: En niveaux de gris, 100 % des paliers du liseré (lointain, proche, imminent, épuisé) restent distincts.
- **SC-004**: Le survol fait apparaître la bande complète en moins de 0,2 s et le panneau selon le délai existant, sur 10 essais consécutifs.
- **SC-005**: CPU moyen sous 1 % au repos et dans un état avec liseré, empreinte mémoire inchangée à 2 Mo près par rapport à la version 0.3.0 ; aucun rafraîchissement d'écran hors changement d'état.
- **SC-006**: Le nombre de requêtes réseau par 10 min reste identique à la version 0.3.0.
- **SC-007**: 100 % des nouveaux textes ont une traduction française au moment de la publication, vérifié automatiquement.
- **SC-008**: VoiceOver annonce l'encoche dans 100 % des états, silence compris.

## Assumptions

- La planche `docs/design/notch-pistes-halo.png` (section B et C1) fait foi pour la disposition ; les valeurs exactes d'épaisseur (environ 2, 2,5 et 3 pt) et de teinte sont fixées au plan et vérifiées sur fond clair et sombre.
- Les paliers d'échéance sont trois plus l'épuisement ; une variation continue de la teinte entre paliers est permise mais pas exigée.
- Les seuils d'attention et critique sont ceux des réglages existants (80 % et 95 % par défaut) ; alertes désactivées = aucun liseré ni pastille de seuil, le liseré d'échéance reste.
- La prévision reste limitée à la fenêtre de 5 h (feature 003) ; les limites hebdomadaires ne peuvent déclencher le liseré que par seuil.
- Le relevé ancien (plus de 30 min) éteint le liseré : une échéance calculée sur une donnée périmée ne doit pas alarmer.
- Le panneau déplié, les réglages, les alertes de seuil (rebond, point en plein écran) et les notifications restent ceux des features 001 à 004.
- Le survol, l'épinglage et la fermeture gardent leurs délais et leurs gestes actuels ; la zone sensible en état calme est l'encoche physique (clarification).
- Pour la fenêtre de 5 h, un pourcentage élevé sans blocage prévu n'est pas un signal : le seuil n'est qu'un repli quand la prévision manque (clarification).
- Le libellé court des limites hebdomadaires est « 7d » en anglais et « 7 j » en français ; la limite de modèle épinglée utilise le nom du modèle s'il tient, sinon « 7d ».
