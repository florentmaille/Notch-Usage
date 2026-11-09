import AppKit
import NotchUsageCore
import SwiftUI

/// Pastille centrée dans la barre de menus d'un écran sans encoche (018, C′, R6), et sa carte au survol.
/// La fenêtre de la pastille épouse la capsule : elle ne prend jamais les clics des menus voisins.
@MainActor
final class CapsulePanelController {
    static let cardGap: CGFloat = 6
    static let widenDuration: TimeInterval = 0.3

    let screenID: String
    private(set) var screen: NSScreen
    private let model: AppModel
    private let capsulePanel: NotchPanel
    private let capsuleHover: HoverView
    private let capsuleHost: NSHostingView<AnyView>
    private var cardPanel: NotchPanel?
    private var cardHover: HoverView?
    private var content: BarContent?
    private var dark = true
    private var hovered = false
    private var lit = false
    private var lastBeat: Int?
    private var unlightWork: DispatchWorkItem?
    private var hoverWork: DispatchWorkItem?
    private var inside: (capsule: Bool, card: Bool) = (false, false)
    private var keyMonitor: Any?
    /// Ouverture de la carte : l'app ferme le popover et l'île (une seule surface ouverte à la fois).
    var onCardOpen: (() -> Void)?

    init(screenID: String, screen: NSScreen, model: AppModel) {
        self.screenID = screenID
        self.screen = screen
        self.model = model
        capsulePanel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: CapsuleView.height))
        // Pas d'espace plein écran : la barre y est masquée, la pastille aussi (point plein écran : plus tard, R7).
        capsulePanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        capsuleHover = HoverView(frame: .zero)
        capsuleHost = NSHostingView(rootView: AnyView(EmptyView()))
        capsuleHost.sizingOptions = []
        capsuleHost.translatesAutoresizingMaskIntoConstraints = false
        capsuleHover.addSubview(capsuleHost)
        NSLayoutConstraint.activate([
            capsuleHost.leadingAnchor.constraint(equalTo: capsuleHover.leadingAnchor),
            capsuleHost.trailingAnchor.constraint(equalTo: capsuleHover.trailingAnchor),
            capsuleHost.topAnchor.constraint(equalTo: capsuleHover.topAnchor),
            capsuleHost.bottomAnchor.constraint(equalTo: capsuleHover.bottomAnchor),
        ])
        capsulePanel.contentView = capsuleHover
        capsuleHover.onEnter = { [weak self] in self?.pointer(capsule: true) }
        capsuleHover.onExit = { [weak self] in self?.pointer(capsule: false) }
    }

    /// Hauteur de la barre de menus de l'écran ; 0 si elle est masquée automatiquement (pas de pastille).
    static func menuBarHeight(_ screen: NSScreen) -> CGFloat {
        max(0, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    func update(screen: NSScreen) {
        self.screen = screen
        layout(animated: false)
    }

    func apply(content: BarContent, dark: Bool, beat: Int, reduceMotion: Bool) {
        let beatChanged = lastBeat != nil && lastBeat != beat
        lastBeat = beat
        let changed = content != self.content || dark != self.dark
        self.content = content
        self.dark = dark
        if changed { render(animated: !reduceMotion) }
        guard beatChanged, content.gauge?.beats == true, !reduceMotion else { return }
        lit = true
        render(animated: false)
        unlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.lit = false
            self?.render(animated: false)
        }
        unlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + StatusItemController.litDuration, execute: work)
    }

    /// Largeur naturelle de la capsule : `fittingSize` vaut 0 quand l'hôte n'expose pas sa taille (`sizingOptions = []`).
    private var capsuleWidth: CGFloat = 0

    private func render(animated: Bool) {
        guard let content else { return }
        let view = CapsuleView(content: content, dark: dark, hovered: hovered, lit: lit)
        capsuleWidth = NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: 600, height: CapsuleView.height)).width.rounded(.up)
        // La fenêtre couvre toute la hauteur de la barre (survol dès le bord de l'écran) ; un fond quasi transparent
        // capte le pointeur autour de la capsule, qui reste dessinée au centre.
        capsuleHost.rootView = AnyView(ZStack {
            Color.black.opacity(0.001)
            view
        })
        layout(animated: animated)
    }

    /// Centrée sur l'écran, élargie des deux côtés à la fois (FR-014).
    private func layout(animated: Bool) {
        let bar = Self.menuBarHeight(screen)
        guard bar >= CapsuleView.height + 2, content != nil, capsuleWidth > 0 else {
            capsulePanel.orderOut(nil)
            closeCard()
            return
        }
        let width = capsuleWidth
        // Centrée dans la hauteur de la barre (retour utilisateur : pastille agrandie à 22 pt).
        // Toute la hauteur de la barre, largeur de la capsule : le pointeur l'atteint en butée en haut de l'écran.
        let frame = NSRect(x: (screen.frame.midX - width / 2).rounded(), y: screen.frame.maxY - bar, width: width, height: bar)
        if animated, capsulePanel.isVisible, frame != capsulePanel.frame {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Self.widenDuration
                capsulePanel.animator().setFrame(frame, display: true)
            }
        } else {
            capsulePanel.setFrame(frame, display: true)
        }
        if !capsulePanel.isVisible {
            capsulePanel.orderFrontRegardless()
            Log.notch.notice("capsule on screen \(self.screenID, privacy: .public) at \(NSStringFromRect(frame), privacy: .public), bar \(bar)")
        }
        if cardPanel != nil { layoutCard() }
    }

    func close() {
        unlightWork?.cancel()
        hoverWork?.cancel()
        closeCard()
        capsulePanel.orderOut(nil)
        capsulePanel.close()
    }

    // MARK: Survol et carte (FR-015)

    private func pointer(capsule: Bool? = nil, card: Bool? = nil) {
        if let capsule { inside.capsule = capsule }
        if let card { inside.card = card }
        let isInside = inside.capsule || inside.card
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.setHovered(isInside) }
        hoverWork = work
        let delay = isInside ? NotchPanelController.hoverOpenDelay : NotchPanelController.hoverCloseDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func setHovered(_ value: Bool) {
        guard value != hovered else { return }
        hovered = value
        Log.notch.notice("capsule hover \(value) on screen \(self.screenID, privacy: .public)")
        render(animated: false)
        if value { openCard() } else { closeCard() }
    }

    private func openCard() {
        guard cardPanel == nil else { return }
        onCardOpen?()
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: CapsuleCardView.width, height: 100))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let hover = HoverView(frame: .zero)
        let host = FirstMouseHostingView(rootView: AnyView(CapsuleCardView().environment(model)))
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        hover.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: hover.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: hover.trailingAnchor),
            host.topAnchor.constraint(equalTo: hover.topAnchor),
            host.bottomAnchor.constraint(equalTo: hover.bottomAnchor),
        ])
        panel.contentView = hover
        hover.onEnter = { [weak self] in self?.pointer(card: true) }
        hover.onExit = { [weak self] in self?.pointer(card: false) }
        cardPanel = panel
        cardHover = hover
        layoutCard()
        panel.orderFrontRegardless()
        panel.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // Échap
            self?.dismissCard()
            return nil
        }
    }

    private func layoutCard() {
        guard let panel = cardPanel else { return }
        // Mesurée à part : `fittingSize` vaut 0 quand l'hôte n'expose pas sa taille (`sizingOptions = []`).
        // Hauteur idéale : proposer 2000 pt laissait le contenu (`maxHeight: .infinity`) tout prendre.
        let measured = NSHostingController(rootView: CapsuleCardView().fixedSize(horizontal: false, vertical: true).environment(model))
            .sizeThatFits(in: CGSize(width: CapsuleCardView.width, height: 2000)).height
        let height = min(measured.rounded(.up), 560)
        let top = screen.frame.maxY - Self.menuBarHeight(screen) - Self.cardGap
        panel.setFrame(NSRect(x: (screen.frame.midX - CapsuleCardView.width / 2).rounded(), y: top - height,
                              width: CapsuleCardView.width, height: height), display: true)
    }

    /// Le contenu a changé de hauteur (réglages, sessions) : la carte suit.
    func refreshCard() {
        if cardPanel != nil { layoutCard() }
    }

    var isCardOpen: Bool { cardPanel != nil }

    func dismissCard() {
        inside = (false, false)
        hoverWork?.cancel()
        setHovered(false)
    }

    private func closeCard() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        cardPanel?.orderOut(nil)
        cardPanel?.close()
        cardPanel = nil
        cardHover = nil
    }
}
