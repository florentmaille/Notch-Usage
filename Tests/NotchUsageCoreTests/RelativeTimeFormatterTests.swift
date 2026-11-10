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

@Suite("RelativeTimeFormatter - français (002)")
struct RelativeTimeFormatterFrenchTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    func until(_ seconds: TimeInterval) -> String {
        RelativeTimeFormatter.untilReset(now.addingTimeInterval(seconds), now: now, language: .french)
    }

    @Test func untilReset() {
        #expect(until(2 * 3600 + 14 * 60) == "dans 2 h 14 min")
        #expect(until(25 * 60) == "dans 25 min")
        #expect(until(30) == "dans 1 min")
        #expect(until(4 * 86400 + 3 * 3600 + 20 * 60) == "dans 4 j 3 h")
        #expect(until(-10) == "réinitialisation imminente")
        #expect(RelativeTimeFormatter.untilReset(nil, now: now, language: .french) == "—")
    }

    @Test func age() {
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-20), now: now, language: .french) == "à l'instant")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-12 * 60), now: now, language: .french) == "il y a 12 min")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-3 * 3600), now: now, language: .french) == "il y a 3 h")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-2 * 86400), now: now, language: .french) == "il y a 2 j")
    }

    @Test func englishDefaultUnchanged() {
        #expect(RelativeTimeFormatter.untilReset(now.addingTimeInterval(4 * 86400 + 3 * 3600), now: now, language: .english) == "in 4d 3h")
        #expect(RelativeTimeFormatter.age(now.addingTimeInterval(-2 * 86400), now: now) == "2 d ago")
    }

    @Test func languageFromCode() {
        #expect(InterfaceLanguage(code: "fr") == .french)
        #expect(InterfaceLanguage(code: "fr-CA") == .french)
        #expect(InterfaceLanguage(code: "fr_BE") == .french)
        #expect(InterfaceLanguage(code: "en") == .english)
        #expect(InterfaceLanguage(code: "de") == .english)
        #expect(InterfaceLanguage(code: nil) == .english)
    }
}

@Suite("RelativeTimeFormatter - encoche (003)")
struct RelativeTimeFormatterCompactTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    func en(_ s: TimeInterval) -> String { RelativeTimeFormatter.duration(until: now.addingTimeInterval(s), now: now) }
    func fr(_ s: TimeInterval) -> String { RelativeTimeFormatter.duration(until: now.addingTimeInterval(s), now: now, language: .french) }

    @Test func englishDurations() {
        #expect(en(2 * 3600 + 14 * 60) == "2h 14m")
        #expect(en(3600 + 2 * 60) == "1h 02m")
        #expect(en(25 * 60) == "25m")
        #expect(en(30) == "1m")
        #expect(en(3 * 86400 + 5 * 3600 + 20 * 60) == "3d 5h")
        #expect(en(-10) == "pending")
    }

    @Test func frenchDurations() {
        #expect(fr(2 * 3600 + 14 * 60) == "2 h 14")
        #expect(fr(3600 + 2 * 60) == "1 h 02")
        #expect(fr(25 * 60) == "25 min")
        #expect(fr(30) == "1 min")
        #expect(fr(3 * 86400 + 5 * 3600 + 20 * 60) == "3 j 5 h")
        #expect(fr(-10) == "imminent")
    }

    @Test func blockLabelUsesClockTimeUnderAnHour() {
        let soon = now.addingTimeInterval(40 * 60)
        #expect(RelativeTimeFormatter.blockLabel(soon, now: now, language: .french, locale: Locale(identifier: "fr_FR"), timeZone: utc) == "10:40")
        #expect(RelativeTimeFormatter.blockLabel(soon, now: now, locale: Locale(identifier: "en_US"), timeZone: utc).hasPrefix("10:40"))
        let later = now.addingTimeInterval(2 * 3600 + 14 * 60)
        #expect(RelativeTimeFormatter.blockLabel(later, now: now, language: .french, locale: Locale(identifier: "fr_FR"), timeZone: utc) == "2 h 14")
        #expect(RelativeTimeFormatter.blockLabel(later, now: now, locale: Locale(identifier: "en_US"), timeZone: utc) == "2h 14m")
    }

    /// Une date aberrante ne fait pas planter la conversion en minutes.
    @Test func absurdDatesDoNotTrap() {
        let now = Date(timeIntervalSince1970: 1_762_000_000)
        let far = Date(timeIntervalSinceReferenceDate: 1e30), past = Date(timeIntervalSinceReferenceDate: -1e30)
        #expect(!RelativeTimeFormatter.untilReset(far, now: now).isEmpty)
        #expect(!RelativeTimeFormatter.duration(until: far, now: now).isEmpty)
        #expect(!RelativeTimeFormatter.age(past, now: now).isEmpty)
        #expect(!RelativeTimeFormatter.blockLabel(far, now: now, timeZone: TimeZone(identifier: "UTC")!).isEmpty)
    }
}
