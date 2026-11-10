import Foundation

/// Ce que l'item de barre de menus et la pastille centrée affichent (018, R2) : dérivé de l'île (`NotchSignal`),
/// sans réécrire la priorité de la 017 ni le format de la 003. Seul changement : l'oreille droite de l'île se
/// partage entre limite et Claude, ici le texte et l'attente se suivent.
public struct BarContent: Sendable, Equatable {
    public struct Gauge: Sendable, Equatable {
        /// Usage de la limite portée, 0…1.
        public let fraction: Double
        public let tint: NotchSignal.Island.Tint
        /// Imminent ou épuisé : battement de la 006.
        public let beats: Bool

        public init(fraction: Double, tint: NotchSignal.Island.Tint, beats: Bool) {
            self.fraction = fraction
            self.tint = tint
            self.beats = beats
        }
    }

    public enum TextEmphasis: Sendable, Equatable { case none, imminent, muted }

    public struct Attention: Sendable, Equatable {
        public let kind: ClaudeWaitingKind
        /// « » sous 2 sessions, « 9+ » à partir de 10.
        public let count: String
        /// Mot d'arrivée, pendant 4 s.
        public let arrivalWord: String?

        public init(kind: ClaudeWaitingKind, count: String, arrivalWord: String?) {
            self.kind = kind
            self.count = count
            self.arrivalWord = arrivalWord
        }
    }

    /// `nil` : anneau vide (pas de relevé, session, erreur).
    public let gauge: Gauge?
    public let text: String?
    public let textEmphasis: TextEmphasis
    public let attention: Attention?
    /// Limite imminente ou épuisée : Claude se réduit à un point sur la jauge (017, R9).
    public let attentionAsBadge: Bool
    public let accessibility: String
    public let isCompact: Bool
    /// Le texte est le pourcentage d'usage (calme ou relevé ancien), pas une échéance.
    public let textIsPercent: Bool

    public init(gauge: Gauge?, text: String?, textEmphasis: TextEmphasis = .none, attention: Attention? = nil,
                attentionAsBadge: Bool = false, accessibility: String, isCompact: Bool = false, textIsPercent: Bool = false) {
        self.gauge = gauge
        self.text = text
        self.textEmphasis = textEmphasis
        self.attention = attention
        self.attentionAsBadge = attentionAsBadge
        self.accessibility = accessibility
        self.isCompact = isCompact
        self.textIsPercent = textIsPercent
    }

    /// Même dessin : tout sauf l'annonce VoiceOver, qui change chaque minute (« resets in 2h 14m ») sans qu'un pixel
    /// ne bouge. Sert à ne redessiner que si le contenu visible change (FR-021).
    public func looksLike(_ other: BarContent) -> Bool {
        gauge == other.gauge && text == other.text && textEmphasis == other.textEmphasis && attention == other.attention
            && attentionAsBadge == other.attentionAsBadge && isCompact == other.isCompact && textIsPercent == other.textIsPercent
    }

    /// Variante de la barre de l'écran à encoche (FR-022) : jauge seule, l'île porte le détail.
    public var compact: BarContent {
        BarContent(gauge: gauge, text: nil, accessibility: accessibility, isCompact: true)
    }

    /// Item de barre de menus (retour utilisateur) : l'anneau dit déjà l'usage, le pourcentage n'y figure plus ;
    /// l'échéance d'un palier et l'attente Claude restent.
    public var menuBarItem: BarContent {
        guard textIsPercent else { return self }
        return BarContent(gauge: gauge, text: nil, attention: attention, attentionAsBadge: attentionAsBadge,
                          accessibility: accessibility, isCompact: isCompact)
    }

    public static func make(signal: NotchSignal, now: Date, strings: CompactStrip.Strings) -> BarContent {
        let island = signal.island
        var gauge: Gauge?
        if case .gauge(let value, let tint) = island.leading {
            gauge = Gauge(fraction: min(max(value, 0), 100) / 100, tint: tint, beats: tint == .imminent || tint == .exhausted)
        }

        var text: String?
        var emphasis = TextEmphasis.none
        var isPercent = false
        switch signal.limitTrailing {
        case .deadline(let s)?:
            text = s
            if island.tint == .imminent { emphasis = .imminent }
        case .back(let s)?, .label(let s)?:
            text = s
        case .muted(let s)?:
            text = s
            emphasis = .muted
            isPercent = true
        case .attention?, .percent?, nil:
            // Au calme l'île se tait : la barre montre le pourcentage.
            text = gauge.map { strings.percent(Int(($0.fraction * 100).rounded())) }
            isPercent = text != nil
        }

        let attention = signal.attention.map {
            Attention(kind: $0.kind, count: AttentionFormat.count($0.count),
                      arrivalWord: AttentionFormat.showsArrival(arrivedAt: $0.arrivedAt, now: now) ? strings.claude.arrival($0.kind) : nil)
        }
        return BarContent(gauge: gauge, text: text, textEmphasis: emphasis, attention: attention,
                          attentionAsBadge: island.badge != nil, accessibility: signal.accessibility, textIsPercent: isPercent)
    }
}
