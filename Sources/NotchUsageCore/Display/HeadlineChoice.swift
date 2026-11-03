import Foundation

/// Limite affichée dans l'encoche repliée : automatique ou choisie dans les réglages (004).
public enum HeadlineChoice: Sendable, Hashable {
    case automatic
    case limit(String)

    /// Valeur des réglages : identifiant de limite, vide pour automatique.
    public var storedValue: String {
        if case .limit(let id) = self { return id }
        return ""
    }

    public init(storedValue: String?) {
        if let storedValue, !storedValue.isEmpty { self = .limit(storedValue) } else { self = .automatic }
    }

    /// Une limite 5 h ou hebdomadaire tous modèles épuisée passe devant le choix : plus aucun modèle n'est
    /// utilisable. Sinon la limite choisie ; à défaut, ou si elle a disparu, le blocage prévu le plus proche,
    /// puis la plus utilisée (003, research R6).
    public func pick(in snapshot: UsageSnapshot, forecasts: [String: Forecast]) -> UsageLimit? {
        if let blocking = snapshot.limits.first(where: { $0.isBlocked && $0.kind != .weeklyModel }) { return blocking }
        if case .limit(let id) = self, let chosen = snapshot.limits.first(where: { $0.id == id }) { return chosen }
        let predicted = snapshot.limits.compactMap { limit -> (UsageLimit, Date)? in
            if case .blockAt(let date)? = forecasts[limit.id] { return (limit, date) }
            return nil
        }.min { $0.1 < $1.1 }?.0
        return predicted ?? snapshot.mostConstraining
    }
}
