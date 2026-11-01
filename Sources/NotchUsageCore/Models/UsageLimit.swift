import Foundation

/// Type de limite, dans l'ordre d'affichage.
public enum LimitKind: String, Codable, Sendable, Comparable, CaseIterable {
    case rollingFiveHour
    case weeklyAll
    case weeklyModel

    public static func < (lhs: LimitKind, rhs: LimitKind) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Une limite exposée par le service pour ce compte.
public struct UsageLimit: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: LimitKind
    /// Nom tel que fourni par le service, `nil` sauf pour `weeklyModel`.
    public let modelName: String?
    /// 0...100, borné.
    public let utilization: Double
    public let resetsAt: Date?

    public init(id: String, kind: LimitKind, modelName: String?, utilization: Double, resetsAt: Date?) {
        self.id = id
        self.kind = kind
        self.modelName = kind == .weeklyModel ? modelName : nil
        self.utilization = min(100, max(0, utilization.isFinite ? utilization : 0))
        self.resetsAt = resetsAt
    }

    public var isBlocked: Bool { utilization >= 100 }

    /// Clé de libellé, localisée côté app.
    public enum LabelKey: Sendable, Equatable {
        case fiveHour
        case weeklyAll
        case weeklyModel(String)
    }

    public var labelKey: LabelKey {
        switch kind {
        case .rollingFiveHour: return .fiveHour
        case .weeklyAll: return .weeklyAll
        case .weeklyModel: return .weeklyModel(modelName ?? "Model")
        }
    }

    /// Ordre d'affichage : type, puis nom de modèle.
    static func displayOrder(_ a: UsageLimit, _ b: UsageLimit) -> Bool {
        if a.kind != b.kind { return a.kind < b.kind }
        return (a.modelName ?? "") < (b.modelName ?? "")
    }
}
