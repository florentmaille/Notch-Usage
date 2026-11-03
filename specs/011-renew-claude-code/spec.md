# Feature Specification: Renouveler la session Claude Code en un clic

**Feature Branch**: `011-renew-claude-code` | **Created**: 2026-11-03 | **Status**: Draft

**Input**: Retour utilisateur du 2026-11-03 : « Claude Code session » affiche « expirée » alors que l'app Claude fonctionne. Le jeton du Trousseau n'est renouvelé que par le CLI `claude` ; l'app de bureau ne le touche pas. Demande : un bouton qui relance Claude en silence pour régénérer le jeton.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Un clic pour renouveler (Priority: P1)

Sur l'écran « Reconnexion requise » d'un compte Claude Code, un bouton « Renouveler la session » lance `claude` en arrière-plan avec une requête d'un mot (Haiku, un tour, sans MCP ni réglages utilisateur, sans session enregistrée), puis reconnecte.

**Acceptance Scenarios**:

1. **Given** jeton expiré et CLI connecté, **When** clic, **Then** « Renouvellement… », puis reconnexion et relevé.
2. **Given** CLI introuvable, déconnecté, muet plus de 45 s ou en erreur, **Then** un message dédié avec le repli Terminal ou navigateur.
3. **Given** aucun clic, **Then** l'app ne lance jamais `claude` (la requête compte dans la fenêtre de 5 h).

## Requirements *(mandatory)*

- **FR-001**: Recherche du binaire dans les emplacements connus puis le PATH (`ClaudeCLI.candidates`).
- **FR-002**: Arguments et environnement minimaux (`HOME`, `USER`, `LOGNAME`, `PATH` système) ; sans `USER` le CLI ne retrouve pas son entrée Trousseau.
- **FR-003**: Délai maximum 45 s, processus arrêté au-delà.
- **FR-004**: La sortie du CLI n'est jamais journalisée.
- **FR-005**: Textes EN et FR.

## Validation (2026-11-03)

- `claude auth status` ne renouvelle pas le jeton (expiration inchangée) : écarté.
- `claude -p … --model haiku` avec environnement vide : « Not logged in ». Avec `USER` et `LOGNAME` : expiration passée de 15:49 à 07:04 le lendemain.
- Commande finale (`--strict-mcp-config --setting-sources "" --no-session-persistence`) : sortie « OK », code 0, aucun MCP ni hook.
- 226 tests core (5 nouveaux), build, 98 textes traduits. Parcours bouton non rejoué sur jeton expiré (jeton renouvelé pendant l'essai).
