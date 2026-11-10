import Foundation
import Testing
@testable import NotchUsageCore

/// Semaine de la planche C1 : reset jeudi 12 novembre 22:00 UTC, on est lundi 9 à 16:00 (90 h écoulées).
@Suite("WeekCurve (021)")
struct WeekCurveTests {
    let reset = Date.iso("2026-11-12T22:00:00Z")
    let now = Date.iso("2026-11-09T16:00:00Z")
    var weekStart: Date { reset.addingTimeInterval(-PaceForecaster.weekPeriod) }
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func limit(_ usage: Double, kind: LimitKind = .weeklyAll, reset: Date? = nil) -> UsageLimit {
        UsageLimit(id: "weekly_all", kind: kind, modelName: nil, utilization: usage, resetsAt: reset ?? self.reset)
    }

    func history(_ points: [(TimeInterval, Double)], reset: Date? = nil) -> HourlyHistory {
        points.reduce(HourlyHistory()) { h, p in
            h.appending(UsageSnapshot(limits: [limit(p.1, reset: reset)], fetchedAt: weekStart.addingTimeInterval(p.0 * 3600)))
        }
    }

    func curve(_ usage: Double, _ h: HourlyHistory, forecast: Forecast?) -> WeekCurve.State? {
        WeekCurve.make(limit: limit(usage), history: h, forecast: forecast, now: now, calendar: utc)
    }

    @Test func onlyWeeklyAllWithAReset() {
        let h = history([(10, 5)])
        #expect(WeekCurve.make(limit: limit(5, kind: .weeklyModel), history: h, forecast: nil, now: now, calendar: utc) == nil)
        #expect(WeekCurve.make(limit: limit(5, kind: .rollingFiveHour), history: h, forecast: nil, now: now, calendar: utc) == nil)
        let noReset = UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: 5, resetsAt: nil)
        #expect(WeekCurve.make(limit: noReset, history: h, forecast: nil, now: now, calendar: utc) == nil)
    }

    @Test func pointsAreWeekFractionsPlusNow() throws {
        guard case .curve(let c)? = curve(23, history([(0, 0), (42, 9), (84, 11)]), forecast: .holdsUntilReset) else {
            Issue.record("expected a curve"); return
        }
        #expect(c.points.map(\.usage) == [0, 9, 11, 23])
        #expect(c.points.first?.fraction == 0)
        #expect(abs(c.points[1].fraction - 42.0 / 168) < 1e-9)
        #expect(abs(c.now.fraction - 90.0 / 168) < 1e-9 && c.now.usage == 23)
    }

    @Test func notEnoughReadings() {
        #expect(curve(23, HourlyHistory(), forecast: .holdsUntilReset) == .notEnough)
    }

    /// FR-007 : il faut 2 relevés depuis le reset. Le point « maintenant » reprend le dernier relevé, déjà dans
    /// l'historique : le compter rendait le message inatteignable dans l'app.
    @Test func aSingleReadingIsNotEnough() {
        #expect(curve(23, history([(89.9, 23)]), forecast: .holdsUntilReset) == .notEnough)
    }

    /// La prévision affichée peut dater du relevé précédent (anti-rebond) : « tient » ne dépasse jamais 100 %.
    @Test func holdsProjectionIsCappedAt100() {
        guard case .curve(let c)? = curve(60, history([(10, 20), (50, 45)]), forecast: .holdsUntilReset) else { Issue.record("curve"); return }
        #expect(c.projection == .holds(atReset: 100))
    }

    @Test func holdsProjectsToTheResetWithThe016Formula() {
        guard case .curve(let c)? = curve(23, history([(10, 2), (50, 12)]), forecast: .holdsUntilReset) else { Issue.record("curve"); return }
        guard case .holds(let atReset) = c.projection else { Issue.record("holds"); return }
        #expect(abs(atReset - 23 * 168.0 / 90) < 1e-9)
        #expect(c.tint == .calm)
    }

    @Test func blockProjectsTo100AtTheBlockTime() {
        let block = Date.iso("2026-11-11T14:00:00Z")   // dans 46 h : palier lointain
        guard case .curve(let c)? = curve(70, history([(10, 20), (50, 45)]), forecast: .blockAt(block)) else { Issue.record("curve"); return }
        guard case .blocks(let at, let fraction) = c.projection else { Issue.record("blocks"); return }
        #expect(at == block)
        #expect(abs(fraction - block.timeIntervalSince(weekStart) / PaceForecaster.weekPeriod) < 1e-9)
        #expect(c.tint == .far)
        let soon = curve(95, history([(10, 20), (50, 45)]), forecast: .blockAt(now.addingTimeInterval(20 * 60)))
        guard case .curve(let s)? = soon else { Issue.record("curve"); return }
        #expect(s.tint == .imminent)
    }

    @Test func unavailableHasNoProjection() {
        guard case .curve(let c)? = curve(23, history([(10, 2), (50, 12)]), forecast: .unavailable) else { Issue.record("curve"); return }
        #expect(c.projection == .none)
    }

    @Test func daysAreLocalMidnights() {
        guard case .curve(let c)? = curve(23, history([(10, 2), (50, 12)]), forecast: nil) else { Issue.record("curve"); return }
        // Semaine du jeudi 5 22:00 au jeudi 12 22:00 : minuits du vendredi 6 au jeudi 12.
        #expect(c.days.count == 7)
        #expect(abs(c.days[0].fraction - 2.0 / 168) < 1e-9)
        #expect(c.days[0].date == .iso("2026-11-06T00:00:00Z"))
        #expect(c.days.last?.date == .iso("2026-11-12T00:00:00Z"))
        #expect(c.todayIndex == 3)   // lundi 9
    }

    /// Reset à minuit local : la semaine compte 7 journées entières, la première commence au reset.
    @Test func aResetAtLocalMidnightShowsSevenDays() {
        let midnight = Date.iso("2026-11-13T00:00:00Z")
        let start = midnight.addingTimeInterval(-PaceForecaster.weekPeriod)
        let h = [10.0, 50].reduce(HourlyHistory()) { h, hours in
            h.appending(UsageSnapshot(limits: [limit(5, reset: midnight)], fetchedAt: start.addingTimeInterval(hours * 3600)))
        }
        let state = WeekCurve.make(limit: limit(23, reset: midnight), history: h, forecast: nil, now: now, calendar: utc)
        guard case .curve(let c)? = state else { Issue.record("curve"); return }
        #expect(c.days.count == 7)
        #expect(c.days.first?.date == start && c.days.first?.fraction == 0)
        #expect(c.days.last?.date == .iso("2026-11-12T00:00:00Z"))
        #expect(c.todayIndex == 3)   // lundi 9
    }

    @Test func readingsOfAnotherPeriodAreIgnored() {
        let old = history([(10, 80)], reset: .iso("2026-11-05T22:00:00Z"))
        #expect(curve(23, old, forecast: .holdsUntilReset) == .notEnough)
    }
}
