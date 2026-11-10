import Foundation
import Testing
@testable import NotchUsageCore

@Suite("HourlyHistory (021)")
struct HourlyHistoryTests {
    let reset = Date.iso("2026-11-12T22:00:00Z")

    func snap(_ usage: Double, at: Date, reset: Date? = nil) -> UsageSnapshot {
        UsageSnapshot(limits: [UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: usage, resetsAt: reset ?? self.reset)],
                      fetchedAt: at)
    }

    @Test func oneReadingPerHour() {
        let h = HourlyHistory()
            .appending(snap(10, at: .iso("2026-11-10T09:05:00Z")))
            .appending(snap(11, at: .iso("2026-11-10T09:40:00Z")))
            .appending(snap(12, at: .iso("2026-11-10T10:02:00Z")))
        let r = h.readings(for: "weekly_all")
        #expect(r.map(\.utilization) == [11, 12])
        #expect(r.first?.at == .iso("2026-11-10T09:40:00Z"))
    }

    @Test func newPeriodDropsOlderReadings() {
        let h = HourlyHistory()
            .appending(snap(80, at: .iso("2026-11-05T09:00:00Z"), reset: .iso("2026-11-05T22:00:00Z")))
            .appending(snap(2, at: .iso("2026-11-06T09:00:00Z")))
        #expect(h.readings(for: "weekly_all").map(\.utilization) == [2])
    }

    @Test func keepsEightDays() {
        var h = HourlyHistory()
        let start = Date.iso("2026-11-01T00:00:00Z")
        for hour in 0..<(10 * 24) {
            h = h.appending(snap(1, at: start.addingTimeInterval(Double(hour) * 3600), reset: nil))
        }
        let r = h.readings(for: "weekly_all")
        #expect(r.count == 8 * 24 + 1)
        #expect(r.first!.at == start.addingTimeInterval(Double(10 * 24 - 1 - 8 * 24) * 3600))
    }

    @Test func readingsAreKeptPerLimit() {
        let s = UsageSnapshot(limits: [
            UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: 30, resetsAt: nil),
            UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: 20, resetsAt: reset),
        ], fetchedAt: .iso("2026-11-10T09:00:00Z"))
        let h = HourlyHistory().appending(s)
        #expect(h.readings(for: "session").map(\.utilization) == [30])
        #expect(h.readings(for: "weekly_all").map(\.utilization) == [20])
    }

    @Test func codableRoundTrip() throws {
        let h = HourlyHistory().appending(snap(10, at: .iso("2026-11-10T09:05:00Z")))
        let data = try JSONEncoder().encode(h)
        #expect(try JSONDecoder().decode(HourlyHistory.self, from: data) == h)
    }
}
