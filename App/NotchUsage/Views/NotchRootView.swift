import NotchUsageCore
import SwiftUI

/// Racine hébergée dans le panneau : bandeau compact en haut, contenu déplié en dessous.
struct NotchRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let d = model.display
        VStack(spacing: 0) {
            if d.fullscreenHidden {
                AlertDotView(level: d.alertLevel, visible: d.showAlertDot)
                    .frame(height: NotchPanelController.hiddenStripHeight)
            } else {
                CompactView(display: d, pulse: model.alertPulse, onReconnect: { model.reconnect() })
                    .frame(height: d.layout.height)
                if d.isExpanded {
                    ExpandedContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) { NotchShape(display: d) }
        .animation(.easeOut(duration: d.isExpanded ? 0.18 : 0.12), value: d.isExpanded)
    }
}

/// Fond noir qui prolonge l'encoche (ou dessine la pilule), arrondi en bas.
private struct NotchShape: View {
    let display: DisplayState

    var body: some View {
        let expanded = display.isExpanded
        let radius: CGFloat = display.mode == .notch ? (expanded ? 18 : 12) : 14
        UnevenRoundedRectangle(topLeadingRadius: display.mode == .pill ? radius : 0,
                               bottomLeadingRadius: radius, bottomTrailingRadius: radius,
                               topTrailingRadius: display.mode == .pill ? radius : 0, style: .continuous)
            .fill(.black)
            .opacity(display.fullscreenHidden ? 0 : 1)
    }
}

/// Contenu déplié : connexion, limites ou réglages.
private struct ExpandedContainer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.display.content == .connect {
                ConnectView()
            } else if model.showSettings {
                SettingsView()
            } else {
                ExpandedView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .padding(.top, 6)
        .foregroundStyle(.white)
    }
}
