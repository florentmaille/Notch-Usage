# Feature Specification: Battement d'imminence

**Feature Branch**: `006-imminence-pulse`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Battement d'imminence : rappel périodique par le liseré quand un blocage est imminent. Contexte : depuis la 005, l'encoche repliée est silencieuse en état calme et montre un liseré coloré autour de l'encoche physique quand un blocage approche […] ; le liseré est statique après un fondu d'entrée de 600 ms. Un liseré immobile finit par faire partie du décor : la vision périphérique capte le mouvement, pas une couleur. Nouveau comportement : quand le palier est « imminent » (blocage prévu dans moins de 30 min), le halo du liseré respire une fois par minute (opacité du halo 0,6 → 1 → 0,6 en environ 600 ms), puis une fois toutes les 30 s sous 10 min ; aucun changement de taille, d'épaisseur, ni de largeur de l'encoche […]. Aucun battement pour les paliers lointain, proche et épuisé, ni quand le signal vient d'un seuil sans prévision […]. La pilule suit la même règle […]. Au survol et quand le panneau est épinglé, pas de battement. En mode « réduire les animations », aucun battement […]. Le battement se cale sur le tick minute déjà existant […] ; aucun timer ni rafraîchissement supplémentaire, budget CPU moyen inchangé (< 1 %) et aucune requête réseau supplémentaire. Aucun réglage […]. Anglais et français : aucun texte nouveau. VoiceOver : annonces inchangées. Mode démo : […] un état « imminent25 » (blocage dans 25 min) pour le rythme 60 s. Une seule user story […]."

**Référence** : [specs/005-silent-notch/spec.md](../005-silent-notch/spec.md) (paliers du liseré, FR-003 à FR-006, FR-011) et son contrat [notch-signal.md](../005-silent-notch/contracts/notch-signal.md).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Être rattrapé du coin de l'œil quand le blocage est imminent (Priority: P1)

L'utilisateur code, les yeux dans son éditeur. Au rythme actuel, sa fenêtre de 5 h sera épuisée
dans 25 min : depuis la 005, un liseré rouge avec halo entoure l'encoche, mais il est immobile et
s'est fondu dans le décor au bout de quelques secondes. Désormais, une fois par minute, le halo
respire : il s'intensifie puis revient à son niveau en un peu plus d'une demi-seconde. Le mouvement
suffit à la vision périphérique ; l'utilisateur lève les yeux, voit le rouge, et décide (pause,
changement de modèle, survol pour l'heure exacte). Sous 10 min, la respiration passe à une toutes
les 30 s. Dès que le blocage n'est plus imminent (prévision revenue au-dessus de 30 min, limite
réinitialisée, ou limite épuisée), le liseré redevient immobile ou disparaît, selon la 005.

À aucun autre moment l'encoche ne bouge : ni en ambre, ni en orange, ni une fois bloqué, ni quand
le rouge vient d'un seuil sans prévision, ni au survol, ni avec le panneau épinglé, ni quand le
système demande de réduire les animations.

**Why this priority**: c'est la seule story. Elle corrige la faiblesse connue d'un signal statique
(FR-011 de la 005 interdisait toute animation continue par prudence sur le budget) en la limitant
au seul palier où une action de l'utilisateur change encore quelque chose.

**Independent Test**: en mode démo, état `imminent25` : un battement visible à chaque minute,
rien entre deux ; état `imminent` (8 min) : un battement toutes les 30 s ; états `far`, `near`,
`blocked`, `critical` (seuil 97 % avec blocage prévu à 50 min, donc orange) et `warning` : aucun
mouvement en 3 min d'observation. Survol pendant `imminent` : aucun battement tant que le pointeur
est dessus. Réduire les animations activé : aucun battement en `imminent`.

**Acceptance Scenarios**:

1. **Given** un blocage prévu dans 25 min sur la limite affichée (liseré rouge avec halo), **When** l'encoche est repliée et non survolée, **Then** le halo respire une fois par minute (montée puis retour en environ 600 ms) et reste immobile entre deux ; le trait, l'épaisseur, la forme et la largeur de l'encoche ne changent pas.
2. **Given** un blocage prévu dans 8 min, **When** l'encoche est repliée et non survolée, **Then** le halo respire une fois toutes les 30 s.
3. **Given** un blocage prévu dans 25 min, **When** la prévision passe sous 10 min, **Then** le rythme passe à 30 s sans autre changement visible ; **When** elle repasse au-dessus de 30 min, **Then** le battement cesse et le liseré suit la 005 (orange ou ambre, immobile).
4. **Given** un liseré ambre (blocage à 2 h) ou orange (blocage à 40 min), **When** 3 min s'écoulent, **Then** aucun mouvement.
5. **Given** une limite épuisée (liseré rouge plein), **When** 3 min s'écoulent, **Then** aucun mouvement.
6. **Given** une limite hebdomadaire au seuil critique sans prévision (liseré rouge statique de la 005), **When** 3 min s'écoulent, **Then** aucun mouvement.
7. **Given** un blocage prévu dans 8 min, **When** le pointeur survole l'encoche ou le panneau est épinglé, **Then** aucun battement pendant tout le survol ou l'épinglage ; **When** le pointeur sort ou le panneau est désépinglé, **Then** le battement reprend au prochain tick.
8. **Given** le mode « réduire les animations » du système activé et un blocage prévu dans 8 min, **When** l'encoche est repliée, **Then** le liseré rouge avec halo est présent et immobile.
9. **Given** un écran sans encoche (pilule) et un blocage prévu dans 8 min, **When** la pilule est visible, **Then** son halo respire au même rythme et selon les mêmes exclusions.
10. **Given** un blocage prévu dans 8 min, **When** VoiceOver lit l'encoche, **Then** l'annonce est celle de la 005, inchangée ; le battement n'est pas annoncé.

