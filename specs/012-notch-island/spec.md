# Feature Specification: Île de chaque côté de l'encoche

**Feature Branch**: `012-notch-island`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Île de chaque côté de l'encoche (logique Dynamic Island), remplace le liseré de la 005. Planche validée : docs/design/notch-island.png, version recommandée « jauge + échéance ». Trois tailles : minimale en état calme […] ; compacte quand un blocage approche […] ; étendue au survol […]. Limite atteinte […]. Limite au seuil sans prévision […]. Hors ligne ou relevé ancien […]. Session expirée […]. Non connecté […]. Oreilles de 52 pt […] ; l'oreille droite n'existe que quand elle porte une donnée. Le liseré autour de l'encoche et son cerne sont retirés. Le battement d'imminence (006) passe sur la jauge […]. La règle « limite la plus menaçante » (008), les notifications, le point plein écran restent. Pilule : même contenu sur une ligne. Transitions : fondu de 0,3 s. Accessibilité : remplissage et donnée sans la couleur ; VoiceOver inchangé. Anglais et français. Budget CPU < 1 % inchangé. Ordre : US1 l'île dans l'encoche, US2 battement sur la jauge et point plein écran, US3 pilule, accessibilité, README et captures."

**Planche de référence** : [docs/design/notch-island.png](../../docs/design/notch-island.png), section « Recommandée : jauge + échéance ».

**Remplace** : le rendu de l'encoche repliée de la [005](../005-silent-notch/spec.md) (silence et liseré). Restent valables : la règle de la limite portée (008), la prévision (003), les paliers de temps (005 : 60 min, 30 min), le rythme du battement (006), les notifications (008), la reconnexion (011).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Lire d'un coup d'œil, comme la Dynamic Island (Priority: P1)

L'utilisateur travaille, l'app tourne. Quand tout va bien, une petite jauge circulaire grise apparaît
dans une oreille noire à gauche de l'encoche : elle montre l'usage de la limite la plus menaçante et
dit, sans texte, que l'app fonctionne. Quand un blocage approche, la jauge prend la couleur de
l'échéance et une oreille droite apparaît avec une seule donnée : le temps avant le blocage. Au
survol, la bande puis le panneau se déplient comme aujourd'hui ; un clic épingle.

**Why this priority**: c'est le changement visible de la feature. Le liseré seul (005) se fondait
dans certains fonds d'écran, ne montrait pas que l'app tournait et ne portait l'urgence que par la
couleur. L'utilisateur veut l'équivalent de la Dynamic Island de son téléphone.

**Independent Test**: en mode démo, chaque état de la table « Contenu par état » ci-dessous, en
encoche, sur fond clair, sombre et orange : contenu, couleur et largeur conformes à la planche.

**Acceptance Scenarios**:

