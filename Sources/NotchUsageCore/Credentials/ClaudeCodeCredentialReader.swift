import Foundation

/// Jeton lu dans l'entrée Trousseau de Claude Code. Ne contient jamais le refresh token.
public struct ClaudeCodeToken: Sendable, Equatable {
    public let accessToken: String
    public let subscriptionType: SubscriptionType
    public let expiresAt: Date?

    /// Marge de 60 s : un jeton qui expire dans la minute échouerait au relevé.
    public func isExpired(at now: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) < 60
    }
}

public enum ClaudeCodeCredentialReader {
    public static func accessToken(from json: Data) throws(CredentialError) -> ClaudeCodeToken {
        guard let root = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else {
            throw CredentialError.invalidJSON
        }
        guard let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw CredentialError.missingOAuthSection
        }
        return ClaudeCodeToken(
            accessToken: token,
            subscriptionType: SubscriptionType(serviceValue: oauth["subscriptionType"] as? String),
            expiresAt: ResetDateParser.parse(oauth["expiresAt"])
        )
    }
}
