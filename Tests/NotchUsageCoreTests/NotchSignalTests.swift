import Foundation
import Testing
@testable import NotchUsageCore

@Suite("NotchSignal (005)")
struct NotchSignalTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, hover: Bool = false, pinned: Bool = false,
                 forecasts: [String: Forecast] = [:], choice: HeadlineChoice = .automatic) -> DisplayState {
        DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level, layout: layout,
                                   fullscreen: false, hover: hover, pinned: pinned, now: now, forecasts: forecasts, choice: choice)
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
        #expect(signal(display(.idle(snap(42)), pinned: true)).content == .band(strip))
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
        let w = signal(display(.idle(weekly), level: .critical, choice: .limit("weekly_all")))
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

    @Test func signalFollowsTheShownLimitOnly() {
        let snapshot = makeSnapshot([("session", 30), ("weekly_all", 97)], fetchedAt: now, resetsAt: now.addingTimeInterval(3600))
        // Épinglée sur la 5 h : l'hebdo à 97 % ne compte pas, le niveau fourni est celui de la 5 h (004).
        let pinned = signal(display(.idle(snapshot), level: .none, choice: .limit("session")))
        #expect(pinned.content == .silent)
        // Épinglée sur l'hebdo : son seuil s'affiche même si la 5 h a une prévision.
        let weekly = signal(display(.idle(snapshot), level: .critical, forecasts: ["session": .blockAt(now.addingTimeInterval(600))], choice: .limit("weekly_all")))
        #expect(weekly.content == .threshold(label: "7d", percent: "97%"))
    }

    @Test func staleReadingTurnsTheEdgeOff() {
        let s = signal(display(.failed(.server(503), previous: snap(55)), level: .warning, forecasts: ["session": .blockAt(now.addingTimeInterval(600))]))
        guard case .band = s.content else { Issue.record("expected band"); return }
        #expect(s.edge == nil)
    }
}
