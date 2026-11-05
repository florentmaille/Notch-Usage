import Foundation

/// Contenu de l'encoche repliée (feature 003, contrat compact-strip.md) : la vue dessine, elle ne décide pas.
public struct CompactStrip: Sendable, Equatable {
    public enum Left: Sendable, Equatable {
        case holds(String)        // coche + durée avant réinitialisation
        case blockIn(String)      // sablier + durée ou heure du blocage prévu
        case blockedFor(String)   // flèche circulaire + durée avant retour
        case offline(String)      // wifi barré + durée avant réinitialisation
        case locked               // cadenas
        case connect              // icône de compte
        case unsupported          // point d'interrogation
        case unavailable          // wifi barré sans texte
    }

    public enum Right: Sendable, Equatable {
        case percent(String)
        case pill(String)
        case signIn(String)
        case connect(String)
        case dash
    }

    public enum Tone: Sendable, Equatable {
        case normal, muted, warning, critical
    }

    /// Textes localisés fournis par l'app : le core n'a pas de catalogue (plan, Complexity Tracking).
    public struct Strings: Sendable {
        public var full: String
        public var signIn: String
        public var connect: String
        public var dash: String
        public var percent: @Sendable (Int) -> String
        public var limitLabel: @Sendable (UsageLimit) -> String
        /// Libellé court d'une limite pour l'aile gauche du signal de seuil (005) : « 5h », « 7d », nom du modèle.
        public var shortLabel: @Sendable (UsageLimit) -> String
        /// (libellé, pourcentage, « in 2h 14m ») → annonce VoiceOver d'une limite.
        public var limitAnnouncement: @Sendable (String, Int, String) -> String
        /// (heure ou durée du blocage) → suffixe d'annonce, virgule comprise.
        public var paceAnnouncement: @Sendable (String) -> String
        /// Annonce des états sans limite (« not connected », …), par nom de `DisplayState.Content`.
        public var stateAnnouncement: @Sendable (String) -> String
        /// Textes des sessions Claude en attente (017) ; anglais par défaut, l'app fournit les siens.
        public var claude: ClaudeStrings = .english

        public init(full: String, signIn: String, connect: String, dash: String,
                    percent: @escaping @Sendable (Int) -> String,
                    limitLabel: @escaping @Sendable (UsageLimit) -> String,
                    shortLabel: @escaping @Sendable (UsageLimit) -> String,
                    limitAnnouncement: @escaping @Sendable (String, Int, String) -> String,
                    paceAnnouncement: @escaping @Sendable (String) -> String,
                    stateAnnouncement: @escaping @Sendable (String) -> String) {
            self.full = full
            self.signIn = signIn
            self.connect = connect
            self.dash = dash
            self.percent = percent
            self.limitLabel = limitLabel
            self.shortLabel = shortLabel
            self.limitAnnouncement = limitAnnouncement
            self.paceAnnouncement = paceAnnouncement
            self.stateAnnouncement = stateAnnouncement
        }
    }

    public let left: Left
    public let right: Right
    public let tone: Tone
    public let accessibility: String

    public static func make(display: DisplayState, now: Date, language: InterfaceLanguage, strings: Strings,
                            locale: Locale = .current, timeZone: TimeZone = .current) -> CompactStrip {
        switch display.content {
        case .connect:
            return CompactStrip(left: .connect, right: .connect(strings.connect), tone: .muted,
                                accessibility: strings.stateAnnouncement("connect"))
        case .reauthRequired:
            return CompactStrip(left: .locked, right: .signIn(strings.signIn), tone: .warning,
                                accessibility: strings.stateAnnouncement("reconnectRequired"))
        case .unsupported:
            return CompactStrip(left: .unsupported, right: .dash, tone: .muted, accessibility: strings.stateAnnouncement("unsupported"))
        case .unavailable:
            return CompactStrip(left: .unavailable, right: .dash, tone: .muted, accessibility: strings.stateAnnouncement("unavailable"))
        case .limits:
            guard let headline = display.headline else {
                return CompactStrip(left: .unavailable, right: .dash, tone: .muted, accessibility: strings.stateAnnouncement("unavailable"))
            }
            return limits(headline.limit, display: display, now: now, language: language, strings: strings, locale: locale, timeZone: timeZone)
        }
    }

    private static func limits(_ limit: UsageLimit, display: DisplayState, now: Date, language: InterfaceLanguage, strings: Strings,
                               locale: Locale, timeZone: TimeZone) -> CompactStrip {
        let pct = Int(limit.utilization.rounded())
        let countdown = limit.resetsAt.map { RelativeTimeFormatter.duration(until: $0, now: now, language: language) } ?? strings.dash
        // Relevé ancien ou en échec : tout en gris, sauf la pastille « Bloqué » (dernière valeur connue).
        let muted = display.banner != nil
        var blockLabel: String?
        var blockClock: String?
        if case .blockAt(let date)? = display.forecasts.notch(for: limit), !limit.isBlocked {
            blockLabel = RelativeTimeFormatter.blockLabel(date, now: now, language: language, locale: locale, timeZone: timeZone)
            // L'annonce donne toujours l'heure : « bloqué à 16:40 » se lit, « bloqué à 1 h 10 » non.
            blockClock = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
        }

        let left: Left
        if limit.isBlocked {
            left = display.fetchFailed ? .offline(countdown) : .blockedFor(countdown)
        } else if display.fetchFailed {
            left = .offline(countdown)
        } else if let blockLabel {
            left = .blockIn(blockLabel)
        } else {
            left = .holds(countdown)
        }

        let right: Right
        if limit.isBlocked {
            right = .pill(strings.full)
        } else if muted || display.alertLevel == .none {
            right = .percent(strings.percent(pct))
        } else {
            right = .pill(strings.percent(pct))
        }

        let tone: Tone
        if limit.isBlocked || display.alertLevel == .critical {
            tone = .critical
        } else if muted {
            tone = .muted
        } else if display.alertLevel == .warning || blockLabel != nil {
            tone = .warning
        } else {
            tone = .normal
        }

        var announcement = strings.limitAnnouncement(strings.limitLabel(limit), pct,
                                                     RelativeTimeFormatter.untilReset(limit.resetsAt, now: now, language: language))
        if let blockClock { announcement += strings.paceAnnouncement(blockClock) }
        return CompactStrip(left: left, right: right, tone: muted && !limit.isBlocked ? .muted : tone, accessibility: announcement)
    }
}
