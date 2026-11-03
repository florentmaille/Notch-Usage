import Foundation

/// Au plus une alerte par seuil, par limite et par période (FR-019). Fonction pure.
public struct AlertEvaluator: Sendable {
    public init() {}

    public func evaluate(_ snapshot: UsageSnapshot, settings: AlertSettings, ledger: AlertLedger) -> (ledger: AlertLedger, events: [AlertEvent]) {
        var newLedger = AlertLedger()
        var events: [AlertEvent] = []
        for limit in snapshot.limits {
            var entry = ledger.entries[limit.id] ?? .init(periodKey: limit.resetsAt)
            if !entry.isSamePeriod(as: limit.resetsAt) {
                entry = .init(periodKey: limit.resetsAt)
            }
            if settings.enabled {
                let level = level(for: limit, settings: settings)
                if level != .none, !entry.firedLevels.contains(level) {
                    events.append(AlertEvent(limitID: limit.id, level: level))
                    entry.firedLevels.insert(level)
                    if level == .critical { entry.firedLevels.insert(.warning) }
                }
            }
            newLedger.entries[limit.id] = entry
        }
        return (newLedger, events)
    }

    /// Niveau d'une limite : seuil de repli, utilisé pour la limite portée par l'encoche et les lignes du panneau.
    public func level(for limit: UsageLimit, settings: AlertSettings) -> AlertLevel {
        guard settings.enabled else { return .none }
        if limit.utilization >= Double(settings.criticalThreshold) { return .critical }
        if limit.utilization >= Double(settings.warningThreshold) { return .warning }
        return .none
    }
}
