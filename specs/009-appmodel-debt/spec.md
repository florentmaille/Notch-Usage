# Feature Specification: Dette d'architecture

**Feature Branch**: `009-appmodel-debt` | **Created**: 2026-11-03 | **Status**: Draft

**Input**: Revue architecture du 2026-11-03 (points 2, 3, 5, 7, 9) : état dérivé calculé en plusieurs endroits, redémarrage du coordinateur à chaque clic de réglage, tick qui ignore la pause et horloge figée entre deux ticks, cadence du battement non testée, code mort des features 001-005, chaîne Spec Kit cassée (004 absente, constitution « 30 s »).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Même comportement, moins d'endroits où se tromper (Priority: P1)

Aucun changement visible. Un seul endroit décide que l'encoche se réduit à sa largeur physique ; un seul calcul de niveau par seuil ; la cadence du battement est une valeur pure et testée ; changer un seuil ne relance ni requête ni flux ; pendant la veille ou l'écran verrouillé, le tick ne recalcule rien ; un survol entre deux ticks lit l'heure courante.

**Acceptance Scenarios**:

1. **Given** un seuil modifié dans les réglages, **Then** aucun redémarrage du coordinateur (pas de « reading » ni de relecture du cache dans le journal), le prochain relevé applique le seuil.
2. **Given** l'écran verrouillé, **Then** le tick ne recalcule pas ; au déverrouillage, recalcul immédiat.
3. **Given** `BeatCounterTests`, **Then** 2 battements sur 4 ticks en `everyMinute`, 4 sur 4 en `everyHalfMinute`, 0 sans rythme.
4. **Given** les captures `far`, `imminent`, `blocked`, `offline`, survol, **Then** identiques à la 0.4.1 au pixel près hors horodatage.

## Requirements *(mandatory)*

- **FR-001**: `NotchSignal.collapsesToNotch(in:)` MUST être la seule règle de réduction à l'encoche (panneau, forme, vue compacte).
- **FR-002**: Les lignes du panneau MUST colorer leurs seuils par `AlertEvaluator.level(for:settings:)`.
- **FR-003**: `BeatCounter` (core) MUST porter la cadence du battement ; l'app ne compte plus elle-même.
- **FR-004**: Le hook d'alerte du coordinateur MUST lire les réglages courants ; un changement de seuil MUST NOT redémarrer le coordinateur.
- **FR-005**: Le tick MUST être inerte pendant une pause ; `recompute` MUST rafraîchir l'heure.
- **FR-006**: Code mort retiré : branches d'ailes inatteignables, `RefreshSettings.launchAtLogin`, `AlertEvaluator.level(for snapshot:)`.
- **FR-007**: Le mode démo MUST vivre dans `AppModel+Demo.swift` ; ses observateurs MUST être retirés à l'arrêt.
- **FR-008**: Spec 004 rétroactive ; constitution alignée sur le plancher réel de 60 s (1.1.1).

## Success Criteria *(mandatory)*

- **SC-001**: `AppModel.swift` sous 480 lignes ; tests core ≥ 211, tous verts.
- **SC-002**: 0 texte modifié dans le catalogue.
- **SC-003**: Captures de démo inchangées (far, imminent, blocked, offline, survol).

## Assumptions

- Hors champ, pour une 010 : découpe de `ConnectionManager` vers le core avec tests, cible de tests app, `assumeIsolated` dans `onPreferenceChange`, doublon du mapping HTTP de `WebUsageProvider`.
