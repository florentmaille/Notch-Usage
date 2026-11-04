import AppKit
import NotchUsageCore

/// Icône facultative de la barre de menus (014) : jauge monochrome de l'usage de la limite portée par l'encoche,
/// et au clic un menu des limites, « Actualiser », « Réglages » et « Quitter ». Image modèle (template) : macOS
/// la teinte selon l'apparence de la barre de menus.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private weak var model: AppModel?
    /// Pourcentage dessiné, pour ne redessiner que lorsqu'il change.
    private var drawnUsage: Int??

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        item.button?.toolTip = "Notch Usage"
    }

    func update(display: DisplayState, accessibility: String) {
        item.button?.setAccessibilityLabel(accessibility)
        let usage = display.content == .limits ? display.headline.map { Int(min(100, max(0, $0.limit.utilization)).rounded()) } : nil
        guard drawnUsage != .some(usage) else { return }
        drawnUsage = .some(usage)
        item.button?.image = Self.gauge(usage)
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    /// Anneau de 18 pt : piste à 35 %, arc plein depuis midi dans le sens horaire.
    static func gauge(_ usage: Int?) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let center = NSPoint(x: 9, y: 9), radius: CGFloat = 6.5
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 2.2
            NSColor.black.withAlphaComponent(0.35).setStroke()
            track.stroke()
            if let usage, usage > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                              endAngle: 90 - 360 * CGFloat(usage) / 100, clockwise: true)
                arc.lineWidth = 2.2
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model else { return }
        let display = model.display
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
        switch forecast {
        case .blockAt(let date)?:
            detail += " · " + String(localized: "At this pace (last hour): blocked at \(date.formatted(date: .omitted, time: .shortened))")
        case .holdsUntilReset?:
            detail += " · " + String(localized: "At this pace: holds until reset")
        default: break
        }
        let sub = info("")
        sub.attributedTitle = NSAttributedString(string: detail, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(sub)
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

    @objc private func quit() { NSApp.terminate(nil) }
}
