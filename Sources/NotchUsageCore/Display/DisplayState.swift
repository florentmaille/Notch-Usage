import Foundation

/// Tout ce dont les vues ont besoin, dérivé à chaque changement. Non persisté.
public struct DisplayState: Sendable, Equatable {
    public enum Panel: Sendable, Equatable {
        case collapsed
        case hoverOpen
        case pinned
    }

    public enum Content: Sendable, Equatable {
        case connect          // aucun compte
        case limits           // valeurs disponibles (fraîches ou non)
        case unavailable      // erreur sans aucun relevé précédent
        case reauthRequired   // aucune valeur chiffrée (FR cas limite)
        case unsupported      // abonnement sans limites exposées
    }

    public enum Banner: Sendable, Equatable {
        case unavailable      // erreur, dernières valeurs conservées
        case challenge        // Cloudflare, proposer de rouvrir la connexion
        case stale            // relevé ≥ 30 min
    }

    public struct Headline: Sendable, Equatable {
        public let limit: UsageLimit
        public var isBlocked: Bool { limit.isBlocked }
        public init(limit: UsageLimit) { self.limit = limit }
    }

    public var layout: NotchLayout
    public var panel: Panel
    public var content: Content
    public var limits: [UsageLimit]
    public var headline: Headline?
    public var banner: Banner?
    public var freshness: FreshnessLevel?
    public var fetchedAt: Date?
    public var isLoading: Bool
    public var alertLevel: AlertLevel
    public var fullscreenHidden: Bool
    public var showAlertDot: Bool

    public var mode: DisplayMode { layout.mode }
    public var isExpanded: Bool { panel != .collapsed }
}
