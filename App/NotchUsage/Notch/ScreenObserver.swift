import AppKit
import NotchUsageCore

/// Écran principal (celui de la barre des menus) → `NotchLayout`, recalculé quand la
/// configuration change. La notification tire plusieurs fois : on compare une signature.
@MainActor
final class ScreenObserver {
    struct Target: Equatable {
        let screen: NSScreen
        let layout: NotchLayout
        static func == (a: Target, b: Target) -> Bool { a.screen == b.screen && a.layout == b.layout }
    }

    private(set) var current: Target?
    var onChange: ((Target) -> Void)?
    private var token: (any NSObjectProtocol)?
    private var signature: String = ""

    func start() {
        token = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh(force: true)
    }

    func stop() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }

    func refresh(force: Bool = false) {
        let sig = NSScreen.screens.map { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "?"
            return "\(id)@\(screen.frame)@\(screen.safeAreaInsets.top)"
        }.joined(separator: "|")
        guard force || sig != signature else { return }
        signature = sig
        guard let screen = NSScreen.screens.first else { return }
        let layout = Self.layout(for: screen)
        let target = Target(screen: screen, layout: layout)
        current = target
        Log.notch.notice("screen changed: mode \(layout.mode == .notch ? "notch" : "pill", privacy: .public) width \(layout.width)")
        onChange?(target)
    }

    static func layout(for screen: NSScreen) -> NotchLayout {
        NotchGeometry.layout(
            screenWidth: screen.frame.width,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }
}
