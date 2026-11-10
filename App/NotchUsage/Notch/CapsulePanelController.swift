import AppKit
import Observation
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
    private let capsuleHost: FirstMouseHostingView
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
    /// Clic sur la pastille : comme sur l'île, les sessions Claude « terminé » s'effacent (017, FR-002).
    var onTap: (() -> Void)?

    init(screenID: String, screen: NSScreen, model: AppModel) {
        self.screenID = screenID
        self.screen = screen
        self.model = model
        capsulePanel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: CapsuleView.height))
        // Pas d'espace plein écran : la barre y est masquée, la pastille aussi (point plein écran : plus tard, R7).
        capsulePanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        capsuleHover = HoverView(frame: .zero)
        // Premier clic accepté sans que la fenêtre ait le clavier, comme pour l'île.
        capsuleHost = FirstMouseHostingView(rootView: AnyView(EmptyView()))
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
        // L'annonce VoiceOver change chaque minute : seule une différence visible re-mesure et anime la pastille.
        let changed = self.content.map { !$0.looksLike(content) } ?? true || dark != self.dark
        self.content = content
        self.dark = dark
        if changed { render(animated: !reduceMotion) } else { state.content = content }
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

    /// État observé par la vue : la racine SwiftUI reste la même, les changements s'animent (fermeture fluide).
    private let state = CapsuleState()
    private var hostsState = false
    private var shrinkWork: DispatchWorkItem?

    private func render(animated: Bool) {
        guard let content else { return }
        let view = CapsuleView(content: content, dark: dark, hovered: hovered, lit: lit)
        capsuleWidth = NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: 600, height: CapsuleView.height)).width.rounded(.up)
        if !hostsState {
            hostsState = true
            capsuleHost.rootView = AnyView(CapsuleRoot(state: state, onTap: { [weak self] in self?.onTap?() }))
        }
        let update = { [state, dark, hovered, lit] in
            state.content = content
            state.dark = dark
            state.hovered = hovered
            state.lit = lit
        }
        let grows = capsulePanel.isVisible && capsuleWidth > capsulePanel.frame.width
        guard animated, capsulePanel.isVisible else {
            update()
            layout(animated: false)
            return
        }
        if grows {
            // La fenêtre s'ouvre d'abord avec l'ancien contenu ; au tour suivant, la capsule s'étire d'un seul tenant.
            layout(animated: true)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: Self.widenDuration)) { update() }
            }
        } else {
            withAnimation(.easeInOut(duration: Self.widenDuration)) { update() }
            layout(animated: true)
        }
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
        // Comme l'île : en s'élargissant, la fenêtre s'ouvre d'abord et la capsule s'anime dedans ; en se resserrant,
        // la capsule s'anime dans l'ancienne fenêtre, qui ne rétrécit qu'à la fin du fondu.
        shrinkWork?.cancel()
        shrinkWork = nil
        if animated, capsulePanel.isVisible, frame.width < capsulePanel.frame.width {
            let work = DispatchWorkItem { [weak self] in self?.capsulePanel.setFrame(frame, display: true) }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.widenDuration, execute: work)
        } else if frame != capsulePanel.frame {
            capsulePanel.setFrame(frame, display: true)
        }
        if !capsulePanel.isVisible {
            capsulePanel.orderFrontRegardless()
            Log.notch.notice("capsule on screen \(self.screenID, privacy: .public) at \(NSStringFromRect(frame), privacy: .public), bar \(bar)")
        }
        if cardPanel != nil { layoutCard() }
    }

    func close() {
        shrinkWork?.cancel()
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

@MainActor
@Observable
final class CapsuleState {
    var content: BarContent?
    var dark = true
    var hovered = false
    var lit = false
}

/// Racine stable de la fenêtre : toute la hauteur de la barre (survol dès le bord de l'écran), un fond quasi
/// transparent qui capte le pointeur, la capsule au centre.
private struct CapsuleRoot: View {
    let state: CapsuleState
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
            if let content = state.content {
                CapsuleView(content: content, dark: state.dark, hovered: state.hovered, lit: state.lit)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.easeOut(duration: 0.12), value: state.hovered)
    }
}

#if DEBUG
/// Capture de la pastille et de sa carte (build Debug, captures du README) dans $TMPDIR.
extension CapsulePanelController {
    func debugSnapshot() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        for (name, view) in [("capsule", capsulePanel.contentView), ("capsule-card", cardPanel?.contentView)] {
            guard let view, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("notchusage-\(name).png"))
        }
        // Rendu 2x indépendant de l'écran (le Dell est en 1x) : la capsule seule, fond transparent.
        if let content = state.content {
            let renderer = ImageRenderer(content: CapsuleView(content: content, dark: state.dark))
            renderer.scale = 2
            if let cg = renderer.cgImage {
                try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?
                    .write(to: dir.appendingPathComponent("notchusage-capsule@2x.png"))
            }
        }
        Log.app.notice("debug capsule snapshot \(dir.path, privacy: .public)")
    }

    /// Ouvre ou ferme la carte comme un survol (captures).
    func debugHover(_ inside: Bool) { setHovered(inside) }
}
#endif
