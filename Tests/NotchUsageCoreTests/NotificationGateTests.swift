import Foundation
import Testing
@testable import NotchUsageCore

@Suite("NotificationGate (008)")
struct NotificationGateTests {
    let reset = Date.iso("2026-11-01T12:00:00Z")

    @Test func firesOncePerLimitReasonAndPeriod() {
        var gate = NotificationGate()
        let first = gate.shouldNotify(limitID: "session", reason: .imminent, resetsAt: reset)
        let again = gate.shouldNotify(limitID: "session", reason: .imminent, resetsAt: reset)
        let otherReason = gate.shouldNotify(limitID: "session", reason: .exhausted, resetsAt: reset)
        let otherLimit = gate.shouldNotify(limitID: "weekly_all", reason: .imminent, resetsAt: reset)
        #expect(first && !again && otherReason && otherLimit)
    }

    @Test func aNewPeriodFiresAgain() {
        var gate = NotificationGate()
        let first = gate.shouldNotify(limitID: "session", reason: .imminent, resetsAt: reset)
        let next = gate.shouldNotify(limitID: "session", reason: .imminent, resetsAt: reset.addingTimeInterval(5 * 3600))
        let old = gate.shouldNotify(limitID: "session", reason: .imminent, resetsAt: reset)
        #expect(first && next && !old)
    }

    /// L'API fait varier `resets_at` de quelques fractions de seconde d'un relevé à l'autre (09:59:59 puis
    /// 10:00:00 pour la même fenêtre) : c'est la même période, une seule notification.
    @Test func resetJitterIsTheSamePeriod() {
        var gate = NotificationGate()
        let first = gate.shouldNotify(limitID: "session", reason: .exhausted, resetsAt: reset)
        let later = gate.shouldNotify(limitID: "session", reason: .exhausted, resetsAt: reset.addingTimeInterval(0.4))
        let earlier = gate.shouldNotify(limitID: "session", reason: .exhausted, resetsAt: reset.addingTimeInterval(-0.9))
        #expect(first && !later && !earlier)
    }

    /// Un `resets_at` absent le temps d'un relevé ne relance pas la notification de la période déjà signalée.
    @Test func unknownAndKnownPeriodsEachFireOnce() {
        var gate = NotificationGate()
        let known = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: reset)
        let unknown = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        let knownAgain = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: reset.addingTimeInterval(0.2))
        let unknownAgain = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        #expect(known && unknown && !knownAgain && !unknownAgain)
    }

    @Test func unknownPeriodStillDedupes() {
        var gate = NotificationGate()
        let first = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        let again = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        #expect(first && !again)
    }
}
