# Feature Specification: Écran sans encoche

**Feature Branch**: `018-no-notch-screen`

**Created**: 2026-11-09

**Status**: Draft

**Input**: User description: "Écran sans encoche (018). Suivre l'usage sur un écran sans encoche (écran externe, capot fermé) sans imiter l'encoche. Planche validée : docs/design/external-screen.html (+ .png), combinaison retenue A + C′. Règle d'écran : l'île (012) s'affiche sur l'écran qui a une encoche et nulle part ailleurs ; le mode pilule actuel est retiré. A, socle : l'item de barre de menus (014) s'enrichit […]. C′, option : pastille de 18 pt centrée dans la barre de menus, contenue dans sa hauteur […]. Écartées : pilule, languette de coin C, languette latérale, widget de bureau."

**Planche de référence** : [docs/design/external-screen.png](../../docs/design/external-screen.png), sections « Quel écran porte quoi », « A. Barre de menus enrichie » et « C′. Pastille centrée ». Les sections « C. Languette de coin » et « Écartées » (pilule, languette latérale, widget de bureau) ne sont pas retenues.

**Spike préalable** : vérifier que l'écran qui porte l'item de barre de menus « réel » suit la barre de menus active, et que ce changement est notifié sans polling. Sinon, repli : l'item est enrichi partout (voir FR-022). **Résultat (2026-11-09)** : confirmé, voir [spike-statusitem.md](spike-statusitem.md).

**S'appuie sur** : l'île de la [012](../012-notch-island/spec.md), l'icône de barre de menus de la [014](../014-logo-menubar/spec.md), le temps restant avant blocage (003, 015, 016), le battement et le point plein écran de la 006, la limite portée (008), le signal Claude de la [017](../017-claude-attention/spec.md). Rien ne change sur l'écran à encoche.

## Contexte

Aujourd'hui, l'app ne vit que sur l'écran de la barre de menus principale. Si cet écran n'a pas d'encoche (écran externe principal, capot fermé), elle affiche une pilule noire centrée qui imite une encoche absente. Si l'écran externe est secondaire, il n'affiche rien. Un utilisateur qui travaille sur un grand écran externe perd donc le suivi de sa limite et le signal Claude, ou reçoit une imitation de matériel qui mord sur la barre de menus.

L'écran sans encoche offre deux supports natifs : **la barre de menus**, présente sur chaque écran, et **son centre**, presque toujours libre sur un écran large. La feature s'y installe, en reprenant la grammaire de la 012 et de la 017 (la jauge à gauche dit « où j'en suis », le chiffre ou le glyphe à droite dit « ce qui arrive ») avec les mêmes teintes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Suivre l'usage depuis la barre de menus de n'importe quel écran (Priority: P1)

L'utilisateur travaille sur un écran externe, capot fermé ou ouvert. Dans la barre de menus de cet écran, l'item de l'app affiche l'anneau d'usage et le pourcentage de la limite portée. Quand un blocage approche, l'anneau prend la couleur du palier et le texte devient le temps restant avant blocage. Quand une session Claude attend, son glyphe s'ajoute à droite de la jauge. Un clic ouvre, sous l'item, le même contenu que le panneau déplié de l'île.

**Why this priority**: c'est le socle. Il marche sur tous les écrans, sans calcul de position, sans permission, et il couvre seul le cas « capot fermé ». Sans les autres histoires, l'utilisateur n'est plus jamais aveugle.

**Independent Test**: en mode démo, un écran externe (ou un Mac sans encoche) : chaque état du tableau « Contenu par état » apparaît dans la barre de menus ; le clic ouvre le popover avec les limites et les sessions Claude.

**Acceptance Scenarios**:

1. **Given** un écran sans encoche et la limite 5 h à 42 %, **When** l'utilisateur regarde la barre de menus, **Then** l'item affiche l'anneau monochrome à 42 % suivi de « 42 % », dans la couleur de la barre (blanc sur barre sombre, noir sur barre claire).
2. **Given** un blocage prévu dans 2 h 05 (palier ambre), **Then** l'anneau est ambre et le texte affiche « 2:05 » en couleur de la barre.
3. **Given** un blocage prévu dans 8 min, **Then** l'anneau est rouge et bat (006), le texte « 8′ » est rouge ; avec « Réduire les animations », l'anneau ne bat pas.
4. **Given** deux sessions Claude qui attendent une approbation, **Then** le glyphe main levée violet et le nombre « 2 » suivent la jauge ; à l'arrivée d'un nouveau signal, le mot (« Approbation », « Question », « Terminé ») s'affiche 4 s puis disparaît.
5. **Given** une barre de menus claire, **Then** le violet devient #A43BD6 ; l'ambre, l'orange et le rouge ne changent pas.
6. **Given** l'item affiché, **When** l'utilisateur clique dessus, **Then** un popover s'ouvre sous l'item avec le même contenu que le panneau déplié de l'île (sessions Claude, limites, prévision) et, en bas, Actualiser, Réglages et Quitter ; un clic droit ouvre ces trois commandes en menu.
7. **Given** le popover ouvert, **When** l'utilisateur clique ailleurs ou appuie sur Échap, **Then** il se ferme.
8. **Given** l'app sans relevé (non connectée, erreur), **Then** l'item affiche l'anneau vide sans texte, et le popover affiche l'écran de connexion ou l'erreur, comme l'île.
9. **Given** un MacBook à encoche et un écran externe, **When** l'utilisateur travaille sur le MacBook (barre de menus active sur l'écran à encoche), **Then** l'item est compact (anneau seul, comme la 014), l'île portant le détail ; **When** il passe sur l'écran externe, **Then** l'item s'enrichit en moins d'une seconde.

