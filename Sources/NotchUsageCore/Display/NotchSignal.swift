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
            case percent(String)    // usage au calme quand on travaille sur l'écran de l'île (019)
            case attention(kind: ClaudeWaitingKind, count: Int)   // session Claude en attente (017)
        }

        public let leading: Leading
        public let trailing: Trailing?
        /// Point au coin de la jauge quand la limite garde l'oreille droite (017, R9).
        public let badge: ClaudeWaitingKind?
        /// 019 : on travaille sur un écran sans encoche, l'île s'efface (ni jauge ni oreille) ; la pastille porte le suivi.
        public let folded: Bool

        public init(leading: Leading, trailing: Trailing? = nil, badge: ClaudeWaitingKind? = nil, folded: Bool = false) {
            self.leading = leading
            self.trailing = trailing
            self.badge = badge
            self.folded = folded
        }

        /// La limite garde l'oreille droite quand elle est imminente (échéance rouge) ou épuisée.
        var limitKeepsTrailing: Bool {
            switch trailing {
            case .back?: return true
            case .deadline?: return tint == .imminent
            default: return false
            }
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

    /// Sessions Claude Code en attente (017) : le cas le plus pressant, le nombre, la dernière arrivée (libellé 4 s)
    /// et la liste pour VoiceOver.
    public struct Attention: Sendable, Equatable {
        public struct Entry: Sendable, Equatable {
            public let name: String
            public let kind: ClaudeWaitingKind
            public init(name: String, kind: ClaudeWaitingKind) { self.name = name; self.kind = kind }
        }

        public let kind: ClaudeWaitingKind
        public let count: Int
        public let arrivedAt: Date
        public let entries: [Entry]

        public init(kind: ClaudeWaitingKind, count: Int, arrivedAt: Date, entries: [Entry]) {
            self.kind = kind
            self.count = count
            self.arrivedAt = arrivedAt
            self.entries = entries
        }
    }

    public let content: Content
    public let edge: Edge?
    public let pulse: Pulse
    public let island: Island
    public let attention: Attention?
    /// Oreille droite de la limite avant que Claude ne la prenne (018 : la barre de menus montre les deux).
    public let limitTrailing: Island.Trailing?
    /// Toujours l'annonce de la bande complète, silence compris (FR-015).
    public let accessibility: String

    init(content: Content, edge: Edge?, pulse: Pulse = .none, island: Island = Island(leading: .glyph(.unavailable)),
         attention: Attention? = nil, limitTrailing: Island.Trailing? = nil, accessibility: String) {
        self.content = content
        self.edge = edge
        self.pulse = pulse
        self.island = island
        self.attention = attention
        self.limitTrailing = limitTrailing
        self.accessibility = accessibility
    }

    func with(island: Island, attention: Attention? = nil, limitTrailing: Island.Trailing? = nil, accessibility: String? = nil) -> NotchSignal {
        NotchSignal(content: content, edge: edge, pulse: pulse, island: island, attention: attention, limitTrailing: limitTrailing,
                    accessibility: accessibility ?? self.accessibility)
    }

    /// Barre de menus active, quand un écran sans encoche est branché (019).
    public enum ActiveBar: Sendable, Equatable {
        case island      // on travaille sur l'écran à encoche
        case elsewhere   // on travaille sur un écran sans encoche
    }

    /// 019 : comme la pastille, l'île montre le chiffre là où l'on travaille et s'efface ailleurs. Sur l'écran de
    /// l'île, une oreille droite vide reçoit le pourcentage ; ailleurs, l'île se replie entièrement (`folded`), jauge
    /// comprise (retour utilisateur). L'annonce VoiceOver, le palier et le battement ne changent pas.
    public func adapted(to activeBar: ActiveBar?, strings: CompactStrip.Strings) -> NotchSignal {
        switch activeBar {
        case nil:
            return self
        case .island?:
            guard island.trailing == nil, case .gauge(let value, _) = island.leading else { return self }
            let percent = strings.percent(Int(min(100, max(0, value)).rounded()))
            return with(island: Island(leading: island.leading, trailing: .percent(percent), badge: island.badge),
                        attention: attention, limitTrailing: limitTrailing)
        case .elsewhere?:
            return with(island: Island(leading: island.leading, folded: true), attention: attention, limitTrailing: limitTrailing)
        }
    }

    public var isSilent: Bool { content == .silent }

    /// Seul contenu qui élargit l'encoche : survol, épinglage, gris, session, compte.
    public var isBand: Bool {
        if case .band = content { return true }
        return false
    }

    public static func make(display: DisplayState, now: Date, language: InterfaceLanguage, strings: CompactStrip.Strings,
                            locale: Locale = .current, timeZone: TimeZone = .current, attention: Attention? = nil) -> NotchSignal {
        let signal = core(display: display, now: now, language: language, strings: strings, locale: locale, timeZone: timeZone)
        let base = island(display: display, now: now, language: language, strings: strings)
        guard let attention else { return signal.with(island: base, limitTrailing: base.trailing) }
        // 017, R9 : la limite garde l'oreille droite si elle est imminente ou épuisée ; sinon la session la prend.
        let island = base.limitKeepsTrailing
            ? Island(leading: base.leading, trailing: base.trailing, badge: attention.kind)
            : Island(leading: base.leading, trailing: .attention(kind: attention.kind, count: attention.count))
        let list = attention.entries.map { "\($0.name), \(strings.claude.kindAnnouncement($0.kind))" }.joined(separator: "; ")
        let prefix = strings.claude.waitingAnnouncement(attention.count) + list + ". "
        return signal.with(island: island, attention: attention, limitTrailing: base.trailing, accessibility: prefix + signal.accessibility)
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
        switch display.forecasts.notch(for: limit) {
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
            let back = limit.resetsAt.map { IslandFormat.back(remaining: $0.timeIntervalSince(now), language: language) } ?? strings.dash
            return Island(leading: .gauge(value: 100, tint: .exhausted), trailing: .back(back))
        }
        switch display.forecasts.notch(for: limit) {
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
        let minutes = wholeMinutes(remaining)
        if minutes >= 60 { return "\(minutes / 60):" + String(format: "%02d", minutes % 60) }
        return "\(minutes)\u{2032}"
    }

    /// Retour d'une limite atteinte : comme `deadline` sous 24 h ; au-delà (limite hebdomadaire), jours et heures
    /// (« 3d 5h », « 3 j 5 h ») plutôt que « 77:00 ».
    public static func back(remaining: TimeInterval, language: InterfaceLanguage) -> String {
        let hours = wholeMinutes(remaining) / 60
        guard hours >= 24 else { return deadline(remaining: remaining) }
        return TimeLabels.for(language).daysHours(hours / 24, hours % 24)
    }

    /// Minute entamée comptée ; jamais négatif, et sans plantage sur une date de reset aberrante.
    private static func wholeMinutes(_ remaining: TimeInterval) -> Int {
        max(0, (remaining / 60).rounded(.up).boundedInt)
    }
}
