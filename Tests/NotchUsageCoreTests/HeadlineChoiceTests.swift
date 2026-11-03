import Foundation
import Testing
@testable import NotchUsageCore

@Suite("HeadlineChoice")
struct HeadlineChoiceTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let snap = makeSnapshot([("session", 30), ("weekly_all", 60), ("weekly_scoped:Fable", 20)])

    @Test func automaticShowsTheFiveHourWindowWhenNothingIsAtRisk() {
        #expect(HeadlineChoice.automatic.pick(in: snap, forecasts: [:])?.id == "session")
        let holds: [String: Forecast] = ["session": .holdsUntilReset]
        #expect(HeadlineChoice.automatic.pick(in: snap, forecasts: holds)?.id == "session")
    }

    @Test func automaticShowsAReachedModelLimit() {
        let fable = makeSnapshot([("session", 30), ("weekly_all", 60), ("weekly_scoped:Fable", 100)])
        #expect(HeadlineChoice.automatic.pick(in: fable, forecasts: [:])?.id == "weekly_scoped:Fable")
    }

    @Test func automaticFallsBackToTheMostUsedWithoutAFiveHourWindow() {
        let weekly = makeSnapshot([("weekly_all", 30), ("weekly_scoped:Fable", 50)])
        #expect(HeadlineChoice.automatic.pick(in: weekly, forecasts: [:])?.id == "weekly_scoped:Fable")
    }

    @Test func chosenLimitIsShownEvenWhenAnotherIsHigher() {
        #expect(HeadlineChoice.limit("weekly_all").pick(in: snap, forecasts: [:])?.id == "weekly_all")
        #expect(HeadlineChoice.limit("weekly_scoped:Fable").pick(in: snap, forecasts: [:])?.id == "weekly_scoped:Fable")
    }

    @Test func chosenLimitWinsOverAPredictedBlock() {
        let block: [String: Forecast] = ["session": .blockAt(now.addingTimeInterval(1800))]
        #expect(HeadlineChoice.limit("weekly_all").pick(in: snap, forecasts: block)?.id == "weekly_all")
    }

    @Test func missingChoiceFallsBackToAutomatic() {
        #expect(HeadlineChoice.limit("weekly_scoped:Sonnet").pick(in: snap, forecasts: [:])?.id == "session")
    }

    @Test func reachedLimitThatBlocksEverythingOverridesTheChoice() {
        let blocked = makeSnapshot([("session", 100), ("weekly_all", 40), ("weekly_scoped:Fable", 20)])
        #expect(HeadlineChoice.limit("weekly_scoped:Fable").pick(in: blocked, forecasts: [:])?.id == "session")
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 100)])
        let block: [String: Forecast] = ["session": .blockAt(now.addingTimeInterval(1800))]
        #expect(HeadlineChoice.automatic.pick(in: weekly, forecasts: block)?.id == "weekly_all")
    }

    @Test func reachedModelLimitDoesNotOverrideTheChoice() {
        let fable = makeSnapshot([("session", 30), ("weekly_scoped:Fable", 100)])
        #expect(HeadlineChoice.limit("session").pick(in: fable, forecasts: [:])?.id == "session")
    }

    @Test func storedValueRoundTrips() {
        #expect(HeadlineChoice(storedValue: nil) == .automatic)
        #expect(HeadlineChoice(storedValue: "") == .automatic)
        #expect(HeadlineChoice(storedValue: "weekly_scoped:Fable") == .limit("weekly_scoped:Fable"))
        #expect(HeadlineChoice.limit("weekly_all").storedValue == "weekly_all")
        #expect(HeadlineChoice.automatic.storedValue == "")
    }
}
