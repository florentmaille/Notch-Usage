import Foundation

/// Quelles surfaces existent pour une configuration d'écrans et de réglages : item de barre de menus (FR-018),
/// pastilles (FR-012, FR-016), et le suivi de la barre active quand l'item n'est pas là pour la lire.
public struct SurfacePlan: Sendable, Equatable {
    public let showsItem: Bool
    /// Écrans sans encoche qui portent une pastille.
    public let capsuleScreens: [String]
    /// L'item lit la barre active sur sa propre fenêtre. Sans lui, elle se suit au clic et au changement d'app,
    /// seulement si une surface s'y adapte : une pastille, ou l'île à côté d'un écran sans encoche (019).
    public let tracksActiveBar: Bool

    public init(showsItem: Bool, capsuleScreens: [String], tracksActiveBar: Bool) {
        self.showsItem = showsItem
        self.capsuleScreens = capsuleScreens
        self.tracksActiveBar = tracksActiveBar
    }

    public static func make(roles: ScreenRoles, iconMode: MenuBarIconMode, capsule: Bool) -> SurfacePlan {
        let showsItem = iconMode.isVisible(roles: roles)
        let capsules = capsule ? roles.plain.filter(\.capsuleEligible).map(\.id) : []
        let adapts = !capsules.isEmpty || (roles.hasPlainScreen && roles.island != nil)
        return SurfacePlan(showsItem: showsItem, capsuleScreens: capsules, tracksActiveBar: !showsItem && adapts)
    }
}

extension ScreenRoles {
    /// Barre de menus active vue de l'île (019) : avec un écran sans encoche branché, l'île montre le chiffre quand
    /// on travaille sur le Mac et se replie sur la jauge ailleurs, comme la pastille. Au survol elle réapparaît
    /// entière : le pointeur ne déplace pas la barre de menus, seul un clic le fait. `nil` : l'île de la 012.
    public func islandBar(active: String?, hover: Bool) -> NotchSignal.ActiveBar? {
        guard hasPlainScreen, island != nil, let active else { return nil }
        if hover { return .island }
        return isIsland(active) ? .island : .elsewhere
    }
}