---

### User Story 2 - L'île sur l'écran à encoche, et nulle part ailleurs (Priority: P1)

Le MacBook est ouvert, un écran externe est branché. L'île reste sur l'écran intégré, quelle que soit la barre de menus principale. L'écran externe n'affiche jamais de fausse encoche. Capot fermé, il n'y a plus d'île du tout.

**Why this priority**: c'est la règle qui retire la pilule et évite deux affichages concurrents. Elle va de pair avec US1 : sans US1, retirer la pilule laisserait l'écran externe vide.

**Independent Test**: brancher et débrancher un écran, changer l'écran principal dans Réglages Système, fermer le capot : l'île suit l'écran à encoche, et aucune pilule n'apparaît jamais.

**Acceptance Scenarios**:

1. **Given** un MacBook à encoche et un écran externe défini comme principal, **Then** l'île s'affiche sur l'écran du MacBook, et rien de noir n'apparaît en haut de l'écran externe.
2. **Given** le capot fermé (écran externe seul), **Then** aucune île ni pilule ; l'item de barre de menus (US1) porte le suivi.
3. **Given** un Mac sans aucun écran à encoche (Mac mini, iMac, MacBook sans encoche), **Then** aucune île ni pilule ; l'item de barre de menus porte le suivi.
4. **Given** le capot qui se rouvre, **Then** l'île réapparaît sur l'écran intégré dans les 2 s.

---

### User Story 3 - La pastille centrée, en option, sur les écrans larges (Priority: P2)

L'utilisateur active « Pastille centrée » dans les réglages. Sur chaque écran sans encoche assez large, une capsule s'affiche au centre de la barre de menus, contenue dans sa hauteur, dans le matériau de la barre. Elle porte la jauge à gauche et l'attente Claude à droite. Au survol, une carte flotte sous la barre avec le même contenu que le panneau de l'île.

**Why this priority**: elle apporte la lecture « d'un coup d'œil » au centre de l'écran, là où le regard va. Mais l'item de US1 suffit déjà, et elle a une limite (collision avec les menus).

**Independent Test**: option activée, en mode démo, sur un écran externe de 1920 pt et plus : chaque état de la section C′ de la planche ; sur un écran de 1440 pt, pas de pastille et l'item de US1 est présent.

**Acceptance Scenarios**:

