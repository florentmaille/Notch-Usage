import SwiftUI

/// Contenu déplié partagé (018, R5) : connexion, limites ou réglages. L'île, le popover de l'item et la carte de la
/// pastille l'hébergent tel quel (SC-005).
struct PanelContentView: View {
    @Environment(AppModel.self) private var model
    /// Seule l'île remonte sa hauteur au modèle : elle dimensionne le panneau (013). Le popover se dimensionne seul.
    var reportsHeight = true

    var body: some View {
        // Hauteur idéale mesurée sur chaque vue, réglages compris : le panneau colle à son contenu (013).
        Group {
            if model.showSettings && model.display.content != .connect {
                SettingsView()
            } else if model.display.content == .connect {
                ConnectView()
            } else {
                ExpandedView()
            }
        }
        .padded()
        .fixedSize(horizontal: false, vertical: true)
        // Fermeture isolée au main actor : ni clé de préférence ni `assumeIsolated` (010).
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if reportsHeight { model.setExpandedContentHeight(height) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
    }
}
