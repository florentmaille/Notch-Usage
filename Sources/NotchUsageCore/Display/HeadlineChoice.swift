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
    /// sinon la fenêtre de 5 h. Une limite de modèle atteinte ne s'affiche que choisie : les autres modèles restent utilisables.
    public func pick(in snapshot: UsageSnapshot, forecasts: [String: Forecast]) -> UsageLimit? {
        if let blocking = snapshot.limits.first(where: { $0.isBlocked && $0.kind != .weeklyModel }) { return blocking }
        if case .limit(let id) = self, let chosen = snapshot.limits.first(where: { $0.id == id }) { return chosen }
        let predicted = snapshot.limits.compactMap { limit -> (UsageLimit, Date)? in
            if case .blockAt(let date)? = forecasts[limit.id] { return (limit, date) }
            return nil
        }.min { $0.1 < $1.1 }?.0
        // Sans fenêtre de 5 h (abonnement qui ne l'expose pas), la plus utilisée reste le meilleur repère.
        return predicted ?? snapshot.limits.first { $0.kind == .rollingFiveHour } ?? snapshot.mostConstraining
    }
}
