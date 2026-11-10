# Feature Specification: Courbe de la semaine

**Feature Branch**: `021-weekly-curve`

**Created**: 2026-11-10

**Status**: Draft

**Input**: User description: "Courbe de la semaine (021). Planche validée : docs/design/weekly-history.png, variante C1 retenue (C2 barres par jour et C3 carte de chaleur écartées). Dans la carte du survol, sous les limites, une section repliable « Cette semaine » : courbe de l'usage de la limite hebdomadaire depuis le dernier reset, ligne des 100 %, point « maintenant », projection en pointillés au rythme actuel jusqu'au reset, jours en abscisse, pourcentage projeté au reset en en-tête. Prérequis : un relevé par heure pendant 8 jours, en local. Section repliable, état mémorisé ; moins de 2 relevés : « Pas encore assez de relevés ». VoiceOver : une phrase. Textes EN/FR. Courbe à la teinte du palier si la projection dépasse 100 %."

**Planche de référence** : [docs/design/weekly-history.png](../../docs/design/weekly-history.png), variante **C1** retenue par Florent le 2026-11-10. Les variantes C2 (barres par jour) et C3 (carte de chaleur par heure) sont écartées.

**S'appuie sur** :
- la prévision hebdomadaire de la [016](../016-weekly-forecast/spec.md) (rythme moyen depuis le début de la semaine) ;
- la carte détachée de la [019](../019-island-follows-active-bar/spec.md) et le panneau partagé de la [018](../018-no-notch-screen/spec.md) ;
- les teintes de palier de la 005.

## Contexte

