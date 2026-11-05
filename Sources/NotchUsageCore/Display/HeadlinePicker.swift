import Foundation

/// Limite portée par l'encoche (008, remplace la règle 004) : la plus menaçante de toutes, d'après la prévision
/// quand elle existe, sinon d'après les seuils. Les limites de modèle (Fable…) ne bloquent pas les requêtes :
/// elles restent dans le panneau ouvert mais ne prennent jamais l'encoche repliée.
public enum HeadlinePicker {
    /// Gravité d'une limite, pour comparaison : 0 = rien à signaler.
    public static func severity(of limit: UsageLimit, forecast: Forecast?, settings: AlertSettings, now: Date) -> Int {
        if limit.isBlocked { return limit.kind == .weeklyModel ? 1 : 5 }
        switch forecast {
        case .blockAt(let date)?:
            switch NotchSignal.Edge.tier(blockAt: date, now: now) {
            case .imminent, .exhausted: return 4
            case .near: return 3
            case .far: return 2
            }
        case .holdsUntilReset?:
            return 0   // la prévision prime sur le seuil (005, FR-007a)
        case .unavailable?, nil:
            switch AlertEvaluator().level(for: limit, settings: settings) {
            case .critical: return 4
            case .warning: return 2
            case .none: return 0
            }
        }
    }

    /// La limite la plus grave hors modèles ; à gravité égale, l'ordre du relevé (fenêtre de 5 h d'abord). Sans menace,
    /// la fenêtre de 5 h, ou la plus utilisée pour un abonnement qui ne l'expose pas. Les limites de modèle ne servent
    /// que de dernier recours, quand le relevé n'en contient pas d'autre.
    public static func pick(in snapshot: UsageSnapshot, forecasts: [String: Forecast], settings: AlertSettings, now: Date) -> UsageLimit? {
        let candidates = snapshot.limits.filter { $0.kind != .weeklyModel }
        let ranked = candidates.map { ($0, severity(of: $0, forecast: forecasts.notch(for: $0), settings: settings, now: now)) }
        if let worst = ranked.max(by: { $0.1 < $1.1 }), worst.1 > 0 {
            // `max(by:)` renvoie le dernier des ex æquo : on reprend le premier de même gravité.
            return ranked.first { $0.1 == worst.1 }?.0
        }
        return candidates.first { $0.kind == .rollingFiveHour }
            ?? candidates.max(by: { $0.utilization < $1.utilization })
            ?? snapshot.mostConstraining
    }
}
