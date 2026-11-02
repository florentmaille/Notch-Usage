import Foundation

/// Langue de l'interface, choisie par l'app (catalogue de textes). Seuls l'anglais et le français existent.
public enum InterfaceLanguage: Sendable, Equatable {
    case english, french

    /// "fr", "fr-CA", "fr_BE"… → français ; tout autre code → anglais.
    public init(code: String?) {
        let base = code?.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
        self = base == "fr" ? .french : .english
    }
}

/// Libellés de durée par langue. Table explicite : les formateurs de Foundation varient selon la région
/// (« 2h 14min », « 2 h et 14 min », unités anglaises en fr-CA), voir research R1 de la feature 002.
struct TimeLabels: Sendable {
    let minutes: @Sendable (Int) -> String
    let hoursMinutes: @Sendable (Int, Int) -> String
    let daysHours: @Sendable (Int, Int) -> String
    let until: @Sendable (String) -> String
    let pending: String
    let ago: @Sendable (String) -> String
    let justNow: String
    // Ancienneté : format historique anglais « 12 min ago », « 3 h ago », « 2 d ago ».
    let ageMinutes: @Sendable (Int) -> String
    let ageHours: @Sendable (Int) -> String
    let ageDays: @Sendable (Int) -> String
    // Encoche (003) : durée nue, minutes sur deux chiffres (« 1h 02m », « 1 h 02 ») ; reset passé en un mot.
    let compactHoursMinutes: @Sendable (Int, Int) -> String
    let compactPending: String

    static func `for`(_ language: InterfaceLanguage) -> TimeLabels {
        switch language {
        case .english:
            return TimeLabels(minutes: { "\($0)m" }, hoursMinutes: { "\($0)h \($1)m" }, daysHours: { "\($0)d \($1)h" },
                              until: { "in \($0)" }, pending: "reset pending", ago: { "\($0) ago" }, justNow: "just now",
                              ageMinutes: { "\($0) min" }, ageHours: { "\($0) h" }, ageDays: { "\($0) d" },
                              compactHoursMinutes: { String(format: "%dh %02dm", $0, $1) }, compactPending: "pending")
        case .french:
            return TimeLabels(minutes: { "\($0) min" }, hoursMinutes: { "\($0) h \($1) min" }, daysHours: { "\($0) j \($1) h" },
                              until: { "dans \($0)" }, pending: "réinitialisation imminente", ago: { "il y a \($0)" }, justNow: "à l'instant",
                              ageMinutes: { "\($0) min" }, ageHours: { "\($0) h" }, ageDays: { "\($0) j" },
                              compactHoursMinutes: { String(format: "%d h %02d", $0, $1) }, compactPending: "imminent")
        }
    }
}