La carte affiche la limite hebdomadaire (pourcentage, reset) et, depuis la 016, une phrase de prévision (« À ce rythme (cette semaine) : bloqué jeudi 14:10 » ou « tient jusqu'au reset »). L'utilisateur ne voit pas comment la semaine s'est déroulée, ni de combien il passe sous la limite ou la dépasse. Une courbe répond d'un coup d'œil à « vais-je tenir jusqu'au reset ? » et montre les jours qui ont pesé.

Aujourd'hui, l'app ne garde que deux heures de relevés, ce qui suffit à la prévision de la fenêtre de 5 h. La courbe demande de conserver un relevé par heure sur une semaine.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Voir sa semaine d'un coup d'œil (Priority: P1)

L'utilisateur survole l'encoche ou la pastille. Sous les limites, la section « Cette semaine » montre la courbe de la limite hebdomadaire depuis le dernier reset, jusqu'à maintenant, puis sa projection jusqu'au prochain reset.

**Why this priority** : c'est la feature ; elle prolonge visuellement la prévision de la 016.

**Independent Test** : en mode démo, une semaine fictive (23 % utilisés lundi 16:00, reset jeudi 22:00) produit la courbe de la planche C1, avec « 43 % prévus au reset » en en-tête.

**Acceptance Scenarios** :

1. **Given** des relevés depuis le dernier reset, **When** l'utilisateur ouvre la carte, **Then** la section « Cette semaine » montre une courbe de l'usage hebdomadaire de 0 au pourcentage actuel, du reset à maintenant.
2. **Given** la courbe affichée, **Then** un point marque « maintenant », une ligne en pointillés prolonge la courbe au rythme moyen de la semaine jusqu'au reset, et une ligne rouge marque 100 %.
3. **Given** la courbe affichée, **Then** les jours de la semaine sont en abscisse, le jour courant en gras, et l'en-tête affiche le pourcentage prévu au reset (« 43 % prévus au reset »).
4. **Given** une projection au-delà de 100 %, **Then** la courbe et la projection prennent la teinte du palier correspondant à la prévision (ambre, orange ou rouge, comme l'île), l'en-tête indique le moment prévu du blocage (« bloqué jeudi 14:10 »), et la projection s'arrête à 100 %.
5. **Given** la prévision hebdomadaire de la 016 disponible, **Then** la projection et l'en-tête reprennent exactement ses valeurs (même rythme, même heure de blocage).

---

### User Story 2 - Garder la carte courte (Priority: P2)

La section se replie en une ligne, comme « Avancé » dans les réglages ; l'app se souvient du choix.

**Why this priority** : la carte reste lisible pour qui ne veut pas la courbe.

**Independent Test** : replier la section, fermer puis rouvrir la carte, redémarrer l'app : la section reste repliée.

**Acceptance Scenarios** :

1. **Given** la section dépliée, **When** l'utilisateur clique sur son titre, **Then** elle se replie en une seule ligne qui garde l'en-tête (« Cette semaine · 43 % prévus au reset »).
2. **Given** la section repliée, **When** l'utilisateur rouvre la carte ou relance l'app, **Then** elle est toujours repliée.
3. **Given** un premier lancement, **Then** la section est dépliée.

---

### User Story 3 - Débuts de semaine et données manquantes (Priority: P2)

Juste après un reset, ou à la première installation, il n'y a pas assez de relevés pour une courbe.

**Why this priority** : la section ne doit jamais afficher une courbe trompeuse.

**Independent Test** : vider l'historique puis ouvrir la carte : la section affiche « Pas encore assez de relevés ».

**Acceptance Scenarios** :

1. **Given** moins de 2 relevés depuis le dernier reset, **Then** la section affiche « Pas encore assez de relevés » à la place de la courbe.
2. **Given** des relevés mais pas de prévision (moins de 12 h écoulées depuis le reset, règle de la 016), **Then** la courbe s'affiche sans projection, et l'en-tête montre seulement le pourcentage actuel.
3. **Given** une interruption (Mac en veille une nuit), **Then** la courbe relie les relevés de part et d'autre sans inventer de points ; le palier reste plat pendant l'absence.
4. **Given** un reset qui survient pendant que la carte est ouverte, **Then** la courbe repart à zéro pour la nouvelle semaine.

---

### User Story 4 - Accessibilité, langue, vie privée (Priority: P3)

**Acceptance Scenarios** :

1. **Given** VoiceOver sur la section, **Then** une seule phrase est lue : « Cette semaine : 23 % utilisés, 43 % prévus au reset jeudi à 22:00 » (ou « bloqué prévu jeudi à 14:10 »).
2. **Given** l'interface en anglais ou en français, **Then** aucun texte nouveau n'est sans traduction.
3. **Given** l'utilisateur se déconnecte ou efface les données de l'app, **Then** l'historique hebdomadaire est effacé avec le reste.

### Edge Cases

- **Plusieurs limites hebdomadaires** (toutes modèles, par modèle) : la courbe montre la limite hebdomadaire « toutes modèles ». Les limites par modèle restent en lignes de texte.
- **Abonnement sans limite hebdomadaire** : la section n'apparaît pas.
- **Reset avancé ou déplacé par Anthropic** : la semaine affichée commence au dernier reset connu ; les relevés d'une période précédente sont écartés (même règle de période que l'historique actuel).
- **Horloge du Mac changée ou fuseau horaire différent** : les jours en abscisse suivent le fuseau courant.
- **Carte étroite** (popover ou carte de la pastille) : la courbe occupe la largeur de la carte, sans défilement.
- **Réduire les animations** : aucune animation de la courbe.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** : L'app MUST conserver localement un relevé par heure et par limite, sur 8 jours glissants, en plus de l'historique de deux heures existant. Les relevés d'une période antérieure au dernier reset d'une limite sont écartés pour cette limite.
- **FR-002** : Cet historique MUST rester sur le Mac (aucune connexion nouvelle) et MUST être effacé à la déconnexion et avec les données de l'app (principe I).
- **FR-003** : La carte (île, pastille, popover) MUST afficher sous les limites une section « Cette semaine » pour la limite hebdomadaire toutes modèles.
- **FR-004** : La section MUST tracer l'usage du dernier reset à maintenant, un point « maintenant », la ligne des 100 %, et les jours de la semaine en abscisse (jour courant en gras).
- **FR-005** : Quand la prévision hebdomadaire de la 016 existe, la section MUST tracer sa projection en pointillés jusqu'au reset (ou jusqu'à 100 % en cas de blocage) et afficher en en-tête le pourcentage prévu au reset ou l'heure du blocage, avec exactement les valeurs de cette prévision.
- **FR-006** : Si la projection dépasse 100 %, la courbe et la projection MUST prendre la teinte du palier de la prévision ; sinon la courbe est blanche, la projection blanche à 50 %, la ligne des 100 % rouge.
- **FR-007** : Avec moins de 2 relevés depuis le dernier reset, la section MUST afficher « Pas encore assez de relevés ».
- **FR-008** : La section MUST se replier en une ligne qui garde l'en-tête ; l'état MUST être mémorisé entre les ouvertures et les lancements ; dépliée par défaut.
- **FR-009** : VoiceOver MUST lire la section en une phrase (usage actuel, prévision au reset ou heure du blocage).
- **FR-010** : Tout texte nouveau MUST exister en anglais et en français.
- **FR-011** : Aucun timer nouveau : l'historique s'enrichit aux relevés existants ; la courbe ne se redessine que si ses données changent (principe II).

### Key Entities

- **Relevé horaire** : limite, heure, pourcentage d'usage, heure de reset de la période. Au plus un par heure et par limite, sur 8 jours.
- **Semaine affichée** : relevés de la limite hebdomadaire depuis son dernier reset, usage actuel, prévision de la 016 (pourcentage au reset ou heure du blocage, palier).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : En un regard sur la carte, l'utilisateur sait s'il tiendra jusqu'au reset hebdomadaire, sans lire de phrase.
- **SC-002** : La projection et l'en-tête donnent les mêmes valeurs que la phrase de prévision de la 016 dans 100 % des états du mode démo.
- **SC-003** : L'historique tient en moins de 50 Ko sur disque, et la consommation au repos reste sous 1 % de CPU et 60 Mo de mémoire (principe II).
- **SC-004** : Aucun texte sans traduction ; VoiceOver lit la section en une phrase.

## Assumptions

- La limite hebdomadaire « toutes modèles » est celle qui intéresse le plus ; les limites par modèle gardent leur ligne de texte (YAGNI).
- Un relevé par heure suffit pour une courbe lisible sur 380 pt de large (168 points au plus).
- L'historique part de l'installation de cette version : la première semaine est partielle, la courbe commence au premier relevé conservé.
- Le rythme de projection est celui de la 016 (moyenne depuis le début de la semaine, nuits comprises) ; aucun nouveau modèle de prévision.
- Hors périmètre : barres par jour, carte de chaleur, historique au-delà de 8 jours, export.
