# Feature Specification: Limites d'abonnement Claude dans l'encoche

**Feature Branch**: `001-claude-usage-notch`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Afficher dans l'encoche du Mac la consommation de l'abonnement
Claude (Pro/Max) : % utilisé de la fenêtre de 5 h, de la limite hebdomadaire et des limites
propres à certains modèles (type Fable), avec l'heure de réinitialisation. Vue compacte en
permanence, vue dépliée au survol ou au clic (un avatar viendra plus tard). Sur un écran sans
encoche, une fausse encoche en haut de l'écran. Alertes à 80 % et 95 %."

## Clarifications

### Session 2026-11-01

- Q: Comment l'utilisateur connecte-t-il son compte Claude à l'app ? → A: Les deux voies :
  réutilisation de la session Claude Code si elle existe, sinon connexion dans le navigateur.
- Q: Le survol de l'encoche suffit-il à ouvrir le panneau déplié, ou faut-il cliquer ? → A: Le
  survol ouvre, le clic épingle.
- Q: Que fait l'affichage quand une app est en plein écran ? → A: Masqué, sauf au survol du
  haut de l'écran. Les alertes restent visibles sous forme d'un point discret.
- Q: Dans quelle langue l'interface est-elle affichée ? → A: Anglais pour le MVP, textes
  préparés pour la traduction. Le français vient dans une feature suivante.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Voir ses limites Claude d'un coup d'œil (Priority: P1)

Un abonné Claude Pro ou Max connecte son compte une fois. Ensuite, une mini-jauge reste
visible en permanence à côté de l'encoche et indique le pourcentage utilisé de la limite
la plus contraignante. Quand il survole ou clique sur l'encoche, un panneau s'ouvre avec le
détail : la fenêtre glissante de 5 h, la limite hebdomadaire tous modèles, chaque limite
hebdomadaire propre à un modèle (par exemple Fable), et pour chacune le pourcentage utilisé
et l'heure de réinitialisation.

**Why this priority**: c'est la raison d'être de l'app. L'utilisateur sait sans changer de
contexte s'il peut lancer une longue session ou s'il va être bloqué.

**Independent Test**: connecter un compte Pro/Max, vérifier que la jauge compacte apparaît,
puis ouvrir le panneau et comparer les valeurs à celles de la page d'usage officielle de Claude.

**Acceptance Scenarios**:

1. **Given** l'app est installée et aucun compte n'est connecté, **When** l'utilisateur
   clique sur l'encoche, **Then** le panneau propose de connecter son compte Claude, et rien
   d'autre ne s'affiche.
2. **Given** un compte connecté, **When** l'utilisateur ne touche à rien, **Then** la vue
   compacte montre le pourcentage de la limite la plus proche d'être atteinte, avec un
   indicateur qui permet de savoir de quelle limite il s'agit.
3. **Given** un compte connecté, **When** l'utilisateur survole l'encoche, **Then** le
   panneau déplié liste chaque limite active avec son pourcentage et son heure de
   réinitialisation, en heure locale et en temps restant (« dans 2 h 14 »).
4. **Given** le panneau est ouvert par survol, **When** le pointeur quitte la zone, **Then**
   le panneau se replie en moins d'une seconde.
5. **Given** le panneau est ouvert, **When** l'utilisateur clique sur l'encoche, **Then** le
   panneau reste ouvert (épinglé) même si le pointeur s'en éloigne, jusqu'à un clic ailleurs,
   un nouveau clic sur l'encoche ou Échap.
6. **Given** l'abonnement ne comporte pas de limite propre à un modèle, **When** le panneau
   s'ouvre, **Then** aucune ligne vide ou « 0 % » n'est affichée pour ce modèle.
7. **Given** Claude Code est installé et connecté sur la machine, **When** l'utilisateur
   lance la connexion, **Then** l'app propose de réutiliser cette session et ne l'utilise
   qu'après son accord explicite.
8. **Given** Claude Code n'est pas installé ou n'est pas connecté, **When** l'utilisateur
   lance la connexion, **Then** l'app ouvre la page de connexion Claude dans le navigateur et
   récupère la session une fois la connexion faite.

