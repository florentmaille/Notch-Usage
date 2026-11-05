import Foundation
import NotchUsageCore
import UserNotifications

/// Notifications système (008) : une à l'entrée en palier imminent, au seuil critique et à l'épuisement, par
/// limite et par période (`NotificationGate`). L'autorisation est demandée à la première notification.
@MainActor
final class SignalNotifier {
    private var gate = NotificationGate()
    private var authorizationRequested = false

    /// Compare le signal courant à la limite qu'il porte et notifie si le motif est nouveau pour la période.
    func notifyIfNeeded(signal: NotchSignal, display: DisplayState, enabled: Bool, now: Date) {
        guard enabled, let limit = display.headline?.limit, let reason = reason(for: signal) else { return }
        guard gate.shouldNotify(limitID: limit.id, reason: reason, resetsAt: limit.resetsAt) else { return }
        send(reason: reason, signal: signal, limit: limit, now: now)
    }

    private func reason(for signal: NotchSignal) -> NotificationGate.Reason? {
        switch (signal.content, signal.edge) {
        case (.exhausted, _): return .exhausted
        case (.deadline, .imminent?): return .imminent
        case (.threshold, .imminent?): return .critical
        default: return nil
        }
    }

    /// Session Claude en attente (017, option désactivée par défaut) : approbation ou question, une par demande.
    func notifyClaude(name: String, kind: ClaudeWaitingKind, id: String) {
        guard kind.isBlocking else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Claude is waiting")
        content.body = kind == .question ? String(localized: "\(name): question pending") : String(localized: "\(name): approval needed")
        content.sound = .default
        deliver(UNNotificationRequest(identifier: "claude-\(id)", content: content, trigger: nil), log: "claude \(kind)")
    }

    private func send(reason: NotificationGate.Reason, signal: NotchSignal, limit: UsageLimit, now: Date) {
        let content = UNMutableNotificationContent()
        let name = LimitLabel.text(for: limit)
        switch (reason, signal.content) {
        case (.imminent, .deadline(let label)):
            content.title = String(localized: "A block is coming")
            content.body = String(localized: "\(name): at this pace, blocked at \(label).")
        case (.exhausted, .exhausted(_, let back)):
            content.title = String(localized: "Limit reached")
            content.body = String(localized: "\(name): back in \(back).")
        case (.critical, .threshold(_, let percent)):
            content.title = String(localized: "Limit almost reached")
            content.body = String(localized: "\(name): \(percent) used.")
        default:
            return
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "\(limit.id)-\(reason.rawValue)-\(Int(now.timeIntervalSince1970))",
                                            content: content, trigger: nil)
        deliver(request, log: "\(reason.rawValue) for \(limit.id)")
    }

    private func deliver(_ request: UNNotificationRequest, log: String) {
        let center = UNUserNotificationCenter.current()
        Task {
            if !authorizationRequested {
                authorizationRequested = true
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            do {
                try await center.add(request)
                Log.app.notice("notification \(log, privacy: .public)")
            } catch {
                Log.app.error("notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
