import AppKit
import Foundation
import NotchUsageCore

#if DEBUG
/// Mode démo (build Debug) : valeurs fictives pour les captures du README, sans compte ni réseau.
/// `com.notchusage.debug.demo` objet "normal" | "far" | "near" | "imminent25" | "imminent" | "pace" | "warning" | "critical"
/// | "blocked" | "offline" | "reauth" | "off" ; `com.notchusage.debug.tick` force un tick de 30 s (006) ;
/// `com.notchusage.debug.layout` objet "nonotch" | "notchonly" | "notch" simule l'absence d'écran à encoche (018),
/// ou un MacBook seul (écrans sans encoche ignorés) ;
/// `com.notchusage.debug.menubar` objet "notch" | "external" | "off" force la barre active (018).
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
        // `com.notchusage.debug.claude` objet "approval" | "question" | "done" | "approval3" | "arrival" | "off" (017).
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.claude"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "off"
            MainActor.assumeIsolated { self?.applyDemoClaude(mode) }
        })
        // `com.notchusage.debug.layout` objet "nonotch" | "notch" (018, R9) : simule l'absence d'écran à encoche.
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.layout"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "notch"
            MainActor.assumeIsolated {
                guard let self else { return }
                self.demoNoNotch = mode == "nonotch"
                self.demoNotchOnly = mode == "notchonly"
                self.applyScreens(self.screens.current)
            }
        })
        // `com.notchusage.debug.menubar` objet "notch" | "external" | "off" (018, R9) : force la barre active.
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.menubar"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "off"
            MainActor.assumeIsolated {
                self?.demoActiveBar = mode == "off" ? nil : mode
                self?.recompute()
            }
        })
        // `com.notchusage.debug.itemsnapshot` : item en barre sombre et claire, popover s'il est ouvert, dans $TMPDIR.
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.itemsnapshot"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.debugItemSnapshot() }
        })
        // `com.notchusage.debug.homebrew` objet "1" | "0" : les Réglages se comportent comme une installation Homebrew (020).
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.homebrew"), object: nil, queue: .main) { [weak self] note in
            let on = (note.object as? String) == "1"
            MainActor.assumeIsolated {
                UpdateLauncher.debugForceHomebrew = on
                self?.recompute()
            }
        })
        // `com.notchusage.debug.capsulehover` objet "1" | "0" : ouvre ou ferme la carte de la pastille (captures).
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.capsulehover"), object: nil, queue: .main) { [weak self] note in
            let inside = (note.object as? String) == "1"
            MainActor.assumeIsolated { self?.debugCapsuleHover(inside) }
        })
        // `com.notchusage.debug.popover` : ouvre le popover de l'item (captures).
        demoObservers.append(center.addObserver(forName: .init("com.notchusage.debug.popover"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.debugOpenPopover() }
        })
    }

    /// Sessions Claude fictives (017) : « arrival » date l'événement de maintenant pour montrer le mot 4 s.
    func applyDemoClaude(_ mode: String) {
        let now = Date()
        func event(_ kind: ClaudeHookEvent.Kind, _ id: String, cwd: String, title: String? = nil, tool: String? = nil, ago: TimeInterval) -> ClaudeHookEvent {
            ClaudeHookEvent(kind: kind, sessionID: id, cwd: cwd, sessionTitle: title, toolName: tool, promptID: id, pid: nil, receivedAt: now.addingTimeInterval(-ago))
        }
        var tracker = ClaudeSessionTracker()
        switch mode {
        case "approval":
            tracker = tracker.reduce(event(.permissionRequest, "a1", cwd: "/Users/demo/Projects/Notch-Usage", tool: "Bash", ago: 120))
        case "arrival":
            tracker = tracker.reduce(event(.permissionRequest, "a1", cwd: "/Users/demo/Projects/Notch-Usage", tool: "Bash", ago: 0))
        case "question":
            tracker = tracker.reduce(event(.userPromptSubmit, "q1", cwd: "/Users/demo/Projects/Notch-Usage", title: "Limites Fable en mode replié", ago: 600))
                .reduce(event(.permissionRequest, "q1", cwd: "/Users/demo/Projects/Notch-Usage", tool: ClaudeHookEvent.questionTool, ago: 45))
        case "done":
            tracker = tracker.reduce(event(.stop, "d1", cwd: "/Users/demo/Projects/deck-q4", ago: 360))
        case "approval3":
            tracker = tracker.reduce(event(.permissionRequest, "a1", cwd: "/Users/demo/Projects/Notch-Usage", tool: "Bash", ago: 120))
                .reduce(event(.permissionRequest, "a2", cwd: "/Users/demo/Projects/ontraak-site", tool: "Edit", ago: 45))
                .reduce(event(.stop, "d1", cwd: "/Users/demo/Projects/deck-q4", ago: 360))
        default:
            demoClaude = nil
            recompute()
            return
        }
        demoClaude = tracker
        if mode == "arrival" {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(AttentionFormat.arrivalDuration), tolerance: .milliseconds(50))
                self?.recompute()
            }
        }
        recompute()
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
