import Foundation

/// Durées relatives courtes, dans la langue de l'interface (anglais par défaut, identique à 0.1.0).
public enum RelativeTimeFormatter {
    public static func untilReset(_ date: Date?, now: Date, language: InterfaceLanguage = .english) -> String {
        guard let date else { return "—" }
        let labels = TimeLabels.for(language)
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return labels.pending }
        let minutes = Int((remaining / 60).rounded(.up))
        if minutes < 60 { return labels.until(labels.minutes(max(1, minutes))) }
        let hours = minutes / 60
        if hours < 24 { return labels.until(labels.hoursMinutes(hours, minutes % 60)) }
        return labels.until(labels.daysHours(hours / 24, hours % 24))
    }

    public static func age(_ date: Date, now: Date, language: InterfaceLanguage = .english) -> String {
        let labels = TimeLabels.for(language)
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return labels.justNow }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return labels.ago(labels.ageMinutes(minutes)) }
        let hours = minutes / 60
        if hours < 24 { return labels.ago(labels.ageHours(hours)) }
        return labels.ago(labels.ageDays(hours / 24))
    }
}
