import Foundation
import Testing
@testable import NotchUsageCore

@Suite("PaceForecaster (003)")
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

    @Test func withoutResetTimeHolds() {
        #expect(forecast([(30, 40), (0, 55)], reset: nil) == .holdsUntilReset)
    }

    @Test func exhaustedLimitIsUnavailable() {
        #expect(forecast([(30, 90), (0, 100)]) == .unavailable)
    }

    @Test func onlyTheFiveHourWindowIsForecast() {
        var history = UsageHistory()
        for (minutesAgo, pct) in [(40.0, 29.0), (30, 36), (20, 42), (10, 49), (0, 55)] {
            history = history.appending(makeSnapshot([("session", pct), ("weekly_all", pct)], fetchedAt: now.addingTimeInterval(-minutesAgo * 60),
                                                     resetsAt: now.addingTimeInterval(4 * 3600)))
        }
        let snapshot = makeSnapshot([("session", 55), ("weekly_all", 55)], fetchedAt: now, resetsAt: now.addingTimeInterval(4 * 3600))
        let f = PaceForecaster.forecasts(history: history, snapshot: snapshot, now: now)
        #expect(f.count == 1)
        #expect(minutes(f["session"] ?? .unavailable) != nil)
        #expect(f["weekly_all"] == nil)
    }
}
