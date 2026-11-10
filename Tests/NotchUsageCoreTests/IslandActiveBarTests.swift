import Foundation
import Testing
@testable import NotchUsageCore

/// 019 : avec un écran sans encoche branché, l'île porte le pourcentage au calme, où que l'on travaille.
@Suite("Island next to a plain screen (019)")
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
        let s = signal(42).carryingPercent(strings: CompactStripTests.english)
        #expect(s.island == Island(leading: .gauge(value: 42, tint: .calm), trailing: .percent("42%")))
    }

    @Test func aDeadlineOrClaudeKeepsItsEarOnTheMac() {
        let tier = signal(70, forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))])
        #expect(tier.carryingPercent(strings: CompactStripTests.english).island == tier.island)
        let claude = signal(42, attention: NotchSignal.Attention(kind: .approval, count: 1, arrivedAt: now, entries: []))
        #expect(claude.carryingPercent(strings: CompactStripTests.english).island == claude.island)
    }

    @Test func barContentKeepsTheLimitDeadlineAfterAdaptation() {
        let tier = signal(70, forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))]).carryingPercent(strings: CompactStripTests.english)
        #expect(BarContent.make(signal: tier, now: now, strings: CompactStripTests.english).text == "1:05")
    }
}
