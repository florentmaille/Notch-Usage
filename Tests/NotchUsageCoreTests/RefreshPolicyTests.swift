import Foundation
import Testing
@testable import NotchUsageCore

@Suite("RefreshPolicy")
struct RefreshPolicyTests {
    @Test func successUsesInterval() {
        let p = RefreshPolicy(settings: RefreshSettings(interval: .seconds(180)))
        #expect(p.delayAfterSuccess() == .seconds(180))
    }

    @Test func intervalClampedToFloorAndCeiling() {
        #expect(RefreshPolicy(settings: RefreshSettings(interval: .seconds(10))).delayAfterSuccess() == .seconds(60))
        #expect(RefreshPolicy(settings: RefreshSettings(interval: .seconds(3600))).delayAfterSuccess() == .seconds(900))
        #expect(RefreshSettings().interval == .seconds(180))
    }

    @Test func rateLimitedWithoutRetryAfterDoubles() {
        let p = RefreshPolicy(settings: RefreshSettings(interval: .seconds(180)))
        #expect(p.delay(afterFailure: .rateLimited(retryAfter: nil), previous: .seconds(180)) == .seconds(360))
        #expect(p.delay(afterFailure: .rateLimited(retryAfter: nil), previous: .seconds(360)) == .seconds(720))
    }

    @Test func rateLimitedWithRetryAfterHonoursIt() {
        let p = RefreshPolicy(settings: RefreshSettings(interval: .seconds(180)))
        #expect(p.delay(afterFailure: .rateLimited(retryAfter: .seconds(471)), previous: .seconds(180)) == .seconds(471))
        // Retry-After trop court → plancher 60 s ; trop long → plafond 15 min
        #expect(p.delay(afterFailure: .rateLimited(retryAfter: .seconds(5)), previous: .seconds(180)) == .seconds(60))
        #expect(p.delay(afterFailure: .rateLimited(retryAfter: .seconds(7200)), previous: .seconds(180)) == .seconds(900))
    }

    @Test func backoffCapped() {
        let p = RefreshPolicy(settings: RefreshSettings(interval: .seconds(180)))
        #expect(p.delay(afterFailure: .server(503), previous: .seconds(720)) == .seconds(900))
        #expect(p.delay(afterFailure: .server(503), previous: .seconds(900)) == .seconds(900))
    }

    @Test func serverAndNetworkDouble() {
        let p = RefreshPolicy(settings: RefreshSettings(interval: .seconds(120)))
        #expect(p.delay(afterFailure: .server(500), previous: .seconds(120)) == .seconds(240))
        #expect(p.delay(afterFailure: .network(.notConnectedToInternet), previous: .seconds(120)) == .seconds(240))
        #expect(p.delay(afterFailure: .malformed, previous: .seconds(120)) == .seconds(240))
    }

    @Test func terminalErrorsStopScheduling() {
        let p = RefreshPolicy(settings: RefreshSettings())
        #expect(p.delay(afterFailure: .unauthorized, previous: .seconds(180)) == nil)
        #expect(p.delay(afterFailure: .credentialsUnavailable, previous: .seconds(180)) == nil)
    }

    /// Sans limite exploitable, la boucle continue à cadence lente : une heure, quel que soit le délai précédent.
    @Test func unsupportedRetriesHourly() {
        let p = RefreshPolicy(settings: RefreshSettings())
        #expect(p.delay(afterFailure: .unsupported, previous: .seconds(180)) == .seconds(3600))
        #expect(p.delay(afterFailure: .unsupported, previous: .seconds(900)) == .seconds(3600))
        #expect(!FetchError.unsupported.isTerminal && FetchError.unauthorized.isTerminal)
    }
}
