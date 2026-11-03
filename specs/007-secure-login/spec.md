# Feature Specification: Connexion sans trace sur disque

**Feature Branch**: `007-secure-login`

**Created**: 2026-11-03

**Status**: Draft

**Input**: Revue sécurité du 2026-11-03 (H1, M1, M2, M4, L1, L2) : le cookie `sessionKey` capturé par la fenêtre de connexion restait sur disque hors Trousseau ; désinstallation Homebrew incomplète ; CI sans permissions explicites ni actions épinglées ; attribut Trousseau sans effet ; validations faibles de la clé collée et de l'identifiant d'organisation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rien du compte ne reste sur disque hors Trousseau (Priority: P1)

L'utilisateur se connecte par la fenêtre claude.ai. Une fois la clé capturée, la fenêtre se ferme et
rien de la session (cookie claude.ai, cookies des fournisseurs d'identité, stockage local) n'existe
ailleurs que dans le Trousseau. Un utilisateur d'une version antérieure voit ces restes effacés au
premier lancement. La désinstallation Homebrew efface tout ce que l'app a pu écrire.

**Why this priority**: la promesse « secrets dans le Trousseau uniquement » du README et de la constitution était fausse ; un cookie de session vaut un mot de passe.

**Independent Test**: après une connexion navigateur, `~/Library/HTTPStorages/com.notchusage.app*` et `~/Library/WebKit/com.notchusage.app/WebsiteData` ne contiennent aucun cookie ni enregistrement ; au lancement d'une build 0.4.1 sur une machine 0.4.0, les anciens fichiers sont vidés.

**Acceptance Scenarios**:

1. **Given** la fenêtre de connexion ouverte, **When** la clé est capturée, **Then** aucun cookie ni donnée de site n'est écrit sur disque pendant ni après la session de connexion.
2. **Given** des données de navigation laissées par une version antérieure, **When** l'app démarre, **Then** elles sont effacées.
3. **Given** `brew uninstall --zap notch-usage`, **When** la commande se termine, **Then** `Application Support`, `Caches`, `HTTPStorages`, `WebKit` et les préférences de l'app sont supprimés ; le cask indique que les entrées Trousseau se suppriment en se déconnectant avant.

### User Story 2 - Entrées validées, CI à droits minimaux (Priority: P2)

**Acceptance Scenarios**:

1. **Given** une clé collée contenant `;`, un espace ou un retour à la ligne, **When** l'utilisateur valide, **Then** elle est refusée avant toute requête.
2. **Given** un identifiant d'organisation qui n'est pas un UUID (serveur ou préférence), **When** une requête d'usage se prépare, **Then** l'organisation est résolue à nouveau ou l'abonnement est déclaré non pris en charge ; jamais de chemin d'URL construit avec la valeur.
3. **Given** le workflow de CI, **When** il s'exécute, **Then** le jeton n'a que `contents: read` et chaque action tierce est épinglée sur un commit.

### Edge Cases

- Connexion annulée : rien à effacer, la fenêtre se ferme ; aucune écriture n'a eu lieu.
- Purge au lancement sans données : silencieuse, sans journal.
- Attribut d'accessibilité Trousseau : retiré car sans effet sur le trousseau fichier ; l'ACL de l'élément reste celle de l'app.

## Requirements *(mandatory)*

- **FR-001**: La fenêtre de connexion MUST utiliser un magasin de données web en mémoire ; rien n'est écrit sur disque.
- **FR-002**: À la capture de la clé, MUST effacer toutes les données du magasin, fournisseurs d'identité compris.
- **FR-003**: Au lancement, à la déconnexion et sur 401, MUST effacer les données du magasin persistant et les cookies partagés laissés par les versions antérieures.
- **FR-004**: Le cask MUST supprimer `Application Support`, `Caches`, `HTTPStorages`, `WebKit` et les préférences ; ses `caveats` MUST indiquer de se déconnecter avant désinstallation pour les entrées Trousseau.
- **FR-005**: La clé de session MUST ne contenir, après le préfixe et la version, que des lettres, chiffres, `_` et `-` ASCII.
- **FR-006**: L'identifiant d'organisation MUST être un UUID avant tout usage dans une URL.
- **FR-007**: Le workflow de CI MUST déclarer `permissions: contents: read` et épingler ses actions sur un SHA.
- **FR-008**: Le README MUST décrire le comportement de la fenêtre de connexion (cookies en mémoire, effacés après capture).

## Success Criteria *(mandatory)*

- **SC-001**: Après connexion navigateur, 0 cookie dans `HTTPStorages` et 0 enregistrement dans `WebsiteData` pour l'app.
- **SC-002**: Les tests de format refusent `;`, espace et retour à la ligne ; 100 % des tests existants restent verts.
- **SC-003**: `brew uninstall --zap` ne laisse aucun fichier de l'app hors Trousseau.
- **SC-004**: CI verte avec les mêmes jobs bloquants ; un job arm64 non bloquant en plus.

## Assumptions

- La signature Developer ID et la notarisation (H2) restent une action de l'auteur (certificat) : hors champ ici, `scripts/release.sh` est prêt.
- Le sandbox (M3) est hors champ : il demande de valider la lecture du Trousseau de Claude Code sous sandbox, à traiter avec la première release signée.

## Validation (2026-11-03, build Debug)

| Point | Résultat |
|---|---|
| Purge au lancement | journal `legacy browser data purged (7 records)` ; `~/Library/HTTPStorages/com.notchusage.app.binarycookies` (4,8 Ko) disparu, `WebsiteData/Default` vidé |
| Connexion navigateur | non rejouée (pas de compte de test) ; magasin `nonPersistent`, effacé à la capture |
| Format de clé | `rejectsHeaderBreakingCharacters` vert ; 207 tests |
| Org UUID | fixtures de test passées en UUID ; valeur non UUID → résolution à nouveau |
| Cask | modèle aligné sur le tap + caveat Trousseau ; `brew uninstall --zap` non rejoué |
| CI | `permissions: contents: read`, checkout épinglé v4.2.2, job arm64 non bloquant ; à vérifier sur la PR |
