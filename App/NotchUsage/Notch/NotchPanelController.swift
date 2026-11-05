import AppKit
import NotchUsageCore
import SwiftUI

/// Position, taille, survol, épinglage et fermeture du panneau (R5, FR-012, FR-012a).
@MainActor
final class NotchPanelController {
    /// Aile de la bande au survol (003).
    static let wingWidth: CGFloat = 72
    /// Oreille de l'île repliée (012).
    static let earWidth: CGFloat = 52
    /// Oreille droite le temps du mot d'arrivée d'une session Claude (017) : glyphe + un mot.
    static let arrivalEarWidth: CGFloat = 116
    static let expandedWidth: CGFloat = 440
    /// Hauteur de départ du contenu déplié, avant la première mesure.
    static let expandedHeight: CGFloat = 320
    /// Hauteur du contenu déplié mesurée par SwiftUI (hors réglages).
    var contentHeight: CGFloat = expandedHeight
    static let hiddenStripHeight: CGFloat = 2
    /// Fondu de l'île (012) : le cadre attend sa fin avant de rétrécir.
    static let islandFade: TimeInterval = 0.3
    static let hoverOpenDelay: TimeInterval = 0.15
    static let hoverCloseDelay: TimeInterval = 0.10

    var onHoverChange: ((Bool) -> Void)?
    var onDismiss: (() -> Void)?

    private let panel: NotchPanel
    private let hoverView: HoverView
    private let hosting: FirstMouseHostingView
    private var target: ScreenObserver.Target
    private var display: DisplayState?
    /// Un menu (Langue) est ouvert : il sort du panneau, qui ne doit pas se refermer pendant le choix.
    private var menuTracking = false
    private var menuObservers: [any NSObjectProtocol] = []
    private var localKeyMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var ears: (left: CGFloat, right: CGFloat) = (0, 0)
    /// Ouvert depuis la barre de menus, pointeur ailleurs : aucune sortie ne referme le panneau avant
    /// un premier survol ; Échap ou un clic hors de l'app le referme.
    private var heldOpen = false
    private var outsideClickMonitor: Any?

    init(target: ScreenObserver.Target, rootView: AnyView) {
        self.target = target
        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        hoverView = HoverView(frame: panel.contentLayoutRect)
        hosting = FirstMouseHostingView(rootView: rootView)
        // Le contrôleur seul fixe la taille du panneau : sinon la hauteur idéale du contenu,
        // remontée par SwiftUI, redimensionne la fenêtre en boucle.
        hosting.sizingOptions = []
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
        let center = NotificationCenter.default
        menuObservers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuTracking = true }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuDidEnd() }
            },
        ]
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

    /// Redimensionne et repositionne selon l'état d'affichage. Replié dans l'encoche, le cadre couvre l'encoche
    /// physique et les oreilles visibles (012) : la zone de survol et les clics suivent ces oreilles seulement.
    func apply(_ display: DisplayState, ears: (left: CGFloat, right: CGFloat)? = nil) {
        let previous = self.display
        self.display = display
        // Changement d'écran : les oreilles restent celles du dernier état.
        let ears = ears ?? self.ears
        self.ears = ears
        let layout = display.layout
        let screen = target.screen.frame
        let wideWidth = layout.mode == .notch ? layout.width + 2 * Self.wingWidth : layout.width
        let rect: NSRect
        if display.fullscreenHidden {
            rect = Self.centered(CGSize(width: wideWidth, height: Self.hiddenStripHeight), in: screen)
        } else if display.isExpanded {
            let height = layout.height + contentHeight
            rect = Self.centered(CGSize(width: max(wideWidth, Self.expandedWidth), height: height), in: screen)
        } else if layout.mode == .notch {
            let width = layout.width + ears.left + ears.right
            let x = (screen.midX - layout.width / 2 - ears.left).rounded()
            rect = NSRect(x: x, y: screen.maxY - layout.height, width: width, height: layout.height)
        } else {
            rect = Self.centered(CGSize(width: layout.width, height: layout.height), in: screen)
        }
        shrinkWork?.cancel()
        shrinkWork = nil
        let shrinking = rect.width < panel.frame.width && !display.isExpanded && !display.fullscreenHidden && previous?.isExpanded == false
        if shrinking {
            // L'oreille qui disparaît joue son fondu dans l'ancien cadre ; le cadre rétrécit ensuite.
            let work = DispatchWorkItem { [weak self] in self?.setFrame(rect) }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.islandFade, execute: work)
        } else {
            setFrame(rect)
        }
        if !panel.isVisible { panel.orderFrontRegardless() }

        // Ouvert : le panneau prend le clavier (champ de clé, Échap) ; replié, il le rend.
        if !display.isExpanded, heldOpen { releaseHold() }
        if display.isExpanded, previous?.isExpanded != true {
            panel.makeKey()
        } else if !display.isExpanded, previous?.isExpanded == true, panel.isKeyWindow {
            panel.resignKey()
        }
    }

    private func setFrame(_ rect: NSRect) {
        guard rect != panel.frame else { return }
        panel.setFrame(rect, display: true)
    }

    private static func centered(_ size: CGSize, in screen: NSRect) -> NSRect {
        NSRect(origin: CGPoint(x: (screen.midX - size.width / 2).rounded(), y: screen.maxY - size.height), size: size)
    }

    func close() {
        menuObservers.forEach { NotificationCenter.default.removeObserver($0) }
        menuObservers = []
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        localKeyMonitor = nil
        releaseHold()
        hoverWork?.cancel()
        shrinkWork?.cancel()
        panel.orderOut(nil)
        panel.close()
    }

    func holdOpen() {
        heldOpen = true
        hoverWork?.cancel()
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.onDismiss?() }
        }
    }

    private func releaseHold() {
        heldOpen = false
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private func scheduleHover(_ inside: Bool) {
        // Le menu Langue recouvre le pointeur : la sortie n'en est pas une tant qu'il est ouvert.
        if !inside, menuTracking || heldOpen { return }
        if inside, heldOpen { releaseHold() }
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onHoverChange?(inside) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? Self.hoverOpenDelay : Self.hoverCloseDelay), execute: work)
    }

    /// Menu refermé : si le pointeur a quitté le panneau entre-temps, on referme.
    private func menuDidEnd() {
        menuTracking = false
        if !panel.frame.contains(NSEvent.mouseLocation) { scheduleHover(false) }
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

    /// AppKit n'appelle pas `updateTrackingAreas` pour la vue de contenu d'un panneau sans bordure :
    /// la zone est posée dès l'arrivée dans la fenêtre. `.inVisibleRect` suit ensuite les redimensionnements.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installTracking()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installTracking()
    }

    private func installTracking() {
        if let tracking { removeTrackingArea(tracking) }
        guard window != nil else { tracking = nil; return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        Log.notch.debug("tracking area installed")
    }

    override func mouseEntered(with event: NSEvent) {
        Log.notch.debug("hover enter")
        onEnter?()
    }
    override func mouseExited(with event: NSEvent) {
        Log.notch.debug("hover exit")
        onExit?()
    }
    override var acceptsFirstResponder: Bool { true }
}
