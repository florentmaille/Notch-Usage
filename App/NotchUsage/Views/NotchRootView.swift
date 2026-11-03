import NotchUsageCore
import SwiftUI

/// Racine hébergée dans le panneau : île ou bande en haut, contenu déplié en dessous (012).
struct NotchRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let d = model.display
        let s = model.signal
        VStack(spacing: 0) {
            if d.fullscreenHidden {
                AlertDotView(level: d.alertLevel, visible: d.showAlertDot, edge: s.edge, beat: model.beat)
                    .frame(height: NotchPanelController.hiddenStripHeight)
            } else {
                CompactView(display: d, signal: s, beat: model.beat)
                    .frame(height: d.layout.height)
                if d.isExpanded {
                    ExpandedContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) { NotchShape(display: d) }
        // Oreille droite et largeur en fondu (012, FR-011) ; le battement a sa propre animation.
        .animation(reduceMotion ? nil : .easeOut(duration: NotchPanelController.islandFade), value: s.island)
        .animation(.easeOut(duration: d.isExpanded ? 0.18 : 0.12), value: d.isExpanded)
    }
}

/// Fond noir qui prolonge l'encoche en île (ou dessine la pilule), arrondi en bas : il remplit le panneau.
private struct NotchShape: View {
    let display: DisplayState

    var body: some View {
        let notch = display.mode == .notch
        let radius: CGFloat = notch ? (display.isExpanded ? 18 : 12) : 14
        UnevenRoundedRectangle(topLeadingRadius: notch ? 0 : radius, bottomLeadingRadius: radius,
                               bottomTrailingRadius: radius, topTrailingRadius: notch ? 0 : radius, style: .continuous)
            .fill(.black)
            .opacity(display.fullscreenHidden ? 0 : 1)
    }
}

/// Contenu déplié : connexion, limites ou réglages.
private struct ExpandedContainer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.showSettings && model.display.content != .connect {
                SettingsView().padded()
            } else {
                // Hauteur idéale mesurée sur ces vues seulement : les réglages défilent dans une hauteur
                // fixe et ne doivent pas fausser la mesure pendant la transition.
                Group {
                    if model.display.content == .connect { ConnectView() } else { ExpandedView() }
                }
                .padded()
                .fixedSize(horizontal: false, vertical: true)
                // Fermeture isolée au main actor : ni clé de préférence ni `assumeIsolated` (010).
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    model.setExpandedContentHeight(height)
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private extension View {
    func padded() -> some View {
        padding(.horizontal, 16).padding(.bottom, 14).padding(.top, 6)
    }
}

