import NotchUsageCore
import SwiftUI

/// Haut du panneau (012) : l'île, repliée comme dépliée (retour utilisateur : la bande à texte de la 003 au
/// survol cassait l'effet Dynamic Island). Jauge ou glyphe à gauche, une donnée à droite ; la pilule l'aligne.
struct CompactView: View {
    let display: DisplayState
    let signal: NotchSignal
    var beat: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if display.mode == .notch {
                // L'encoche physique au centre. Repliée, l'oreille droite n'existe qu'avec une donnée ; dépliée, elle
                // garde sa place pour que l'encoche reste au centre du panneau.
                HStack(spacing: 0) {
                    islandLeading.frame(width: NotchPanelController.earWidth)
                    Color.clear.frame(width: display.layout.width)
                    if let trailing = signal.island.trailing {
                        islandTrailing(trailing).frame(width: NotchPanelController.earWidth).transition(.opacity)
                    } else if display.isExpanded {
                        Color.clear.frame(width: NotchPanelController.earWidth)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    islandLeading
                    if let trailing = signal.island.trailing { islandTrailing(trailing).transition(.opacity) }
                }
                .padding(.horizontal, 10)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(false)
        .accessibilityLabel(signal.accessibility)
    }

    @ViewBuilder private var islandLeading: some View {
        switch signal.island.leading {
        case .gauge(let value, let tint):
            IslandGauge(value: value, tint: tint, beat: beat, reduceMotion: reduceMotion)
        case .glyph(let glyph):
            Image(systemName: Self.symbol(glyph))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func islandTrailing(_ trailing: NotchSignal.Island.Trailing) -> some View {
        let (text, color): (String, Color) = switch trailing {
        case .deadline(let t): (t, signal.island.tint.color)
        case .back(let t): ("\u{21BB}" + t, .white)
        case .label(let t): (t, signal.island.tint.color)
        case .muted(let t): (t, .secondary)
        }
        return Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(color)
    }

    private static func symbol(_ glyph: NotchSignal.Island.Glyph) -> String {
        switch glyph {
        case .offline: return "wifi.slash"
        case .locked: return "lock.fill"
        case .account: return "person.crop.circle"
        case .unavailable: return "questionmark.circle"
        }
    }
}

/// Teintes des paliers (005), en apparence sombre : jauge de l'île et point plein écran.
extension NotchSignal.Edge {
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .far: return (1.0, 0.62, 0.04)                 // ambre #FF9F0A
        case .near: return (1.0, 0.42, 0.10)                // orange #FF6A1A
        case .imminent, .exhausted: return (1.0, 0.27, 0.23) // rouge #FF453A
        }
    }

    var color: Color { color(lightened: 0) }

    /// Teinte du palier mélangée au blanc (`amount` de 0 à 1) : éclaircit le trait pendant le battement (006).
    /// Une couleur calculée plutôt qu'un filtre `brightness`, que `cacheDisplay` (captures) ne rend pas.
    func color(lightened amount: Double) -> Color {
        let c = rgb
        return Color(red: c.red + (1 - c.red) * amount, green: c.green + (1 - c.green) * amount, blue: c.blue + (1 - c.blue) * amount)
    }

    var hasHalo: Bool { self == .imminent || self == .exhausted }
}

extension NotchSignal.Island.Tint {
    /// Gris secondaire au calme, teintes des paliers sinon (005).
    var edge: NotchSignal.Edge? {
        switch self {
        case .calm: return nil
        case .far: return .far
        case .near: return .near
        case .imminent: return .imminent
        case .exhausted: return .exhausted
        }
    }

    var color: Color { edge?.color ?? Color(white: 0.78) }
}

/// Jauge circulaire de l'île (012, R4) : usage de la limite portée. Halo en imminent et épuisé, double battement
/// sur `beat` (006) ; en mode réduit d'animations, halo fixe.
struct IslandGauge: View {
    let value: Double
    let tint: NotchSignal.Island.Tint
    let beat: Int
    let reduceMotion: Bool

    static let size: CGFloat = 16
    static let line: CGFloat = 3

    var body: some View {
        if let edge = tint.edge, edge.hasHalo {
            if reduceMotion {
                ring(color: tint.color).shadow(color: tint.color.opacity(0.6), radius: 3)
            } else {
                Color.clear.frame(width: Self.size, height: Self.size)
                    .phaseAnimator([0.6, 1.0, 0.7, 1.0], trigger: beat) { _, opacity in
                        let rise = (opacity - 0.6) / 0.4
                        ring(color: edge.color(lightened: 0.45 * rise))
                            .shadow(color: edge.color.opacity(opacity), radius: 3 + 6 * rise)
                    } animation: { _ in .easeInOut(duration: 0.2) }
            }
        } else {
            ring(color: tint.color)
        }
    }

    private func ring(color: Color) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: Self.line)
            Circle().trim(from: 0, to: min(max(value, 0), 100) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: Self.line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: Self.size, height: Self.size)
    }
}

/// Barre piste + remplissage du panneau déplié : `ProgressView` et `Gauge` rendent mal sur fond noir.
struct UsageBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: max(geo.size.height, geo.size.width * min(max(value, 0), 100) / 100))
            }
        }
    }
}

enum LimitLabel {
    static func text(for limit: UsageLimit) -> String {
        switch limit.labelKey {
        case .fiveHour: return String(localized: "5-hour window")
        case .weeklyAll: return String(localized: "Weekly, all models")
        case .weeklyModel(let name): return String(localized: "Weekly · \(name)")
        }
    }

}

extension CompactStrip.Strings {
    /// Textes du catalogue de l'app, résolus une fois : la langue ne change qu'au relancement.
    static let app = CompactStrip.Strings(
        full: String(localized: "Full"),
        signIn: String(localized: "Sign in"),
        connect: String(localized: "Connect"),
        dash: "—",
        percent: { String(localized: "\($0)%") },
        limitLabel: { LimitLabel.text(for: $0) },
        shortLabel: { limit in
            switch limit.kind {
            case .rollingFiveHour: String(localized: "5h")
            case .weeklyAll: String(localized: "7d")
            case .weeklyModel: limit.modelName ?? String(localized: "7d")
            }
        },
        limitAnnouncement: { String(localized: "\($0), \($1) percent, resets \($2)") },
        paceAnnouncement: { String(localized: ", at this pace blocked at \($0)") },
        stateAnnouncement: { state in
            switch state {
            case "connect": String(localized: "Notch Usage, not connected")
            case "reconnectRequired": String(localized: "Notch Usage, reconnect required")
            case "unsupported": String(localized: "Notch Usage, plan not supported")
            default: String(localized: "Notch Usage, data unavailable")
            }
        })
}
