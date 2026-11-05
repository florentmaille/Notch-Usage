import Foundation

/// Prévision de blocage à partir du rythme observé (feature 003, contrat forecast.md, research R1). 015 : les relevés
/// récents pèsent plus, et 10 min sans hausse valent une pause.
public enum PaceForecaster {
    /// Fenêtre d'observation, durée minimale entre premier et dernier relevé, trou maximal entre deux relevés.
    public static let window: TimeInterval = 3600
    public static let minimumSpan: TimeInterval = 600
    public static let maximumGap: TimeInterval = 1800
    /// Constante de temps de la pondération (015) : un relevé de 20 min pèse 1/e d'un relevé actuel, demi-vie ≈ 14 min.
    public static let recencyTau: TimeInterval = 1200
    /// Durée sans hausse au-delà de laquelle l'utilisateur est considéré en pause (015).
    public static let pauseSpan: TimeInterval = 600

    public static func forecast(readings: [Reading], resetsAt: Date?, now: Date) -> Forecast {
        let points = readings
            .filter { $0.at <= now && now.timeIntervalSince($0.at) <= window }
            .sorted { $0.at < $1.at }
        guard let first = points.first, let last = points.last, points.count >= 2 else { return .unavailable }
        guard last.at.timeIntervalSince(first.at) >= minimumSpan else { return .unavailable }
        for (a, b) in zip(points, points.dropFirst()) where b.at.timeIntervalSince(a.at) > maximumGap { return .unavailable }
        guard last.utilization < 100 else { return .unavailable }

        // Pause : aucune hausse depuis au moins `pauseSpan`. Une rafale passée ne doit pas annoncer un blocage.
        if let pauseStart = points.last(where: { $0.utilization < last.utilization })
            .flatMap({ below in points.first(where: { $0.at > below.at }) }) ?? points.first,
           last.at.timeIntervalSince(pauseStart.at) >= pauseSpan {
            return .holdsUntilReset
        }

        // Régression linéaire pondérée (moindres carrés, poids exp(x / τ)) : pente en points par seconde.
        let xs = points.map { $0.at.timeIntervalSince(now) }
        let ys = points.map(\.utilization)
        let ws = xs.map { exp($0 / recencyTau) }
        let sw = ws.reduce(0, +)
        let mx = zip(ws, xs).map(*).reduce(0, +) / sw
        let my = zip(ws, ys).map(*).reduce(0, +) / sw
        var sxy = 0.0, sxx = 0.0
        for ((x, y), w) in zip(zip(xs, ys), ws) { sxy += w * (x - mx) * (y - my); sxx += w * (x - mx) * (x - mx) }
        guard sxx > 0 else { return .unavailable }
        let slope = sxy / sxx
        guard slope > 0 else { return .holdsUntilReset }

        let blockAt = now.addingTimeInterval((100 - last.utilization) / slope)
        guard let resetsAt, blockAt < resetsAt else { return .holdsUntilReset }
        return .blockAt(blockAt)
    }

    /// Durée d'une période hebdomadaire et part écoulée minimale avant d'extrapoler (016).
    public static let weekPeriod: TimeInterval = 7 * 24 * 3600
    public static let weeklyMinimumElapsed: TimeInterval = 12 * 3600

    /// Prévision hebdomadaire (016) : rythme moyen depuis le début de la période (nuits et pauses comprises),
    /// et non la pente de la dernière heure, qui projetée sur des jours supposerait un travail continu (003, R7).
    public static func weeklyForecast(utilization: Double, resetsAt: Date?, now: Date) -> Forecast {
        guard let resetsAt, resetsAt > now, utilization < 100 else { return .unavailable }
        let elapsed = now.timeIntervalSince(resetsAt.addingTimeInterval(-weekPeriod))
        guard elapsed >= weeklyMinimumElapsed else { return .unavailable }
        guard utilization > 0 else { return .holdsUntilReset }
        let blockAt = now.addingTimeInterval((100 - utilization) * elapsed / utilization)
        return blockAt < resetsAt ? .blockAt(blockAt) : .holdsUntilReset
    }

    /// Une entrée par limite : pente récente pour la fenêtre de 5 h, rythme de la semaine pour les hebdomadaires (016).
    public static func forecasts(history: UsageHistory, snapshot: UsageSnapshot, now: Date) -> [String: Forecast] {
        var result: [String: Forecast] = [:]
        for limit in snapshot.limits {
            switch limit.kind {
            case .rollingFiveHour:
                result[limit.id] = forecast(readings: history.readings(for: limit.id), resetsAt: limit.resetsAt, now: now)
            case .weeklyAll, .weeklyModel:
                result[limit.id] = weeklyForecast(utilization: limit.utilization, resetsAt: limit.resetsAt, now: now)
            }
        }
        return result
    }
}
