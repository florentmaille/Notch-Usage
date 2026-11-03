import Foundation
import Testing
@testable import NotchUsageCore

@Suite("CompactStrip (003)")
struct CompactStripTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)

    static let english = CompactStrip.Strings(
        full: "Full", signIn: "Sign in", connect: "Connect", dash: "—",
        percent: { "\($0)%" },
        limitLabel: { $0.id == "session" ? "5-hour window" : "Weekly, all models" },
        shortLabel: { $0.kind == .rollingFiveHour ? "5h" : ($0.kind == .weeklyAll ? "7d" : ($0.modelName ?? "7d")) },
        limitAnnouncement: { "\($0), \($1) percent, resets \($2)" },
        paceAnnouncement: { ", at this pace blocked at \($0)" },
        stateAnnouncement: { "Notch Usage, \($0)" })

    static let french = CompactStrip.Strings(
        full: "Bloqué", signIn: "Connexion", connect: "Connexion", dash: "—",
        percent: { "\($0)\u{00A0}%" },
        limitLabel: { _ in "Fenêtre de 5 h" },
        shortLabel: { $0.kind == .rollingFiveHour ? "5 h" : "7 j" },
        limitAnnouncement: { "\($0), \($1) pour cent, réinitialisation \($2)" },
        paceAnnouncement: { ", à ce rythme bloqué à \($0)" },
        stateAnnouncement: { "Notch Usage, \($0)" })

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, now: Date? = nil,
                 forecasts: [String: Forecast] = [:]) -> DisplayState {
        var d = DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level,
                                           layout: layout, fullscreen: false, hover: false, pinned: false, now: now ?? self.now)
        d.forecasts = forecasts
        return d
    }

    func strip(_ d: DisplayState, language: InterfaceLanguage = .english, strings: CompactStrip.Strings = english,
               locale: String = "en_US") -> CompactStrip {
        CompactStrip.make(display: d, now: now, language: language, strings: strings, locale: Locale(identifier: locale), timeZone: utc)
    }

    func snap(_ pct: Double, reset: TimeInterval = 2 * 3600 + 14 * 60, at: TimeInterval = 0) -> UsageSnapshot {
        makeSnapshot([("session", pct), ("weekly_all", 20)], fetchedAt: now.addingTimeInterval(at), resetsAt: now.addingTimeInterval(reset))
    }

    @Test func shortLabelsPerLimitKind() {
        let limits = makeSnapshot([("session", 10), ("weekly_all", 10), ("weekly_scoped:Fable", 10)]).limits
        #expect(limits.map(Self.english.shortLabel) == ["5h", "7d", "Fable"])
        #expect(limits.map(Self.french.shortLabel) == ["5 h", "7 j", "7 j"])
    }

    @Test func normal() {
        let s = strip(display(.idle(snap(42))))
        #expect(s.left == .holds("2h 14m"))
        #expect(s.right == .percent("42%"))
        #expect(s.tone == .normal)
        #expect(s.accessibility == "5-hour window, 42 percent, resets in 2h 14m")
    }

    @Test func warningAndCriticalUseAPill() {
        let w = strip(display(.idle(snap(83)), level: .warning))
        #expect(w.right == .pill("83%") && w.tone == .warning && w.left == .holds("2h 14m"))
        let c = strip(display(.idle(snap(97)), level: .critical))
        #expect(c.right == .pill("97%") && c.tone == .critical)
    }

    @Test func blockedLimit() {
        let s = strip(display(.idle(snap(100, reset: 3600 + 2 * 60)), level: .critical))
        #expect(s.left == .blockedFor("1h 02m"))
        #expect(s.right == .pill("Full"))
        #expect(s.tone == .critical)
    }

    @Test func failedReadingIsMutedWithOfflineGlyph() {
        let s = strip(display(.failed(.network(.notConnectedToInternet), previous: snap(42)), level: .warning))
        #expect(s.left == .offline("2h 14m"))
        #expect(s.right == .percent("42%"))
        #expect(s.tone == .muted)
    }

    @Test func staleReadingIsMuted() {
        let later = now.addingTimeInterval(1800)
        let d = display(.idle(snap(83)), level: .warning, now: later)
        let s = CompactStrip.make(display: d, now: later, language: .english, strings: Self.english, locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(s.left == .holds("1h 44m"))
        #expect(s.right == .percent("83%"))
        #expect(s.tone == .muted)
    }

    @Test func blockedStaysRedEvenOffline() {
        let s = strip(display(.failed(.server(503), previous: snap(100)), level: .critical))
        #expect(s.left == .offline("2h 14m"))
        #expect(s.right == .pill("Full"))
        #expect(s.tone == .critical)
    }

    @Test func predictedBlock() {
        let soon = strip(display(.idle(snap(55, reset: 4 * 3600)), forecasts: ["session": .blockAt(now.addingTimeInterval(70 * 60))]))
        #expect(soon.left == .blockIn("1h 10m"))
        #expect(soon.right == .percent("55%"))
        #expect(soon.tone == .warning)
        #expect(soon.accessibility.hasPrefix("5-hour window, 55 percent, resets in 4h 0m, at this pace blocked at 11:10"))

        let underAnHour = strip(display(.idle(snap(97)), level: .critical, forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]))
        #expect(underAnHour.left == .blockIn("10:40 AM") || underAnHour.left == .blockIn("10:40\u{202F}AM"))
        #expect(underAnHour.right == .pill("97%"))
        #expect(underAnHour.tone == .critical)
    }

    @Test func forecastOnAnotherLimitIsIgnored() {
        let s = strip(display(.idle(snap(42)), forecasts: ["weekly_all": .blockAt(now.addingTimeInterval(600))]))
        #expect(s.left == .holds("2h 14m"))
    }

    @Test func holdsAndUnavailableForecastsShowTheCountdown() {
        #expect(strip(display(.idle(snap(42)), forecasts: ["session": .holdsUntilReset])).left == .holds("2h 14m"))
        #expect(strip(display(.idle(snap(42)), forecasts: ["session": .unavailable])).left == .holds("2h 14m"))
    }

    @Test func resetPending() {
        let s = strip(display(.idle(snap(42, reset: -10))))
        #expect(s.left == .holds("pending"))
    }

    @Test func reauthRequired() {
        let s = strip(display(.reauthRequired(previous: nil)))
        #expect(s.left == .locked)
        #expect(s.right == .signIn("Sign in"))
        #expect(s.tone == .warning)
        #expect(s.accessibility == "Notch Usage, reconnectRequired")
    }

    @Test func notConnected() {
        let s = strip(display(.idle(nil), connected: false))
        #expect(s.left == .connect && s.right == .connect("Connect") && s.tone == .muted)
    }

    @Test func unsupportedAndUnavailable() {
        let u = strip(display(.unsupported))
        #expect(u.left == .unsupported && u.right == .dash && u.tone == .muted)
        let n = strip(display(.failed(.server(503), previous: nil)))
        #expect(n.left == .unavailable && n.right == .dash && n.tone == .muted)
    }

    @Test func french() {
        let s = strip(display(.idle(snap(42)), forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]),
                      language: .french, strings: Self.french, locale: "fr_FR")
        #expect(s.left == .blockIn("10:40"))
        #expect(s.right == .percent("42\u{00A0}%"))
        #expect(s.accessibility == "Fenêtre de 5 h, 42 pour cent, réinitialisation dans 2 h 14 min, à ce rythme bloqué à 10:40")
    }
}
