import NotchUsageCore
import SwiftUI

/// Bandeau permanent (003) : à gauche la prévision, à droite le pourcentage, le tout décidé par `CompactStrip`.
struct CompactView: View {
    let display: DisplayState
    var now: Date = Date()
    var pulse: Int = 0
    var onReconnect: (() -> Void)?

    private var strip: CompactStrip {
        CompactStrip.make(display: display, now: now, language: AppLanguage.current, strings: .app)
    }

    var body: some View {
        let strip = strip
        Group {
            if display.mode == .notch {
                HStack(spacing: 0) {
                    leading(strip, glyph: true).frame(width: wing, alignment: .trailing)
                    Color.clear.frame(width: display.layout.width)
                    trailing(strip).frame(width: wing, alignment: .leading)
                }
            } else {
                // Pilule : une ligne, avec le glyphe si la place le permet, jamais de troncature (research R5).
                ViewThatFits(in: .horizontal) {
                    pillLine(strip, glyph: true)
                    pillLine(strip, glyph: false)
                }
            }
        }
        .padding(.horizontal, 10)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strip.accessibility)
    }

    private var wing: CGFloat { NotchPanelController.wingWidth - 10 }

    private func pillLine(_ strip: CompactStrip, glyph: Bool) -> some View {
        HStack(spacing: 5) {
            leading(strip, glyph: glyph)
            if leftText(strip) != nil { Text(verbatim: "·").foregroundStyle(.secondary) }
            trailing(strip)
        }
        .fixedSize()
    }

    // MARK: Aile gauche

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

    // MARK: Aile droite

    @ViewBuilder private func trailing(_ strip: CompactStrip) -> some View {
        switch strip.right {
        case .percent(let t):
            Text(t).monospacedDigit().fixedSize().foregroundStyle(strip.tone == .muted ? Color.secondary : Color.white)
        case .pill(let t):
            Text(t).monospacedDigit().fixedSize()
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(tint(strip.tone)))
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
