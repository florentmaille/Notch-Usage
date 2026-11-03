import Foundation

/// Ce que l'encoche repliée montre sans survol (feature 005, contrat notch-signal.md) : la vue dessine,
/// le panneau lit `isSilent` et `isBand`. Dans l'encoche, seul `band` porte du texte : les autres contenus
/// se réduisent au liseré autour de l'encoche physique, leurs textes ne servent qu'à la pilule.
/// La bande complète (`CompactStrip`) reste celle de la 003.
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

    /// Rythme du battement du halo (006, contrat pulse.md) : seul un blocage prévu imminent bat.
    public enum Pulse: Sendable, Equatable {
        case none, everyMinute, everyHalfMinute

        /// Sous 10 min, toutes les 30 s ; sinon, en palier imminent, chaque minute.
        public static func rhythm(blockAt: Date, now: Date) -> Pulse {
            if blockAt.timeIntervalSince(now) < 600 { return .everyHalfMinute }
            return Edge.tier(blockAt: blockAt, now: now) == .imminent ? .everyMinute : .none
        }
    }

    /// Île de l'encoche repliée (012, contrat island.md) : jauge ou glyphe à gauche, donnée facultative à droite.
    public struct Island: Sendable, Equatable {
        public enum Tint: Sendable, Equatable { case calm, far, near, imminent, exhausted }
        public enum Glyph: Sendable, Equatable { case offline, locked, account, unavailable }
        public enum Leading: Sendable, Equatable {
            case gauge(value: Double, tint: Tint)   // usage 0-100 de la limite portée
            case glyph(Glyph)
        }
        public enum Trailing: Sendable, Equatable {
            case deadline(String)   // temps avant blocage, teinte de la jauge
            case back(String)       // temps avant retour d'une limite épuisée
            case label(String)      // libellé court d'une limite au seuil sans prévision
            case muted(String)      // pourcentage d'un relevé ancien
        }

        public let leading: Leading
        public let trailing: Trailing?

        public init(leading: Leading, trailing: Trailing? = nil) {
            self.leading = leading
            self.trailing = trailing
        }

        public var tint: Tint {
            if case .gauge(_, let tint) = leading { return tint }
            return .calm
        }

        static func tint(_ edge: Edge) -> Tint {
            switch edge {
            case .far: return .far
            case .near: return .near
            case .imminent: return .imminent
            case .exhausted: return .exhausted
            }
        }
    }

    public let content: Content
    public let edge: Edge?
    public let pulse: Pulse
    public let island: Island
    /// Toujours l'annonce de la bande complète, silence compris (FR-015).
    public let accessibility: String

    init(content: Content, edge: Edge?, pulse: Pulse = .none, island: Island = Island(leading: .glyph(.unavailable)), accessibility: String) {
        self.content = content
        self.edge = edge
        self.pulse = pulse
        self.island = island
        self.accessibility = accessibility
    }

    func with(island: Island) -> NotchSignal {
        NotchSignal(content: content, edge: edge, pulse: pulse, island: island, accessibility: accessibility)
    }

    public var isSilent: Bool { content == .silent }

    /// Seul contenu qui élargit l'encoche : survol, épinglage, gris, session, compte.
    public var isBand: Bool {
        if case .band = content { return true }
        return false
    }

    public static func make(display: DisplayState, now: Date, language: InterfaceLanguage, strings: CompactStrip.Strings,
                            locale: Locale = .current, timeZone: TimeZone = .current) -> NotchSignal {
        let signal = core(display: display, now: now, language: language, strings: strings, locale: locale, timeZone: timeZone)
        return signal.with(island: island(display: display, now: now, language: language, strings: strings))
    }

    /// Contenu, palier et rythme (005, 006, 008) : servent aux notifications, au plein écran et au battement.
    static func core(display: DisplayState, now: Date, language: InterfaceLanguage, strings: CompactStrip.Strings,
                     locale: Locale, timeZone: TimeZone) -> NotchSignal {
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
            return NotchSignal(content: .deadline(label), edge: .tier(blockAt: date, now: now), pulse: .rhythm(blockAt: date, now: now),
                               accessibility: strip.accessibility)
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

    /// Île de l'encoche repliée (012) : calculée même au survol, la vue choisit entre île et bande.
    static func island(display: DisplayState, now: Date, language: InterfaceLanguage, strings: CompactStrip.Strings) -> Island {
        switch display.content {
        case .connect: return Island(leading: .glyph(.account))
        case .reauthRequired: return Island(leading: .glyph(.locked))
        case .unavailable, .unsupported: return Island(leading: .glyph(.unavailable))
        case .limits: break
        }
        guard let limit = display.headline?.limit else { return Island(leading: .glyph(.unavailable)) }
        let usage = min(100, max(0, limit.utilization))
        if display.banner != nil || display.fetchFailed {
            return Island(leading: .glyph(.offline), trailing: .muted(strings.percent(Int(usage.rounded()))))
        }
        if limit.isBlocked {
            let back = limit.resetsAt.map { IslandFormat.deadline(remaining: $0.timeIntervalSince(now)) } ?? strings.dash
            return Island(leading: .gauge(value: 100, tint: .exhausted), trailing: .back(back))
        }
        switch display.forecasts[limit.id] {
        case .blockAt(let date)?:
            return Island(leading: .gauge(value: usage, tint: Island.tint(Edge.tier(blockAt: date, now: now))),
                          trailing: .deadline(IslandFormat.deadline(remaining: date.timeIntervalSince(now))))
        case .holdsUntilReset?:
            return Island(leading: .gauge(value: usage, tint: .calm))
        case .unavailable?, nil:
            guard let tier = Edge.tier(alertLevel: display.alertLevel) else { return Island(leading: .gauge(value: usage, tint: .calm)) }
            return Island(leading: .gauge(value: usage, tint: Island.tint(tier)), trailing: .label(strings.shortLabel(limit)))
        }
    }
}

/// Format court de l'oreille droite (012, R5) : « 2:05 » à une heure et plus, « 40′ » en dessous. Minute
/// entamée comptée, comme un compte à rebours : 7 min 30 s affichent « 8′ ».
public enum IslandFormat {
    public static func deadline(remaining: TimeInterval) -> String {
        let minutes = max(0, Int((remaining / 60).rounded(.up)))
        if minutes >= 60 { return "\(minutes / 60):" + String(format: "%02d", minutes % 60) }
        return "\(minutes)\u{2032}"
    }
}
