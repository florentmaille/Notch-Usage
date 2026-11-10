import Foundation
import Testing
@testable import NotchUsageCore

@Suite("RecoveryGate")
struct RecoveryGateTests {
    let t0 = Date.iso("2026-11-01T10:00:00Z")

    @Test func firstAttemptAllowed() {
        var gate = RecoveryGate()
        let first = gate.allow(at: t0)
        #expect(first)
    }

    @Test func secondAttemptWithinMinimumIntervalRefused() {
        var gate = RecoveryGate()
        _ = gate.allow(at: t0)
        let after1s = gate.allow(at: t0.addingTimeInterval(1))
        let after59s = gate.allow(at: t0.addingTimeInterval(59))
        #expect(!after1s && !after59s)
    }

    @Test func attemptAfterIntervalAllowed() {
        var gate = RecoveryGate()
        _ = gate.allow(at: t0)
        let after60s = gate.allow(at: t0.addingTimeInterval(60))
        #expect(after60s)
    }

    @Test func refusedAttemptDoesNotExtendWindow() {
        var gate = RecoveryGate()
        _ = gate.allow(at: t0)
        _ = gate.allow(at: t0.addingTimeInterval(30))
        let after61s = gate.allow(at: t0.addingTimeInterval(61))
        #expect(after61s)
    }

    /// Horloge reculée (changement de fuseau, synchronisation) : la reprise n'attend pas le temps reculé en plus.
    @Test func aClockSetBackDoesNotBlockRecovery() {
        var gate = RecoveryGate()
        let t = Date.iso("2026-11-01T10:00:00Z")
        let first = gate.allow(at: t)
        let afterStepBack = gate.allow(at: t.addingTimeInterval(-3600))
        let rightAfter = gate.allow(at: t.addingTimeInterval(-3590))
        #expect(first && afterStepBack && !rightAfter)
    }
}
