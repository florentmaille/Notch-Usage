import AppKit
import NotchUsageCore
import SwiftUI

/// Position, taille, survol, épinglage et fermeture du panneau (R5, FR-012, FR-012a).
@MainActor
final class NotchPanelController {
    static let wingWidth: CGFloat = 72
    static let expandedWidth: CGFloat = 440
    static let expandedHeight: CGFloat = 320
    static let hiddenStripHeight: CGFloat = 2
    static let hoverOpenDelay: TimeInterval = 0.15
    static let hoverCloseDelay: TimeInterval = 0.10

    var onHoverChange: ((Bool) -> Void)?
    var onToggleClick: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let panel: NotchPanel
    private let hoverView: HoverView
    private let hosting: FirstMouseHostingView
    private var target: ScreenObserver.Target
    private var display: DisplayState?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var hoverWork: DispatchWorkItem?

    init(target: ScreenObserver.Target, rootView: AnyView) {
        self.target = target
        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        hoverView = HoverView(frame: panel.contentLayoutRect)
        hosting = FirstMouseHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hoverView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: hoverView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: hoverView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: hoverView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: hoverView.bottomAnchor),
        ])
        panel.contentView = hoverView
        hoverView.onEnter = { [weak self] in self?.scheduleHover(true) }
        hoverView.onExit = { [weak self] in self?.scheduleHover(false) }
        panel.onMouseDown = { [weak self] point in self?.handleMouseDown(at: point) }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event } // Échap
            self.onDismiss?()
            return nil
        }
        panel.orderFrontRegardless()
        #if DEBUG
        installDebugHooks()
        #endif
    }

    func update(target: ScreenObserver.Target) {
        self.target = target
        if let display { apply(display) }
    }

    /// Redimensionne et repositionne selon l'état d'affichage.
    func apply(_ display: DisplayState) {
        let previous = self.display
        self.display = display
        let layout = display.layout
        let collapsedWidth = layout.mode == .notch ? layout.width + 2 * Self.wingWidth : layout.width
        let size: CGSize
        if display.fullscreenHidden {
            size = CGSize(width: collapsedWidth, height: Self.hiddenStripHeight)
        } else if display.isExpanded {
            size = CGSize(width: max(collapsedWidth, Self.expandedWidth), height: layout.height + Self.expandedHeight)
        } else {
            size = CGSize(width: collapsedWidth, height: layout.height)
        }
        let frame = target.screen.frame
        let origin = CGPoint(x: (frame.midX - size.width / 2).rounded(), y: frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }

        let pinned = display.panel == .pinned
        if pinned, previous?.panel != .pinned {
            panel.makeKey()
            installGlobalClickMonitor()
        } else if !pinned, previous?.panel == .pinned {
            removeGlobalClickMonitor()
            if panel.isKeyWindow { panel.resignKey() }
        }
    }

    func close() {
        removeGlobalClickMonitor()
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        localKeyMonitor = nil
        hoverWork?.cancel()
        panel.orderOut(nil)
        panel.close()
    }

    /// FR-012 : un clic épingle ; une fois épinglé, seul un clic sur la bande de l'encoche désépingle
    /// (les clics dans le contenu servent aux boutons et aux réglages).
    private func handleMouseDown(at point: NSPoint) {
        guard let display else { return }
        let inStrip = point.y >= panel.frame.height - display.layout.height
        if display.panel != .pinned || inStrip { onToggleClick?() }
    }

    private func scheduleHover(_ inside: Bool) {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onHoverChange?(inside) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? Self.hoverOpenDelay : Self.hoverCloseDelay), execute: work)
    }

    private func installGlobalClickMonitor() {
        guard globalClickMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Les moniteurs globaux ne reçoivent pas les clics dans notre propre fenêtre : c'est donc un clic ailleurs.
            Task { @MainActor in self?.onDismiss?() }
        }
    }

    private func removeGlobalClickMonitor() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        globalClickMonitor = nil
    }
}

/// Le panneau n'a pas le focus clavier quand il est ouvert au survol : sans ceci, SwiftUI
/// consomme le premier clic et les boutons semblent ne pas répondre.
final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

#if DEBUG
/// Crochets de test (build Debug uniquement) : simuler survol et clic dans le panneau, capturer son rendu,
/// sans permission Accessibilité ni Enregistrement d'écran.
/// `com.notchusage.debug.hover` objet "1"/"0", `.click` objet "x,y" (pt depuis le coin haut gauche), `.snapshot`.
extension NotchPanelController {
    fileprivate func installDebugHooks() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.notchusage.debug.hover"), object: nil, queue: .main) { [weak self] note in
            let inside = (note.object as? String) == "1"
            MainActor.assumeIsolated { self?.onHoverChange?(inside) }
        }
        center.addObserver(forName: .init("com.notchusage.debug.click"), object: nil, queue: .main) { [weak self] note in
            let parts = ((note.object as? String) ?? "").split(separator: ",").compactMap { Double($0) }
            guard parts.count == 2 else { return }
            MainActor.assumeIsolated { self?.debugClick(x: parts[0], y: parts[1]) }
        }
        center.addObserver(forName: .init("com.notchusage.debug.escape"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                             windowNumber: self.panel.windowNumber, context: nil, characters: "\u{1b}",
                                                             charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) else { return }
                NSApp.postEvent(event, atStart: false)
            }
        }
        center.addObserver(forName: .init("com.notchusage.debug.snapshot"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.debugSnapshot() }
        }
    }

    private func debugClick(x: Double, y: Double) {
        let point = NSPoint(x: x, y: panel.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) else { continue }
            NSApp.postEvent(event, atStart: false)
        }
        Log.app.notice("debug click at \(x),\(y) key=\(self.panel.isKeyWindow)")
    }

    private func debugSnapshot() {
        let view = hoverView
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("notchusage-snapshot.png")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        Log.app.notice("debug snapshot \(url.path, privacy: .public) \(Int(view.bounds.width))x\(Int(view.bounds.height))")
    }
}
#endif

/// Zone de survol et de clic couvrant tout le panneau.
final class HoverView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
    override var acceptsFirstResponder: Bool { true }
}
