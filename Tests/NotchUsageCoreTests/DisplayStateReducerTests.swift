import Foundation
import Testing
@testable import NotchUsageCore

@Suite("DisplayStateReducer")
struct DisplayStateReducerTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let notch = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)
    let settings = RefreshSettings()

    func reduce(_ state: FetchState, connected: Bool = true, hover: Bool = false, fullscreen: Bool = false, alertLevel: AlertLevel = .none, now: Date? = nil) -> DisplayState {
        DisplayStateReducer.reduce(state: state, connected: connected, settings: settings, alertLevel: alertLevel, layout: notch, fullscreen: fullscreen, hover: hover, now: now ?? self.now)
    }

    @Test func blockedLimit() {
        let snap = makeSnapshot([("session", 100), ("weekly_all", 20)], fetchedAt: now)
        let d = reduce(.idle(snap))
        #expect(d.content == .limits)
        #expect(d.headline?.limit.id == "session")
        #expect(d.headline?.isBlocked == true)
        #expect(d.limits.count == 2)
        #expect(d.banner == nil)
    }

    @Test func failedKeepsPreviousValuesWithUnavailableBanner() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        let d = reduce(.failed(.server(503), previous: snap))
        #expect(d.content == .limits)
        #expect(d.limits.count == 1)
        #expect(d.banner == .unavailable)
    }

    @Test func headlinePrefersTheEarliestPredictedBlock() {
        let snap = makeSnapshot([("session", 55), ("weekly_all", 60)], fetchedAt: now)
        let block: [String: Forecast] = ["weekly_all": .blockAt(now.addingTimeInterval(3600))]
        let d = DisplayStateReducer.reduce(state: .idle(snap), connected: true, settings: settings, alertLevel: .none, layout: notch,
                                           fullscreen: false, hover: false, now: now, forecasts: block)
        #expect(d.headline?.limit.id == "weekly_all")
        #expect(d.forecasts == block)
        let holds: [String: Forecast] = ["weekly_all": .holdsUntilReset]
        let h = DisplayStateReducer.reduce(state: .idle(snap), connected: true, settings: settings, alertLevel: .none, layout: notch,
                                           fullscreen: false, hover: false, now: now, forecasts: holds)
        #expect(h.headline?.limit.id == "session")
    }

    @Test func headlineIsTheMostThreateningLimit() {
        let snap = makeSnapshot([("session", 30), ("weekly_all", 97)], fetchedAt: now)
        let d = DisplayStateReducer.reduce(state: .idle(snap), connected: true, settings: settings, alertLevel: .none, layout: notch,
                                           fullscreen: false, hover: false, now: now)
        #expect(d.headline?.limit.id == "weekly_all")
    }

    @Test func failedReadingIsFlagged() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        #expect(reduce(.failed(.server(503), previous: snap)).fetchFailed)
        #expect(!reduce(.idle(snap)).fetchFailed)
        #expect(reduce(.idle(snap)).forecasts.isEmpty)
    }

    @Test func failedWithoutPreviousShowsUnavailableOnly() {
        let d = reduce(.failed(.network(.notConnectedToInternet), previous: nil))
        #expect(d.content == .unavailable)
        #expect(d.limits.isEmpty)
        #expect(d.headline == nil)
    }

    @Test func challengeBannerOffersReconnect() {
        let d = reduce(.failed(.challenge, previous: nil))
        #expect(d.banner == .challenge)
    }

    @Test func reauthRequiredShowsNoNumbers() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        let d = reduce(.reauthRequired(previous: snap))
        #expect(d.content == .reauthRequired)
        #expect(d.limits.isEmpty)
        #expect(d.headline == nil)
    }

    @Test func unsupportedPlan() {
        let d = reduce(.unsupported)
        #expect(d.content == .unsupported)
        #expect(d.limits.isEmpty)
    }

    @Test func disconnectedShowsConnect() {
        let d = reduce(.idle(nil), connected: false)
        #expect(d.content == .connect)
    }

    @Test func agingAndStaleFreshness() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        #expect(reduce(.idle(snap), now: now.addingTimeInterval(100)).freshness == .fresh)
        #expect(reduce(.idle(snap), now: now.addingTimeInterval(400)).freshness == .aging)
        #expect(reduce(.idle(snap), now: now.addingTimeInterval(1800)).freshness == .stale)
        #expect(reduce(.idle(snap), now: now.addingTimeInterval(1800)).banner == .stale)
    }

    @Test func loadingKeepsPreviousValues() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        let d = reduce(.loading(previous: snap))
        #expect(d.content == .limits)
        #expect(d.isLoading)
        #expect(d.limits.count == 1)
    }

    @Test func panelStates() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        #expect(reduce(.idle(snap)).panel == .collapsed)
        #expect(reduce(.idle(snap), hover: true).panel == .hoverOpen)
    }

    @Test func fullscreenHidesUnlessHovered() {
        let snap = makeSnapshot([("session", 40)], fetchedAt: now)
        let hidden = reduce(.idle(snap), fullscreen: true)
        #expect(hidden.fullscreenHidden)
        #expect(hidden.panel == .collapsed)
        #expect(!hidden.showAlertDot)
        let hovered = reduce(.idle(snap), hover: true, fullscreen: true)
        #expect(!hovered.fullscreenHidden)
        #expect(hovered.panel == .hoverOpen)
        let alerting = reduce(.idle(snap), fullscreen: true, alertLevel: .warning)
        #expect(alerting.fullscreenHidden && alerting.showAlertDot)
        #expect(alerting.alertLevel == .warning)
    }

    @Test func layoutIsPassedThrough() {
        let d = reduce(.idle(nil), connected: false)
        #expect(d.layout == notch)
        #expect(d.mode == .notch)
    }
}

@Suite("DisplayStateReducer - plein écran (US3)")
struct DisplayStateReducerFullscreenTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)

    func reduce(hover: Bool, alertLevel: AlertLevel) -> DisplayState {
        let snap = makeSnapshot([("session", 85)], fetchedAt: now)
        return DisplayStateReducer.reduce(state: .idle(snap), connected: true, settings: RefreshSettings(), alertLevel: alertLevel,
                                          layout: layout, fullscreen: true, hover: hover, now: now)
    }

    @Test func hiddenWithAlertShowsDot() {
        let d = reduce(hover: false, alertLevel: .critical)
        #expect(d.fullscreenHidden && d.showAlertDot && d.alertLevel == .critical)
    }

    @Test func hiddenWithoutAlertShowsNothing() {
        let d = reduce(hover: false, alertLevel: .none)
        #expect(d.fullscreenHidden && !d.showAlertDot)
    }

    @Test func hoverRevealsPanel() {
        let d = reduce(hover: true, alertLevel: .warning)
        #expect(!d.fullscreenHidden && !d.showAlertDot && d.panel == .hoverOpen)
    }

}