1. **Given** l'option activée, un écran sans encoche de 1920 pt de large, la limite à 42 %, **Then** une capsule de 18 pt de haut est centrée dans la barre de menus, sans dépasser sous la barre, et affiche l'anneau et « 42 % ».
2. **Given** une session qui demande une approbation, **Then** la capsule s'élargit des deux côtés à la fois : jauge, filet, glyphe main levée et mot « Approbation » pendant 4 s, puis glyphe seul (et nombre s'il y a plusieurs sessions).
3. **Given** un blocage prévu dans 2 h 05 et une session en attente, **Then** la capsule affiche à la fois « 2:05 » en ambre et le glyphe Claude.
4. **Given** un blocage prévu dans 8 min, **Then** le fond de la capsule passe au rouge léger, la jauge bat, le texte « 8′ » est rouge, et Claude se réduit à un point violet sur la jauge (règle de la 017). C'est le seul état où le fond se colore.
5. **Given** une barre de menus claire, **Then** la capsule est un voile sombre et son texte est noir.
6. **Given** la capsule affichée, **When** le pointeur la survole 0,15 s, **Then** elle s'éclaire et une carte apparaît 6 pt sous la barre, arrondie sur ses quatre coins, sans toucher la capsule ; la carte se ferme quand le pointeur quitte la capsule et la carte.
7. **Given** l'option activée sur un écran de moins de 1700 pt de large, **Then** aucune pastille sur cet écran ; l'item de US1 reste le seul affichage.
8. **Given** une app en plein écran sur un écran sans encoche, **Then** la capsule disparaît avec la barre de menus et rien ne la remplace, comme l'île depuis la 016 ; le signal attend la sortie du plein écran.
9. **Given** l'option désactivée, **Then** aucune pastille sur les écrans sans encoche.

---

### User Story 4 - Réglages, accessibilité, documentation (Priority: P3)

L'utilisateur choisit dans les réglages quand l'item de barre de menus s'affiche, et s'il veut la pastille centrée. VoiceOver lit l'item et la pastille comme il lit l'île. Le README montre les deux affichages.

**Why this priority**: finitions et cohérence avec les réglages de la 013 et la 014.

**Independent Test**: changer chaque réglage et vérifier l'effet immédiat ; VoiceOver sur l'item et sur la pastille.

**Acceptance Scenarios**:

1. **Given** le réglage « Icône de barre de menus » sur « Automatique » (défaut), **When** un écran sans encoche est connecté, **Then** l'item s'affiche ; **When** il ne reste que des écrans à encoche, **Then** l'item disparaît.
2. **Given** le réglage sur « Toujours » ou « Jamais », **Then** l'item s'affiche toujours, ou jamais, quel que soit l'écran.
3. **Given** un utilisateur qui avait activé l'icône de la 014, **When** il met à jour l'app, **Then** son réglage devient « Toujours » ; sinon « Automatique ».
4. **Given** VoiceOver sur l'item ou sur la pastille, **Then** l'annonce est celle de l'île : sessions en attente d'abord, puis la limite et le temps restant.
5. **Given** l'interface en anglais ou en français, **Then** aucun texte nouveau sans traduction.

---

### Edge Cases

- **Écran principal changé à chaud** : l'île reste sur l'écran à encoche ; l'item de barre de menus est présent sur chaque barre, géré par macOS.
- **Écran à encoche en écran secondaire** : l'île s'y affiche, même si la barre de menus principale est ailleurs.
- **Barre de menus trop pleine** : macOS peut masquer l'item ; la pastille (si activée et si l'écran est assez large) reste le relais. Sans pastille, c'est une limite connue de macOS, documentée.
- **Masquage automatique de la barre de menus** : l'item et la pastille ne sont visibles que quand la barre l'est.
- **Menus d'app qui atteignent le centre sur un écran de 1700 pt ou plus** : la capsule peut chevaucher le dernier menu ; c'est accepté, puisqu'on ne lit pas l'étendue des menus (voir Hypothèses).
- **Plusieurs écrans sans encoche** : une pastille par écran assez large ; un seul popover ou une seule carte ouverte à la fois.
- **Popover ouvert pendant un changement d'écran** : il se ferme.
- **Taille de l'item** : l'item ne dépasse jamais l'équivalent de « jauge + 2:05 + glyphe + nombre » ; le mot d'arrivée s'affiche dans le popover, pas dans l'item, si la barre est étroite.
- **Popover et île ouverts en même temps** : ouvrir l'un ferme l'autre.
- **Réplique de l'item sur la barre inactive** : macOS y affiche une copie de l'item actif. Quand l'utilisateur travaille sur le MacBook, l'écran externe montre donc l'item compact ; c'est accepté, le regard est sur l'île.
- **Aucun doublon voulu** : l'utilisateur peut régler l'icône sur « Jamais » et activer la pastille ; l'écran externe n'est alors couvert que s'il fait au moins 1700 pt et que sa barre est visible.

