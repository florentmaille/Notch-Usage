import NotchUsageCore
import SwiftUI

/// Pastille centrée dans la barre de menus (018, C′, contrat surfaces.md) : jauge et texte à gauche, attente Claude
/// à droite après un filet. Fond sombre presque opaque : un voile à 13 % disparaissait sur une barre teintée par un
/// fond d'écran coloré (retour utilisateur). Le contenu suit donc toujours la palette sombre.
struct CapsuleView: View {
    let content: BarContent
    let dark: Bool
    var hovered = false
    /// Phase haute d'un battement (006) : anneau éclairci.
    var lit = false

    static let height: CGFloat = 22
    static let ring: CGFloat = 14
    static let ringLine: CGFloat = 2.4

    private var palette: BarContentImage.Palette { BarContentImage.palette(dark: true) }
    private var imminent: Bool { content.gauge?.tint == .imminent }

    var body: some View {
        HStack(spacing: 6) {
            gauge
            if let text = content.text {
                Text(text)
                    .font(.system(size: 13.5, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(textColor)
                    .transition(.opacity)
            }
            if let attention = content.attention, !content.attentionAsBadge {
                Rectangle()
                    .fill(Color(nsColor: palette.mono).opacity(0.25))
                    .frame(width: 1, height: 13)
                    .padding(.horizontal, 1)
                    .transition(.opacity)
                HStack(spacing: 2) {
                    Image(systemName: attention.kind.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 16, height: 16)
                    if let word = attention.arrivalWord {
                        Text(word).font(.system(size: 13, weight: .semibold)).fixedSize().transition(.opacity)
                    } else if !attention.count.isEmpty {
                        Text(attention.count).font(.system(size: 13, weight: .bold, design: .monospaced)).fixedSize()
                    }
                }
                .foregroundStyle(Color(nsColor: palette.kind(attention.kind)))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .background(Capsule().fill(.black.opacity(hovered ? 0.85 : 0.72)))
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibility)
    }

    private var gauge: some View {
        let mono = Color(nsColor: palette.mono)
        var arc = content.gauge.map { Color(nsColor: palette.tint($0.tint)) } ?? mono
        if lit, content.gauge?.beats == true, let blended = content.gauge.map({ palette.tint($0.tint).blended(withFraction: 0.45, of: .white) }) ?? nil {
            arc = Color(nsColor: blended)
        }
        return ZStack {
            Circle().stroke(mono.opacity(0.3), lineWidth: Self.ringLine)
            if let g = content.gauge {
                Circle().trim(from: 0, to: g.fraction)
                    .stroke(arc, style: StrokeStyle(lineWidth: Self.ringLine, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: Self.ring - Self.ringLine, height: Self.ring - Self.ringLine)
        .frame(width: Self.ring, height: Self.ring)
        .overlay(alignment: .topTrailing) {
            // 017 : limite imminente ou épuisée, Claude se réduit à un point sur la jauge.
            if content.attentionAsBadge, let kind = content.attention?.kind {
                Circle().fill(Color(nsColor: palette.kind(kind))).frame(width: 5, height: 5).offset(x: 2, y: -2)
            }
        }
    }

    private var textColor: Color {
        switch content.textEmphasis {
        case .none: Color(nsColor: palette.mono)
        case .imminent: Color(nsColor: palette.red)
        case .muted: Color(nsColor: palette.mono).opacity(0.5)
        }
    }

    /// Teinte sous le fond sombre : seul l'imminent la colore (FR-013).
    private var fill: Color {
        imminent ? Color(nsColor: palette.red).opacity(0.9) : .clear
    }

    private var stroke: Color {
        if imminent { return Color(nsColor: palette.red).opacity(0.6) }
        return .white.opacity(hovered ? 0.22 : 0.12)
    }
}

/// Carte du survol (018, FR-015) : le contenu du panneau de l'île, sur fond noir, quatre coins arrondis.
struct CapsuleCardView: View {
    @Environment(AppModel.self) private var model
    static let width: CGFloat = 380

    var body: some View {
        PanelContentView(reportsHeight: false)
            .frame(width: Self.width)
            .background(Color.black.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
