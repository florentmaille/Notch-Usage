# Feature Specification: Prévision hebdomadaire

**Feature Branch**: `016-weekly-forecast` | **Created**: 2026-11-05 | **Status**: Draft

**Input**: Demande du 2026-11-05 : afficher la projection aussi pour la limite hebdomadaire (tous modèles) et la limite hebdomadaire Fable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Savoir si la semaine tient (Priority: P1)

**Acceptance Scenarios**:

1. **Given** une limite hebdo à 50 % après 2 jours sur 7, **Then** « À ce rythme (cette semaine) : blocage <jour heure> » (dans 2 jours).
2. **Given** une limite hebdo de modèle à 20 % après 2 jours, **Then** « À ce rythme : tient jusqu'à la réinitialisation ».
3. **Given** moins de 12 h écoulées depuis le début de la semaine, ou pas d'heure de reset, **Then** aucune ligne de prévision.
4. **Given** une prévision hebdo, quelle qu'elle soit, **Then** l'encoche, la pastille et les notifications ne changent pas (seuils pour l'hebdo, prévision pour la 5 h).

## Requirements *(mandatory)*

- **FR-001**: Rythme moyen depuis le début de la période (`resetsAt - 7 j`), nuits et pauses comprises ; la pente sur une heure reste réservée à la fenêtre de 5 h (003, R7 : projetée sur des jours, elle supposerait un travail continu).
- **FR-002**: Pas de prévision avant 12 h écoulées, sans heure de reset, ou limite épuisée ; usage nul = « tient ».
- **FR-003**: Panneau et menu de la barre : jour + heure du blocage ; l'encoche (HeadlinePicker, CompactStrip, NotchSignal) n'utilise que la prévision de 5 h.

## Success Criteria *(mandatory)*

- **SC-001**: Tests `weeklyLimitsUseTheWeekPace`, `weeklyForecastNeedsHalfADayAndAReset`, `weeklyForecastsDoNotDriveTheNotch` verts ; suite complète verte.
