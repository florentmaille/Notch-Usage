import Foundation
import Testing
@testable import NotchUsageCore

@Suite("AlertSettings Codable")
struct AlertSettingsCodableTests {
    @Test func settingsDefaultsAndRoundTrip() throws {
        let s = AlertSettings()
        #expect(s.enabled && s.warningThreshold == 80 && s.criticalThreshold == 95)
        let decoded = try JSONDecoder().decode(AlertSettings.self, from: try JSONEncoder().encode(s))
        #expect(decoded == s)
    }
}
