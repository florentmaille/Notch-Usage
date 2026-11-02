import Foundation
import Testing
@testable import NotchUsageCore

@Suite("ForecastDebouncer (003)")
struct ForecastDebouncerTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    var t1: Forecast { .blockAt(now.addingTimeInterval(40 * 60)) }
    var t2: Forecast { .blockAt(now.addingTimeInterval(42 * 60)) }

    @Test func switchingToBlockNeedsTwoConsecutiveCandidates() {
        var d = ForecastDebouncer()
        #expect(d.push(["session": .holdsUntilReset])["session"] == .holdsUntilReset)
        #expect(d.push(["session": t1])["session"] == .holdsUntilReset)
        #expect(d.push(["session": t2])["session"] == t2)
    }

    @Test func switchingBackToHoldsNeedsTwoConsecutiveCandidates() {
        var d = ForecastDebouncer()
        _ = d.push(["session": t1]); _ = d.push(["session": t1])
        #expect(d.push(["session": .holdsUntilReset])["session"] == t1)
        #expect(d.push(["session": .holdsUntilReset])["session"] == .holdsUntilReset)
    }

    @Test func blockDateRefreshesImmediately() {
        var d = ForecastDebouncer()
        _ = d.push(["session": t1]); _ = d.push(["session": t1])
        #expect(d.push(["session": t2])["session"] == t2)
    }

    @Test func unavailableAppliesImmediatelyAndResetsPending() {
        var d = ForecastDebouncer()
        _ = d.push(["session": t1]); _ = d.push(["session": t1])
        #expect(d.push(["session": .unavailable])["session"] == .unavailable)
        #expect(d.push(["session": .holdsUntilReset])["session"] == .holdsUntilReset)
        _ = d.push(["session": t1])
        _ = d.push(["session": .unavailable])
        #expect(d.push(["session": t2])["session"] == t2)
    }

    @Test func aCounterCandidateResetsTheStreak() {
        var d = ForecastDebouncer()
        _ = d.push(["session": .holdsUntilReset])
        _ = d.push(["session": t1])
        _ = d.push(["session": .holdsUntilReset])
        #expect(d.push(["session": t2])["session"] == .holdsUntilReset)
    }

    @Test func limitsAreIndependentAndDroppedWhenAbsent() {
        var d = ForecastDebouncer()
        _ = d.push(["session": t1, "weekly_all": .holdsUntilReset])
        let shown = d.push(["session": t1])
        #expect(shown["session"] == t1)
        #expect(shown["weekly_all"] == nil)
    }
}
