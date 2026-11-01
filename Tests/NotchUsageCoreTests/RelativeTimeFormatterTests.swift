import Foundation
import Testing
@testable import NotchUsageCore

@Suite("RelativeTimeFormatter")
struct RelativeTimeFormatterTests {
    let now = Date.iso("2026-11-01T10:00:00Z")

    @Test func hoursAndMinutes() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(2 * 3600 + 14 * 60), now: now) == "in 2h 14m")
    }

    @Test func minutesOnly() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(25 * 60), now: now) == "in 25m")
    }

    @Test func underAMinuteRoundsUp() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(45), now: now) == "in 1m")
    }

    @Test func daysAndHours() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(4 * 86400 + 3 * 3600 + 20 * 60), now: now) == "in 4d 3h")
    }

    @Test func pastIsPending() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(-10), now: now) == "reset pending")
    }

    @Test func nilIsDash() {
        #expect(RelativeTimeFormatter.untilReset(nil, now: now) == "—")
    }

    @Test func ageText() {
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-12 * 60), now: now) == "12 min ago")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-30), now: now) == "just now")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-3 * 3600), now: now) == "3 h ago")
    }
}
