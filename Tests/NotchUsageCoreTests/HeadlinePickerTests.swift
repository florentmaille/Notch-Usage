import Foundation
import Testing
@testable import NotchUsageCore

@Suite("HeadlinePicker (008)")
struct HeadlinePickerTests {
    let now = Date.iso("2026-11-01T10:00:00Z")
    let settings = AlertSettings()
    let calm = makeSnapshot([("session", 30), ("weekly_all", 60), ("weekly_scoped:Fable", 20)])

    func pick(_ s: UsageSnapshot, _ forecasts: [String: Forecast] = [:], settings: AlertSettings? = nil) -> String? {
        HeadlinePicker.pick(in: s, forecasts: forecasts, settings: settings ?? self.settings, now: now)?.id
    }

    @Test func nothingAtRiskShowsTheFiveHourWindow() {
        #expect(pick(calm) == "session")
        #expect(pick(calm, ["session": .holdsUntilReset]) == "session")
    }

    @Test func weeklyAboveThresholdWinsOverACalmFiveHourWindow() {
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 97), ("weekly_scoped:Fable", 20)])
        #expect(pick(weekly) == "weekly_all")
        #expect(pick(weekly, ["session": .holdsUntilReset]) == "weekly_all")
        let model = makeSnapshot([("session", 30), ("weekly_all", 40), ("weekly_scoped:Fable", 83)])
        #expect(pick(model) == "weekly_scoped:Fable")
    }

    @Test func imminentForecastWinsOverAWeeklyWarning() {
        let s = makeSnapshot([("session", 70), ("weekly_all", 83)])
        #expect(pick(s, ["session": .blockAt(now.addingTimeInterval(8 * 60))]) == "session")
        // Prévision lointaine (gravité 2) contre seuil critique hebdo (4) : l'hebdo.
        let critical = makeSnapshot([("session", 40), ("weekly_all", 97)])
        #expect(pick(critical, ["session": .blockAt(now.addingTimeInterval(3 * 3600))]) == "weekly_all")
    }

    @Test func weeklyForecastsDoNotDriveTheNotch() {
        // 016 : une prévision hebdo « tient » n'éteint pas le seuil critique, un blocage hebdo ne prend pas l'encoche.
        let critical = makeSnapshot([("session", 30), ("weekly_all", 97)])
        #expect(pick(critical, ["weekly_all": .holdsUntilReset]) == "weekly_all")
        #expect(pick(calm, ["weekly_scoped:Fable": .blockAt(now.addingTimeInterval(8 * 60))]) == "session")
    }

    @Test func tiesGoToTheFiveHourWindow() {
        let s = makeSnapshot([("session", 97), ("weekly_all", 97)])
        #expect(pick(s) == "session")
        #expect(pick(s, ["session": .blockAt(now.addingTimeInterval(8 * 60))]) == "session")
    }

    @Test func aReachedLimitThatBlocksEverythingWins() {
        let blocked = makeSnapshot([("session", 100), ("weekly_all", 97), ("weekly_scoped:Fable", 20)])
        #expect(pick(blocked) == "session")
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 100)])
        #expect(pick(weekly, ["session": .blockAt(now.addingTimeInterval(1800))]) == "weekly_all")
    }

    @Test func aReachedModelLimitOnlyShowsWhenNothingElseThreatens() {
        let fable = makeSnapshot([("session", 30), ("weekly_all", 60), ("weekly_scoped:Fable", 100)])
        #expect(pick(fable) == "weekly_scoped:Fable")
        let warned = makeSnapshot([("session", 30), ("weekly_all", 83), ("weekly_scoped:Fable", 100)])
        #expect(pick(warned) == "weekly_all")
    }

    @Test func disabledThresholdsOnlyLeaveForecastsAndExhaustion() {
        let off = AlertSettings(enabled: false)
        let weekly = makeSnapshot([("session", 30), ("weekly_all", 97)])
        #expect(pick(weekly, settings: off) == "session")
        #expect(pick(weekly, ["session": .blockAt(now.addingTimeInterval(600))], settings: off) == "session")
    }

    @Test func withoutAFiveHourWindowTheMostUsedIsShown() {
        let weekly = makeSnapshot([("weekly_all", 30), ("weekly_scoped:Fable", 50)])
        #expect(pick(weekly) == "weekly_scoped:Fable")
    }
}
