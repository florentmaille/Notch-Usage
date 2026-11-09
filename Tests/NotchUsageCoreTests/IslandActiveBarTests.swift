import Foundation
import Testing
@testable import NotchUsageCore

/// 019 : avec un écran sans encoche branché, l'île suit la barre active comme la pastille.
@Suite("Island and active menu bar (019)")
struct IslandActiveBarTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    typealias Island = NotchSignal.Island

    func signal(_ session: Double, forecasts: [String: Forecast] = [:], attention: NotchSignal.Attention? = nil) -> NotchSignal {
        let snap = makeSnapshot([("session", session), ("weekly_all", 20)], fetchedAt: now, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60))
        let d = DisplayStateReducer.reduce(state: .idle(snap), connected: true, settings: RefreshSettings(), alertLevel: .none, layout: .fallback,
                                           fullscreen: false, hover: false, now: now, forecasts: forecasts)
        return NotchSignal.make(display: d, now: now, language: .english, strings: CompactStripTests.english, locale: Locale(identifier: "en_US"),
                                timeZone: utc, attention: attention)
    }

    @Test func workingOnTheMacShowsThePercentRightOfTheNotch() {
        let s = signal(42).adapted(to: .island, strings: CompactStripTests.english)
        #expect(s.island == Island(leading: .gauge(value: 42, tint: .calm), trailing: .percent("42%")))
    }

    @Test func aDeadlineOrClaudeKeepsItsEarOnTheMac() {
        let tier = signal(70, forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))])
        #expect(tier.adapted(to: .island, strings: CompactStripTests.english).island == tier.island)
        let claude = signal(42, attention: NotchSignal.Attention(kind: .approval, count: 1, arrivedAt: now, entries: []))
        #expect(claude.adapted(to: .island, strings: CompactStripTests.english).island == claude.island)
    }

    @Test func workingElsewhereFoldsTheWholeIsland() {
        let tier = signal(70, forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))],
                          attention: NotchSignal.Attention(kind: .approval, count: 1, arrivedAt: now, entries: []))
        let folded = tier.adapted(to: .elsewhere, strings: CompactStripTests.english)
        #expect(folded.island == Island(leading: tier.island.leading, folded: true))
        #expect(folded.island.trailing == nil && folded.island.badge == nil)
        #expect(folded.accessibility == tier.accessibility && folded.pulse == tier.pulse)
    }

    @Test func unknownActiveBarChangesNothing() {
        let s = signal(42)
        #expect(s.adapted(to: nil, strings: CompactStripTests.english) == s)
    }

    @Test func barContentKeepsTheLimitDeadlineAfterAdaptation() {
        let tier = signal(70, forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))]).adapted(to: .elsewhere, strings: CompactStripTests.english)
        #expect(BarContent.make(signal: tier, now: now, strings: CompactStripTests.english).text == "1:05")
    }
}
