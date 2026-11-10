import Foundation

/// Quelles surfaces existent pour une configuration d'écrans et de réglages : item de barre de menus (FR-018) et
/// pastilles (FR-012, FR-016).
public struct SurfacePlan: Sendable, Equatable {
    public let showsItem: Bool
    /// Écrans sans encoche qui portent une pastille.
    public let capsuleScreens: [String]

    public init(showsItem: Bool, capsuleScreens: [String]) {
        self.showsItem = showsItem
        self.capsuleScreens = capsuleScreens
    }

    public static func make(roles: ScreenRoles, iconMode: MenuBarIconMode, capsule: Bool) -> SurfacePlan {
        SurfacePlan(showsItem: iconMode.isVisible(roles: roles),
                    capsuleScreens: capsule ? roles.plain.filter(\.capsuleEligible).map(\.id) : [])
    }
}

extension ScreenRoles {
    /// À côté d'un écran sans encoche, l'île porte le pourcentage au calme (019), que l'on travaille sur le Mac ou
    /// sur l'autre écran : elle ne s'efface plus quand on travaille ailleurs (retour utilisateur, 2026-11-10).
    /// Faux : MacBook seul, l'île de la 012.
    public var islandCarriesPercent: Bool {
        hasPlainScreen && island != nil
    }
}
