import NotchUsageCore
import SwiftUI

/// Point discret visible en plein écran quand une alerte est active (FR-012a, US3).
struct AlertDotView: View {
    let level: AlertLevel
    let visible: Bool

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
        .accessibilityHidden(!visible)
        .accessibilityLabel(level == .critical ? String(localized: "Critical usage alert") : String(localized: "Usage warning"))
    }
}
