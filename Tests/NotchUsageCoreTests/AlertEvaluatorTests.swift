import Foundation
import Testing
@testable import NotchUsageCore

/// Seuils de repli : niveau d'une limite quand aucune prévision n'existe. « Une notification par limite et par
/// période » est tenu par `NotificationGate` (voir `NotificationGateTests`).
@Suite("AlertEvaluator")
struct AlertEvaluatorTests {
    let evaluator = AlertEvaluator()
    let settings = AlertSettings()

    func limit(_ pct: Double) -> UsageLimit { makeSnapshot([("session", pct)]).limits[0] }

    @Test func levelIsTheHighestCrossedThreshold() {
        #expect(evaluator.level(for: limit(10), settings: settings) == .none)
        #expect(evaluator.level(for: limit(79.9), settings: settings) == .none)
        #expect(evaluator.level(for: limit(80), settings: settings) == .warning)
        #expect(evaluator.level(for: limit(95), settings: settings) == .critical)
    }

    @Test func disabledGivesNoLevel() {
        var s = settings
        s.enabled = false
        #expect(evaluator.level(for: limit(99), settings: s) == .none)
    }

    @Test func customThresholds() {
        let s = AlertSettings(enabled: true, warningThreshold: 50, criticalThreshold: 70)
        #expect(evaluator.level(for: limit(49), settings: s) == .none)
        #expect(evaluator.level(for: limit(55), settings: s) == .warning)
        #expect(evaluator.level(for: limit(70), settings: s) == .critical)
    }

    @Test func thresholdInvariantEnforced() {
        let s = AlertSettings(enabled: true, warningThreshold: 95, criticalThreshold: 80)
        #expect(s.warningThreshold < s.criticalThreshold)
        #expect(s.warningThreshold >= 1 && s.criticalThreshold <= 100)
        let low = AlertSettings(enabled: true, warningThreshold: 0, criticalThreshold: 150)
        #expect(low.warningThreshold == 1 && low.criticalThreshold == 100)
    }

    @Test func levelOfEachLimitOfAReading() {
        let snap = makeSnapshot([("session", 30), ("weekly_all", 96)])
        #expect(evaluator.level(for: snap.limits[0], settings: settings) == .none)
        #expect(evaluator.level(for: snap.limits[1], settings: settings) == .critical)
    }
}
