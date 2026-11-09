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
                // Plein écran : rien de visible (016), la bande transparente sert seulement au survol qui rouvre l'encoche.
                Color.clear
                    .frame(height: NotchPanelController.hiddenStripHeight)
            } else {
                CompactView(display: d, signal: s, beat: model.beat, now: model.now, onTap: { model.clearDoneSessions() })
                    .frame(height: d.layout.height)
                    // L'île ne bouge pas à l'écran quand le panneau s'ouvre : seul son cadre change (décalé replié,
                    // centré déplié). Animée, elle glissait vers sa nouvelle place puis sautait (retour utilisateur).
                    .transaction(value: d.isExpanded) { $0.animation = nil }
                if d.isExpanded {
                    PanelContentView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Forme et arrondi suivent la fenêtre sans délai : animés, ils arrivaient après le cadre (coins carrés).
        .background(alignment: .top) { NotchShape(display: d).transaction(value: d.isExpanded) { $0.animation = nil } }
        // Oreille droite et largeur en fondu (012, FR-011) ; le battement a sa propre animation.
        .animation(reduceMotion ? nil : .easeOut(duration: NotchPanelController.islandFade), value: s.island)
        .animation(.easeOut(duration: d.isExpanded ? 0.18 : 0.12), value: d.isExpanded)
    }
}

/// Fond noir qui prolonge l'encoche en île, arrondi en bas : il remplit le panneau.
private struct NotchShape: View {
    let display: DisplayState

    var body: some View {
        let radius: CGFloat = display.isExpanded ? 18 : 12
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

