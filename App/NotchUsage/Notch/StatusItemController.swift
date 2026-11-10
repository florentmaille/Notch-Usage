import AppKit
import NotchUsageCore
import SwiftUI

/// Item de barre de menus (014, enrichi en 018) : anneau, texte et attente Claude (`BarContent`), compact sur la
/// barre de l'écran à encoche. Clic gauche : popover avec le contenu du panneau de l'île ; clic droit : le menu
/// des limites, « Actualiser », « Réglages » et « Quitter ».
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private let item: NSStatusItem
    private weak var model: AppModel?
    private let menu = NSMenu()
    private var popover: NSPopover?
    private var drawn: BarContent?
    private var lastBeat: Int?
    private var unlightWork: DispatchWorkItem?
    private var observers: [(NotificationCenter, any NSObjectProtocol)] = []
    /// Écran qui porte la fenêtre de l'item, donc la barre de menus active (R4, spike).
    var onActiveScreenChange: ((String?) -> Void)?
    private var activeScreenID: String??

    /// Durée de la phase éclairée d'un battement (006 : double battement de l'île en ~0,8 s).
    static let litDuration: TimeInterval = 0.4

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.button?.toolTip = "Notch Usage"
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageOnly
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append((workspace, workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readActiveScreen() }
        }))
        // La fenêtre du bouton n'existe qu'après l'ajout à la barre.
        DispatchQueue.main.async { [weak self] in self?.observeButtonWindow() }
    }

    /// Fenêtre de l'item observée : elle n'existe qu'une fois l'item dessiné dans la barre, parfois après l'init.
    private weak var observedWindow: NSWindow?

    private func observeButtonWindow() {
        guard let window = item.button?.window, window !== observedWindow else {
            Log.notch.debug("menu bar item window: \(self.item.button?.window == nil ? "none" : "already observed", privacy: .public)")
            return
        }
        observedWindow = window
        Log.notch.notice("menu bar item window observed")
        let center = NotificationCenter.default
        observers.append((center, center.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readActiveScreen() }
        }))
        readActiveScreen()
    }

    private func readActiveScreen() {
        let id = item.button?.window?.screen.map(ScreenObserver.id(of:))
        guard activeScreenID != .some(id) else { return }
        activeScreenID = .some(id)
        Log.notch.notice("menu bar item on screen \(id ?? "none", privacy: .public)")
        onActiveScreenChange?(id)
    }

    /// Redessine seulement si le contenu change (FR-021) ; un nouveau battement éclaire l'anneau un instant (006).
    func update(content: BarContent, beat: Int, reduceMotion: Bool) {
        if observedWindow == nil { observeButtonWindow() }
        let beatChanged = lastBeat != nil && lastBeat != beat
        lastBeat = beat
        if content != drawn {
            // L'annonce VoiceOver change chaque minute : l'image n'est régénérée que si le dessin change (FR-021).
            let redraw = drawn.map { !$0.looksLike(content) } ?? true
            drawn = content
            if redraw { item.button?.image = BarContentImage.image(content) }
            item.button?.setAccessibilityLabel(content.accessibility)
            // La fenêtre peut n'apparaître qu'après ce premier dessin : nouvelle tentative au tour suivant.
            if observedWindow == nil { DispatchQueue.main.async { [weak self] in self?.observeButtonWindow() } }
        }
        guard beatChanged, content.gauge?.beats == true, !reduceMotion else { return }
        item.button?.image = BarContentImage.image(content, lit: true)
        unlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let drawn = self.drawn else { return }
            self.item.button?.image = BarContentImage.image(drawn)
        }
        unlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.litDuration, execute: work)
    }

    func remove() {
        closePopover()
        unlightWork?.cancel()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers = []
        NSStatusBar.system.removeStatusItem(item)
    }

    // MARK: Clic

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            closePopover()
            // Menu attaché le temps du clic : sinon il prendrait aussi le clic gauche.
            item.menu = menu
            sender.performClick(nil)
            item.menu = nil
        } else if popover?.isShown == true {
            closePopover()
        } else {
            showPopover(from: sender)
        }
    }

    private func showPopover(from button: NSStatusBarButton) {
        guard let model else { return }
        model.popoverWillOpen()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        // Même fond noir que l'île : le contenu est écrit en blanc, le matériau du popover suit sinon la barre.
        popover.appearance = NSAppearance(named: .vibrantDark)
        let host = NSHostingController(rootView: AnyView(
            PanelContentView(reportsHeight: false)
                .frame(width: Self.popoverWidth)
                .background(Color.black.opacity(0.92))
                .environment(model)))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Échap ferme un popover transitoire s'il a le clavier.
        popover.contentViewController?.view.window?.makeKey()
        self.popover = popover
    }

    /// Réglages depuis le menu sans île, ou capture : ouvre le popover s'il ne l'est pas.
    func openPopover() {
        // Sans fenêtre (item pas encore dessiné, ou masqué par une barre pleine), `NSPopover.show` lèverait une exception.
        guard popover?.isShown != true, let button = item.button, button.window != nil else { return }
        showPopover(from: button)
    }

    static let popoverWidth: CGFloat = 380

    var isPopoverShown: Bool { popover?.isShown == true }

    /// Apparence de la barre de menus où l'item est dessiné (R6) : sert à la pastille.
    var buttonAppearance: NSAppearance? { item.button?.effectiveAppearance }

    func closePopover() {
        popover?.performClose(nil)
        popover = nil
    }

    /// Fermeture effective, quelle qu'en soit la cause (clic ailleurs, second clic sur l'item, autre surface ouverte).
    func popoverDidClose(_ notification: Notification) {
        model?.popoverDidClose()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model else { return }
        let display = model.display
        // Sessions Claude en attente (017), avant les limites : clic = amener l'application d'origine devant.
        let waiting = model.claude.visibleSessions.waiting
        if !waiting.isEmpty {
            menu.addItem(info(String(localized: "Claude Code")))
            for session in waiting {
                menu.addItem(claudeLine(session, now: model.now))
            }
            menu.addItem(.separator())
        }
        switch display.content {
        case .limits:
            for limit in display.limits { addLines(for: limit, forecast: display.forecasts[limit.id], now: model.now, to: menu) }
        case .connect:
            menu.addItem(info(String(localized: "Connect your Claude account")))
        case .reauthRequired:
            menu.addItem(info(String(localized: "Reconnect required")))
        case .unsupported:
            menu.addItem(info(String(localized: "Plan not supported")))
        case .unavailable:
            menu.addItem(info(String(localized: "Data unavailable")))
        }
        menu.addItem(.separator())
        menu.addItem(action(String(localized: "Refresh now"), #selector(refresh)))
        menu.addItem(action(String(localized: "Settings"), #selector(openSettings)))
        menu.addItem(action(String(localized: "Check for Updates…"), #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(action(String(localized: "Quit"), #selector(quit), key: "q"))
    }

    private func addLines(for limit: UsageLimit, forecast: Forecast?, now: Date, to menu: NSMenu) {
        let percent = String(localized: "\(Int(limit.isBlocked ? 100 : limit.utilization.rounded()))%")
        let title = NSMutableAttributedString(string: LimitLabel.text(for: limit) + "  ",
                                              attributes: [.font: NSFont.menuFont(ofSize: 0)])
        title.append(NSAttributedString(string: percent, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .semibold)]))
        let head = info("")
        head.attributedTitle = title
        menu.addItem(head)

        let untilReset = RelativeTimeFormatter.untilReset(limit.resetsAt, now: now, language: AppLanguage.current)
        var detail = limit.isBlocked ? String(localized: "Blocked, resets \(untilReset)") : String(localized: "Resets \(untilReset)")
        if let pace = PaceText.line(for: limit, forecast: forecast) { detail += " · " + pace }
        let sub = info("")
        sub.attributedTitle = NSAttributedString(string: detail, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(sub)
    }

    private func claudeLine(_ session: ClaudeSession, now: Date) -> NSMenuItem {
        let strings = CompactStrip.Strings.app.claude
        let waiting = session.waiting!
        let name = session.displayName(fallback: strings.sessionFallback)
        let title = NSMutableAttributedString(string: "● ", attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: waiting.kind.nsColor])
        title.append(NSAttributedString(string: name + "  ", attributes: [.font: NSFont.menuFont(ofSize: 0)]))
        title.append(NSAttributedString(string: strings.rowLabel(waiting.kind) + " · " + AttentionFormat.since(waiting.since, now: now, language: AppLanguage.current),
                                        attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]))
        let item = NSMenuItem(title: name, action: #selector(activateSession(_:)), keyEquivalent: "")
        item.attributedTitle = title
        item.representedObject = session.id
        item.target = self
        return item
    }

    @objc private func activateSession(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        model?.activateSession(id)
    }

    /// Ligne d'information : active (texte lisible, pas grisé) mais sans action.
    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = true
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refresh() { model?.refreshNow() }

    @objc private func openSettings() { model?.openSettingsFromMenu() }

    @objc private func checkForUpdates() { UpdateLauncher.launch() }

    @objc private func quit() { NSApp.terminate(nil) }
}

extension ClaudeWaitingKind {
    var nsColor: NSColor {
        switch self {
        case .approval, .question: return NSColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1)
        case .done: return .labelColor
        }
    }
}

#if DEBUG
/// Capture de l'item sur fond de barre sombre et claire, et du popover ouvert (build Debug, sans Enregistrement d'écran).
extension StatusItemController {
    func debugSnapshot() {
        guard let content = drawn else { return }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        for (name, appearance, background) in [("dark", NSAppearance.Name.darkAqua, NSColor(white: 0.16, alpha: 1)),
                                               ("light", .aqua, NSColor(white: 0.93, alpha: 1))] {
            let size = BarContentImage.size(for: content)
            let scale: CGFloat = 4, pad: CGFloat = 6
            let canvas = NSSize(width: size.width + 2 * pad, height: 24)
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            rep.size = canvas
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            background.setFill()
            NSRect(origin: .zero, size: canvas).fill()
            NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
                BarContentImage.image(content).draw(in: NSRect(x: pad, y: (canvas.height - size.height) / 2, width: size.width, height: size.height))
            }
            NSGraphicsContext.restoreGraphicsState()
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("notchusage-item-\(name).png"))
        }
        if let view = popover?.contentViewController?.view, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("notchusage-popover.png"))
        }
        Log.app.notice("debug item snapshot \(dir.path, privacy: .public) \(String(describing: content), privacy: .public)")
    }
}
#endif
