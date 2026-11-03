import Foundation

public struct RefreshSettings: Codable, Sendable, Equatable {
    public static let minimumInterval: Duration = .seconds(60)
    public static let maximumInterval: Duration = .seconds(15 * 60)
    public static let defaultInterval: Duration = .seconds(180)

    /// Borné à 60 s ... 15 min (FR-007).
    public var interval: Duration {
        didSet { interval = Self.clamp(interval) }
    }

    public init(interval: Duration = RefreshSettings.defaultInterval) {
        self.interval = Self.clamp(interval)
    }

    static func clamp(_ d: Duration) -> Duration {
        min(Self.maximumInterval, max(Self.minimumInterval, d))
    }
}
