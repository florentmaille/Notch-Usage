import Foundation
import ServiceManagement

/// Lancement à l'ouverture de session (FR-020), désactivé par défaut. Ne fonctionne que depuis un `.app`.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unavailable
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        default: return .disabled
        }
    }

    @discardableResult
    static func set(enabled: Bool) -> Status {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.app.error("launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        return status
    }
}
