import AppKit
import CoreGraphics

/// Heuristique plein écran sans API privée ni permission (R6) : une fenêtre de couche 0 de
/// l'app frontale couvre tout l'écran principal. Faux négatifs acceptés.
@MainActor
final class FullscreenObserver {
    var onChange: ((Bool) -> Void)?
    var screen: NSScreen? { didSet { evaluate() } }
    private(set) var isFullscreen = false
    private var tokens: [any NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            })
        }
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        })
        evaluate()
    }

    func stop() {
        tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0); NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }

    func evaluate() {
        let result = Self.frontmostAppCoversScreen(screen ?? NSScreen.screens.first)
        guard result != isFullscreen else { return }
        isFullscreen = result
        Log.notch.notice("fullscreen: \(result)")
        onChange?(result)
    }

    private static func frontmostAppCoversScreen(_ screen: NSScreen?) -> Bool {
        guard let screen, let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != "com.apple.finder",
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        // CGWindowList : origine en haut à gauche de l'écran principal ; NSScreen : en bas à gauche.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let target = CGRect(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
        let tolerance: CGFloat = 2
        return windows.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return false }
            return abs(bounds.minX - target.minX) <= tolerance && abs(bounds.minY - target.minY) <= tolerance
                && abs(bounds.width - target.width) <= tolerance && abs(bounds.height - target.height) <= tolerance
        }
    }
}
