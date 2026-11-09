import AppKit
import NotchUsageCore

/// Écrans connectés → rôles (018, R1) : l'île sur l'écran à encoche, l'item et la pastille sur les autres.
/// Recalculé quand la configuration change ; la notification tire plusieurs fois, on compare une signature.
@MainActor
final class ScreenObserver {
    /// Écran de l'île et sa géométrie, pour `NotchPanelController`.
    struct Target: Equatable {
        let screen: NSScreen
        let layout: NotchLayout
        static func == (a: Target, b: Target) -> Bool { a.screen == b.screen && a.layout == b.layout }
    }

    struct Snapshot {
        let roles: ScreenRoles
        let screens: [String: NSScreen]

        var island: Target? {
            guard let island = roles.island, let screen = screens[island.id] else { return nil }
            return Target(screen: screen, layout: island.layout)
        }
    }

    private(set) var current = Snapshot(roles: .empty, screens: [:])
    var onChange: ((Snapshot) -> Void)?
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
        let all = NSScreen.screens
        let sig = all.map { "\(Self.id(of: $0))@\($0.frame)@\($0.safeAreaInsets.top)" }.joined(separator: "|")
        guard force || sig != signature else { return }
        signature = sig
        let descriptors = all.enumerated().map { index, screen in Self.descriptor(screen, isMain: index == 0) }
        let snapshot = Snapshot(roles: ScreenRoles.assign(descriptors),
                                screens: Dictionary(all.map { (Self.id(of: $0), $0) }, uniquingKeysWith: { a, _ in a }))
        current = snapshot
        Log.notch.notice("screens changed: island \(snapshot.roles.island?.id ?? "none", privacy: .public), plain \(snapshot.roles.plain.map { "\($0.id)\($0.capsuleEligible ? "+" : "")" }.joined(separator: ","), privacy: .public)")
        onChange?(snapshot)
    }

    static func id(of screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "?"
    }

    static func descriptor(_ screen: NSScreen, isMain: Bool, forceNoNotch: Bool = false) -> ScreenDescriptor {
        ScreenDescriptor(id: id(of: screen), width: screen.frame.width,
                         safeAreaTop: forceNoNotch ? 0 : screen.safeAreaInsets.top,
                         auxLeftWidth: forceNoNotch ? nil : screen.auxiliaryTopLeftArea?.width,
                         auxRightWidth: forceNoNotch ? nil : screen.auxiliaryTopRightArea?.width,
                         isMain: isMain)
    }
}
