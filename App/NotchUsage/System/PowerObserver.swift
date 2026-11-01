import AppKit
import Foundation
import NotchUsageCore

/// Veille, écrans éteints, verrouillage et économie d'énergie → pause / reprise (R7, FR-008).
@MainActor
final class PowerObserver {
    var onPause: ((PauseReason) -> Void)?
    var onResume: ((PauseReason) -> Void)?

    private var tokens: [any NSObjectProtocol] = []
    private let workspace = NSWorkspace.shared.notificationCenter
    private let distributed = DistributedNotificationCenter.default()

    func start() {
        observe(workspace, NSWorkspace.willSleepNotification) { $0.onPause?(.sleep) }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.onPause?(.sleep) }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.onResume?(.sleep) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.onResume?(.sleep) }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.onPause?(.screenLocked) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.onResume?(.screenLocked) }
        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) { $0.applyLowPowerState() }
        applyLowPowerState()
    }

    func stop() {
        tokens.forEach { workspace.removeObserver($0); distributed.removeObserver($0); NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }

    private func applyLowPowerState() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { onPause?(.lowPower) } else { onResume?(.lowPower) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor (PowerObserver) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.app.debug("power event: \(name.rawValue, privacy: .public)")
                handler(self)
            }
        }
        tokens.append(token)
    }
}
