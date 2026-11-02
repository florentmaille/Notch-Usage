import AppKit
import CoreGraphics
import NotchUsageCore

/// Suit l'état plein écran de l'écran du panneau (R6). La règle est dans `FullscreenHeuristic`.
@MainActor
final class FullscreenObserver {
    var onChange: ((Bool) -> Void)?
    var screen: NSScreen? { didSet { evaluate() } }
    private(set) var isFullscreen = false
    private var tokens: [any NSObjectProtocol] = []
    private var followUps: [DispatchWorkItem] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluateNowAndAfterTransition() }
            })
        }
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        })
        evaluate()
    }

    /// La notification arrive pendant l'animation de l'espace : à la sortie du plein écran, la fenêtre
    /// couvre encore l'écran. Deux contrôles différés rattrapent l'état final.
    private func evaluateNowAndAfterTransition() {
        evaluate()
        followUps.forEach { $0.cancel() }
        followUps = [0.6, 1.5].map { delay in
            let work = DispatchWorkItem { [weak self] in self?.evaluate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    func stop() {
        followUps.forEach { $0.cancel() }
        followUps.removeAll()
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
        let target = WindowFrame(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY,
                                 width: screen.frame.width, height: screen.frame.height)
        var frontmost: [WindowFrame] = []
        var others: [WindowFrame] = []
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let frame = WindowFrame(x: b.minX, y: b.minY, width: b.width, height: b.height)
            if pid == app.processIdentifier { frontmost.append(frame) } else { others.append(frame) }
        }
        return FullscreenHeuristic.isFullscreen(screen: target, frontmost: frontmost, others: others)
    }
}
