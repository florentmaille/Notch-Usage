import Foundation

/// Prévision de blocage à partir du rythme observé (feature 003, contrat forecast.md, research R1).
public enum PaceForecaster {
    /// Fenêtre d'observation, durée minimale entre premier et dernier relevé, trou maximal entre deux relevés.
    public static let window: TimeInterval = 3600
    public static let minimumSpan: TimeInterval = 600
    public static let maximumGap: TimeInterval = 1800

    public static func forecast(readings: [Reading], resetsAt: Date?, now: Date) -> Forecast {
        let points = readings
            .filter { $0.at <= now && now.timeIntervalSince($0.at) <= window }
            .sorted { $0.at < $1.at }
        guard let first = points.first, let last = points.last, points.count >= 2 else { return .unavailable }
        guard last.at.timeIntervalSince(first.at) >= minimumSpan else { return .unavailable }
        for (a, b) in zip(points, points.dropFirst()) where b.at.timeIntervalSince(a.at) > maximumGap { return .unavailable }
        guard last.utilization < 100 else { return .unavailable }

        // Régression linéaire : pente en points de pourcentage par seconde.
        let xs = points.map { $0.at.timeIntervalSince(now) }
        let ys = points.map(\.utilization)
        let mx = xs.reduce(0, +) / Double(xs.count)
        let my = ys.reduce(0, +) / Double(ys.count)
        var sxy = 0.0, sxx = 0.0
        for (x, y) in zip(xs, ys) { sxy += (x - mx) * (y - my); sxx += (x - mx) * (x - mx) }
        guard sxx > 0 else { return .unavailable }
        let slope = sxy / sxx
        guard slope > 0 else { return .holdsUntilReset }

        let blockAt = now.addingTimeInterval((100 - last.utilization) / slope)
        guard let resetsAt, blockAt < resetsAt else { return .holdsUntilReset }
        return .blockAt(blockAt)
    }

    /// Une entrée par fenêtre de 5 h de l'instantané ; les limites hebdomadaires n'ont pas de prévision (research R7).
    public static func forecasts(history: UsageHistory, snapshot: UsageSnapshot, now: Date) -> [String: Forecast] {
        var result: [String: Forecast] = [:]
        for limit in snapshot.limits where limit.kind == .rollingFiveHour {
            result[limit.id] = forecast(readings: history.readings(for: limit.id), resetsAt: limit.resetsAt, now: now)
        }
        return result
    }
}
