# Feature Specification: Prévision pondérée

**Feature Branch**: `015-weighted-forecast` | **Created**: 2026-11-04 | **Status**: Draft

**Input**: Revue produit du 2026-11-03 (point 4) : la prévision est une droite sur les 60 dernières minutes, chaque relevé pesant autant. Après une rafale suivie d'une pause, la jauge reste ambre jusqu'à 45 min alors que l'utilisateur a arrêté ; une accélération récente est sous-estimée.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La prévision suit le rythme du moment (Priority: P1)

**Acceptance Scenarios**:

1. **Given** une rafale de 20 à 50 % entre 45 et 30 min avant, puis 30 min sans hausse, **Then** « tient jusqu'à la réinitialisation » (jauge grise).
2. **Given** un usage régulier puis moins de 10 min sans hausse, **Then** le blocage reste prévu (pause trop courte pour conclure).
3. **Given** un usage lent en début d'heure et rapide sur les 20 dernières minutes, **Then** le blocage prévu est plus proche qu'avec une droite non pondérée (moins de 100 min dans l'exemple de test, contre environ 120).
4. **Given** un rythme régulier, **Then** la prévision est inchangée (même droite).

## Requirements *(mandatory)*

- **FR-001**: Régression linéaire pondérée par `exp(x / τ)`, τ = 20 min (x ≤ 0, secondes avant maintenant) ; fenêtre, écart minimal, trous et hystérésis inchangés (003).
- **FR-002**: Si l'usage n'a pas augmenté depuis au moins 10 min, la prévision est « tient jusqu'à la réinitialisation ».
- **FR-003**: Aucun changement d'affichage, de texte ni de cadence.

## Success Criteria *(mandatory)*

- **SC-001**: Les 3 nouveaux tests passent ; les 9 tests existants de `PaceForecaster` restent verts sans modification.
