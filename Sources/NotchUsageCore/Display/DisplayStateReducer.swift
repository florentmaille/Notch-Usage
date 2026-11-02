import Foundation

public enum DisplayStateReducer {
    public static func reduce(state: FetchState, connected: Bool, settings: RefreshSettings, alertLevel: AlertLevel,
                              layout: NotchLayout, fullscreen: Bool, hover: Bool, pinned: Bool, now: Date,
                              forecasts: [String: Forecast] = [:]) -> DisplayState {
        let panel: DisplayState.Panel = pinned ? .pinned : (hover ? .hoverOpen : .collapsed)
        let fullscreenHidden = fullscreen && !hover && !pinned

        var d = DisplayState(
            layout: layout, panel: panel, content: .connect, limits: [], headline: nil, banner: nil,
            freshness: nil, fetchedAt: nil, isLoading: false, alertLevel: alertLevel,
            fullscreenHidden: fullscreenHidden, showAlertDot: fullscreenHidden && alertLevel != .none,
            forecasts: [:], fetchFailed: false
        )
        guard connected else { return d }

        func applySnapshot(_ s: UsageSnapshot) {
            d.content = .limits
            d.limits = s.limits
            d.forecasts = forecasts
            // Le blocage prévu le plus proche prime sur le pourcentage le plus élevé (003, research R6).
            let predicted = s.limits.compactMap { limit -> (UsageLimit, Date)? in
                if case .blockAt(let date)? = forecasts[limit.id] { return (limit, date) }
                return nil
            }.min { $0.1 < $1.1 }?.0
            d.headline = (predicted ?? s.mostConstraining).map(DisplayState.Headline.init)
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
