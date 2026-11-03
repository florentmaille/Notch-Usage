import Foundation

/// Ce que l'encoche repliée montre sans survol (feature 005, contrat notch-signal.md) : la vue dessine,
/// le panneau lit `isSilent`. La bande complète (`CompactStrip`) reste celle de la 003.
public struct NotchSignal: Sendable, Equatable {
    public enum Content: Sendable, Equatable {
        case silent                                   // rien : ni oreille, ni texte
        case band(CompactStrip)                       // bande complète : survol, épinglé, gris, session, compte
        case deadline(String)                         // sablier + durée ou heure du blocage, aile droite seule
        case exhausted(full: String, back: String)    // pastille « Full » à gauche, flèche + retour à droite
        case threshold(label: String, percent: String) // libellé court à gauche, pastille à droite
    }

    /// Palier du liseré : la teinte et l'épaisseur sont des constantes de l'app.
    public enum Edge: Sendable, Equatable {
        case far, near, imminent, exhausted

        public static func tier(blockAt: Date, now: Date) -> Edge {
            let remaining = blockAt.timeIntervalSince(now)
            if remaining >= 3600 { return .far }
            if remaining >= 1800 { return .near }
            return .imminent
        }

        public static func tier(alertLevel: AlertLevel) -> Edge? {
            switch alertLevel {
            case .none: return nil
            case .warning: return .far
            case .critical: return .imminent
            }
        }
    }

    public let content: Content
    public let edge: Edge?
    /// Toujours l'annonce de la bande complète, silence compris (FR-015).
    public let accessibility: String

    public var isSilent: Bool { content == .silent }

    public static func make(display: DisplayState, now: Date, language: InterfaceLanguage, strings: CompactStrip.Strings,
                            locale: Locale = .current, timeZone: TimeZone = .current) -> NotchSignal {
        let strip = CompactStrip.make(display: display, now: now, language: language, strings: strings, locale: locale, timeZone: timeZone)
        let band = NotchSignal(content: .band(strip), edge: nil, accessibility: strip.accessibility)
        // Survol et épinglage montrent la bande ; un relevé gris, une session ou un compte absent aussi, sans liseré.
        guard display.content == .limits, !display.isExpanded, display.banner == nil, !display.fetchFailed,
              let limit = display.headline?.limit else { return band }

        let countdown = limit.resetsAt.map { RelativeTimeFormatter.duration(until: $0, now: now, language: language) } ?? strings.dash
        if limit.isBlocked {
            return NotchSignal(content: .exhausted(full: strings.full, back: countdown), edge: .exhausted, accessibility: strip.accessibility)
        }
        // Fenêtre de 5 h : la prévision prime sur le seuil (clarification FR-007a).
        switch display.forecasts[limit.id] {
        case .blockAt(let date)?:
            let label = RelativeTimeFormatter.blockLabel(date, now: now, language: language, locale: locale, timeZone: timeZone)
            return NotchSignal(content: .deadline(label), edge: .tier(blockAt: date, now: now), accessibility: strip.accessibility)
        case .holdsUntilReset?:
            return NotchSignal(content: .silent, edge: nil, accessibility: strip.accessibility)
        case .unavailable?, nil:
            guard let tier = Edge.tier(alertLevel: display.alertLevel) else {
                return NotchSignal(content: .silent, edge: nil, accessibility: strip.accessibility)
            }
            let percent = strings.percent(Int(limit.utilization.rounded()))
            return NotchSignal(content: .threshold(label: strings.shortLabel(limit), percent: percent), edge: tier, accessibility: strip.accessibility)
        }
    }
}
