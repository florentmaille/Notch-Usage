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
                AlertDotView(level: d.alertLevel, visible: d.showAlertDot, edge: s.edge, beat: model.beat)
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
            NotchShape(display: d, edge: s.edge, narrow: s.isSilent || (d.mode == .notch && !s.isBand), beat: model.beat)
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
    /// Compteur de battements (006) : chaque incrément fait respirer le halo.
    let beat: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                BeatingStroke(shape: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius + w, bottomTrailingRadius: radius + w,
                                                            topTrailingRadius: 0, style: .continuous),
                              lineWidth: w, edge: edge, beat: beat, reduceMotion: reduceMotion)
                    .frame(width: narrow ? display.layout.width + 2 * w : nil, height: display.layout.height + w)
            }
            let shape = UnevenRoundedRectangle(topLeadingRadius: notch ? 0 : radius,
                                               bottomLeadingRadius: radius, bottomTrailingRadius: radius,
                                               topTrailingRadius: notch ? 0 : radius, style: .continuous)
            shape.fill(.black)
                .overlay {
                    if let edge, !notch {
                        // Pilule : entièrement visible, cerne puis trait à l'intérieur, tout autour.
                        shape.strokeBorder(NotchSignal.Edge.keylineColor, lineWidth: NotchSignal.Edge.keyline)
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        BeatingStroke(shape: shape.inset(by: NotchSignal.Edge.keyline), lineWidth: edge.lineWidth,
                                      edge: edge, beat: beat, reduceMotion: reduceMotion)
                    }
                }
                .frame(width: narrow && notch ? display.layout.width : nil, height: narrow ? display.layout.height : nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(display.fullscreenHidden ? 0 : 1)
    }
}

/// Trait du liseré avec son halo. Sur les paliers à halo, chaque incrément de `beat` déclenche un double
/// battement de cœur en 1 s (006, R4) : halo 0,6 → 1 → 0,7 → 1 → 0,6 et rayon 6 → 14 pt, trait éclairci vers le
/// blanc sur la montée. Épaisseur et géométrie ne changent pas ; en mode réduit d'animations, tout est fixe.
private struct BeatingStroke<S: InsettableShape>: View {
    let shape: S
    let lineWidth: CGFloat
    let edge: NotchSignal.Edge
    let beat: Int
    let reduceMotion: Bool

    var body: some View {
        if !edge.hasHalo {
            shape.strokeBorder(edge.color, lineWidth: lineWidth)
        } else if reduceMotion {
            shape.strokeBorder(edge.color, lineWidth: lineWidth)
                .shadow(color: edge.color.opacity(Beat.restOpacity), radius: Beat.restRadius, y: 2)
        } else {
            Color.clear.phaseAnimator([Beat.restOpacity, 1.0, 0.7, 1.0], trigger: beat) { _, opacity in
                let rise = (opacity - Beat.restOpacity) / (1 - Beat.restOpacity)
                shape.strokeBorder(edge.color(lightened: Beat.peakLightening * rise), lineWidth: lineWidth)
                    .shadow(color: edge.color.opacity(opacity), radius: Beat.restRadius + (Beat.peakRadius - Beat.restRadius) * rise, y: 2)
            } animation: { _ in .easeInOut(duration: 0.2) }
        }
    }
}

private enum Beat {
    static let restOpacity = 0.6
    static let restRadius: CGFloat = 6
    static let peakRadius: CGFloat = 14
    static let peakLightening = 0.45
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