## Requirements *(mandatory)*

### Functional Requirements

**Règle d'écran**

- **FR-001**: L'île (012) MUST s'afficher sur l'écran qui a une encoche, qu'il porte ou non la barre de menus principale, et sur aucun autre écran.
- **FR-002**: Le mode pilule MUST être retiré : aucun écran ne doit afficher de forme noire imitant une encoche.
- **FR-003**: S'il y a plusieurs écrans à encoche (cas théorique), l'île s'affiche sur celui qui porte la barre de menus principale, sinon sur le premier.

**A. Item de barre de menus enrichi**

- **FR-004**: L'item MUST afficher l'anneau d'usage de la limite portée (008) suivi d'un texte : le pourcentage au calme, le temps restant avant blocage dès qu'un palier est atteint (même règle et même format que l'oreille droite de la 012).
- **FR-005**: Au calme, l'anneau et le texte MUST suivre l'apparence de la barre de menus (monochrome). À partir d'un palier, l'anneau MUST prendre la couleur du palier ; le texte reste monochrome, sauf à l'imminence (rouge).
- **FR-006**: À l'imminence, l'anneau MUST battre comme dans la 006 ; avec « Réduire les animations », il ne bat pas.
- **FR-007**: Quand une session Claude attend (017), l'item MUST ajouter à droite de la jauge le glyphe du cas le plus pressant et, au-delà d'une session, leur nombre ; le mot d'arrivée MUST s'afficher 4 s puis disparaître ; la règle de priorité face à la limite de la 017 s'applique.
- **FR-008**: Sur une barre claire, le violet MUST être #A43BD6 ; sur une barre sombre, #BF5AF2.
- **FR-009**: Un clic sur l'item MUST ouvrir sous lui un popover dont le contenu est celui du panneau déplié de l'île (mêmes sections, mêmes interactions), avec Actualiser, Réglages et Quitter en bas ; un clic droit MUST ouvrir ces trois commandes en menu.
- **FR-022**: L'item MUST être compact (anneau seul, sans texte ni glyphe, comme la 014) quand la barre de menus active est celle d'un écran à encoche, et enrichi (FR-004 à FR-008) quand elle est celle d'un écran sans encoche ; le passage de l'un à l'autre MUST se faire en moins d'une seconde et sans polling. Si le spike montre que ce n'est pas possible, l'item est enrichi sur toutes les barres.
- **FR-010**: Le popover MUST se fermer au clic extérieur, à Échap, à un changement de configuration d'écran, et à l'ouverture de l'île.

**C′. Pastille centrée**

- **FR-011**: Option « Pastille centrée », désactivée par défaut, persistée.
- **FR-012**: Option activée, chaque écran sans encoche d'au moins 1700 pt de large MUST afficher une capsule centrée horizontalement dans la barre de menus, haute de 18 pt, entièrement contenue dans la hauteur de la barre.
- **FR-013**: La capsule MUST suivre l'apparence de la barre (voile clair sur barre sombre, voile sombre sur barre claire) ; son fond ne se colore qu'à l'imminence (rouge léger).
- **FR-014**: La capsule MUST porter la jauge et son texte à gauche (mêmes règles que FR-004 à FR-006) et l'attente Claude à droite (mêmes règles que FR-007 et FR-008), séparées par un filet ; elle MUST s'élargir et se rétrécir symétriquement autour du centre de l'écran.
- **FR-015**: Au survol de 0,15 s, la capsule MUST s'éclairer et une carte MUST apparaître 6 pt sous la barre, centrée, arrondie sur ses quatre coins, avec le contenu de FR-009 ; elle MUST se fermer 0,10 s après la sortie du pointeur de la capsule et de la carte, ou à Échap.
- **FR-016**: Sur un écran de moins de 1700 pt de large, aucune capsule ne MUST s'afficher.
- **FR-017**: En plein écran sur un écran sans encoche, la capsule MUST disparaître avec la barre de menus, sans rien à sa place (aligné sur la 016 : plus de point plein écran, mis à jour le 2026-11-09).