1. **Given** un relevé frais, aucun blocage prévu et aucune limite au seuil, **When** l'encoche est repliée, **Then** une oreille gauche porte une jauge grise remplie à hauteur de l'usage de la limite portée ; aucune oreille droite.
2. **Given** un blocage prévu dans 2 h 05, **Then** jauge ambre et oreille droite « 2:05 » en ambre.
3. **Given** un blocage prévu dans 40 min, **Then** jauge orange et « 40′ » en orange ; dans 8 min, jauge rouge et « 8′ » en rouge.
4. **Given** la limite portée épuisée, **Then** jauge pleine rouge et à droite « ↻ » + temps avant retour, en blanc.
5. **Given** une limite au seuil sans prévision (hebdo à 97 %), **Then** jauge rouge (ambre au seuil d'attention) et à droite le libellé court de la limite (« 7d » / « 7 j », ou le nom du modèle).
6. **Given** un relevé ancien ou un dernier relevé en échec, **Then** glyphe wifi barré gris à gauche et pourcentage gris à droite.
7. **Given** une session expirée, **Then** cadenas à gauche, aucune oreille droite ; le survol ouvre l'écran de reconnexion (« Renouveler la session »). **Given** aucun compte, **Then** glyphe compte à gauche.
8. **Given** n'importe quel état, **When** le pointeur survole l'encoche ou l'utilisateur clique, **Then** bande puis panneau, épinglage, comme avant.
9. **Given** un passage d'un état à un autre, **Then** l'oreille droite apparaît ou disparaît et la largeur change en fondu d'environ 0,3 s ; rien d'autre ne bouge.
10. **Given** n'importe quel état, **Then** aucun liseré ni cerne autour de l'encoche.

---

### User Story 2 - Le battement et le plein écran suivent la jauge (Priority: P2)

Sous 30 min, la jauge bat (double battement de son halo) une fois par minute, toutes les 30 s sous
10 min. En plein écran, le point garde la couleur de la jauge et bat avec elle.

**Why this priority**: le mouvement rattrape l'œil ; il doit passer du liseré, retiré, à la jauge.

**Independent Test**: démo `imminent25` et `imminent` avec `tick` : la jauge bat aux bons ticks ;
`far`, `near`, `blocked`, seuil : jamais ; réduction des animations : jamais.

**Acceptance Scenarios**:

1. **Given** un blocage prévu dans 25 min, **Then** un battement de la jauge par minute ; dans 8 min, un toutes les 30 s.
2. **Given** les autres états, le survol, l'épinglage ou la réduction des animations, **Then** aucun battement.
3. **Given** une app en plein écran et un blocage imminent, **Then** le point rouge bat avec la jauge.

---

### User Story 3 - Pilule, accessibilité, documentation (Priority: P3)

Sur un écran sans encoche, la pilule montre le même contenu sur une ligne (jauge puis donnée). La
jauge et la donnée transmettent l'information sans la couleur. VoiceOver annonce la bande complète
comme aujourd'hui. Le README et ses captures montrent l'île.

**Acceptance Scenarios**:

1. **Given** un écran sans encoche et un blocage prévu dans 40 min, **Then** la pilule montre la jauge orange et « 40′ » ; au calme, la jauge grise seule.
2. **Given** les captures des états en niveaux de gris, **Then** chaque état reste identifiable par le remplissage de la jauge, la donnée de droite ou le glyphe.
3. **Given** VoiceOver sur l'encoche, **Then** l'annonce est celle de la bande complète, dans tous les états.
4. **Given** le README, **Then** la planche des états et l'image principale montrent l'île.

### Edge Cases

- Abonnement sans fenêtre de 5 h : la jauge porte la limite retenue par la règle 008 (la plus utilisée).
- Temps avant blocage de 10 h ou plus : « 10:00 » et au-delà, sans troncature ; au-delà de 24 h il n'y a pas de prévision (fenêtre de 5 h).
- Blocage prévu déjà dépassé (relevé en retard) : « 0′ » en rouge jusqu'au relevé suivant.
- Usage à 0 % : jauge vide grise, toujours visible (l'app tourne).
- Nom de modèle long dans l'oreille droite : tronqué au plus court sans couper la jauge ; la largeur d'oreille ne change pas.
- Alertes par seuil désactivées : une limite au seuil sans prévision ne colore plus la jauge (grise), l'oreille droite disparaît.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'encoche repliée MUST afficher une oreille gauche avec une jauge circulaire de l'usage de la limite portée (règle 008) dans tous les états où un relevé existe.
- **FR-002**: La jauge MUST être grise au calme, colorée par le palier d'échéance quand un blocage est prévu (ambre ≥ 60 min, orange < 60 min, rouge < 30 min), rouge pleine à l'épuisement, colorée par le niveau de seuil sans prévision.
- **FR-003**: Une oreille droite MUST apparaître seulement quand elle porte une donnée : temps avant blocage (h:mm à 60 min et plus, minutes suivies de ′ en dessous), « ↻ » + temps avant retour à l'épuisement, libellé court de la limite au seuil sans prévision, pourcentage gris en relevé ancien.
- **FR-004**: Relevé ancien ou en échec, session expirée, aucun compte : un glyphe gris remplace la jauge (wifi barré, cadenas, compte).
- **FR-005**: Les oreilles MUST faire 52 pt de large, noires, arrondies en bas, collées à l'encoche physique ; la zone de survol suit les oreilles visibles.
- **FR-006**: Le liseré et le cerne autour de l'encoche MUST être retirés.
- **FR-007**: Le survol et le clic MUST garder leur comportement (bande, panneau, épinglage).
- **FR-008**: Le battement d'imminence MUST porter sur la jauge, avec le rythme et les exclusions de la 006.
- **FR-009**: En plein écran, le point MUST garder la couleur de la jauge et battre avec elle.
- **FR-010**: La pilule MUST montrer la jauge et la même donnée sur une ligne ; au calme, la jauge seule.
- **FR-011**: Les changements d'état MUST se faire en fondu d'environ 0,3 s (oreille droite, largeur) ; aucun fondu en réduction des animations.
- **FR-012**: VoiceOver MUST annoncer la bande complète, inchangée ; les textes nouveaux en anglais et en français.
- **FR-013**: Aucune cadence, aucune requête ni aucun rafraîchissement supplémentaires.

### Key Entities

- **Contenu de l'île** : ce que l'encoche repliée montre, dérivé du même signal que la 005 : glyphe ou jauge (valeur 0-100, teinte), donnée de droite (aucune, échéance, retour, libellé, pourcentage), rythme de battement.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Chaque état de la planche est reproduit en démo, capture à l'appui, sur fonds clair, sombre et orange.
- **SC-002**: Au calme, l'île ajoute au plus 52 pt à la largeur de l'encoche ; avec une donnée, au plus 104 pt (contre 144 pt en 003).
- **SC-003**: En niveaux de gris, les 7 états restent distincts (remplissage, donnée, glyphe).
- **SC-004**: Un utilisateur identifie en moins de 2 s, sans survol, si un blocage approche et dans combien de temps.
- **SC-005**: CPU moyen < 1 % sur 10 min en état imminent ; empreinte à ± 2 Mo de la 0.4.2 ; nombre de requêtes identique.
- **SC-006**: 0 texte sans traduction ; annonce VoiceOver identique à la 0.4.2.

## Assumptions

- La jauge montre l'usage de la limite portée, pas le temps restant : le temps est la donnée de droite.
- Les teintes des paliers sont celles de la 005 (#FF9F0A, #FF6A1A, #FF453A) ; le gris est le gris secondaire du système.
- L'oreille gauche au calme est permanente dès qu'un relevé existe : c'est un choix assumé (découvrabilité), qui revient sur la règle 005 « jamais d'oreille sans texte ».
- Les notifications (008) et le bouton de renouvellement (011) ne changent pas.
- Hors champ : réglage pour masquer l'île au calme (à ajouter si l'usage le demande).
