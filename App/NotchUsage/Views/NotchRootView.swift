import NotchUsageCore
import SwiftUI

/// Racine hébergée dans le panneau : île ou bande en haut, contenu déplié en dessous (012).
struct NotchRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 019 : l'île reste repliée au survol, le panneau s'ouvre dans une carte détachée dessous (NotchCardView).
        var d = model.display
        let _ = (d.panel = .collapsed)
        let s = model.signal
        VStack(spacing: 0) {
            if d.fullscreenHidden {
                // Plein écran : rien de visible (016), la bande transparente sert seulement au survol qui rouvre l'encoche.
                Color.clear
                    .frame(height: NotchPanelController.hiddenStripHeight)
            } else {
                CompactView(display: d, signal: s, beat: model.beat, now: model.now, onTap: { model.claude.clearDone() },
                            onOpen: { model.openPanel() })
                    .frame(height: d.layout.height)
                    // Le fond noir épouse l'île et non la fenêtre : la fenêtre s'élargit d'abord, invisible, puis
                    // l'oreille s'étire (019).
                    .background { NotchShape(display: d).opacity(s.island.folded ? 0 : 1) }
                    // L'encoche reste à sa place quand l'oreille gauche se resserre (fenêtre inchangée à gauche).
                    .padding(.leading, NotchPanelController.earWidth - CompactView.leadingWidth(display: d, signal: s))
            }
        }
        // L'île part du bord gauche de la fenêtre, posée sur l'encoche par le contrôleur.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Oreilles et largeur en fondu (012, FR-011) ; le battement a sa propre animation.
        .animation(reduceMotion ? nil : .easeOut(duration: NotchPanelController.islandFade), value: s.island)
    }
}

/// Carte du survol de l'île (019) : le contenu du panneau, détaché de l'encoche, quatre coins arrondis.
struct NotchCardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PanelContentView()
            .frame(width: NotchPanelController.cardWidth)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Fond noir qui prolonge l'encoche en île, arrondi en bas : il remplit le panneau.
private struct NotchShape: View {
    let display: DisplayState

    var body: some View {
        let radius: CGFloat = 12
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius,
                               bottomTrailingRadius: radius, topTrailingRadius: 0, style: .continuous)
            .fill(.black)
            .opacity(display.fullscreenHidden ? 0 : 1)
    }
}

extension View {
    func padded() -> some View {
        padding(.horizontal, 16).padding(.bottom, 14).padding(.top, 6)
    }
}

