# Feature Specification: Connexion testable

**Feature Branch**: `010-testable-connection` | **Created**: 2026-11-03 | **Status**: Draft

**Input**: Reste de la revue architecture (009, hypothèses) : `ConnectionManager` (flux de connexion, reprise de jeton) sans tests, aucune cible de tests app, `MainActor.assumeIsolated` dans `onPreferenceChange`, mapping HTTP dupliqué dans `WebUsageProvider`, message « Pas de connexion réseau » pour toute erreur réseau.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Les flux de connexion sont couverts par des tests (Priority: P1)

Aucun changement visible, sauf des messages d'erreur réseau plus justes. Les deux voies de connexion, la reprise silencieuse du jeton, la déconnexion et le choix du fournisseur sont testés sur des doubles (Trousseau de Claude Code, HTTP, magasins).

**Acceptance Scenarios**:

1. **Given** une entrée Claude Code valide, **Then** le jeton est stocké et le relevé mis en cache ; absente → `claudeCodeUnavailable` ; illisible → `claudeCodeMalformed` ; expirée ou refusée (401) → `claudeCodeExpired`, jeton supprimé.
2. **Given** une reprise après 401, **Then** lecture sans dialogue, nouveau jeton seulement s'il diffère, au plus une relecture par intervalle.
3. **Given** une clé de session valide, **Then** l'organisation est mémorisée ; invalide ou refusée → rien ne reste.
4. **Given** une déconnexion, **Then** identifiants, organisation et cache effacés.
5. **Given** une erreur réseau, **Then** trois messages : pas de réseau, délai dépassé, Claude injoignable.

## Requirements *(mandatory)*

- **FR-001**: `ConnectionManager` et `ConnectionError` MUST vivre dans le core, avec horloge et journal injectés ; les messages restent dans l'app.
- **FR-002**: `ClaudeCodeCredentialSource` MUST exposer `entryExists()`.
- **FR-003**: Un seul mapping HTTP → `FetchError` (`ProviderSupport.check`) pour l'usage et les organisations.
- **FR-004**: La hauteur du panneau MUST se mesurer sans `assumeIsolated` (`onGeometryChange`).
- **FR-005**: Une cible de tests app (`NotchUsageAppTests`) MUST tourner en CI ; l'app hôte ne démarre rien sous test.

## Success Criteria *(mandatory)*

- **SC-001**: ≥ 9 tests `ConnectionManager` dans le core ; 100 % des tests verts.
- **SC-002**: Tests app verts en local avec les options de signature de la CI.
- **SC-003**: 0 texte sans traduction (2 messages réseau ajoutés).

## Assumptions

- Une réponse d'organisations vide en 200 devient `emptyBody` au lieu de `malformed` (même message).
- Les `assumeIsolated` des observateurs système (écran, plein écran, énergie) et des hooks Debug restent : leurs notifications arrivent sur la file principale par construction (`queue: .main`).
