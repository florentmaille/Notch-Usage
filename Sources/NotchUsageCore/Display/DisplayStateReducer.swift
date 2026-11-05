import Foundation

public enum DisplayStateReducer {
    public static func reduce(state: FetchState, connected: Bool, settings: RefreshSettings, alertLevel: AlertLevel,
                              layout: NotchLayout, fullscreen: Bool, hover: Bool, now: Date,
                              forecasts: [String: Forecast] = [:], alertSettings: AlertSettings = AlertSettings()) -> DisplayState {
        let panel: DisplayState.Panel = hover ? .hoverOpen : .collapsed
        let fullscreenHidden = fullscreen && !hover

        var d = DisplayState(
            layout: layout, panel: panel, content: .connect, limits: [], headline: nil, banner: nil,
            freshness: nil, fetchedAt: nil, isLoading: false, alertLevel: alertLevel,
            fullscreenHidden: fullscreenHidden,
            forecasts: [:], fetchFailed: false
        )
        guard connected else { return d }

        func applySnapshot(_ s: UsageSnapshot) {
            d.content = .limits
            d.limits = s.limits
            d.forecasts = forecasts
            d.headline = HeadlinePicker.pick(in: s, forecasts: forecasts, settings: alertSettings, now: now).map(DisplayState.Headline.init)
            d.fetchedAt = s.fetchedAt
            let f = Freshness.of(s, now: now, interval: settings.interval)
            d.freshness = f
            if f == .stale { d.banner = .stale }
        }

        switch state {
        case .idle(let s):
            if let s { applySnapshot(s) } else { d.content = .unavailable; d.isLoading = true }
        case .loading(let previous):
            d.isLoading = true
            if let previous { applySnapshot(previous) } else { d.content = .unavailable }
        case .failed(let error, let previous):
            if let previous { applySnapshot(previous) } else { d.content = .unavailable }
            d.banner = error == .challenge ? .challenge : .unavailable
            d.fetchFailed = true
        case .reauthRequired:
            d.content = .reauthRequired
        case .unsupported:
            d.content = .unsupported
        }
        return d
    }
}
