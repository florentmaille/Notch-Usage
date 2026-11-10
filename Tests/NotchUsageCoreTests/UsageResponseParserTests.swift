import Foundation
import Testing
@testable import NotchUsageCore

@Suite("UsageResponseParser")
struct UsageResponseParserTests {
    @Test func limitsFormWithFable() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-limits-fable.json"))
        #expect(limits.map(\.kind) == [.rollingFiveHour, .weeklyAll, .weeklyModel])
        #expect(limits.map(\.id) == ["session", "weekly_all", "weekly_scoped:Fable"])
        #expect(limits[0].utilization == 27.5)
        #expect(limits[0].resetsAt == .iso("2026-11-01T14:00:00Z"))
        #expect(limits[1].utilization == 12)
        #expect(limits[2].modelName == "Fable")
        #expect(limits[2].utilization == 44)
        #expect(limits[0].modelName == nil)
    }

    @Test func twoModelsSortedByNameAndUnknownKindIgnored() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-limits-two-models.json"))
        #expect(limits.map(\.id) == ["session", "weekly_all", "weekly_scoped:Fable", "weekly_scoped:Opus"])
    }

    @Test func legacyForm() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-legacy.json"))
        #expect(limits.map(\.id) == ["session", "weekly_all", "weekly_scoped:Sonnet"])
        #expect(limits[0].utilization == 8)
        #expect(limits[2].modelName == "Sonnet")
        #expect(limits[2].utilization == 1)
        // seven_day_opus: null → absent ; seven_day_cowork → ignoré (pas un modèle)
        #expect(!limits.contains { $0.id.contains("opus") || $0.id.contains("cowork") })
    }

    @Test func bothFormsNoDuplicates() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-both-forms.json"))
        #expect(limits.count == 2)
        #expect(limits[0].utilization == 27.5)
        #expect(limits[1].utilization == 12)
    }

    @Test func fractionDetectedAndScaled() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-fraction.json"))
        #expect(limits.map(\.utilization) == [8, 70])
    }

    /// Juste après un reset, toutes les limites valent 0 ou 1 % : `percent` est un pourcentage, jamais une fraction.
    /// Multipliées par 100, elles annonçaient une limite atteinte en début de semaine.
    @Test func lowPercentagesAreNotMistakenForFractions() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-limits-low.json"))
        #expect(limits.map(\.id) == ["session", "weekly_all", "weekly_scoped:Fable"])
        #expect(limits.map(\.utilization) == [0.5, 1, 0])
    }

    /// Forme legacy : des entiers 0 et 1 sont des pourcentages ; seule une valeur strictement entre 0 et 1 trahit
    /// une fraction.
    @Test func legacyIntegersAtOnePercentAreNotScaled() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-legacy-low.json"))
        #expect(limits.map(\.utilization) == [1, 0])
    }

    @Test func valuesClamped() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-overflow.json"))
        #expect(limits.map(\.utilization) == [100, 0])
    }

    @Test func epochResetDates() throws {
        let limits = try UsageResponseParser.parse(Fixture.data("usage-epoch-ms.json"))
        #expect(limits[0].resetsAt == Date(timeIntervalSince1970: 1_762_005_600))
        #expect(limits[1].resetsAt == Date(timeIntervalSince1970: 1_762_387_200))
    }

    @Test func noLimits() {
        #expect(throws: ParseError.noLimits) {
            try UsageResponseParser.parse(Fixture.data("usage-no-limits.json"))
        }
    }

    @Test func malformed() {
        #expect(throws: ParseError.invalidJSON) {
            try UsageResponseParser.parse(Fixture.data("usage-malformed.json"))
        }
    }

    @Test func htmlIsInvalidJSON() {
        #expect(throws: ParseError.invalidJSON) {
            try UsageResponseParser.parse(Fixture.data("usage-cloudflare.html"))
        }
    }
}
