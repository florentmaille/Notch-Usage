import AppKit
import NotchUsageCore
import SwiftUI

/// Position, taille, survol, épinglage et fermeture du panneau (R5, FR-012, FR-012a).
@MainActor
final class NotchPanelController {
    /// Oreille de l'île repliée (012).
    static let earWidth: CGFloat = 52
    /// Oreille droite le temps du mot d'arrivée d'une session Claude (017) : glyphe + un mot.
    static let arrivalEarWidth: CGFloat = 116
    static let expandedWidth: CGFloat = 440
    /// Carte du survol (019) : détachée de l'île, 6 pt sous l'encoche, comme la carte de la pastille (018).
    static let cardWidth: CGFloat = 380
    static let cardGap: CGFloat = 6
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
    private let menus = MenuTracking()
    private var localKeyMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var ears: (left: CGFloat, right: CGFloat) = (0, 0)
    /// Ouvert depuis la barre de menus, pointeur ailleurs : aucune sortie ne referme le panneau avant
    /// un premier survol ; Échap ou un clic hors de l'app le referme.
    private var heldOpen = false
    private var outsideClickMonitor: Any?

    /// Contenu de la carte (panneau de l'île) et sa fenêtre, créée au premier survol.
    private let cardView: AnyView
    private var cardPanel: NotchPanel?

    init(target: ScreenObserver.Target, rootView: AnyView, cardView: AnyView) {
        self.target = target
        self.cardView = cardView
        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        // L'île ne contient aucun champ de saisie : un clic dessus (effacer les « terminé ») ne prend pas le clavier.
        panel.becomesKeyOnlyIfNeeded = true
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
        menus.onEnd = { [weak self] in self?.menuDidEnd() }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Échap referme l'île ouverte ; sinon la touche continue vers le popover ou la fenêtre de connexion.
            guard let self, event.keyCode == 53, self.display?.isExpanded == true else { return event }
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
        self.display = display
        // Changement d'écran : les oreilles restent celles du dernier état.
        let ears = ears ?? self.ears
        self.ears = ears
        let layout = display.layout
        let screen = target.screen.frame
        let rect = Self.islandFrame(layout: layout, ears: ears, screen: screen, hidden: display.fullscreenHidden)
        shrinkWork?.cancel()
        shrinkWork = nil
        // 019 : l'île ne s'agrandit plus au survol, la carte flotte dessous ; seules les oreilles changent le cadre.
        let shrinking = rect.width < panel.frame.width && !display.fullscreenHidden
        if shrinking {
            // L'oreille qui disparaît joue son fondu dans l'ancien cadre ; le cadre rétrécit ensuite.
            let work = DispatchWorkItem { [weak self] in self?.setFrame(rect) }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.islandFade, execute: work)
        } else {
            setFrame(rect)
        }
        if !panel.isVisible { panel.orderFrontRegardless() }

        // Ouverte au survol, la carte ne prend pas le clavier : pointeur posé sur l'encoche, la frappe continuait
        // d'arriver chez elle au lieu de l'app en cours. Elle le prend au clic (champ de clé, Échap) ou quand elle
        // est ouverte exprès (`holdOpen`). Fermée, elle disparaît et rend le clavier.
        if !display.isExpanded, heldOpen { releaseHold() }
        if display.isExpanded, !display.fullscreenHidden {
            showCard(layout: layout, screen: screen)
        } else {
            hideCard()
        }
    }

    /// Cadre de l'île repliée : l'encoche et ses oreilles. En plein écran, une bande de 2 pt de la même largeur :
    /// le pointeur qui la touche se retrouve sur l'île qui réapparaît. Plus large que l'île, elle la faisait
    /// clignoter (survol, île plus étroite, sortie, bande, survol…).
    static func islandFrame(layout: NotchLayout, ears: (left: CGFloat, right: CGFloat), screen: NSRect, hidden: Bool) -> NSRect {
        let height = hidden ? hiddenStripHeight : layout.height
        let x = (screen.midX - layout.width / 2 - ears.left).rounded()
        return NSRect(x: x, y: screen.maxY - height, width: layout.width + ears.left + ears.right, height: height)
    }

    private func showCard(layout: NotchLayout, screen: NSRect) {
        let card: NotchPanel
        if let cardPanel {
            card = cardPanel
        } else {
            card = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: Self.cardWidth, height: 100))
            let hover = HoverView(frame: .zero)
            let host = FirstMouseHostingView(rootView: cardView)
            host.sizingOptions = []
            host.translatesAutoresizingMaskIntoConstraints = false
            hover.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: hover.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: hover.trailingAnchor),
                host.topAnchor.constraint(equalTo: hover.topAnchor),
                host.bottomAnchor.constraint(equalTo: hover.bottomAnchor),
            ])
            card.contentView = hover
            // L'île et la carte forment une seule zone : passer de l'une à l'autre en 0,10 s ne ferme rien.
            hover.onEnter = { [weak self] in self?.scheduleHover(true) }
            hover.onExit = { [weak self] in self?.scheduleHover(false) }
            cardPanel = card
        }
        let top = screen.maxY - layout.height - Self.cardGap
        let height = CardLayout.height(measured: contentHeight, top: top, floor: target.screen.visibleFrame.minY)
        let frame = NSRect(x: (screen.midX - Self.cardWidth / 2).rounded(), y: top - height,
                           width: Self.cardWidth, height: height)
        if card.frame != frame { card.setFrame(frame, display: true) }
        if !card.isVisible { card.orderFrontRegardless() }
    }

    private func hideCard() {
        guard let cardPanel else { return }
        if cardPanel.isKeyWindow { cardPanel.resignKey() }
        cardPanel.orderOut(nil)
        cardPanel.close()
        self.cardPanel = nil
    }

    private func setFrame(_ rect: NSRect) {
        guard rect != panel.frame else { return }
        panel.setFrame(rect, display: true)
    }

    func close() {
        menus.stop()
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        localKeyMonitor = nil
        releaseHold()
        hoverWork?.cancel()
        shrinkWork?.cancel()
        hideCard()
        panel.orderOut(nil)
        panel.close()
    }

    /// Ouverture demandée (menu de la barre, app rouverte, VoiceOver) : le panneau reste ouvert sans survol et
    /// prend le clavier, pour Échap et la navigation au clavier.
    func holdOpen() {
        heldOpen = true
        hoverWork?.cancel()
        cardPanel?.makeKey()
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
        if !inside, menus.isActive || heldOpen { return }
        if inside, heldOpen { releaseHold() }
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onHoverChange?(inside) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? Self.hoverOpenDelay : Self.hoverCloseDelay), execute: work)
    }

    /// Menu refermé : si le pointeur a quitté le panneau entre-temps, on referme.
    private func menuDidEnd() {
        let mouse = NSEvent.mouseLocation
        if !panel.frame.contains(mouse), cardPanel?.frame.contains(mouse) != true { scheduleHover(false) }
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
        // Les clics de démo visent la carte quand elle est ouverte (019).
        let panel: NSWindow = cardPanel ?? self.panel
        let point = NSPoint(x: x, y: panel.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) else { continue }
            NSApp.postEvent(event, atStart: false)
        }
        Log.app.notice("debug click at \(x),\(y) key=\(self.panel.isKeyWindow)")
    }

    private func debugSnapshot() {
        let view: NSView = cardPanel?.contentView ?? hoverView
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
