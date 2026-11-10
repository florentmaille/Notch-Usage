import Foundation
import Testing
@testable import NotchUsageCore

/// Annonce VoiceOver de l'encoche (003, FR-015). Les champs visuels de l'ancienne bande ont disparu avec elle :
/// l'île (012) et la barre de menus (018) ont leurs propres tests.
@Suite("CompactStrip, annonce VoiceOver (003)")
struct CompactStripTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let utc = TimeZone(identifier: "UTC")!
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)!

    static let english = CompactStrip.Strings(
        full: "Full", dash: "—",
        percent: { "\($0)%" },
        limitLabel: { $0.id == "session" ? "5-hour window" : "Weekly, all models" },
        shortLabel: { $0.kind == .rollingFiveHour ? "5h" : ($0.kind == .weeklyAll ? "7d" : ($0.modelName ?? "7d")) },
        limitAnnouncement: { "\($0), \($1) percent, resets \($2)" },
        paceAnnouncement: { ", at this pace blocked at \($0)" },
        stateAnnouncement: { "Notch Usage, \($0)" })

    static let french = CompactStrip.Strings(
        full: "Bloqué", dash: "—",
        percent: { "\($0)\u{00A0}%" },
        limitLabel: { _ in "Fenêtre de 5 h" },
        shortLabel: { $0.kind == .rollingFiveHour ? "5 h" : "7 j" },
        limitAnnouncement: { "\($0), \($1) pour cent, réinitialisation \($2)" },
        paceAnnouncement: { ", à ce rythme bloqué à \($0)" },
        stateAnnouncement: { "Notch Usage, \($0)" })

    func display(_ state: FetchState, connected: Bool = true, level: AlertLevel = .none, now: Date? = nil,
                 forecasts: [String: Forecast] = [:]) -> DisplayState {
        var d = DisplayStateReducer.reduce(state: state, connected: connected, settings: RefreshSettings(), alertLevel: level,
                                           layout: layout, fullscreen: false, hover: false, now: now ?? self.now)
        d.forecasts = forecasts
        return d
    }

    func announcement(_ d: DisplayState, language: InterfaceLanguage = .english, strings: CompactStrip.Strings = english,
                      locale: String = "en_US") -> String {
        CompactStrip.make(display: d, now: now, language: language, strings: strings, locale: Locale(identifier: locale), timeZone: utc).accessibility
    }

    func snap(_ pct: Double, reset: TimeInterval = 2 * 3600 + 14 * 60, at: TimeInterval = 0) -> UsageSnapshot {
        makeSnapshot([("session", pct), ("weekly_all", 20)], fetchedAt: now.addingTimeInterval(at), resetsAt: now.addingTimeInterval(reset))
    }

    @Test func shortLabelsPerLimitKind() {
        let limits = makeSnapshot([("session", 10), ("weekly_all", 10), ("weekly_scoped:Fable", 10)]).limits
        #expect(limits.map(Self.english.shortLabel) == ["5h", "7d", "Fable"])
        #expect(limits.map(Self.french.shortLabel) == ["5 h", "7 j", "7 j"])
    }

    @Test func aLimitIsAnnouncedInOneSentence() {
        #expect(announcement(display(.idle(snap(42)))) == "5-hour window, 42 percent, resets in 2h 14m")
        // Seuil, relevé en échec ou ancien : la phrase ne change pas, seule la valeur compte.
        #expect(announcement(display(.idle(snap(83)), level: .warning)) == "5-hour window, 83 percent, resets in 2h 14m")
        #expect(announcement(display(.failed(.network(.notConnectedToInternet), previous: snap(42)), level: .warning))
                == "5-hour window, 42 percent, resets in 2h 14m")
    }

    @Test func aPredictedBlockAddsItsClockTime() {
        let soon = announcement(display(.idle(snap(55, reset: 4 * 3600)), forecasts: ["session": .blockAt(now.addingTimeInterval(70 * 60))]))
        #expect(soon.hasPrefix("5-hour window, 55 percent, resets in 4h 0m, at this pace blocked at 11:10"))
        // Sous une heure aussi : l'annonce donne toujours l'heure, jamais une durée.
        let underAnHour = announcement(display(.idle(snap(97)), level: .critical, forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]))
        #expect(underAnHour.contains("at this pace blocked at 10:40"))
    }

    @Test func noPaceWithoutABlockForecastOnTheLimitShown() {
        let plain = "5-hour window, 42 percent, resets in 2h 14m"
        #expect(announcement(display(.idle(snap(42)), forecasts: ["weekly_all": .blockAt(now.addingTimeInterval(600))])) == plain)
        #expect(announcement(display(.idle(snap(42)), forecasts: ["session": .holdsUntilReset])) == plain)
        #expect(announcement(display(.idle(snap(42)), forecasts: ["session": .unavailable])) == plain)
    }

    /// Limite atteinte : plus de blocage à prévoir, l'annonce s'arrête au retour.
    @Test func aReachedLimitHasNoPace() {
        let blocked = announcement(display(.idle(snap(100, reset: 3600 + 2 * 60)), level: .critical,
                                           forecasts: ["session": .blockAt(now.addingTimeInterval(600))]))
        #expect(blocked == "5-hour window, 100 percent, resets in 1h 2m")
    }

    @Test func resetPending() {
        #expect(announcement(display(.idle(snap(42, reset: -10)))) == "5-hour window, 42 percent, resets reset pending")
    }

    @Test func statesWithoutALimitAreNamed() {
        #expect(announcement(display(.reauthRequired(previous: nil))) == "Notch Usage, reconnectRequired")
        #expect(announcement(display(.idle(nil), connected: false)) == "Notch Usage, connect")
        #expect(announcement(display(.unsupported)) == "Notch Usage, unsupported")
        #expect(announcement(display(.failed(.server(503), previous: nil))) == "Notch Usage, unavailable")
    }

    @Test func french() {
        let s = announcement(display(.idle(snap(42)), forecasts: ["session": .blockAt(now.addingTimeInterval(40 * 60))]),
                             language: .french, strings: Self.french, locale: "fr_FR")
        #expect(s == "Fenêtre de 5 h, 42 pour cent, réinitialisation dans 2 h 14 min, à ce rythme bloqué à 10:40")
    }
}
