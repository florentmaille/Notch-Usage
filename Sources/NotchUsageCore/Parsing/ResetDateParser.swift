import Foundation

/// `resets_at` arrive en ISO 8601, en epoch secondes ou en epoch millisecondes.
public enum ResetDateParser {
    // ISO8601DateFormatter n'est pas Sendable : on en crée un à la demande (coût négligeable, quelques appels par relevé).
    private static func isoDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// Au-delà de cette valeur, un nombre est interprété en millisecondes.
    private static let millisecondsThreshold: Double = 1e11

    public static func parse(_ value: Any?) -> Date? {
        switch value {
        case nil, is NSNull:
            return nil
        case let n as NSNumber:
            return fromEpoch(n.doubleValue)
        case let d as Double:
            return fromEpoch(d)
        case let i as Int:
            return fromEpoch(Double(i))
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if let d = isoDate(t) { return plausible(d) }
            if let n = Double(t) { return fromEpoch(n) }
            return nil
        default:
            return nil
        }
    }

    private static func fromEpoch(_ n: Double) -> Date? {
        guard n.isFinite, n > 0 else { return nil }
        let seconds = n >= millisecondsThreshold ? n / 1000 : n
        return plausible(Date(timeIntervalSince1970: seconds))
    }

    /// 2020 à 2100 : hors de là, la valeur est corrompue (ou dans une unité inconnue) et vaut mieux ignorée que
    /// affichée ou convertie en minutes.
    private static let plausibleRange = Date(timeIntervalSince1970: 1_577_836_800)...Date(timeIntervalSince1970: 4_102_444_800)

    static func plausible(_ date: Date) -> Date? {
        plausibleRange.contains(date) ? date : nil
    }
}