---

### User Story 2 - Être prévenu avant d'atteindre une limite (Priority: P2)

Quand une limite franchit 80 %, puis 95 %, l'encoche change d'état visuel pour prévenir
l'utilisateur, sans interrompre son travail. Les seuils sont réglables.

**Why this priority**: l'alerte évite le blocage surprise en pleine tâche, mais elle n'a de
sens qu'une fois l'affichage (US1) en place.

**Independent Test**: régler un seuil sous la consommation actuelle et vérifier que l'alerte
se déclenche une seule fois, puis disparaît après la réinitialisation de la limite.

**Acceptance Scenarios**:

1. **Given** une limite à 78 %, **When** elle passe à 81 %, **Then** l'encoche affiche un
   état « attention » et le panneau met en évidence la limite concernée.
2. **Given** une limite à 93 %, **When** elle passe à 96 %, **Then** l'encoche affiche un
   état « critique », distinct de l'état « attention ».
3. **Given** une alerte a déjà été émise pour un seuil, **When** la valeur oscille autour de
   ce seuil, **Then** aucune nouvelle alerte n'est émise avant la prochaine réinitialisation.
4. **Given** l'utilisateur change les seuils dans les réglages, **When** il valide, **Then**
   les nouveaux seuils s'appliquent dès le rafraîchissement suivant.

---

### User Story 3 - Fonctionner sur un écran sans encoche (Priority: P3)

Sur un Mac sans encoche, ou quand l'utilisateur travaille sur un écran externe, une pilule
centrée en haut de l'écran principal reproduit le comportement de l'encoche : vue compacte,
dépliage au survol ou au clic, alertes.

**Why this priority**: une partie des utilisateurs travaille couvercle fermé ou sur un Mac
sans encoche. Sans ce repli, l'app leur est inutilisable.

**Independent Test**: lancer l'app sur un écran sans encoche et vérifier que la pilule
apparaît et se comporte comme décrit en US1 et US2.

**Acceptance Scenarios**:

1. **Given** l'écran principal n'a pas d'encoche, **When** l'app démarre, **Then** une pilule
   apparaît centrée en haut de cet écran.
2. **Given** l'utilisateur change d'écran principal ou branche ou débranche un écran,
   **When** la configuration change, **Then** l'affichage se repositionne en moins de 2 s,
   sur l'encoche si elle existe, sinon sous forme de pilule.
3. **Given** une app est en plein écran, **When** l'utilisateur ne survole pas le haut de
   l'écran, **Then** la vue compacte est masquée. Seul un point discret reste visible si une
   alerte « attention » ou « critique » est active.
4. **Given** une app est en plein écran, **When** l'utilisateur survole le haut de l'écran,
   **Then** la vue compacte et le panneau déplié réapparaissent, puis disparaissent quand le
   pointeur s'éloigne.

---

### Edge Cases

- **Session expirée ou révoquée** : l'app affiche un état « reconnexion requise » à la place
  des valeurs. Elle n'affiche jamais de chiffres périmés comme s'ils étaient à jour.
- **Hors ligne ou service indisponible** : les dernières valeurs connues restent affichées
  avec leur ancienneté (« il y a 12 min »). Au-delà de 30 min, elles sont marquées comme périmées.
- **Limite à 100 %** : la vue compacte affiche un état « bloqué » avec le temps restant avant
  la réinitialisation.
- **Réinitialisation pendant que l'app tourne** : la valeur repasse à 0 % sans attendre plus
  qu'un cycle de rafraîchissement, et les alertes de cette limite sont réarmées.
- **Compte gratuit, ou sans limites exposées** : l'app indique que le type d'abonnement n'est
  pas pris en charge au lieu d'afficher des jauges vides.
- **Nouvelle limite de modèle apparue côté Claude** : elle s'affiche automatiquement dans le
  panneau, sous le nom de modèle fourni par le service.
- **Format de réponse du service inattendu** : l'app affiche « données indisponibles » sans
  planter et conserve les dernières valeurs valides.
