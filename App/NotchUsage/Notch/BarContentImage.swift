import AppKit
import NotchUsageCore

/// Dessin de l'item de barre de menus (018, R3, contrat surfaces.md) : anneau, texte, glyphe Claude.
/// Une seule image non modèle dont le `drawingHandler` lit l'apparence au moment du dessin : AppKit la redessine
/// quand la barre passe de sombre à claire, sans observation de notre part.
enum BarContentImage {
    static let height: CGFloat = 18
    static let ring: CGFloat = 14
    static let ringLine: CGFloat = 2.2
    static let textGap: CGFloat = 5
    static let attentionGap: CGFloat = 6
    static let glyph: CGFloat = 15
    /// Le nombre colle au glyphe (contrat : -3 depuis la boîte de 15 pt du symbole).
    static let countGap: CGFloat = -3
    static let wordGap: CGFloat = 3
    /// Largeur réservée au compact : celle de l'icône de la 014.
    static let compactSize = NSSize(width: 18, height: 18)

    static var textFont: NSFont { .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold) }
    static var countFont: NSFont { .monospacedSystemFont(ofSize: 12, weight: .bold) }
    static var wordFont: NSFont { .systemFont(ofSize: 12, weight: .semibold) }

    struct Palette: Equatable {
        let mono: NSColor
        let claude: NSColor
        let far: NSColor
        let near: NSColor
        let red: NSColor

        func tint(_ tint: NotchSignal.Island.Tint) -> NSColor {
            switch tint {
            case .calm: return mono
            case .far: return far
            case .near: return near
            case .imminent, .exhausted: return red
            }
        }

        func kind(_ kind: ClaudeWaitingKind) -> NSColor {
            kind == .done ? mono : claude
        }
    }

    /// Violet assombri sur barre claire (FR-008) ; teintes de palier identiques dans les deux apparences.
    static func palette(dark: Bool) -> Palette {
        Palette(mono: dark ? .white : .black,
                claude: dark ? rgb(0xBF, 0x5A, 0xF2) : rgb(0xA4, 0x3B, 0xD6),
                far: rgb(0xFF, 0x9F, 0x0A), near: rgb(0xFF, 0x6A, 0x1A), red: rgb(0xFF, 0x45, 0x3A))
    }

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    // MARK: Mesure

    private struct Layout {
        var width: CGFloat = 0
        var textX: CGFloat?
        var glyphX: CGFloat?
        var countX: CGFloat?
        var wordX: CGFloat?
    }

    private static func layout(_ content: BarContent) -> Layout {
        var l = Layout()
        if content.isCompact { l.width = compactSize.width; return l }
        l.width = ring
        if let text = content.text {
            l.textX = l.width + textGap
            l.width = l.textX! + measure(text, textFont)
        }
        if let attention = content.attention, !content.attentionAsBadge {
            l.glyphX = l.width + attentionGap
            l.width = l.glyphX! + glyph
            if !attention.count.isEmpty {
                l.countX = l.width + countGap
                l.width = l.countX! + measure(attention.count, countFont)
            }
            if let word = attention.arrivalWord {
                l.wordX = l.width + wordGap
                l.width = l.wordX! + measure(word, wordFont)
            }
        }
        l.width = l.width.rounded(.up)
        return l
    }

    static func size(for content: BarContent) -> NSSize {
        NSSize(width: layout(content).width, height: height)
    }

    private static func measure(_ s: String, _ font: NSFont) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: font]).width
    }

    // MARK: Dessin

    /// `lit` : phase haute du battement (006), anneau éclairci ; jamais en Réduire les animations (géré par l'appelant).
    static func image(_ content: BarContent, lit: Bool = false) -> NSImage {
        let l = layout(content)
        let size = NSSize(width: l.width, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            draw(content, layout: l, palette: palette(dark: dark), lit: lit)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = content.accessibility
        return image
    }

    private static func draw(_ content: BarContent, layout l: Layout, palette p: Palette, lit: Bool) {
        let midY = height / 2
        let ringX: CGFloat = content.isCompact ? (compactSize.width - ring) / 2 : 0
        let center = NSPoint(x: ringX + ring / 2, y: midY)
        let radius = (ring - ringLine) / 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = ringLine
        p.mono.withAlphaComponent(0.3).setStroke()
        track.stroke()
        if let gauge = content.gauge, gauge.fraction > 0 {
            var color = p.tint(gauge.tint)
            if lit, gauge.beats { color = color.blended(withFraction: 0.45, of: .white) ?? color }
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * CGFloat(gauge.fraction), clockwise: true)
            arc.lineWidth = ringLine
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
        }
        // 017 : limite imminente ou épuisée, Claude se réduit à un point au coin de la jauge.
        if content.attentionAsBadge, let kind = content.attention?.kind {
            let dot = NSRect(x: ringX + ring - 4.5, y: height - 6, width: 5, height: 5)
            p.kind(kind).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }

        if let text = content.text, let x = l.textX {
            let color: NSColor = switch content.textEmphasis {
            case .none: p.mono
            case .imminent: p.red
            case .muted: p.mono.withAlphaComponent(0.5)
            }
            drawText(text, font: textFont, color: color, x: x, midY: midY)
        }

        if let attention = content.attention, let gx = l.glyphX {
            let color = p.kind(attention.kind)
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold).applying(.init(paletteColors: [color]))
            if let symbol = NSImage(systemSymbolName: attention.kind.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let s = symbol.size
                let scale = min(glyph / s.width, glyph / s.height, 1)
                let w = s.width * scale, h = s.height * scale
                symbol.draw(in: NSRect(x: gx + (glyph - w) / 2, y: midY - h / 2, width: w, height: h))
            }
            if let cx = l.countX { drawText(attention.count, font: countFont, color: color, x: cx, midY: midY) }
            if let word = attention.arrivalWord, let wx = l.wordX { drawText(word, font: wordFont, color: color, x: wx, midY: midY) }
        }
    }

    private static func drawText(_ s: String, font: NSFont, color: NSColor, x: CGFloat, midY: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: x, y: (midY - size.height / 2).rounded()), withAttributes: attrs)
    }
}
