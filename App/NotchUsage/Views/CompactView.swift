import NotchUsageCore
import SwiftUI

/// Bandeau replié (003, 012) : au repos, l'île (jauge ou glyphe à gauche, une donnée à droite) ; au survol et
/// épinglé, la bande complète (`CompactStrip`). La pilule montre l'île sur une ligne.
struct CompactView: View {
    let display: DisplayState
    let signal: NotchSignal
    var now: Date = Date()
    var pulse: Int = 0
    var beat: Int = 0
    var onReconnect: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if display.isExpanded, case .band(let strip) = signal.content {
                if display.mode == .notch {
                    HStack(spacing: 0) {
                        leading(strip, glyph: true).frame(width: wing, alignment: .trailing)
                        Color.clear.frame(width: display.layout.width)
                        trailing(strip).frame(width: wing, alignment: .leading)
                    }
                    .padding(.horizontal, Self.horizontalPadding)
                } else {
                    ViewThatFits(in: .horizontal) {
                        bandLine(strip, glyph: true)
                        bandLine(strip, glyph: false)
                    }
                    .padding(.horizontal, Self.horizontalPadding)
                }
            } else if display.mode == .notch {
                // L'encoche physique au centre, une oreille de chaque côté ; la droite n'existe qu'avec une donnée.
                HStack(spacing: 0) {
                    islandLeading.frame(width: NotchPanelController.earWidth)
                    Color.clear.frame(width: display.layout.width)
                    if let trailing = signal.island.trailing {
                        islandTrailing(trailing).frame(width: NotchPanelController.earWidth).transition(.opacity)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    islandLeading
                    if let trailing = signal.island.trailing { islandTrailing(trailing).transition(.opacity) }
                }
                .padding(.horizontal, Self.horizontalPadding)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(false)
        .accessibilityLabel(signal.accessibility)
    }

    private static let horizontalPadding: CGFloat = 10
    /// Largeur utile d'une aile de la bande : la largeur de l'aile moins la marge horizontale.
    private var wing: CGFloat { NotchPanelController.wingWidth - Self.horizontalPadding }

    // MARK: Île (012)

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

    private func bandLine(_ strip: CompactStrip, glyph: Bool) -> some View {
        HStack(spacing: 5) {
            leading(strip, glyph: glyph)
            if leftText(strip) != nil { Text(verbatim: "·").foregroundStyle(.secondary) }
            trailing(strip)
        }
        .fixedSize()
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text).monospacedDigit().fixedSize()
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(tint))
    }

    // MARK: Bande complète (003)

    private func leftText(_ strip: CompactStrip) -> String? {
        switch strip.left {
        case .holds(let t), .blockIn(let t), .blockedFor(let t), .offline(let t): return t
        case .locked, .connect, .unsupported, .unavailable: return nil
        }
    }

    private func leading(_ strip: CompactStrip, glyph: Bool) -> some View {
        let (symbol, color): (String, Color) = switch strip.left {
        case .holds: ("checkmark", .secondary)
        case .blockIn: ("hourglass", tint(strip.tone))
        case .blockedFor: ("arrow.clockwise", .red)
        case .offline: ("wifi.slash", .secondary)
        case .locked: ("lock", .orange)
        case .connect: ("person.crop.circle.badge.plus", .secondary)
        case .unsupported: ("questionmark.circle", .secondary)
        case .unavailable: ("wifi.exclamationmark", .secondary)
        }
        return HStack(spacing: 4) {
            if glyph || leftText(strip) == nil {
                Image(systemName: symbol).symbolEffect(.bounce, value: pulse)
            }
            if let text = leftText(strip) {
                Text(text).monospacedDigit().fontWeight(color == .secondary ? .medium : .semibold).fixedSize()
            }
        }
        .foregroundStyle(color)
    }

    @ViewBuilder private func trailing(_ strip: CompactStrip) -> some View {
        switch strip.right {
        case .percent(let t):
            Text(t).monospacedDigit().fixedSize().foregroundStyle(strip.tone == .muted ? Color.secondary : Color.white)
        case .pill(let t):
            pill(t, tint: tint(strip.tone))
        case .signIn(let t):
            Button { onReconnect?() } label: { Text(t).foregroundStyle(.orange).fixedSize() }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        case .connect(let t):
            Text(t).foregroundStyle(.secondary).fixedSize()
        case .dash:
            Text("—").foregroundStyle(.secondary)
        }
    }

    private func tint(_ tone: CompactStrip.Tone) -> Color {
        switch tone {
        case .critical: return .red
        case .warning: return .orange
        case .muted: return .secondary
        case .normal: return .white
        }
    }
}

/// Rendu des paliers du liseré (contrat notch-signal.md) : teintes système en apparence sombre.
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