---

### Edge Cases

- Prévision qui oscille autour de 30 min ou de 10 min : le rythme suit la valeur au moment du tick ; aucune hystérésis propre au battement (l'hystérésis de la prévision, 003, suffit : deux relevés consécutifs).
- Un battement en cours quand l'état change (survol, retour au calme, épuisement) : le battement termine sa demi-seconde, puis la règle de l'état suivant s'applique ; pas de battement coupé net.
- Le tick minute tombe pendant le fondu d'entrée du liseré (600 ms) : pas de battement superposé au fondu ; le premier battement attend le tick suivant.
- Mac en veille, écran verrouillé, mode économie d'énergie : le battement suit le tick de la vue, lui-même suspendu avec l'affichage ; au réveil, aucun rattrapage des battements manqués.
- Relevé ancien ou en échec pendant un état imminent : la 005 bascule la bande en gris sans liseré ; aucun battement.
- Limite épinglée dans les réglages : le battement porte sur la limite affichée, comme le liseré (004, 005).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'encoche MUST faire respirer le halo du liseré (intensité qui monte puis revient, durée d'environ 600 ms) quand le palier du liseré est « imminent » au sens de la 005 (blocage prévu dans moins de 30 min sur la limite affichée).
- **FR-002**: Le rythme MUST être d'un battement par minute entre 30 min et 10 min avant le blocage prévu, et d'un battement toutes les 30 s sous 10 min.
- **FR-003**: Un battement MUST ne changer que l'intensité du halo : trait, épaisseur, teinte, forme et largeur de l'encoche ou de la pilule restent identiques pendant et après le battement.
- **FR-004**: Aucun battement MUST NOT se produire pour les paliers lointain, proche et épuisé, ni quand le liseré rouge vient d'un seuil critique sans prévision.
- **FR-005**: Aucun battement MUST NOT se produire pendant le survol de l'encoche ni quand le panneau est épinglé.
- **FR-006**: Quand le système demande de réduire les animations, aucun battement MUST NOT se produire ; le liseré reste celui de la 005, immobile.
- **FR-007**: La pilule (écran sans encoche) MUST suivre les mêmes règles que l'encoche pour son halo.
- **FR-008**: Le battement MUST se caler sur le rafraîchissement périodique déjà existant de l'affichage replié ; aucune cadence, aucun rafraîchissement ni aucune requête réseau supplémentaires.
- **FR-009**: Aucun réglage MUST NOT être ajouté ; la règle est fixe.
- **FR-010**: Aucun texte nouveau ; les annonces d'accessibilité restent celles de la 005.
- **FR-011**: Le mode démo MUST offrir un état « blocage prévu dans 25 min » (`imminent25`) pour valider le rythme d'une minute ; l'état `imminent` existant (8 min) valide le rythme de 30 s.

### Key Entities

- **Rythme de battement** : dérivé du palier du liseré et du temps avant le blocage prévu : aucun (par défaut), une minute (imminent, 30 à 10 min), trente secondes (imminent, sous 10 min). Calculé en même temps que le signal de l'encoche (005), à partir des mêmes entrées.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En état imminent à 25 min, un observateur compte exactement 3 battements en 3 min, à 1 min d'intervalle (± 5 s, la tolérance du rafraîchissement périodique) ; à 8 min, 6 battements en 3 min.
- **SC-002**: En états lointain, proche, épuisé, seuil sans prévision, survol, épinglé et réduction des animations, un observateur ne voit aucun mouvement en 3 min.
- **SC-003**: Pendant un battement, la capture de l'encoche ne diffère de la capture immobile que par l'intensité du halo : mêmes dimensions, même trait, même teinte.
- **SC-004**: Le battement est perçu sans regarder l'encoche : vu depuis le centre de l'écran, l'observateur remarque le mouvement sans qu'on le lui signale (test à l'œil, 3 essais sur 3).
- **SC-005**: Consommation moyenne inchangée : CPU < 1 % sur 10 min en état imminent à 8 min, empreinte mémoire à ± 1 Mo de la 0.4.0, nombre de requêtes identique à la 0.4.0.
- **SC-006**: Aucun texte sans traduction ; VoiceOver annonce la même phrase qu'en 0.4.0.

## Assumptions

- Les paliers, teintes, épaisseurs et le halo sont ceux de la 005 ; cette feature n'en change aucun.
- « Imminent » couvre uniquement un blocage prévu par la prévision (003) ; le seuil critique à 95 % sans prévision donne un rouge statique et reste hors champ.
- La respiration va de l'intensité normale du halo à son maximum et retour ; elle ne s'éteint jamais complètement, pour qu'un regard posé à n'importe quel instant voie le liseré.
- Le rafraîchissement périodique de la vue repliée (celui qui met à jour les comptes à rebours) bat toutes les 30 s, à 5 s près ; le rythme de 30 s s'obtient en battant à chaque rafraîchissement, celui d'une minute un rafraîchissement sur deux, sans nouvelle horloge.
- Un seul rythme à la fois ; le passage d'un rythme à l'autre n'est pas animé.
- Hors champ : son, notification système, battement du point d'alerte en plein écran (inchangé, 001), battement dans le panneau déplié.
