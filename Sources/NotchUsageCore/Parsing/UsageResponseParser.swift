import Foundation

/// Parseur unique des deux formes de réponse (voir contracts/usage-api.md).
public enum UsageResponseParser {
    /// Clés plates legacy qui ne désignent pas un modèle.
    private static let ignoredFlatSuffixes: Set<String> = ["cowork", "oauth_apps", "routines", "omelette"]

    public static func parse(_ data: Data) throws(ParseError) -> [UsageLimit] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        var raw: [(id: String, kind: LimitKind, model: String?, value: Double, resetsAt: Date?)] = []

        if let limits = root["limits"] as? [[String: Any]], !limits.isEmpty {
            // Forme actuelle : seule source, les clés plates sont ignorées.
            for entry in limits {
                guard let kindRaw = entry["kind"] as? String,
                      let value = number(entry["percent"] ?? entry["utilization"]) else { continue }
                let resets = ResetDateParser.parse(entry["resets_at"])
                switch kindRaw {
                case "session":
                    raw.append(("session", .rollingFiveHour, nil, value, resets))
                case "weekly_all":
                    raw.append(("weekly_all", .weeklyAll, nil, value, resets))
                case "weekly_scoped":
                    let scope = entry["scope"] as? [String: Any]
                    let model = scope?["model"] as? [String: Any]
                    let name = (model?["display_name"] as? String)
                        ?? (model?["id"] as? String)
                        ?? "Model"
                    raw.append(("weekly_scoped:\(name)", .weeklyModel, name, value, resets))
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

        // Toutes les valeurs ≤ 1 ⇒ fraction 0...1 (cf. incertitude cc-pool).
        let scale: Double = raw.allSatisfy({ $0.value <= 1 }) && raw.contains(where: { $0.value > 0 }) ? 100 : 1

        return raw.map { UsageLimit(id: $0.id, kind: $0.kind, modelName: $0.model, utilization: $0.value * scale, resetsAt: $0.resetsAt) }
            .sorted(by: UsageLimit.displayOrder)
    }

    private static func window(_ value: Any?) -> (Double, Date?)? {
        guard let dict = value as? [String: Any], let v = number(dict["utilization"] ?? dict["percent"]) else { return nil }
        return (v, ResetDateParser.parse(dict["resets_at"]))
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
