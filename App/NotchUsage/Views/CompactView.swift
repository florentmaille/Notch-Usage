import NotchUsageCore
import SwiftUI

/// Bandeau replié (003, 005) : dessine `NotchSignal`. Dans l'encoche, seule la bande complète (`CompactStrip`)
/// porte du texte : survol, épinglage, états gris ; prévision, seuil et épuisement n'y sont que le liseré de la
/// forme. La pilule, sans encoche à entourer, garde une donnée unique.
struct CompactView: View {
    let display: DisplayState
    let signal: NotchSignal
    var now: Date = Date()
    var pulse: Int = 0
    var onReconnect: (() -> Void)?

    var body: some View {
        Group {
            if signal.isSilent || (display.mode == .notch && !signal.isBand) {
                Color.clear
            } else if display.mode == .notch {
                HStack(spacing: 0) {
                    leftWing.frame(width: wing, alignment: .trailing)
                    Color.clear.frame(width: display.layout.width)
                    rightWing.frame(width: wing, alignment: .leading)
                }
                .transition(.opacity)
            } else {
                // Pilule : une ligne, avec le glyphe si la place le permet, jamais de troncature (research R5).
                ViewThatFits(in: .horizontal) {
                    pillLine(glyph: true)
                    pillLine(glyph: false)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(false)
        .accessibilityLabel(signal.accessibility)
    }

    private var wing: CGFloat { NotchPanelController.wingWidth - 10 }
    private var edgeColor: Color { signal.edge?.color ?? .orange }

    // MARK: Ailes

    @ViewBuilder private var leftWing: some View {
        switch signal.content {
        case .silent, .deadline: EmptyView()
        case .band(let strip): leading(strip, glyph: true)
        case .exhausted(let full, _): pill(full, tint: .red)
        case .threshold(let label, _): Text(label).fontWeight(.medium).foregroundStyle(.secondary).fixedSize()
        }
    }

    @ViewBuilder private var rightWing: some View {
        switch signal.content {
        case .silent: EmptyView()
        case .band(let strip): trailing(strip)
        case .deadline(let label): glyphText("hourglass", label, edgeColor)
        case .exhausted(_, let back): glyphText("arrow.clockwise", back, .red)
        case .threshold(_, let percent): pill(percent, tint: edgeColor)
        }
    }

    @ViewBuilder private func pillLine(glyph: Bool) -> some View {
        switch signal.content {
        case .silent: EmptyView()
        case .band(let strip):
            HStack(spacing: 5) {
                leading(strip, glyph: glyph)
                if leftText(strip) != nil { Text(verbatim: "·").foregroundStyle(.secondary) }
                trailing(strip)
            }
            .fixedSize()
        case .deadline(let label):
            glyphText(glyph ? "hourglass" : nil, label, edgeColor).fixedSize()
        case .exhausted(let full, let back):
            HStack(spacing: 5) { pill(full, tint: .red); Text(verbatim: "·").foregroundStyle(.secondary); glyphText(glyph ? "arrow.clockwise" : nil, back, .red) }.fixedSize()
        case .threshold(let label, let percent):
            HStack(spacing: 5) { Text(label).fontWeight(.medium).foregroundStyle(.secondary); Text(verbatim: "·").foregroundStyle(.secondary); pill(percent, tint: edgeColor) }.fixedSize()
        }
    }

    private func glyphText(_ symbol: String?, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).symbolEffect(.bounce, value: pulse) }
            Text(text).monospacedDigit().fixedSize()
        }
        .foregroundStyle(color)
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

    var lineWidth: CGFloat {
        switch self {
        case .far: return 2
        case .near: return 2.5
        case .imminent, .exhausted: return 3
        }
    }

    var hasHalo: Bool { self == .imminent || self == .exhausted }

    /// Débord du halo au-delà du trait, transparent : couvre le rayon de 14 pt au sommet du battement (006).
    static let haloPad: CGFloat = 16

    /// Cerne sombre autour du trait : le sépare d'un fond clair ou de la même teinte (le trait n'a aucune
    /// teinte lisible sur un fond orange sans lui).
    static let keyline: CGFloat = 2.5
    static let keylineColor = Color.black.opacity(0.85)

    /// Débord hors de l'encoche physique : le trait, son cerne, plus le halo s'il y en a un.
    var outerPad: CGFloat { lineWidth + Self.keyline + (hasHalo ? Self.haloPad : 0) }
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

    /// Libellé d'une limite connue seulement par son identifiant (choix enregistré, relevé absent).
    static func text(forID id: String) -> String {
        switch id {
        case "session": return String(localized: "5-hour window")
        case "weekly_all": return String(localized: "Weekly, all models")
        default:
            let name = id.hasPrefix("weekly_scoped:") ? String(id.dropFirst("weekly_scoped:".count)) : id
            return String(localized: "Weekly · \(name)")
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
