import Foundation

/// Courbe de la semaine (021, planche C1) : usage de la limite hebdomadaire toutes modèles du dernier reset à
/// maintenant, et projection reprise de la prévision de la 016 (même rythme, même heure de blocage).
public struct WeekCurve: Sendable, Equatable {
    public struct Point: Sendable, Equatable {
        /// Part de la semaine écoulée, 0 au début de la période, 1 au reset.
        public let fraction: Double
        public let usage: Double
    }

    public struct Day: Sendable, Equatable {
        /// Minuit local, en part de la semaine.
        public let fraction: Double
        public let date: Date
    }

    public enum Projection: Sendable, Equatable {
        case none                                  // moins de 12 h écoulées (016)
        case holds(atReset: Double)                // usage prévu au reset
        case blocks(at: Date, fraction: Double)    // 100 % atteints avant le reset
    }

    public enum State: Sendable, Equatable {
        case notEnough
        case curve(WeekCurve)
    }

    public let points: [Point]
    public let now: Point
    public let projection: Projection
    /// Calme sauf blocage prévu : teinte du palier de la prévision (FR-006).
    public let tint: NotchSignal.Island.Tint
    public let days: [Day]
    /// Jour du `now` dans `days` (en gras sous la courbe), `nil` avant le premier minuit de la semaine.
    public let todayIndex: Int?
    public let resetsAt: Date

    /// `nil` : pas une limite hebdomadaire toutes modèles avec un reset connu, la section n'apparaît pas.
    public static func make(limit: UsageLimit, history: HourlyHistory, forecast: Forecast?, now: Date,
                            calendar: Calendar = .current) -> State? {
        guard limit.kind == .weeklyAll, let resetsAt = limit.resetsAt else { return nil }
        let week = PaceForecaster.weekPeriod
        let start = resetsAt.addingTimeInterval(-week)
        func fraction(_ date: Date) -> Double { min(1, max(0, date.timeIntervalSince(start) / week)) }

        let past = history.readings(for: limit.id)
            .filter { $0.isSamePeriod(as: resetsAt) && $0.at >= start && $0.at < now }
            .map { Point(fraction: fraction($0.at), usage: $0.utilization) }
        // FR-007 : 2 relevés depuis le reset. Le point « maintenant » reprend le dernier relevé, il ne compte pas.
        guard past.count >= 2 else { return .notEnough }
        let current = Point(fraction: fraction(now), usage: limit.utilization)
        let points = past + [current]

        var projection = Projection.none
        var tint = NotchSignal.Island.Tint.calm
        switch forecast {
        case .blockAt(let date)?:
            projection = .blocks(at: date, fraction: fraction(date))
            tint = NotchSignal.Island.tint(NotchSignal.Edge.tier(blockAt: date, now: now))
        case .holdsUntilReset?:
            // Même rythme que la 016 : usage moyen depuis le début de la semaine, nuits comprises.
            let elapsed = now.timeIntervalSince(start)
            // Plafonné : la prévision affichée peut dater du relevé précédent (anti-rebond), « tient » reste sous 100 %.
            projection = .holds(atReset: min(100, elapsed > 0 ? limit.utilization * week / elapsed : limit.utilization))
        case .unavailable?, nil:
            break
        }

        var days: [Day] = []
        var midnight = calendar.startOfDay(for: start)
        // Reset à minuit local : la première journée commence au reset et garde son repère.
        if midnight < start { midnight = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight.addingTimeInterval(86_400) }
        while midnight < resetsAt {
            days.append(Day(fraction: fraction(midnight), date: midnight))
            midnight = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight.addingTimeInterval(86_400)
        }
        let todayIndex = days.lastIndex { $0.date <= now }

        return .curve(WeekCurve(points: points, now: current, projection: projection, tint: tint, days: days,
                                todayIndex: todayIndex, resetsAt: resetsAt))
    }
}
