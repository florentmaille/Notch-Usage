import Foundation

/// Parseur unique des deux formes de réponse (voir contracts/usage-api.md).
public enum UsageResponseParser {
    /// Clés plates legacy qui ne désignent pas un modèle.
    private static let ignoredFlatSuffixes: Set<String> = ["cowork", "oauth_apps", "routines", "omelette"]

    public static func parse(_ data: Data) throws(ParseError) -> [UsageLimit] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        var raw: [(id: String, kind: LimitKind, model: String?, reading: Reading, resetsAt: Date?)] = []

        if let limits = root["limits"] as? [[String: Any]], !limits.isEmpty {
            // Forme actuelle : seule source, les clés plates sont ignorées.
            for entry in limits {
                guard let kindRaw = entry["kind"] as? String, let reading = reading(entry, preferPercent: true) else { continue }
                let resets = ResetDateParser.parse(entry["resets_at"])
                switch kindRaw {
                case "session":
                    raw.append(("session", .rollingFiveHour, nil, reading, resets))
                case "weekly_all":
                    raw.append(("weekly_all", .weeklyAll, nil, reading, resets))
                case "weekly_scoped":
                    let scope = entry["scope"] as? [String: Any]
                    let model = scope?["model"] as? [String: Any]
                    let name = (model?["display_name"] as? String)
                        ?? (model?["id"] as? String)
                        ?? "Model"
                    raw.append(("weekly_scoped:\(name)", .weeklyModel, name, reading, resets))
                default:
                    continue
                }
            }
        } else {
            // Forme legacy.
            if let w = window(root["five_hour"]) { raw.append(("session", .rollingFiveHour, nil, w.0, w.1)) }
            if let w = window(root["seven_day"]) { raw.append(("weekly_all", .weeklyAll, nil, w.0, w.1)) }
            for (key, value) in root where key.hasPrefix("seven_day_") {
                let suffix = String(key.dropFirst("seven_day_".count))
                guard !ignoredFlatSuffixes.contains(suffix), let w = window(value) else { continue }
                let name = suffix.prefix(1).uppercased() + suffix.dropFirst()
                raw.append(("weekly_scoped:\(name)", .weeklyModel, name, w.0, w.1))
            }
        }

        guard !raw.isEmpty else { throw ParseError.noLimits }

        // Fraction 0…1 (incertitude cc-pool) : seulement pour `utilization`, quand tout est ≤ 1 et qu'une valeur au
        // moins est strictement entre 0 et 1. `percent` est un pourcentage, et des entiers 0 ou 1 sont des
        // pourcentages bas : juste après un reset, les multiplier par 100 annonçait une limite atteinte.
        let isFraction = raw.allSatisfy { !$0.reading.isPercent && $0.reading.value <= 1 }
            && raw.contains { $0.reading.value > 0 && $0.reading.value < 1 }
        let scale: Double = isFraction ? 100 : 1

        return raw.map { UsageLimit(id: $0.id, kind: $0.kind, modelName: $0.model, utilization: $0.reading.value * scale, resetsAt: $0.resetsAt) }
            .sorted(by: UsageLimit.displayOrder)
    }

    /// Valeur lue ; `isPercent` si elle vient de la clé `percent`, un pourcentage par définition.
    private typealias Reading = (value: Double, isPercent: Bool)

    /// Une clé présente mais `null` laisse la main à l'autre.
    private static func reading(_ dict: [String: Any], preferPercent: Bool) -> Reading? {
        let percent: Reading? = number(dict["percent"]).map { (value: $0, isPercent: true) }
        let utilization: Reading? = number(dict["utilization"]).map { (value: $0, isPercent: false) }
        return preferPercent ? percent ?? utilization : utilization ?? percent
    }

    private static func window(_ value: Any?) -> (Reading, Date?)? {
        guard let dict = value as? [String: Any], let reading = reading(dict, preferPercent: false) else { return nil }
        return (reading, ResetDateParser.parse(dict["resets_at"]))
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: return n.doubleValue
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        default: return nil
        }
    }
}
