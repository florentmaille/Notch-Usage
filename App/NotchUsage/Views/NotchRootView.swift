import NotchUsageCore
import SwiftUI

/// Racine hébergée dans le panneau : bandeau compact en haut, contenu déplié en dessous.
/// En silence (005), ni forme ni texte ; le fondu d'entrée et de sortie dure 0,6 s.
struct NotchRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let d = model.display
        let s = model.signal
        VStack(spacing: 0) {
            if d.fullscreenHidden {
                AlertDotView(level: d.alertLevel, visible: d.showAlertDot, edge: s.edge)
                    .frame(height: NotchPanelController.hiddenStripHeight)
            } else {
                CompactView(display: d, signal: s, now: model.now, pulse: model.alertPulse, onReconnect: { model.reconnect() })
                    .frame(height: d.layout.height)
                if d.isExpanded {
                    ExpandedContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) {
            // Toujours présente, seule son opacité s'anime : un retrait conditionnel saccade à la sortie.
            NotchShape(display: d, edge: s.edge, narrow: s.isSilent || (d.mode == .notch && !s.isBand))
                .opacity(s.isSilent ? 0 : 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: NotchPanelController.silenceFade), value: s.isSilent)
        .animation(.easeOut(duration: d.isExpanded ? 0.18 : 0.12), value: d.isExpanded)
    }
}

/// Fond noir qui prolonge l'encoche (ou dessine la pilule), arrondi en bas, avec le liseré du palier (005).
/// Dans l'encoche, le liseré est tracé à l'extérieur de la forme : sous le cutout physique rien ne s'affiche.
private struct NotchShape: View {
    let display: DisplayState
    let edge: NotchSignal.Edge?
    /// Forme réduite à l'encoche physique (silence ou liseré seul) plutôt qu'au panneau entier.
    let narrow: Bool

    var body: some View {
        let expanded = display.isExpanded
        let notch = display.mode == .notch
        let radius: CGFloat = notch ? (expanded ? 18 : 12) : 14
        ZStack(alignment: .top) {
            if let edge, notch {
                // Contour extérieur tout autour de l'encoche (flancs, arrondis, bas) : son bord intérieur coïncide
                // avec l'encoche physique ; le haut est le bord de l'écran.
                let w = edge.lineWidth
                let k = NotchSignal.Edge.keyline
                // Cerne sombre hors du trait : le détache d'un fond d'écran clair ou de la même teinte.
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius + w + k, bottomTrailingRadius: radius + w + k,
                                       topTrailingRadius: 0, style: .continuous)
                    .strokeBorder(NotchSignal.Edge.keylineColor, lineWidth: k)
                    .frame(width: narrow ? display.layout.width + 2 * (w + k) : nil, height: display.layout.height + w + k)
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius + w, bottomTrailingRadius: radius + w,
                                       topTrailingRadius: 0, style: .continuous)
                    .strokeBorder(edge.color, lineWidth: w)
                    .frame(width: narrow ? display.layout.width + 2 * w : nil, height: display.layout.height + w)
                    .shadow(color: edge.hasHalo ? edge.color.opacity(0.6) : .clear, radius: 6, y: 2)
            }
            let shape = UnevenRoundedRectangle(topLeadingRadius: notch ? 0 : radius,
                                               bottomLeadingRadius: radius, bottomTrailingRadius: radius,
                                               topTrailingRadius: notch ? 0 : radius, style: .continuous)
            shape.fill(.black)
                .overlay {
                    if let edge, !notch {
                        // Pilule : entièrement visible, cerne puis trait à l'intérieur, tout autour.
                        shape.strokeBorder(NotchSignal.Edge.keylineColor, lineWidth: NotchSignal.Edge.keyline)
                        shape.inset(by: NotchSignal.Edge.keyline).strokeBorder(edge.color, lineWidth: edge.lineWidth)
                            .shadow(color: edge.hasHalo ? edge.color.opacity(0.6) : .clear, radius: 6, y: 2)
                    }
                }
                .frame(width: narrow && notch ? display.layout.width : nil, height: narrow ? display.layout.height : nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                .background(GeometryReader { geo in Color.clear.preference(key: ExpandedHeightKey.self, value: geo.size.height) })
                .onPreferenceChange(ExpandedHeightKey.self) { height in
                    MainActor.assumeIsolated { model.setExpandedContentHeight(height) }
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

private struct ExpandedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