- **Mac en veille ou écran verrouillé** : aucun rafraîchissement. Une mise à jour est faite
  dans les 5 s qui suivent le réveil.
- **Session Claude Code révoquée ou expirée** : l'app passe en état « reconnexion requise »
  et propose au choix de reprendre la nouvelle session Claude Code ou de se connecter dans le
  navigateur.
- **Connexion dans le navigateur abandonnée** : l'utilisateur ferme l'onglet sans se
  connecter. L'app reste en état « non connecté », sans message d'erreur bloquant, et
  permet de relancer la démarche.

## Requirements *(mandatory)*

### Functional Requirements

**Connexion**

- **FR-001**: L'utilisateur MUST pouvoir connecter son compte Claude (Pro ou Max) depuis l'app,
  en une seule démarche guidée, par l'une des deux voies suivantes.
- **FR-002**: Si Claude Code est installé et connecté sur la machine, l'app MUST proposer en
  premier de réutiliser sa session, et ne l'utiliser qu'après le consentement explicite de
  l'utilisateur.
- **FR-002a**: Sinon, ou si l'utilisateur refuse, l'app MUST ouvrir la page de connexion Claude
  dans le navigateur par défaut et récupérer la session une fois la connexion faite.
- **FR-003**: L'utilisateur MUST pouvoir se déconnecter. Les identifiants et les dernières
  valeurs stockées en local sont alors supprimés.
- **FR-004**: Les identifiants MUST être stockés dans le coffre sécurisé du système et
  n'apparaître ni dans les journaux ni dans les messages d'erreur.

**Données d'usage**

- **FR-005**: L'app MUST afficher, pour chaque limite active du compte : son libellé, le
  pourcentage utilisé et l'heure de réinitialisation.
- **FR-006**: Les limites prises en charge MUST inclure au minimum la fenêtre glissante de 5 h,
  la limite hebdomadaire tous modèles, et chaque limite hebdomadaire propre à un modèle que le
  service expose.
- **FR-007**: L'app MUST rafraîchir les données toutes les 60 s par défaut. L'intervalle est
  réglable entre 30 s et 15 min.
- **FR-008**: L'app MUST suspendre le rafraîchissement pendant la veille, quand l'écran est
  verrouillé ou en mode économie d'énergie, et le reprendre au réveil.
- **FR-009**: En cas d'erreur ou de limitation de débit du service, l'app MUST espacer les
  tentatives de façon progressive. Elle ne doit jamais interroger le service plus d'une fois
  toutes les 30 s.
- **FR-010**: L'app MUST afficher l'ancienneté des données quand elles datent de plus de
  2 cycles de rafraîchissement.

**Affichage**

- **FR-011**: Une vue compacte MUST rester visible en permanence à côté de l'encoche. Elle
  montre la limite la plus proche d'être atteinte.
- **FR-012**: Survoler l'encoche MUST ouvrir la vue dépliée, qui se referme quand le pointeur
  quitte la zone. Cliquer sur l'encoche MUST l'épingler : elle reste ouverte jusqu'à un clic
  ailleurs, un nouveau clic sur l'encoche ou Échap.
- **FR-012a**: Quand une app est en plein écran, la vue compacte MUST être masquée. Survoler le
  haut de l'écran la fait réapparaître avec la vue dépliée. Une alerte active reste signalée
  par un point discret.
- **FR-013**: Le temps restant avant réinitialisation MUST être affiché en heure locale et en
  durée relative.
- **FR-014**: Sur un écran sans encoche, l'app MUST afficher une pilule centrée en haut de
  l'écran principal, avec le même comportement.
- **FR-015**: L'affichage MUST se repositionner automatiquement quand la configuration des
  écrans change.
- **FR-016**: L'app MUST être utilisable avec VoiceOver : chaque limite est annoncée avec son
  libellé, son pourcentage et son temps restant.
- **FR-016a**: L'interface MUST être en anglais. Tous les textes affichés MUST être
  externalisés pour permettre une traduction (le français est prévu dans une feature suivante)
  sans toucher à la logique.

**Alertes**

