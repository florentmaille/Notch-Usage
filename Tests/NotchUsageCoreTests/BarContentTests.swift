import Foundation
import Testing
@testable import NotchUsageCore

/// Une ligne du tableau « Contenu par état » de la spec 018 par test.
@Suite("BarContent (018)")
struct BarContentTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchLayout.fallback

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, forecasts: [String: Forecast] = [:]) -> DisplayState {
        DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level, layout: layout,
                                   fullscreen: false, hover: false, now: now, forecasts: forecasts)
    }

    func snap(_ session: Double, reset: TimeInterval = 2 * 3600 + 14 * 60) -> UsageSnapshot {
        makeSnapshot([("session", session), ("weekly_all", 20)], fetchedAt: now, resetsAt: now.addingTimeInterval(reset))
    }

    func content(_ d: DisplayState, attention: NotchSignal.Attention? = nil, at: Date? = nil) -> BarContent {
        let s = NotchSignal.make(display: d, now: now, language: .english, strings: CompactStripTests.english,
                                 locale: Locale(identifier: "en_US"), timeZone: utc, attention: attention)
        return BarContent.make(signal: s, now: at ?? now, strings: CompactStripTests.english)
    }

    func attention(_ kind: ClaudeWaitingKind, count: Int = 1, arrivedAt: Date? = nil) -> NotchSignal.Attention {
        NotchSignal.Attention(kind: kind, count: count, arrivedAt: arrivedAt ?? now.addingTimeInterval(-60),
                              entries: Array(repeating: .init(name: "Notch-Usage", kind: kind), count: count))
    }

    @Test func calmShowsMonochromeRingAndPercent() {
        let c = content(display(.idle(snap(42))))
        #expect(c.gauge == BarContent.Gauge(fraction: 0.42, tint: .calm, beats: false))
        #expect(c.text == "42%" && c.textEmphasis == .none)
        #expect(c.attention == nil && !c.attentionAsBadge)
    }

    @Test func tierShowsRemainingTime() {
        let c = content(display(.idle(snap(70)), forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))]))
        #expect(c.gauge?.tint == .far && c.gauge?.beats == false)
        #expect(c.text == "1:05" && c.textEmphasis == .none)
        let near = content(display(.idle(snap(80)), forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]))
        #expect(near.gauge?.tint == .near && near.text == "40\u{2032}")
    }

    @Test func imminentBeatsAndTextTurnsRed() {
        let c = content(display(.idle(snap(92)), forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))]))
        #expect(c.gauge == BarContent.Gauge(fraction: 0.92, tint: .imminent, beats: true))
        #expect(c.text == "8\u{2032}" && c.textEmphasis == .imminent)
    }

    @Test func exhaustedBeatsAndShowsBack() {
        let c = content(display(.idle(snap(100))))
        #expect(c.gauge == BarContent.Gauge(fraction: 1, tint: .exhausted, beats: true))
        #expect(c.text == "\u{21BB}2:14")
    }

    @Test func claudeWaitingAddsGlyphAndCount() {
        let c = content(display(.idle(snap(42))), attention: attention(.approval, count: 2))
        #expect(c.attention == BarContent.Attention(kind: .approval, count: "2", arrivalWord: nil))
        #expect(c.text == "42%" && !c.attentionAsBadge)
    }

    /// Spec US3 sc. 3 : au palier, le temps restant et le glyphe Claude cohabitent (l'île, elle, cède son oreille).
    @Test func tierKeepsRemainingTimeNextToClaude() {
        let c = content(display(.idle(snap(70)), forecasts: ["session": .blockAt(now.addingTimeInterval(2 * 3600 + 5 * 60))]),
                        attention: attention(.question))
        #expect(c.text == "2:05" && c.gauge?.tint == .far)
        #expect(c.attention?.kind == .question && !c.attentionAsBadge)
    }

    @Test func arrivalWordLastsFourSeconds() {
        let a = attention(.question, arrivedAt: now)
        #expect(content(display(.idle(snap(42))), attention: a, at: now.addingTimeInterval(2)).attention?.arrivalWord == "Question")
        #expect(content(display(.idle(snap(42))), attention: a, at: now.addingTimeInterval(5)).attention?.arrivalWord == nil)
    }

    @Test func imminentReducesClaudeToABadge() {
        let c = content(display(.idle(snap(92)), forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))]), attention: attention(.approval))
        #expect(c.attentionAsBadge && c.attention?.kind == .approval)
        #expect(c.text == "8\u{2032}")
    }

    @Test func withoutReadingShowsEmptyRing() {
        let c = content(display(.idle(nil), connected: false))
        #expect(c.gauge == nil && c.text == nil)
        let reauth = content(display(.reauthRequired(previous: nil)))
        #expect(reauth.gauge == nil && reauth.text == nil)
    }

    @Test func failedReadingKeepsMutedPercent() {
        let c = content(display(.failed(.server(503), previous: snap(42))))
        #expect(c.gauge == nil && c.text == "42%" && c.textEmphasis == .muted)
    }

    @Test func compactKeepsGaugeOnly() {
        let c = content(display(.idle(snap(42))), attention: attention(.approval)).compact
        #expect(c.gauge?.fraction == 0.42 && c.text == nil && c.attention == nil && !c.attentionAsBadge)
        #expect(c.isCompact)
    }

    @Test func menuBarItemDropsThePercentButKeepsDeadlinesAndClaude() {
        let calm = content(display(.idle(snap(42))), attention: attention(.approval, count: 2)).menuBarItem
        #expect(calm.text == nil && calm.gauge?.fraction == 0.42 && calm.attention?.count == "2")
        let tier = content(display(.idle(snap(70)), forecasts: ["session": .blockAt(now.addingTimeInterval(3600 + 5 * 60))])).menuBarItem
        #expect(tier.text == "1:05")
        let muted = content(display(.failed(.server(503), previous: snap(42)))).menuBarItem
        #expect(muted.text == nil)
    }

    @Test func accessibilityIsTheIslandAnnouncement() {
        let d = display(.idle(snap(42)))
        let s = NotchSignal.make(display: d, now: now, language: .english, strings: CompactStripTests.english,
                                 locale: Locale(identifier: "en_US"), timeZone: utc, attention: attention(.approval))
        #expect(BarContent.make(signal: s, now: now, strings: CompactStripTests.english).accessibility == s.accessibility)
    }

    @Test func sameStateIsEqual() {
        let d = display(.idle(snap(42)))
        #expect(content(d) == content(d))
    }

    /// L'annonce VoiceOver change chaque minute sans que le dessin change : ce n'est pas un motif de redessin.
    @Test func looksLikeIgnoresTheAnnouncementOnly() {
        let gauge = BarContent.Gauge(fraction: 0.42, tint: .calm, beats: false)
        let a = BarContent(gauge: gauge, text: "42%", accessibility: "5-hour window 42 percent, resets in 2h 14m", textIsPercent: true)
        let b = BarContent(gauge: gauge, text: "42%", accessibility: "5-hour window 42 percent, resets in 2h 13m", textIsPercent: true)
        #expect(a != b && a.looksLike(b))
        let c = BarContent(gauge: gauge, text: "43%", accessibility: a.accessibility, textIsPercent: true)
        #expect(!a.looksLike(c))
        #expect(!a.looksLike(a.compact))
    }
}
