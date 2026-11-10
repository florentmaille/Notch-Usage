import Foundation
import Testing
@testable import NotchUsageCore

@Suite("PaceForecaster (003, 015)")
struct PaceForecasterTests {
    let now = Date.iso("2026-11-01T10:00:00Z")

    /// Relevés (minutes avant `now`, pourcentage) d'une même limite.
    func readings(_ points: [(Double, Double)], reset: TimeInterval? = 4 * 3600) -> [Reading] {
        points.map { Reading(limitID: "session", at: now.addingTimeInterval(-$0.0 * 60), utilization: $0.1, resetsAt: reset.map(now.addingTimeInterval)) }
    }

    func forecast(_ points: [(Double, Double)], reset: TimeInterval? = 4 * 3600) -> Forecast {
        PaceForecaster.forecast(readings: readings(points, reset: reset), resetsAt: reset.map(now.addingTimeInterval), now: now)
    }

    func minutes(_ f: Forecast) -> Double? {
        if case .blockAt(let d) = f { return d.timeIntervalSince(now) / 60 }
        return nil
    }

    @Test func steadyPaceBlocksBeforeReset() {
        let f = forecast([(40, 29), (30, 36), (20, 42), (10, 49), (0, 55)])
        let m = minutes(f)
        #expect(m != nil && m! > 65 && m! < 75)
    }

    // MARK: 015 - pondération récente

    @Test func burstThenPauseHolds() {
        // Rafale de 30 à 45 min avant, puis 30 min sans aucune hausse : l'utilisateur a arrêté.
        let f = forecast([(45, 20), (40, 30), (35, 40), (30, 50), (25, 50), (20, 50), (15, 50), (10, 50), (5, 50), (0, 50)])
        #expect(f == .holdsUntilReset)
    }

    @Test func shortPauseAfterSteadyUseStillWarns() {
        // Moins de 10 min sans hausse : une pause trop courte pour conclure, le rythme de l'heure compte encore.
        let f = forecast([(40, 20), (30, 32), (20, 44), (10, 56), (5, 60), (0, 60)])
        #expect(minutes(f) != nil)
    }

    @Test func recentAccelerationWarnsSooner() {
        // Lent au début de l'heure, rapide sur les 20 dernières minutes : la prévision suit le rythme récent.
        let f = forecast([(60, 10), (50, 12), (40, 14), (30, 16), (20, 24), (10, 32), (0, 40)])
        let m = minutes(f)
        #expect(m != nil && m! < 100)
    }

    @Test func slowPaceHoldsUntilReset() {
        #expect(forecast([(40, 40), (20, 42), (0, 44)], reset: 2 * 3600 + 14 * 60) == .holdsUntilReset)
    }

    @Test func flatAndDecreasingHold() {
        #expect(forecast([(30, 42), (15, 42), (0, 42)]) == .holdsUntilReset)
        #expect(forecast([(30, 43), (15, 42), (0, 42)]) == .holdsUntilReset)
    }

    @Test func tooFewOrTooCloseReadingsAreUnavailable() {
        #expect(forecast([(0, 55)]) == .unavailable)
        #expect(forecast([(5, 50), (0, 55)]) == .unavailable)
        #expect(forecast([]) == .unavailable)
    }

    @Test func gapsMakeTheForecastUnavailable() {
        #expect(forecast([(70, 30), (0, 55)]) == .unavailable)
        #expect(forecast([(40, 30), (5, 52), (0, 55)]) == .unavailable)
    }

    @Test func blockAfterResetHolds() {
        #expect(forecast([(30, 80), (0, 82)], reset: 30 * 60) == .holdsUntilReset)
    }

    /// Sans heure de reset, rien ne dit que le reset arrive avant le blocage : « tient » éteignait le seuil à 99 %.
    /// Pas de prévision, les seuils reprennent la main. Sans hausse, la limite tient quel que soit le reset.
    @Test func withoutResetTimeARisingPaceIsUnavailable() {
        #expect(forecast([(30, 40), (0, 55)], reset: nil) == .unavailable)
        #expect(forecast([(30, 42), (15, 42), (0, 42)], reset: nil) == .holdsUntilReset)
    }

    @Test func exhaustedLimitIsUnavailable() {
        #expect(forecast([(30, 90), (0, 100)]) == .unavailable)
    }

    @Test func weeklyLimitsUseTheWeekPace() {
        var history = UsageHistory()
        for (minutesAgo, pct) in [(40.0, 29.0), (30, 36), (20, 42), (10, 49), (0, 55)] {
            history = history.appending(makeSnapshot([("session", pct)], fetchedAt: now.addingTimeInterval(-minutesAgo * 60),
                                                     resetsAt: now.addingTimeInterval(4 * 3600)))
        }
        // Hebdo : 2 jours écoulés sur 7 (reset dans 5 j). Total à 50 % → 100 % dans 2 j ; Fable à 20 % → tient.
        let snapshot = UsageSnapshot(limits: [
            UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: 55, resetsAt: now.addingTimeInterval(4 * 3600)),
            UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: 50, resetsAt: now.addingTimeInterval(5 * 86400)),
            UsageLimit(id: "weekly_scoped:Fable", kind: .weeklyModel, modelName: "Fable", utilization: 20, resetsAt: now.addingTimeInterval(5 * 86400)),
        ], fetchedAt: now)
        let f = PaceForecaster.forecasts(history: history, snapshot: snapshot, now: now)
        #expect(minutes(f["session"] ?? .unavailable) != nil)
        #expect(f["weekly_all"] == .blockAt(now.addingTimeInterval(2 * 86400)))
        #expect(f["weekly_scoped:Fable"] == .holdsUntilReset)
    }

    @Test func weeklyForecastNeedsHalfADayAndAReset() {
        let early = now.addingTimeInterval(7 * 86400 - 6 * 3600)   // 6 h écoulées
        #expect(PaceForecaster.weeklyForecast(utilization: 30, resetsAt: early, now: now) == .unavailable)
        #expect(PaceForecaster.weeklyForecast(utilization: 30, resetsAt: nil, now: now) == .unavailable)
        #expect(PaceForecaster.weeklyForecast(utilization: 100, resetsAt: now.addingTimeInterval(86400), now: now) == .unavailable)
        #expect(PaceForecaster.weeklyForecast(utilization: 0, resetsAt: now.addingTimeInterval(86400), now: now) == .holdsUntilReset)
    }
}
