import Foundation
import NotchUsageCore

/// Langue réellement retenue pour l'interface (celle du catalogue de textes), transmise au core pour
/// que les durées ne divergent jamais du reste des textes, y compris avec la langue par app du système.
enum AppLanguage {
    static let current = InterfaceLanguage(code: Bundle.main.preferredLocalizations.first)
}
