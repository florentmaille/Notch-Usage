import Foundation

/// Cadence du battement du halo (006, R2) sur le tick de 30 s de l'app : chaque tick au rythme `everyHalfMinute`,
/// un tick sur deux au rythme `everyMinute`. Le rythme fourni est celui lu *avant* le recalcul du tick, pour que
/// le tick qui fait entrer l'état imminent ne batte pas (R3).
public struct BeatCounter: Sendable, Equatable {
    public private(set) var ticks = 0
    public private(set) var beats = 0

    public init() {}

    public mutating func tick(rhythm: NotchSignal.Pulse) {
        ticks += 1
        if rhythm == .everyHalfMinute || (rhythm == .everyMinute && ticks.isMultiple(of: 2)) {
            beats += 1
        }
    }
}
