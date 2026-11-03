import Foundation

/// Format du cookie `sessionKey` de claude.ai : `sk-ant-sid` + version à deux chiffres + `-`.
/// La version change (sid01, puis sid02 relevé le 2026-11-02) : elle n'est pas figée.
public enum SessionKeyFormat {
    public static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Préfixe, version, puis un corps d'au moins 20 caractères d'URL sûrs : une valeur contenant `;`, un espace
    /// ou un retour à la ligne ne doit jamais atteindre l'en-tête `Cookie` (007).
    public static func isValid(_ raw: String) -> Bool {
        let key = normalized(raw)
        guard key.hasPrefix("sk-ant-sid") else { return false }
        let rest = key.dropFirst("sk-ant-sid".count)
        guard rest.count > 20, rest.prefix(2).allSatisfy(\.isNumber), rest.dropFirst(2).first == "-" else { return false }
        let body = rest.dropFirst(3)
        return body.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }
}