- **FR-017**: L'app MUST signaler visuellement dans l'encoche le franchissement d'un seuil
  « attention » (80 % par défaut) et d'un seuil « critique » (95 % par défaut).
- **FR-018**: L'utilisateur MUST pouvoir régler les deux seuils, ou désactiver les alertes.
- **FR-019**: Une alerte MUST être émise au plus une fois par seuil, par limite et par période
  de réinitialisation.

**Réglages et cycle de vie**

- **FR-020**: L'app MUST proposer un lancement automatique à l'ouverture de session.
  Cette option est désactivée par défaut.
- **FR-021**: L'app MUST n'avoir ni icône dans le Dock ni fenêtre principale. Les réglages
  sont accessibles depuis la vue dépliée.
- **FR-022**: L'app MUST NOT transmettre de données à un tiers autre que le service Claude
  lui-même (constitution, principe I).

### Key Entities

- **Compte** : l'abonnement Claude connecté. Il porte le type d'abonnement (Pro ou Max),
  la voie de connexion (session Claude Code ou navigateur), l'état de la connexion (connecté,
  expiré, déconnecté) et une référence vers les identifiants stockés de façon sécurisée.
- **Limite d'usage** : une limite exposée par le service. Elle porte un type (fenêtre de 5 h,
  hebdomadaire globale, hebdomadaire par modèle), un libellé, le modèle concerné s'il y en a un,
  le pourcentage utilisé, l'heure de réinitialisation et la date de la dernière mesure.
- **Relevé** : l'ensemble des limites obtenues à un instant donné. Il porte un horodatage et
  un état (frais, périmé, en erreur).
- **Réglages d'alerte** : le seuil « attention », le seuil « critique », l'activation, et pour
  chaque limite les seuils déjà notifiés pendant la période en cours.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un nouvel utilisateur voit ses limites dans l'encoche moins de 2 minutes après
  le premier lancement.
- **SC-002**: Les pourcentages affichés ne s'écartent pas de plus de 1 point de ceux de la page
  d'usage officielle de Claude, une fois le délai de rafraîchissement écoulé.
- **SC-003**: La vue dépliée s'ouvre en moins de 200 ms après le survol ou le clic.
- **SC-004**: Au repos, l'app n'entraîne aucune perte d'autonomie mesurable sur une journée de
  travail type de 8 h : processeur sous 1 % en moyenne, mémoire sous 60 Mo.
- **SC-005**: 100 % des franchissements de seuil sont signalés dans le cycle de
  rafraîchissement qui suit, sans doublon.
- **SC-006**: Pendant les tests, l'app ne s'est jamais arrêtée de façon inattendue, y compris
  en cas de coupure réseau, de session expirée ou de réponse malformée.

## Assumptions

- Les utilisateurs cibles sont des abonnés Claude Pro ou Max sur macOS 14 ou une version
  plus récente. Les comptes gratuits, Team et Enterprise sont hors périmètre du MVP.
- Le service Claude met à disposition, pour un compte connecté, les pourcentages d'usage et
  les heures de réinitialisation des limites, comme le montre sa page d'usage. Si cette
  source n'est pas documentée publiquement, elle peut changer sans préavis : c'est un risque
  à couvrir dans le plan (tests sur fixtures, dégradation propre).
- Le nom des modèles soumis à une limite propre (par exemple Fable) vient du service et n'est
  pas codé en dur.
- La consommation de l'API payante (Console) et l'analyse des journaux de Claude Code sont
  hors périmètre du MVP.
- Les notifications système (Centre de notifications) sont hors périmètre du MVP. Les alertes
  restent visuelles dans l'encoche.
- Un seul compte connecté à la fois. La gestion de plusieurs comptes est hors périmètre.
- La traduction en français de l'interface est hors périmètre du MVP et fera l'objet d'une
  feature distincte.
- **Évolution prévue** : un avatar animé dans l'encoche, qui reflète l'état de consommation,
  remplacera ou complétera la jauge compacte. Il fera l'objet d'une feature distincte.
- L'historique et les graphiques d'usage sur plusieurs jours sont hors périmètre du MVP.
