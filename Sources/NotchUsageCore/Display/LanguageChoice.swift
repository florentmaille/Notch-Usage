/// Langue choisie dans les réglages, stockée comme la préférence par app de macOS (`AppleLanguages`),
/// lue par le système au lancement : le choix s'applique donc au redémarrage.
public enum LanguageChoice: String, Sendable, CaseIterable, Identifiable {
    case system, english, french

    public var id: String { rawValue }

    /// Valeur à écrire dans `AppleLanguages` ; `nil` retire la préférence et rend la main au système.
    public var appleLanguages: [String]? {
        switch self {
        case .system: return nil
        case .english: return ["en"]
        case .french: return ["fr"]
        }
    }

    public init(appleLanguages: [String]?) {
        guard let first = appleLanguages?.first else { self = .system; return }
        let base = first.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
        switch base {
        case "fr": self = .french
        case "en": self = .english
        default: self = .system
        }
    }
}
