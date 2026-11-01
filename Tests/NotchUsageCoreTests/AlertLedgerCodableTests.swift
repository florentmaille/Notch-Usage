import Foundation
import Testing
@testable import NotchUsageCore

@Suite("AlertLedger & AlertSettings Codable")
struct AlertLedgerCodableTests {
    @Test func ledgerRoundTrip() throws {
        let ledger = AlertLedger(entries: [
            "session": .init(periodKey: .iso("2026-11-01T14:00:00Z"), firedLevels: [.warning, .critical]),
            "weekly_scoped:Fable": .init(periodKey: nil, firedLevels: []),
        ])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AlertLedger.self, from: try encoder.encode(ledger))
        #expect(decoded == ledger)
    }

    @Test func settingsDefaultsAndRoundTrip() throws {
        let s = AlertSettings()
        #expect(s.enabled && s.warningThreshold == 80 && s.criticalThreshold == 95)
        let decoded = try JSONDecoder().decode(AlertSettings.self, from: try JSONEncoder().encode(s))
        #expect(decoded == s)
    }
}
