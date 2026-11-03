import NotchUsageCore
import SwiftUI

/// Point discret visible en plein écran quand une alerte est active (FR-012a, US3).
struct AlertDotView: View {
    let level: AlertLevel
    let visible: Bool
    /// Palier du liseré (005) : la bande masquée en prend la couleur.
    var edge: NotchSignal.Edge? = nil

    var body: some View {
        HStack {
            Spacer()
            if visible {
                Circle()
                    .fill(level == .critical ? Color.red : Color.orange)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(edge?.color ?? .clear)
        .accessibilityHidden(!visible)
        .accessibilityLabel(level == .critical ? String(localized: "Critical usage alert") : String(localized: "Usage warning"))
    }
}
