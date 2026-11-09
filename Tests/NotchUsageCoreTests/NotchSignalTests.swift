import Foundation
import Testing
@testable import NotchUsageCore

@Suite("NotchSignal (005)")
struct NotchSignalTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)!

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, hover: Bool = false,
                 forecasts: [String: Forecast] = [:]) -> DisplayState {
        DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level, layout: layout,
                                   fullscreen: false, hover: hover, now: now, forecasts: forecasts)
    }

    func signal(_ d: DisplayState) -> NotchSignal {
        NotchSignal.make(display: d, now: now, language: .english, strings: CompactStripTests.english, locale: Locale(identifier: "en_US"), timeZone: utc)
    }

    func snap(_ session: Double, weekly: Double = 20, reset: TimeInterval = 2 * 3600 + 14 * 60, age: TimeInterval = 0) -> UsageSnapshot {
        makeSnapshot([("session", session), ("weekly_all", weekly)], fetchedAt: now.addingTimeInterval(-age), resetsAt: now.addingTimeInterval(reset))
    }

    // MARK: US1 - silence et bande

    @Test func calmReadingIsSilent() {
        let s = signal(display(.idle(snap(42))))
        #expect(s.content == .silent && s.edge == nil && s.isSilent)
        #expect(s.accessibility == "5-hour window, 42 percent, resets in 2h 14m")
        let holds = signal(display(.idle(snap(42)), forecasts: ["session": .holdsUntilReset]))
        #expect(holds.content == .silent)
    }

    @Test func hoverAndPinShowTheBand() {
        let d = display(.idle(snap(42)), hover: true)
        let strip = CompactStrip.make(display: d, now: now, language: .english, strings: CompactStripTests.english, locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(signal(d).content == .band(strip))
        #expect(!signal(d).isSilent)
    }

    @Test func staleOrFailedReadingShowsAGreyBandWithoutEdge() {
        let failed = signal(display(.failed(.server(503), previous: snap(42))))
        guard case .band(let strip) = failed.content else { Issue.record("expected band"); return }
        #expect(strip.tone == .muted && failed.edge == nil)
        let stale = signal(display(.idle(snap(42, age: 45 * 60))))
        guard case .band = stale.content else { Issue.record("expected band"); return }
        #expect(stale.edge == nil)
    }

    @Test func sessionAndAccountStatesShowTheBand() {
        for state in [FetchState.reauthRequired(previous: nil), .unsupported, .failed(.network(.notConnectedToInternet), previous: nil)] {
            guard case .band = signal(display(state)).content else { Issue.record("expected band for \(state)"); continue }
        }
        guard case .band = signal(display(.idle(nil), connected: false)).content else { Issue.record("expected band"); return }
        #expect(signal(display(.reauthRequired(previous: nil))).edge == nil)
    }

    @Test func onlyTheBandWidensTheNotch() {
        #expect(signal(display(.idle(snap(42)), hover: true)).isBand)
        #expect(!signal(display(.idle(snap(42)))).isBand)
        #expect(!signal(display(.idle(snap(55)), forecasts: ["session": .blockAt(now.addingTimeInterval(7200))])).isBand)
        #expect(!signal(display(.idle(snap(83)), level: .warning)).isBand)
        #expect(!signal(display(.idle(snap(100)), level: .critical)).isBand)
    }

    // MARK: US2 - paliers

    @Test func tiersFollowTheDeadline() {
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(125 * 60), now: now) == .far)
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(60 * 60), now: now) == .far)
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(59 * 60), now: now) == .near)
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(30 * 60), now: now) == .near)
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(8 * 60), now: now) == .imminent)
        #expect(NotchSignal.Edge.tier(blockAt: now.addingTimeInterval(-60), now: now) == .imminent)
    }

    @Test func tiersFollowTheAlertLevel() {
        #expect(NotchSignal.Edge.tier(alertLevel: .none) == nil)
        #expect(NotchSignal.Edge.tier(alertLevel: .warning) == .far)
        #expect(NotchSignal.Edge.tier(alertLevel: .critical) == .imminent)
    }

    @Test func predictedBlockShowsOneDatumWithItsTier() {
        let far = signal(display(.idle(snap(55, reset: 4 * 3600)), forecasts: ["session": .blockAt(now.addingTimeInterval(125 * 60))]))
        #expect(far.content == .deadline("2h 05m") && far.edge == .far)
        let near = signal(display(.idle(snap(78)), level: .none, forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]))
        guard case .deadline(let label) = near.content else { Issue.record("expected deadline"); return }
        #expect(label.hasPrefix("10:40") && near.edge == .near)
        let imminent = signal(display(.idle(snap(92)), level: .warning, forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))]))
        #expect(imminent.edge == .imminent)
        #expect(imminent.accessibility.hasSuffix("at this pace blocked at 10:08 AM") || imminent.accessibility.contains("blocked at 10:08"))
    }

    @Test func exhaustedLimitShowsFullAndTheReturn() {
        let s = signal(display(.idle(snap(100, reset: 3600 + 2 * 60)), level: .critical))
        #expect(s.content == .exhausted(full: "Full", back: "1h 02m") && s.edge == .exhausted)
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 100)], fetchedAt: now, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600))
        let w = signal(display(.idle(weekly), level: .critical))
        #expect(w.content == .exhausted(full: "Full", back: "3d 5h"))
    }

    @Test func thresholdWithoutForecastShowsLabelAndPill() {
        let warning = signal(display(.idle(snap(83)), level: .warning))
        #expect(warning.content == .threshold(label: "5h", percent: "83%") && warning.edge == .far)
        let critical = signal(display(.idle(snap(97)), level: .critical, forecasts: ["session": .unavailable]))
        #expect(critical.content == .threshold(label: "5h", percent: "97%") && critical.edge == .imminent)
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 97)], fetchedAt: now, resetsAt: now.addingTimeInterval(3 * 86400))
        let w = signal(display(.idle(weekly), level: .critical))   // 008 : l'hebdo à 97 % porte le signal d'elle-même
        #expect(w.content == .threshold(label: "7d", percent: "97%") && w.edge == .imminent)
    }

    @Test func forecastWinsOverThresholdForTheFiveHourWindow() {
        let s = signal(display(.idle(snap(97)), level: .critical, forecasts: ["session": .holdsUntilReset]))
        #expect(s.content == .silent && s.edge == nil)
    }

    @Test func disabledAlertsKeepTheDeadlineOnly() {
        // Alertes désactivées = niveau .none fourni par l'app : plus de seuil, la prévision reste.
        #expect(signal(display(.idle(snap(97)), level: .none)).content == .silent)
        let s = signal(display(.idle(snap(97)), level: .none, forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))]))
        #expect(s.edge == .imminent)
    }

    @Test func signalFollowsTheMostThreateningLimit() {
        let snapshot = makeSnapshot([("session", 30), ("weekly_all", 97)], fetchedAt: now, resetsAt: now.addingTimeInterval(3600))
        // Hebdo à 97 %, 5 h tranquille : l'hebdo porte le signal (008), avec le niveau que l'app calcule sur elle.
        let weekly = signal(display(.idle(snapshot), level: .critical))
        #expect(weekly.content == .threshold(label: "7d", percent: "97%"))
        // Prévision imminente sur la 5 h : elle passe devant l'hebdo.
        let imminent = signal(display(.idle(snapshot), level: .none, forecasts: ["session": .blockAt(now.addingTimeInterval(600))]))
        guard case .deadline = imminent.content else { Issue.record("expected deadline"); return }
        #expect(imminent.edge == .imminent)
    }

    @Test func staleReadingTurnsTheEdgeOff() {
        let s = signal(display(.failed(.server(503), previous: snap(55)), level: .warning, forecasts: ["session": .blockAt(now.addingTimeInterval(600))]))
        guard case .band = s.content else { Issue.record("expected band"); return }
        #expect(s.edge == nil)
    }

    // MARK: 006 - rythme du battement

    func deadline(_ minutes: Double, session: Double = 92, level: AlertLevel = .none) -> NotchSignal {
        signal(display(.idle(snap(session, reset: 3600)), level: level, forecasts: ["session": .blockAt(now.addingTimeInterval(minutes * 60))]))
    }

    @Test func imminentDeadlineBeatsEveryMinuteThenEveryHalfMinute() {
        #expect(deadline(25, session: 85).pulse == .everyMinute)
        #expect(deadline(29.9).pulse == .everyMinute)
        #expect(deadline(10).pulse == .everyMinute)
        #expect(deadline(9.98).pulse == .everyHalfMinute)
        #expect(deadline(8).pulse == .everyHalfMinute)
        #expect(deadline(-1).pulse == .everyHalfMinute)
    }

    @Test func onlyAnImminentForecastBeats() {
        #expect(deadline(40, session: 78).pulse == NotchSignal.Pulse.none)
        #expect(deadline(125, session: 55).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.idle(snap(100, reset: 3600)), level: .critical)).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.idle(snap(97)), level: .critical)).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.idle(snap(83)), level: .warning)).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.idle(snap(42)))).pulse == NotchSignal.Pulse.none)
    }

    @Test func hoverPinAndBandsNeverBeat() {
        let forecasts: [String: Forecast] = ["session": .blockAt(now.addingTimeInterval(8 * 60))]
        #expect(signal(display(.idle(snap(92)), hover: true, forecasts: forecasts)).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.failed(.server(503), previous: snap(92)), forecasts: forecasts)).pulse == NotchSignal.Pulse.none)
        #expect(signal(display(.reauthRequired(previous: nil))).pulse == NotchSignal.Pulse.none)
    }

    @Test func aBeatImpliesTheImminentTier() {
        for minutes in [25.0, 10, 9.9, 8, 0.5] {
            let s = deadline(minutes)
            #expect(s.pulse != NotchSignal.Pulse.none && s.edge == .imminent)
            guard case .deadline = s.content else { Issue.record("expected deadline"); continue }
        }
    }

    // MARK: 012 - île

    typealias Island = NotchSignal.Island

    @Test func islandDeadlineFormat() {
        #expect(IslandFormat.deadline(remaining: 125 * 60) == "2:05")
        #expect(IslandFormat.deadline(remaining: 60 * 60) == "1:00")
        #expect(IslandFormat.deadline(remaining: 59 * 60 + 1) == "1:00")
        #expect(IslandFormat.deadline(remaining: 58 * 60 + 30) == "59\u{2032}")
        #expect(IslandFormat.deadline(remaining: 7 * 60 + 30) == "8\u{2032}")
        #expect(IslandFormat.deadline(remaining: 8 * 60) == "8\u{2032}")
        #expect(IslandFormat.deadline(remaining: -30) == "0\u{2032}")
    }

    @Test func calmIslandIsAGreyGaugeAlone() {
        #expect(signal(display(.idle(snap(42)))).island == Island(leading: .gauge(value: 42, tint: .calm)))
        #expect(signal(display(.idle(snap(97)), level: .critical, forecasts: ["session": .holdsUntilReset])).island
                == Island(leading: .gauge(value: 97, tint: .calm)))
    }

    @Test func forecastTiersColourTheGaugeAndAddTheDeadline() {
        let far = signal(display(.idle(snap(55, reset: 4 * 3600)), forecasts: ["session": .blockAt(now.addingTimeInterval(125 * 60))])).island
        #expect(far == Island(leading: .gauge(value: 55, tint: .far), trailing: .deadline("2:05")))
        let near = signal(display(.idle(snap(78)), forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))])).island
        #expect(near == Island(leading: .gauge(value: 78, tint: .near), trailing: .deadline("40\u{2032}")))
        let imminent = signal(display(.idle(snap(92)), forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))])).island
        #expect(imminent == Island(leading: .gauge(value: 92, tint: .imminent), trailing: .deadline("8\u{2032}")))
    }

    @Test func exhaustedIslandIsAFullGaugeWithTheReturn() {
        let s = signal(display(.idle(snap(100, reset: 3600 + 2 * 60)), level: .critical)).island
        #expect(s == Island(leading: .gauge(value: 100, tint: .exhausted), trailing: .back("1:02")))
    }

    @Test func thresholdWithoutForecastShowsTheShortLabel() {
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 97)], fetchedAt: now, resetsAt: now.addingTimeInterval(3 * 86400))
        #expect(signal(display(.idle(weekly), level: .critical)).island == Island(leading: .gauge(value: 97, tint: .imminent), trailing: .label("7d")))
        #expect(signal(display(.idle(snap(83)), level: .warning)).island == Island(leading: .gauge(value: 83, tint: .far), trailing: .label("5h")))
    }

    @Test func greyAndSessionStatesUseAGlyph() {
        #expect(signal(display(.failed(.server(503), previous: snap(42)))).island == Island(leading: .glyph(.offline), trailing: .muted("42%")))
        #expect(signal(display(.idle(snap(42, age: 45 * 60)))).island.leading == .glyph(.offline))
        #expect(signal(display(.reauthRequired(previous: nil))).island == Island(leading: .glyph(.locked)))
        #expect(signal(display(.idle(nil), connected: false)).island == Island(leading: .glyph(.account)))
        #expect(signal(display(.unsupported)).island == Island(leading: .glyph(.unavailable)))
    }

    @Test func hoverKeepsTheIslandForTheViewToChoose() {
        let s = signal(display(.idle(snap(42)), hover: true))
        #expect(s.isBand && s.island == Island(leading: .gauge(value: 42, tint: .calm)))
    }
}


