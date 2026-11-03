import Testing
@testable import NotchUsageCore

@Suite("BeatCounter (006, 009)")
struct BeatCounterTests {
    @Test func halfMinuteBeatsEveryTick() {
        var c = BeatCounter()
        for _ in 0..<4 { c.tick(rhythm: .everyHalfMinute) }
        #expect(c.beats == 4 && c.ticks == 4)
    }

    @Test func minuteBeatsEveryOtherTick() {
        var c = BeatCounter()
        var beats: [Int] = []
        for _ in 0..<4 { c.tick(rhythm: .everyMinute); beats.append(c.beats) }
        #expect(beats == [0, 1, 1, 2])
    }

    @Test func noRhythmNeverBeatsButKeepsCounting() {
        var c = BeatCounter()
        c.tick(rhythm: .none); c.tick(rhythm: .none); c.tick(rhythm: .everyMinute)
        #expect(c.beats == 0 && c.ticks == 3)
        c.tick(rhythm: .everyMinute)
        #expect(c.beats == 1)
    }
}
