import Foundation

/// Format du cookie `sessionKey` de claude.ai : `sk-ant-sid` + version à deux chiffres + `-`.
/// La version change (sid01, puis sid02 relevé le 2026-11-02) : elle n'est pas figée.
public enum SessionKeyFormat {
    public static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isValid(_ raw: String) -> Bool {
        let key = normalized(raw)
        guard key.hasPrefix("sk-ant-sid") else { return false }
        let rest = key.dropFirst("sk-ant-sid".count)
        guard rest.count > 20, rest.prefix(2).allSatisfy(\.isNumber), rest.dropFirst(2).first == "-" else { return false }
        return true
    }
}
