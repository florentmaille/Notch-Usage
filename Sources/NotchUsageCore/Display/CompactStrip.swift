import Foundation

/// Annonce VoiceOver de l'encoche repliée (003, FR-015) : une phrase par état, quelle que soit la forme affichée.
/// La bande visuelle de la 003 (icône à gauche, pourcentage ou pastille à droite) a laissé la place à l'île (012)
/// puis à la carte (019) ; il en reste cette annonce et les textes fournis par l'app.
public struct CompactStrip: Sendable, Equatable {
    /// Textes localisés fournis par l'app : le core n'a pas de catalogue (plan, Complexity Tracking).
    public struct Strings: Sendable {
        public var full: String
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

        public init(full: String, dash: String,
                    percent: @escaping @Sendable (Int) -> String,
                    limitLabel: @escaping @Sendable (UsageLimit) -> String,
                    shortLabel: @escaping @Sendable (UsageLimit) -> String,
                    limitAnnouncement: @escaping @Sendable (String, Int, String) -> String,
                    paceAnnouncement: @escaping @Sendable (String) -> String,
                    stateAnnouncement: @escaping @Sendable (String) -> String) {
            self.full = full
            self.dash = dash
            self.percent = percent
            self.limitLabel = limitLabel
            self.shortLabel = shortLabel
            self.limitAnnouncement = limitAnnouncement
            self.paceAnnouncement = paceAnnouncement
            self.stateAnnouncement = stateAnnouncement
        }
    }

    public let accessibility: String

    public static func make(display: DisplayState, now: Date, language: InterfaceLanguage, strings: Strings,
                            locale: Locale = .current, timeZone: TimeZone = .current) -> CompactStrip {
        switch display.content {
        case .connect:
            return CompactStrip(accessibility: strings.stateAnnouncement("connect"))
        case .reauthRequired:
            return CompactStrip(accessibility: strings.stateAnnouncement("reconnectRequired"))
        case .unsupported:
            return CompactStrip(accessibility: strings.stateAnnouncement("unsupported"))
        case .unavailable:
            return CompactStrip(accessibility: strings.stateAnnouncement("unavailable"))
        case .limits:
            guard let limit = display.headline?.limit else {
                return CompactStrip(accessibility: strings.stateAnnouncement("unavailable"))
            }
            var announcement = strings.limitAnnouncement(strings.limitLabel(limit), Int(limit.utilization.rounded()),
                                                         RelativeTimeFormatter.untilReset(limit.resetsAt, now: now, language: language))
            if case .blockAt(let date)? = display.forecasts.notch(for: limit), !limit.isBlocked {
                // L'annonce donne toujours l'heure : « bloqué à 16:40 » se lit, « bloqué à 1 h 10 » non.
                let clock = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
                announcement += strings.paceAnnouncement(clock)
            }
            return CompactStrip(accessibility: announcement)
        }
    }
}
