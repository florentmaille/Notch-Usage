import Foundation
import Testing
@testable import NotchUsageCore

@Suite("FetchState affichage")
struct FetchStateTests {
    let snap = makeSnapshot([("session", 40)])

    /// Scénario 8 : hors ligne, chaque nouvelle tentative durait 30 s en « loading » et masquait le bandeau.
    @Test func retryAfterFailureKeepsFailure() {
        let failed = FetchState.failed(.network(.timedOut), previous: snap)
        #expect(failed.displayed(next: .loading(previous: snap)) == failed)
    }

    @Test func resultAfterRetryReplacesFailure() {
        let failed = FetchState.failed(.network(.timedOut), previous: snap)
        #expect(failed.displayed(next: .idle(snap)) == .idle(snap))
        #expect(failed.displayed(next: .reauthRequired(previous: snap)) == .reauthRequired(previous: snap))
    }

    @Test func loadingAfterSuccessIsShown() {
        #expect(FetchState.idle(snap).displayed(next: .loading(previous: snap)) == .loading(previous: snap))
    }
}
