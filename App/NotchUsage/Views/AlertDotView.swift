import NotchUsageCore
import SwiftUI

/// Point discret visible en plein écran (FR-012a, US3). Depuis la 008 il suit le palier du liseré : couleur du
/// palier, battement avec `beat` en imminent ; sans liseré, il garde le comportement des seuils (001).
struct AlertDotView: View {
    let level: AlertLevel
    let visible: Bool
    /// Palier du liseré (005) : la bande masquée et le point en prennent la couleur.
    var edge: NotchSignal.Edge? = nil
    var beat: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: Bool { visible || edge != nil }
    private var color: Color { edge?.color ?? (level == .critical ? Color.red : Color.orange) }

    var body: some View {
        HStack {
            Spacer()
            if shown {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 8)
                    .phaseAnimator([1.0, 1.8], trigger: beat) { view, scale in
                        view.scaleEffect(reduceMotion ? 1 : scale)
                    } animation: { _ in .easeInOut(duration: 0.25) }
            }
        }
        .frame(maxWidth: .infinity)
        .background(edge?.color ?? .clear)
        .accessibilityHidden(!shown)
        .accessibilityLabel(level == .critical || edge == .imminent || edge == .exhausted
                            ? String(localized: "Critical usage alert") : String(localized: "Usage warning"))
    }
}
