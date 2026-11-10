import Foundation

/// Seuils de repli (FR-019) : niveau d'une limite quand aucune prévision n'existe. Fonction pure. Les notifications,
/// une par limite et par période, passent par `NotificationGate` (008).
public struct AlertEvaluator: Sendable {
    public init() {}

    /// Niveau d'une limite : seuil de repli, utilisé pour la limite portée par l'encoche et les lignes du panneau.
    public func level(for limit: UsageLimit, settings: AlertSettings) -> AlertLevel {
        guard settings.enabled else { return .none }
        if limit.utilization >= Double(settings.criticalThreshold) { return .critical }
        if limit.utilization >= Double(settings.warningThreshold) { return .warning }
        return .none
    }
}
