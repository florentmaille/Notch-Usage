import Foundation
import Testing
@testable import NotchUsageCore

@Suite("UsageHistory (003)")
struct UsageHistoryTests {
    let now = Date.iso("2026-11-01T10:00:00Z")

    func snap(_ offset: TimeInterval, session: Double, reset: TimeInterval = 4 * 3600) -> UsageSnapshot {
        UsageSnapshot(limits: [
            UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: session, resetsAt: now.addingTimeInterval(reset)),
            UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: 20, resetsAt: now.addingTimeInterval(3 * 86400)),
        ], fetchedAt: now.addingTimeInterval(offset))
    }

    @Test func appendsOneReadingPerLimit() {
        let h = UsageHistory().appending(snap(0, session: 40))
        #expect(h.readings.count == 2)
        #expect(h.readings(for: "session").map(\.utilization) == [40])
        #expect(h.readings(for: "session").first?.resetsAt == now.addingTimeInterval(4 * 3600))
    }

    @Test func keepsTwoHoursAfterTheLatestReading() {
        var h = UsageHistory()
        for minutes in stride(from: -150, through: 0, by: 30) { h = h.appending(snap(Double(minutes) * 60, session: 40)) }
        #expect(h.readings(for: "session").count == 5)
        #expect(h.readings(for: "session").first?.at == now.addingTimeInterval(-120 * 60))
    }

    @Test func dropsReadingsOfAPreviousPeriod() {
        var h = UsageHistory().appending(snap(-600, session: 90))
        h = h.appending(snap(0, session: 5, reset: 9 * 3600))
        #expect(h.readings(for: "session").map(\.utilization) == [5])
        #expect(h.readings(for: "weekly_all").count == 2)
    }

    @Test func toleratesJitteredResetTimes() {
        var h = UsageHistory().appending(snap(-600, session: 40))
        h = h.appending(snap(0, session: 44, reset: 4 * 3600 + 30))
        #expect(h.readings(for: "session").count == 2)
    }

    @Test func readingsAreSortedByDate() {
        var h = UsageHistory().appending(snap(0, session: 44))
        h = h.appending(snap(-600, session: 40))
        #expect(h.readings(for: "session").map(\.utilization) == [40, 44])
    }

    @Test func codableRoundTrip() throws {
        let h = UsageHistory().appending(snap(-600, session: 40)).appending(snap(0, session: 44))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(UsageHistory.self, from: encoder.encode(h))
        #expect(back == h)
    }
}
