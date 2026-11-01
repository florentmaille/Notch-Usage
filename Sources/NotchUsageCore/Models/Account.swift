import Foundation

public enum ConnectionMethod: String, Codable, Sendable, Equatable {
    case claudeCode
    case browser
}

public enum SubscriptionType: String, Codable, Sendable, Equatable {
    case pro
    case max
    case unsupported

    /// Valeur brute du service (`"pro"`, `"max"`, `"team"`…) → type connu ou `unsupported`.
    public init(serviceValue: String?) {
        switch serviceValue?.lowercased() {
        case "pro": self = .pro
        case "max": self = .max
        default: self = .unsupported
        }
    }
}

public enum AccountStatus: String, Codable, Sendable, Equatable {
    case connected
    case expired
    case disconnected
}

/// Le compte Claude connecté. Un seul à la fois. Ne contient jamais de secret.
public struct Account: Codable, Sendable, Equatable {
    public var connectionMethod: ConnectionMethod
    public var subscriptionType: SubscriptionType
    public var status: AccountStatus
    /// Identifiant de l'entrée Trousseau de l'app, jamais la valeur du secret.
    public var credentialRef: String
    public var connectedAt: Date

    public init(connectionMethod: ConnectionMethod, subscriptionType: SubscriptionType, status: AccountStatus, credentialRef: String, connectedAt: Date) {
        self.connectionMethod = connectionMethod
        self.subscriptionType = subscriptionType
        self.status = status
        self.credentialRef = credentialRef
        self.connectedAt = connectedAt
    }
}
