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
    private let hosting: NSHostingView<AnyView>
    private var target: ScreenObserver.Target
    private var display: DisplayState?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var hoverWork: DispatchWorkItem?

    init(target: ScreenObserver.Target, rootView: AnyView) {
        self.target = target
        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10))
        hoverView = HoverView(frame: panel.contentLayoutRect)
        hosting = NSHostingView(rootView: rootView)
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
        hoverView.onClick = { [weak self] in self?.onToggleClick?() }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event } // Échap
            self.onDismiss?()
            return nil
        }
        panel.orderFrontRegardless()
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

/// Zone de survol et de clic couvrant tout le panneau.
final class HoverView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onClick: (() -> Void)?
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
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onClick?()
    }
    override var acceptsFirstResponder: Bool { true }
}
