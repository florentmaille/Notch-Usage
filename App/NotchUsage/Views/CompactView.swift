import NotchUsageCore
import SwiftUI

/// Haut du panneau (012) : l'île, repliée comme dépliée (retour utilisateur : la bande à texte de la 003 au
/// survol cassait l'effet Dynamic Island). Jauge ou glyphe à gauche, une donnée à droite.
struct CompactView: View {
    let display: DisplayState
    let signal: NotchSignal
    var beat: Int = 0
    var now: Date = Date()
    /// Clic sur l'île : efface les sessions Claude « terminé » (017).
    var onTap: (() -> Void)? = nil
    /// Action VoiceOver : ouvre le panneau, qui ne s'ouvre sinon qu'au survol.
    var onOpen: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // L'encoche physique au centre. Repliée, l'oreille droite n'existe qu'avec une donnée ; dépliée, elle
        // garde sa place pour que l'encoche reste au centre du panneau.
        HStack(spacing: 0) {
            // Repliée (019), l'oreille gauche se resserre vers l'encoche ; la racine compense par une marge à gauche.
            islandLeading.opacity(isFolded ? 0 : 1).frame(width: Self.leadingWidth(display: display, signal: signal)).clipped()
            Color.clear.frame(width: display.layout.width)
            // Oreille droite toujours présente, sa largeur s'anime (0 ↔ 52 pt) : l'île s'étire d'un seul tenant au
            // lieu d'apparaître en bloc (019, retour utilisateur), le contenu en fondu.
            ZStack(alignment: .center) {
                if let trailing = signal.island.trailing {
                    islandTrailing(trailing).fixedSize().transition(.opacity)
                }
            }
            .frame(width: trailingWidth)
            .clipped()
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(false)
        .accessibilityLabel(signal.accessibility)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen?() }
    }

    private var isFolded: Bool { signal.island.folded && !display.isExpanded }

    /// Largeur de l'oreille gauche : 0 quand l'île est repliée sur un autre écran (019).
    static func leadingWidth(display: DisplayState, signal: NotchSignal) -> CGFloat {
        signal.island.folded && !display.isExpanded ? 0 : NotchPanelController.earWidth
    }

    private var trailingWidth: CGFloat {
        if signal.island.trailing != nil { return signal.trailingEarWidth(now: now) }
        return display.isExpanded ? NotchPanelController.earWidth : 0
    }

    @ViewBuilder private var islandLeading: some View {
        switch signal.island.leading {
        case .gauge(let value, let tint):
            IslandGauge(value: value, tint: tint, beat: beat, reduceMotion: reduceMotion)
                // Point au coin de la jauge quand la limite garde l'oreille droite (017, R9).
                .overlay(alignment: .topTrailing) {
                    if let badge = signal.island.badge {
                        Circle().fill(badge.color)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(.black, lineWidth: 1.5))
                            .offset(x: 3, y: -3)
                            .transition(.opacity)
                    }
                }
        case .glyph(let glyph):
            Image(systemName: Self.symbol(glyph))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func islandTrailing(_ trailing: NotchSignal.Island.Trailing) -> some View {
        switch trailing {
        case .attention(let kind, let count):
            AttentionEar(kind: kind, count: count, showsWord: signal.showsArrival(now: now))
        default:
            let (text, color): (String, Color) = switch trailing {
            case .deadline(let t): (t, signal.island.tint.color)
            case .back(let t): ("\u{21BB}" + t, .white)
            case .label(let t): (t, signal.island.tint.color)
            case .muted(let t): (t, .secondary)
            case .percent(let t): (t, .white)
            case .attention: ("", .white)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(color)
        }
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

/// Oreille droite d'une session Claude en attente (017, contrat attention.md) : glyphe, puis le mot pendant 4 s à
/// l'arrivée, ou le nombre de sessions à partir de 2. Rien ne bat.
struct AttentionEar: View {
    let kind: ClaudeWaitingKind
    let count: Int
    let showsWord: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbol)
                .font(.system(size: 13, weight: .semibold))
            if showsWord {
                Text(CompactStrip.Strings.app.claude.arrival(kind))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .transition(.opacity)
            } else if !AttentionFormat.count(count).isEmpty {
                Text(AttentionFormat.count(count))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(kind.color)
        .padding(.horizontal, 4)
    }
}

extension ClaudeWaitingKind {
    /// Violet pour ce qui bloque, blanc pour ce qui informe ; jamais les teintes des paliers.
    var color: Color {
        switch self {
        case .approval, .question: return Color(red: 0.75, green: 0.35, blue: 0.95)   // #BF5AF2
        case .done: return .white
        }
    }

    var symbol: String {
        switch self {
        case .approval: return "hand.raised.fill"
        case .question: return "questionmark.bubble.fill"
        case .done: return "checkmark"
        }
    }
}

@MainActor
extension NotchSignal {
    func showsArrival(now: Date) -> Bool {
        guard let attention, case .attention? = island.trailing else { return false }
        return AttentionFormat.showsArrival(arrivedAt: attention.arrivedAt, now: now)
    }

    /// Largeur de l'oreille droite repliée : rien sans donnée, 52 pt, élargie le temps du mot d'arrivée (017).
    func trailingEarWidth(now: Date) -> CGFloat {
        guard island.trailing != nil else { return 0 }
        return showsArrival(now: now) ? NotchPanelController.arrivalEarWidth : NotchPanelController.earWidth
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
    static let app: CompactStrip.Strings = {
        var strings = base
        strings.claude = ClaudeStrings(
            arrival: { kind in
                switch kind {
                case .approval: String(localized: "Approval")
                case .question: String(localized: "Question")
                case .done: String(localized: "Done")
                }
            },
            rowLabel: { kind in
                switch kind {
                case .approval: String(localized: "approval needed")
                case .question: String(localized: "question pending")
                case .done: String(localized: "finished")
                }
            },
            waitingAnnouncement: { count in
                count == 1 ? String(localized: "1 Claude session is waiting: ") : String(localized: "\(count) Claude sessions are waiting: ")
            },
            kindAnnouncement: { kind in
                switch kind {
                case .approval: String(localized: "an approval")
                case .question: String(localized: "a question")
                case .done: String(localized: "finished")
                }
            },
            sessionFallback: String(localized: "Session"))
        return strings
    }()

    private static let base = CompactStrip.Strings(
        full: String(localized: "Full"),
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
