import AppKit
import CoreGraphics

/// Écran de la barre de menus active sans item dans la barre (icône réglée sur « Jamais ») : la sonde de largeur
/// nulle de la 018 laissait un trou entre deux icônes (retour utilisateur). La barre suit la fenêtre active ; on la
/// déduit du clic (écran sous le pointeur) et du changement d'app (écran de sa fenêtre au premier plan). Moniteur
/// global de souris : aucune permission (seul le clavier en demande), aucun timer.
@MainActor
final class ActiveBarTracker {
    var onChange: ((String?) -> Void)?
    private(set) var screenID: String?
    private var mouseMonitor: Any?
    private var activationToken: (any NSObjectProtocol)?

    func start() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.update(Self.screen(containing: NSEvent.mouseLocation)) }
        }
        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                guard let pid, let screen = Self.frontWindowScreen(pid: pid) else { return }
                self?.update(screen)
            }
        }
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { update(Self.frontWindowScreen(pid: pid)) }
    }

    func stop() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        if let activationToken { NSWorkspace.shared.notificationCenter.removeObserver(activationToken) }
        activationToken = nil
        screenID = nil
    }

    private func update(_ screen: NSScreen?) {
        guard let screen else { return }
        let id = ScreenObserver.id(of: screen)
        guard id != screenID else { return }
        screenID = id
        Log.notch.notice("active menu bar on screen \(id, privacy: .public) (tracker)")
        onChange?(id)
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// Fenêtre normale au premier plan de l'app : `CGWindowList` va de l'avant vers l'arrière.
    private static func frontWindowScreen(pid: pid_t) -> NSScreen? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid, (info[kCGWindowLayer as String] as? Int) == 0,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary, let b = CGRect(dictionaryRepresentation: dict),
                  b.width > 40, b.height > 40 else { continue }
            // CGWindowList : origine en haut à gauche de l'écran principal ; NSScreen : en bas à gauche.
            let rect = NSRect(x: b.minX, y: primaryHeight - b.maxY, width: b.width, height: b.height)
            return NSScreen.screens.max { $0.frame.intersection(rect).area < $1.frame.intersection(rect).area }
        }
        return nil
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
