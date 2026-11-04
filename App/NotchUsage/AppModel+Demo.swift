import AppKit
import Foundation
import NotchUsageCore

#if DEBUG
/// Mode démo (build Debug) : valeurs fictives pour les captures du README, sans compte ni réseau.
/// `com.notchusage.debug.demo` objet "normal" | "far" | "near" | "imminent25" | "imminent" | "pace" | "warning" | "critical"
/// | "blocked" | "offline" | "reauth" | "off" ; `com.notchusage.debug.tick` force un tick de 30 s (006) ;
/// `com.notchusage.debug.layout` objet "pill" | "notch" simule un écran sans encoche.
extension AppModel {
    func installDemoHook() {
        let center = DistributedNotificationCenter.default()
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.demo"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "off"
            MainActor.assumeIsolated { self?.applyDemo(mode) }
        })
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.tick"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        })
        // `com.notchusage.debug.menusettings` : rejoue « Réglages » du menu de la barre (menu ouvert, action, menu refermé).
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.menusettings"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: nil)
                self?.openSettingsFromMenu()
                NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: nil)
            }
        })
        // `com.notchusage.debug.layout` objet "pill" | "notch" : simule un écran sans encoche pour les captures.
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.layout"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "notch"
            MainActor.assumeIsolated {
                guard let self, let current = self.screens.current else { return }
                let layout = mode == "pill"
                    ? NotchGeometry.layout(screenWidth: current.screen.frame.width, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
                    : current.layout
                self.applyScreen(ScreenObserver.Target(screen: current.screen, layout: layout))
            }
        })
    }

    func applyDemo(_ mode: String) {
        let now = Date()
        func snapshot(_ session: Double, _ weekly: Double, _ model: Double,
                      sessionReset: TimeInterval = 2 * 3600 + 14 * 60, age: TimeInterval = 0) -> UsageSnapshot {
            UsageSnapshot(limits: [
                UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: session, resetsAt: now.addingTimeInterval(sessionReset)),
                UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: weekly, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
                UsageLimit(id: "weekly_scoped:Fable", kind: .weeklyModel, modelName: "Fable", utilization: model, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
            ], fetchedAt: now.addingTimeInterval(-age))
        }
        demoForecasts = [:]
        switch mode {
        case "normal": demoState = .idle(snapshot(42, 27, 35))
        case "far":
            demoState = .idle(snapshot(55, 30, 28, sessionReset: 4 * 3600))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(125 * 60))]
        case "near":
            demoState = .idle(snapshot(78, 30, 28))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(40 * 60))]
        case "imminent25":
            demoState = .idle(snapshot(85, 30, 28, sessionReset: 3600))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(25 * 60))]
        case "imminent":
            demoState = .idle(snapshot(92, 30, 28, sessionReset: 3600))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(8 * 60))]
        case "pace":
            // Historique synthétique passé par le vrai calcul : 29 → 55 % en 40 min, reset dans 4 h.
            let current = snapshot(55, 30, 28, sessionReset: 4 * 3600)
            var synthetic = UsageHistory()
            for (minutesAgo, pct) in [(40.0, 29.0), (30, 36), (20, 42), (10, 49)] {
                synthetic = synthetic.appending(snapshot(pct, 30, 28, sessionReset: 4 * 3600, age: minutesAgo * 60))
            }
            synthetic = synthetic.appending(current)
            demoState = .idle(current)
            demoForecasts = PaceForecaster.forecasts(history: synthetic, snapshot: current, now: now)
        case "warning": demoState = .idle(snapshot(83, 38, 64))
        case "critical":
            demoState = .idle(snapshot(97, 52, 71))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(50 * 60))]
        case "blocked": demoState = .idle(snapshot(100, 52, 71, sessionReset: 3600 + 2 * 60))
        case "offline": demoState = .failed(.network(.notConnectedToInternet), previous: snapshot(42, 27, 35, sessionReset: 3600 + 49 * 60, age: 25 * 60))
        case "reauth": demoState = .reauthRequired(previous: nil)
        default: demoState = nil
        }
        recompute()
    }
}
#endif
