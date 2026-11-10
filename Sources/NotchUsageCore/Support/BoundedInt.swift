import Foundation

extension Double {
    /// Conversion en entier sans plantage : `Int(_:)` s'arrête sur une valeur hors plage ou non finie (date
    /// aberrante dans une réponse ou un événement). Borné à ±10¹² (plus de 30 000 ans en secondes).
    var boundedInt: Int {
        guard isFinite else { return 0 }
        return Int(Swift.min(Swift.max(self, -1e12), 1e12))
    }
}