**Réglages, accessibilité, langue**

- **FR-018**: Le réglage de l'icône de barre de menus (014) MUST devenir un choix à trois valeurs : Automatique (défaut : visible tant qu'au moins un écran sans encoche est connecté), Toujours, Jamais. Un utilisateur qui l'avait activé passe à Toujours.
- **FR-019**: VoiceOver MUST annoncer l'item et la capsule avec le même texte que l'île (sessions en attente, puis limite et temps restant).
- **FR-020**: Tout texte nouveau MUST exister en anglais et en français.
- **FR-021**: Aucun relevé réseau, timer ni polling supplémentaire : l'item et la capsule se redessinent seulement quand l'état affiché change.

### Key Entities

- **Rôle d'écran** : pour chaque écran connecté, « à encoche » (porte l'île) ou « sans encoche » (porte la capsule si l'option est activée et si l'écran fait au moins 1700 pt), recalculé à chaque changement de configuration.
- **Contenu d'affichage** : l'état déjà calculé pour l'île (jauge, palier, texte, signal Claude), partagé tel quel par l'île, l'item et la capsule.
- **Réglage d'icône** : Automatique, Toujours ou Jamais.
- **Réglage de pastille** : activé ou non.

## Contenu par état

| État | Item de barre de menus (A) | Capsule centrée (C′) |
|---|---|---|
| Barre active sur l'écran à encoche | anneau seul (014), quel que soit l'état | sans objet |
| Calme, 42 % | anneau monochrome + « 42 % » | anneau + « 42 % » |
| Palier, blocage dans 2 h 05 | anneau ambre + « 2:05 » | anneau ambre + « 2:05 » ambre |
| Imminent, 8 min | anneau rouge battant + « 8′ » rouge | fond rouge léger, anneau battant, « 8′ » rouge, point violet si Claude attend |
| Claude attend (2 approbations) | jauge + main violette + « 2 » | jauge, filet, main violette + « 2 » |
| Arrivée d'un signal Claude | + mot 4 s | + mot 4 s, élargissement symétrique |
| Sans relevé | anneau vide | anneau vide |
| Plein écran | invisible (barre masquée) | invisible (016) |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Dans 100 % des configurations testées (MacBook seul, MacBook + externe principal, MacBook + externe secondaire, capot fermé, Mac sans encoche), l'utilisateur voit sa limite sans ouvrir de fenêtre, et aucune forme imitant une encoche n'apparaît.
- **SC-002**: Après un branchement, un débranchement ou la fermeture du capot, l'affichage est correct en moins de 2 s.
- **SC-003**: L'utilisateur lit le pourcentage ou le temps restant sur l'écran externe en un regard, sans clic.
- **SC-004**: Au repos, avec l'item et la capsule affichés, la consommation CPU reste sous 1 % et l'empreinte mémoire sous 60 Mo (principe II).
- **SC-005**: Le contenu du popover et de la carte est identique à celui du panneau de l'île dans tous les états du mode démo.
- **SC-006**: Aucun texte sans traduction ; VoiceOver annonce l'item et la capsule dans le même ordre que l'île.

## Assumptions

- macOS affiche les items de barre de menus sur la barre de chaque écran (réglage par défaut « Les écrans disposent d'espaces distincts ») : l'item réel sur la barre active, une réplique sur les autres. On ne peut pas dessiner deux versions en même temps ; l'item s'adapte donc à la barre active (FR-022) pour éviter de doubler l'île.
- La largeur de l'écran est le seul critère de collision avec les menus : lire l'étendue des menus des apps demanderait la permission Accessibilité, refusée pour ce besoin. Le seuil de 1700 pt pourra être ajusté au vu des essais.
- Le réglage « Automatique » change le défaut de la 014 (icône désactivée par défaut) : sans lui, un utilisateur capot fermé n'aurait plus aucun affichage une fois la pilule retirée.
- Le panneau déplié est réutilisé tel quel dans le popover et la carte ; aucun contenu propre aux écrans sans encoche.
- Pas de nouvelle connexion réseau, de nouvelle permission ni de nouvel entitlement.
- Hors périmètre : languette de coin, languette latérale, widget de bureau, affichage sur les écrans à encoche autre que l'île.
