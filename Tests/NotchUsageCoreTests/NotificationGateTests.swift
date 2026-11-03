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

    @Test func unknownPeriodStillDedupes() {
        var gate = NotificationGate()
        let first = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        let again = gate.shouldNotify(limitID: "session", reason: .critical, resetsAt: nil)
        #expect(first && !again)
    }
}
