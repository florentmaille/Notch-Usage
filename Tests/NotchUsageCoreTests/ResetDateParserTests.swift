import Foundation
import Testing
@testable import NotchUsageCore

@Suite("ResetDateParser")
struct ResetDateParserTests {
    @Test func iso8601WithZ() {
        #expect(ResetDateParser.parse("2026-11-01T14:00:00Z") == .iso("2026-11-01T14:00:00Z"))
    }

    @Test func iso8601WithOffset() {
        #expect(ResetDateParser.parse("2026-11-01T16:00:00+02:00") == .iso("2026-11-01T14:00:00Z"))
    }

    @Test func iso8601WithFraction() {
        let d = ResetDateParser.parse("2026-11-01T14:00:00.250Z")!
        #expect(abs(d.timeIntervalSince(.iso("2026-11-01T14:00:00Z")) - 0.25) < 0.001)
    }

    @Test func epochSeconds() {
        #expect(ResetDateParser.parse(1762005600) == Date(timeIntervalSince1970: 1_762_005_600))
        #expect(ResetDateParser.parse(1762005600.0) == Date(timeIntervalSince1970: 1_762_005_600))
    }

    @Test func epochMilliseconds() {
        #expect(ResetDateParser.parse(1762005600000) == Date(timeIntervalSince1970: 1_762_005_600))
        #expect(ResetDateParser.parse(1762005600000.0) == Date(timeIntervalSince1970: 1_762_005_600))
    }

    @Test func numericStringEpoch() {
        #expect(ResetDateParser.parse("1762005600") == Date(timeIntervalSince1970: 1_762_005_600))
    }

    @Test func emptyAndNull() {
        #expect(ResetDateParser.parse("") == nil)
        #expect(ResetDateParser.parse(nil) == nil)
        #expect(ResetDateParser.parse(NSNull()) == nil)
        #expect(ResetDateParser.parse("not a date") == nil)
    }
}
