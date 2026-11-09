import Foundation

/// Affichage de l'item de barre de menus (018, FR-018) : remplace le booléen de la 014.
public enum MenuBarIconMode: String, Sendable, CaseIterable {
    case automatic, always, never

    /// L'ancien réglage activé devient « Toujours » ; sinon « Automatique ».
    public static func migrate(legacy: Bool?) -> MenuBarIconMode {
        legacy == true ? .always : .automatic
    }

    public func isVisible(roles: ScreenRoles) -> Bool {
        switch self {
        case .always: return true
        case .never: return false
        case .automatic: return roles.hasPlainScreen
        }
    }
}
