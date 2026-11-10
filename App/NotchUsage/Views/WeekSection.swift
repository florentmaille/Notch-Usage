import NotchUsageCore
import SwiftUI

/// « Cette semaine » (021, planche C1) : courbe de la limite hebdomadaire depuis le dernier reset, projection de la
/// 016 en pointillés jusqu'au reset, ligne des 100 %, jours en abscisse. Repliable, état mémorisé.
struct WeekSection: View {
    let state: WeekCurve.State
    @AppStorage("weekSectionCollapsed") private var collapsed = false

    static let chartHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { collapsed.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2.weight(.semibold)).frame(width: 10)
                    Text("This week").font(.caption.weight(.semibold)).textCase(.uppercase)
                    Spacer()
                    Text(headline).font(.caption).monospacedDigit()
                        .foregroundStyle(headlineColor)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !collapsed {
                switch state {
                case .notEnough:
                    Text("Not enough readings yet").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                case .curve(let curve):
                    WeekChart(curve: curve).frame(height: Self.chartHeight)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(collapsed ? Text("Collapsed") : Text("Expanded"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { collapsed.toggle() }
    }

    private var curve: WeekCurve? {
        if case .curve(let c) = state { return c }
        return nil
    }

    /// Pourcentage prévu au reset, heure du blocage, ou usage actuel sans prévision (moins de 12 h écoulées).
    private var headline: String {
        guard let curve else { return "" }
        switch curve.projection {
        case .holds(let atReset): return String(localized: "\(Int(atReset.rounded()))% projected at reset")
        case .blocks(let at, _): return String(localized: "blocked \(WeekSection.when(at))")
        case .none: return String(localized: "\(Int(curve.now.usage.rounded()))% used")
        }
    }

    private var headlineColor: Color {
        guard let curve, curve.tint != .calm else { return .secondary }
        return curve.tint.color
    }

    private var accessibilityText: String {
        guard let curve else { return String(localized: "This week: not enough readings yet") }
        let used = Int(curve.now.usage.rounded())
        switch curve.projection {
        case .holds(let atReset):
            return String(localized: "This week: \(used)% used, \(Int(atReset.rounded()))% projected at reset \(WeekSection.when(curve.resetsAt))")
        case .blocks(let at, _):
            return String(localized: "This week: \(used)% used, blocked expected \(WeekSection.when(at))")
        case .none:
            return String(localized: "This week: \(used)% used")
        }
    }

    static func when(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

/// Tracé de la semaine : usage (0-100 %) en ordonnée, part de la semaine en abscisse.
private struct WeekChart: View {
    let curve: WeekCurve

    private let top: CGFloat = 4
    private let bottom: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let plotHeight = size.height - top - bottom
            func x(_ fraction: Double) -> CGFloat { CGFloat(fraction) * size.width }
            func y(_ usage: Double) -> CGFloat { top + plotHeight * (1 - CGFloat(min(max(usage, 0), 100)) / 100) }
            let accent: Color = curve.tint == .calm ? .white : curve.tint.color

            for day in curve.days {
                var line = Path()
                line.move(to: CGPoint(x: x(day.fraction), y: top))
                line.addLine(to: CGPoint(x: x(day.fraction), y: top + plotHeight))
                context.stroke(line, with: .color(.white.opacity(0.07)), lineWidth: 1)
            }

            var limit = Path()
            limit.move(to: CGPoint(x: 0, y: y(100)))
            limit.addLine(to: CGPoint(x: size.width, y: y(100)))
            context.stroke(limit, with: .color(NotchSignal.Edge.imminent.color.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            var line = Path()
            for (index, point) in curve.points.enumerated() {
                let p = CGPoint(x: x(point.fraction), y: y(point.usage))
                if index == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            var area = line
            area.addLine(to: CGPoint(x: x(curve.now.fraction), y: y(0)))
            area.addLine(to: CGPoint(x: x(curve.points.first?.fraction ?? 0), y: y(0)))
            area.closeSubpath()
            context.fill(area, with: .color(accent.opacity(0.10)))
            context.stroke(line, with: .color(accent), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            let end: CGPoint? = switch curve.projection {
            case .holds(let atReset): CGPoint(x: x(1), y: y(atReset))
            case .blocks(_, let fraction): CGPoint(x: x(fraction), y: y(100))
            case .none: nil
            }
            if let end {
                var projection = Path()
                projection.move(to: CGPoint(x: x(curve.now.fraction), y: y(curve.now.usage)))
                projection.addLine(to: end)
                context.stroke(projection, with: .color(accent.opacity(0.5)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
            }

            let dot = CGRect(x: x(curve.now.fraction) - 3, y: y(curve.now.usage) - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dot), with: .color(accent))

            // Initiale du jour au milieu de chaque journée ; le jour courant en gras.
            for (index, day) in curve.days.enumerated() {
                let next = index + 1 < curve.days.count ? curve.days[index + 1].fraction : 1
                let isToday = index == curve.todayIndex
                let label = Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : Color.white.opacity(0.45))
                context.draw(label, at: CGPoint(x: x((day.fraction + next) / 2), y: size.height - 5))
            }
        }
    }
}
