import Foundation

public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration, tolerance: Duration) async throws
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
    public func sleep(for duration: Duration, tolerance: Duration) async throws {
        try await Task.sleep(for: duration, tolerance: tolerance)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let c = components
        return TimeInterval(c.seconds) + TimeInterval(c.attoseconds) / 1e18
    }
}