// MARK: - 017 : sessions Claude en attente

@Suite("NotchSignal attention (017)")
struct NotchSignalAttentionTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)!
    typealias Island = NotchSignal.Island

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, hover: Bool = false,
                 forecasts: [String: Forecast] = [:]) -> DisplayState {
        DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level, layout: layout,
                                   fullscreen: false, hover: hover, now: now, forecasts: forecasts)
    }

    func signal(_ d: DisplayState, attention: NotchSignal.Attention? = nil) -> NotchSignal {
        NotchSignal.make(display: d, now: now, language: .english, strings: CompactStripTests.english, locale: Locale(identifier: "en_US"),
                         timeZone: utc, attention: attention)
    }

    func snap(_ session: Double, weekly: Double = 20, reset: TimeInterval = 2 * 3600 + 14 * 60, age: TimeInterval = 0) -> UsageSnapshot {
        makeSnapshot([("session", session), ("weekly_all", weekly)], fetchedAt: now.addingTimeInterval(-age), resetsAt: now.addingTimeInterval(reset))
    }

    func attention(_ kind: ClaudeWaitingKind, count: Int = 1, entries: [(String, ClaudeWaitingKind)]? = nil) -> NotchSignal.Attention {
        NotchSignal.Attention(kind: kind, count: count, arrivedAt: now,
                              entries: (entries ?? [("Notch-Usage", kind)]).map { .init(name: $0.0, kind: $0.1) })
    }

    // US1

    @Test func withoutAttentionTheIslandIsUnchanged() {
        let d = display(.idle(snap(42)))
        #expect(signal(d) == signal(d, attention: nil))
        #expect(signal(d).island == Island(leading: .gauge(value: 42, tint: .calm)))
        #expect(signal(d).attention == nil)
    }

    @Test func calmIslandGivesTheRightEarToTheSession() {
        let d = display(.idle(snap(42)))
        for kind in ClaudeWaitingKind.allCases {
            let s = signal(d, attention: attention(kind))
            #expect(s.island == Island(leading: .gauge(value: 42, tint: .calm), trailing: .attention(kind: kind, count: 1)))
            #expect(s.island.badge == nil && s.attention?.kind == kind)
        }
    }

    @Test func accessibilityIsPrefixedWithTheWaitingSessions() {
        let d = display(.idle(snap(42)))
        let one = signal(d, attention: attention(.approval))
        #expect(one.accessibility == "1 Claude session is waiting: Notch-Usage, an approval. 5-hour window, 42 percent, resets in 2h 14m")
        let two = signal(d, attention: attention(.approval, count: 2, entries: [("Notch-Usage", .approval), ("deck-q4", .done)]))
        #expect(two.accessibility.hasPrefix("2 Claude sessions are waiting: Notch-Usage, an approval; deck-q4, finished. "))
    }

    // US2 : priorité

    @Test func imminentOrExhaustedLimitKeepsTheEarAndShowsABadge() {
        let imminent = signal(display(.idle(snap(92)), forecasts: ["session": .blockAt(now.addingTimeInterval(8 * 60))]), attention: attention(.approval))
        #expect(imminent.island.trailing == .deadline("8\u{2032}") && imminent.island.badge == .approval)
        #expect(imminent.island.tint == .imminent && imminent.pulse == .everyHalfMinute)
        let blocked = signal(display(.idle(snap(100))), attention: attention(.done))
        #expect(blocked.island.trailing == .back("2:14") && blocked.island.badge == .done && blocked.island.tint == .exhausted)
    }

    @Test func fartherDeadlinesThresholdsAndOfflineGiveTheEarToTheSession() {
        let far = signal(display(.idle(snap(55)), forecasts: ["session": .blockAt(now.addingTimeInterval(125 * 60))]), attention: attention(.question))
        #expect(far.island == Island(leading: .gauge(value: 55, tint: .far), trailing: .attention(kind: .question, count: 1)))
        let near = signal(display(.idle(snap(78)), forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]), attention: attention(.approval))
        #expect(near.island.trailing == .attention(kind: .approval, count: 1) && near.island.tint == .near)
        let critical = signal(display(.idle(snap(97)), level: .critical), attention: attention(.approval))
        #expect(critical.island.trailing == .attention(kind: .approval, count: 1) && critical.island.tint == .imminent && critical.island.badge == nil)
        let offline = signal(display(.failed(.server(503), previous: snap(42))), attention: attention(.approval))
        #expect(offline.island == Island(leading: .glyph(.offline), trailing: .attention(kind: .approval, count: 1)))
        let locked = signal(display(.reauthRequired(previous: nil)), attention: attention(.done))
        #expect(locked.island == Island(leading: .glyph(.locked), trailing: .attention(kind: .done, count: 1)))
    }

    @Test func hoverKeepsTheSameIsland() {
        let a = attention(.approval, count: 3)
        let collapsed = signal(display(.idle(snap(42))), attention: a)
        let hovered = signal(display(.idle(snap(42)), hover: true), attention: a)
        #expect(collapsed.island == hovered.island && hovered.isBand)
    }

    @Test func badgeAndTrailingTakePartInEquality() {
        let a = Island(leading: .gauge(value: 1, tint: .calm), trailing: nil, badge: .approval)
        let b = Island(leading: .gauge(value: 1, tint: .calm), trailing: nil, badge: nil)
        #expect(a != b)
        #expect(Island(leading: .gauge(value: 1, tint: .calm), trailing: .attention(kind: .approval, count: 2))
                != Island(leading: .gauge(value: 1, tint: .calm), trailing: .attention(kind: .approval, count: 3)))
    }
}
