import NotchUsageCore
import SwiftUI

/// Bandeau permanent : pictogramme à gauche de l'encoche, jauge et pourcentage à droite (FR-011).
struct CompactView: View {
    let display: DisplayState
    var pulse: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: wing, alignment: .trailing)
            if display.mode == .notch {
                Color.clear.frame(width: display.layout.width)
            } else {
                Spacer(minLength: 6)
            }
            trailing
                .frame(width: wing, alignment: .leading)
        }
        .padding(.horizontal, display.mode == .notch ? 10 : 10)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var wing: CGFloat {
        display.mode == .notch ? NotchPanelController.wingWidth - 10 : (NotchGeometry.pillSize.width - 26) / 2
    }

    @ViewBuilder private var leading: some View {
        switch display.content {
        case .connect:
            Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(.secondary)
        case .reauthRequired:
            Image(systemName: "exclamationmark.lock").foregroundStyle(.orange)
        case .unsupported:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        case .unavailable:
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.secondary)
        case .limits:
            if let h = display.headline {
                Image(systemName: display.alertLevel == .none ? icon(for: h.limit.kind) : "exclamationmark.triangle.fill")
                    .foregroundStyle(display.alertLevel == .none ? (display.banner == nil ? .white : .secondary) : tint)
                    .symbolEffect(.bounce, value: pulse)
            }
        }
    }

    @ViewBuilder private var trailing: some View {
        switch display.content {
        case .limits:
            if let h = display.headline {
                HStack(spacing: 5) {
                    Gauge(value: h.limit.utilization, in: 0...100) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(tint)
                        .frame(width: 30)
                    Text(h.isBlocked ? "FULL" : "\(Int(h.limit.utilization.rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
            }
        case .connect:
            Text("Connect").foregroundStyle(.secondary)
        case .reauthRequired:
            Text("Sign in").foregroundStyle(.orange)
        case .unsupported, .unavailable:
            Text("—").foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        if display.headline?.isBlocked == true { return .red }
        switch display.alertLevel {
        case .critical: return .red
        case .warning: return .orange
        case .none: return display.banner == nil ? .white : .secondary
        }
    }

    private func icon(for kind: LimitKind) -> String {
        switch kind {
        case .rollingFiveHour: return "clock"
        case .weeklyAll: return "calendar"
        case .weeklyModel: return "cpu"
        }
    }

    private var accessibilityText: String {
        switch display.content {
        case .connect: return String(localized: "Notch Usage, not connected")
        case .reauthRequired: return String(localized: "Notch Usage, reconnect required")
        case .unsupported: return String(localized: "Notch Usage, plan not supported")
        case .unavailable: return String(localized: "Notch Usage, data unavailable")
        case .limits:
            guard let h = display.headline else { return "Notch Usage" }
            let reset = RelativeTimeFormatter.untilReset(h.limit.resetsAt, now: Date())
            return "\(LimitLabel.text(for: h.limit)), \(Int(h.limit.utilization.rounded())) percent, resets \(reset)"
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
