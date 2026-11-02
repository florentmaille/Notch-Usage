import Foundation

/// Durées relatives courtes, en anglais (base de localisation, FR-016a). Les vues peuvent
/// localiser à partir des composants si besoin.
public enum RelativeTimeFormatter {
    public static func untilReset(_ date: Date?, now: Date) -> String {
        guard let date else { return "—" }
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "reset pending" }
        let minutes = Int((remaining / 60).rounded(.up))
        if minutes < 60 { return "in \(max(1, minutes))m" }
        let hours = minutes / 60
        if hours < 24 { return "in \(hours)h \(minutes % 60)m" }
        let days = hours / 24
        return "in \(days)d \(hours % 24)h"
    }

    public static func age(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h ago" }
        return "\(hours / 24) d ago"
    }
}
