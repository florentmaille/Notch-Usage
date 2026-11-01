import Foundation
import Testing
@testable import NotchUsageCore

@Suite("Freshness")
struct FreshnessTests {
    let fetched = Date.iso("2026-11-01T10:00:00Z")
    let interval = Duration.seconds(180)

    @Test func freshUnderTwoIntervals() {
        let s = makeSnapshot([("session", 10)], fetchedAt: fetched)
        #expect(Freshness.of(s, now: fetched.addingTimeInterval(359), interval: interval) == .fresh)
    }

    @Test func agingFromTwoIntervals() {
        let s = makeSnapshot([("session", 10)], fetchedAt: fetched)
        #expect(Freshness.of(s, now: fetched.addingTimeInterval(360), interval: interval) == .aging)
        #expect(Freshness.of(s, now: fetched.addingTimeInterval(1799), interval: interval) == .aging)
    }

    @Test func staleFromThirtyMinutesEvenWithLongInterval() {
        let s = makeSnapshot([("session", 10)], fetchedAt: fetched)
        #expect(Freshness.of(s, now: fetched.addingTimeInterval(1800), interval: interval) == .stale)
        #expect(Freshness.of(s, now: fetched.addingTimeInterval(1800), interval: .seconds(900)) == .stale)
    }
}
