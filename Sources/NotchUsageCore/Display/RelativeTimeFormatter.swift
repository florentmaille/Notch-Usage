import Foundation

/// Durées relatives courtes, dans la langue de l'interface (anglais par défaut, identique à 0.1.0).
public enum RelativeTimeFormatter {
    public static func untilReset(_ date: Date?, now: Date, language: InterfaceLanguage = .english) -> String {
        guard let date else { return "—" }
        let labels = TimeLabels.for(language)
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return labels.pending }
        let minutes = (remaining / 60).rounded(.up).boundedInt
        if minutes < 60 { return labels.until(labels.minutes(max(1, minutes))) }
        let hours = minutes / 60
        if hours < 24 { return labels.until(labels.hoursMinutes(hours, minutes % 60)) }
        return labels.until(labels.daysHours(hours / 24, hours % 24))
    }

    /// Durée nue pour l'encoche (003) : « 2h 14m » / « 2 h 14 », sans préfixe, minutes sur deux chiffres.
    public static func duration(until date: Date, now: Date, language: InterfaceLanguage = .english) -> String {
        let labels = TimeLabels.for(language)
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return labels.compactPending }
        let minutes = (remaining / 60).rounded(.up).boundedInt
        if minutes < 60 { return labels.minutes(max(1, minutes)) }
        let hours = minutes / 60
        if hours < 24 { return labels.compactHoursMinutes(hours, minutes % 60) }
        return labels.daysHours(hours / 24, hours % 24)
    }

    /// Heure du blocage prévu : heure courte du système à moins d'une heure, durée nue au-delà (003, research R4).
    public static func blockLabel(_ date: Date, now: Date, language: InterfaceLanguage = .english,
                                  locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        if date.timeIntervalSince(now) < 3600 {
            return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
        }
        return duration(until: date, now: now, language: language)
    }

    public static func age(_ date: Date, now: Date, language: InterfaceLanguage = .english) -> String {
        let labels = TimeLabels.for(language)
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return labels.justNow }
        let minutes = (seconds / 60).boundedInt
        if minutes < 60 { return labels.ago(labels.ageMinutes(minutes)) }
        let hours = minutes / 60
        if hours < 24 { return labels.ago(labels.ageHours(hours)) }
        return labels.ago(labels.ageDays(hours / 24))
    }
}
