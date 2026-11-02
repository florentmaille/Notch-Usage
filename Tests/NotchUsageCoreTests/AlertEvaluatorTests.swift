import Foundation
import Testing
@testable import NotchUsageCore

@Suite("AlertEvaluator")
struct AlertEvaluatorTests {
    let evaluator = AlertEvaluator()
    let settings = AlertSettings()
    let reset = Date.iso("2026-11-01T14:00:00Z")

    func snap(_ pct: Double, resetsAt: Date? = nil) -> UsageSnapshot {
        makeSnapshot([("session", pct)], resetsAt: resetsAt ?? reset)
    }

    @Test func warningFiresOnceWhenCrossing80() {
        let (l1, e1) = evaluator.evaluate(snap(78), settings: settings, ledger: AlertLedger())
        #expect(e1.isEmpty)
        let (l2, e2) = evaluator.evaluate(snap(81), settings: settings, ledger: l1)
        #expect(e2 == [AlertEvent(limitID: "session", level: .warning)])
        let (_, e3) = evaluator.evaluate(snap(85), settings: settings, ledger: l2)
        #expect(e3.isEmpty)
    }

    /// L'API renvoie resets_at avec des fractions de seconde qui varient d'un appel à l'autre,
    /// et l'encodage du registre sur disque les tronque : même période malgré l'écart.
    @Test func jitteredResetTimeIsSamePeriod() throws {
        let (l1, e1) = evaluator.evaluate(snap(85, resetsAt: reset.addingTimeInterval(-0.488)), settings: settings, ledger: AlertLedger())
        #expect(e1.count == 1)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let reloaded = try decoder.decode(AlertLedger.self, from: encoder.encode(l1))
        let (l2, e2) = evaluator.evaluate(snap(86, resetsAt: reset.addingTimeInterval(-0.912)), settings: settings, ledger: reloaded)
        #expect(e2.isEmpty)
        let (_, e3) = evaluator.evaluate(snap(87, resetsAt: reset.addingTimeInterval(1)), settings: settings, ledger: l2)
        #expect(e3.isEmpty)
    }

    @Test func nextWindowIsNewPeriod() {
        let (l1, _) = evaluator.evaluate(snap(85), settings: settings, ledger: AlertLedger())
        let (_, e2) = evaluator.evaluate(snap(85, resetsAt: reset.addingTimeInterval(5 * 3600)), settings: settings, ledger: l1)
        #expect(e2 == [AlertEvent(limitID: "session", level: .warning)])
    }

    @Test func criticalFiresWhenCrossing95() {
        let (l1, _) = evaluator.evaluate(snap(93), settings: settings, ledger: AlertLedger())
        let (_, e2) = evaluator.evaluate(snap(96), settings: settings, ledger: l1)
        #expect(e2 == [AlertEvent(limitID: "session", level: .critical)])
    }

    @Test func jumpingStraightToCriticalEmitsCriticalOnly() {
        let (_, e) = evaluator.evaluate(snap(97), settings: settings, ledger: AlertLedger())
        #expect(e == [AlertEvent(limitID: "session", level: .critical)])
    }

    @Test func oscillationAroundThresholdDoesNotRefire() {
        var ledger = AlertLedger()
        var events: [AlertEvent] = []
        for pct in [81.0, 79, 82, 78, 83] {
            let (l, e) = evaluator.evaluate(snap(pct), settings: settings, ledger: ledger)
            ledger = l
            events += e
        }
        #expect(events.count == 1)
    }

    @Test func newPeriodResetsLedger() {
        let (l1, e1) = evaluator.evaluate(snap(85), settings: settings, ledger: AlertLedger())
        #expect(e1.count == 1)
        let nextReset = reset.addingTimeInterval(5 * 3600)
        let (_, e2) = evaluator.evaluate(snap(85, resetsAt: nextReset), settings: settings, ledger: l1)
        #expect(e2 == [AlertEvent(limitID: "session", level: .warning)])
    }

    @Test func disabledEmitsNothing() {
        var s = settings
        s.enabled = false
        let (_, e) = evaluator.evaluate(snap(99), settings: s, ledger: AlertLedger())
        #expect(e.isEmpty)
        #expect(evaluator.level(for: snap(99), settings: s) == .none)
    }

    @Test func levelIsMaxOfCrossedThresholds() {
        #expect(evaluator.level(for: snap(10), settings: settings) == .none)
        #expect(evaluator.level(for: snap(80), settings: settings) == .warning)
        #expect(evaluator.level(for: snap(95), settings: settings) == .critical)
        let multi = makeSnapshot([("session", 50), ("weekly_all", 90)], resetsAt: reset)
        #expect(evaluator.level(for: multi, settings: settings) == .warning)
    }

    @Test func customThresholds() {
        let s = AlertSettings(enabled: true, warningThreshold: 50, criticalThreshold: 70)
        let (_, e) = evaluator.evaluate(snap(55), settings: s, ledger: AlertLedger())
        #expect(e == [AlertEvent(limitID: "session", level: .warning)])
    }

    @Test func thresholdInvariantEnforced() {
        let s = AlertSettings(enabled: true, warningThreshold: 95, criticalThreshold: 80)
        #expect(s.warningThreshold < s.criticalThreshold)
        #expect(s.warningThreshold >= 1 && s.criticalThreshold <= 100)
        let low = AlertSettings(enabled: true, warningThreshold: 0, criticalThreshold: 150)
        #expect(low.warningThreshold == 1 && low.criticalThreshold == 100)
    }

    @Test func ledgerDroppedForLimitsThatDisappeared() {
        let (l1, _) = evaluator.evaluate(snap(85), settings: settings, ledger: AlertLedger())
        let other = makeSnapshot([("weekly_all", 10)], resetsAt: reset)
        let (l2, _) = evaluator.evaluate(other, settings: settings, ledger: l1)
        #expect(l2.entries["session"] == nil)
    }
}
