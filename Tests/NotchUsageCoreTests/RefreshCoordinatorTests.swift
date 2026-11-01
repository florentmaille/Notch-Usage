import Foundation
import Testing
@testable import NotchUsageCore

@Suite("RefreshCoordinator", .serialized)
struct RefreshCoordinatorTests {
    let snapA = makeSnapshot([("session", 10)])
    let snapB = makeSnapshot([("session", 20)])

    struct Harness {
        let coordinator: RefreshCoordinator
        let provider: StubUsageProvider
        let store: MemorySnapshotStore
        let clock: TestClock
        let collector: StateCollector
    }

    /// Collecte les états émis.
    actor StateCollector {
        private(set) var states: [FetchState] = []
        func append(_ s: FetchState) { states.append(s) }
        /// Le consommateur du stream tourne en concurrence : on attend la condition (borné).
        func waitUntil(_ predicate: @Sendable ([FetchState]) -> Bool) async -> [FetchState] {
            for _ in 0..<200 {
                if predicate(states) { return states }
                await Task.yield()
            }
            return states
        }
    }

    func makeHarness(_ results: [Result<UsageSnapshot, FetchError>], cached: UsageSnapshot? = nil, interval: Duration = .seconds(180)) -> Harness {
        let provider = StubUsageProvider(results)
        let store = MemorySnapshotStore(snapshot: cached)
        let clock = TestClock()
        let c = RefreshCoordinator(provider: provider, policy: RefreshPolicy(settings: RefreshSettings(interval: interval)), store: store, clock: clock)
        let collector = StateCollector()
        let stream = c.states
        Task { for await s in stream { await collector.append(s) } }
        return Harness(coordinator: c, provider: provider, store: store, clock: clock, collector: collector)
    }

    @Test func startEmitsLoadingThenIdle() async throws {
        let h = makeHarness([.success(snapA)])
        await h.coordinator.start()
        await h.clock.settle()
        let states = await h.collector.waitUntil { $0.last == .idle(self.snapA) }
        #expect(states.contains(.loading(previous: nil)))
        #expect(states.last == .idle(snapA))
        #expect(h.store.snapshot == snapA)
        #expect(await h.provider.calls == 1)
    }

    @Test func cachedSnapshotShownBeforeFirstFetch() async throws {
        let h = makeHarness([.success(snapB)], cached: snapA)
        await h.coordinator.start()
        await h.clock.settle()
        let states = await h.collector.waitUntil { $0.last == .idle(self.snapB) }
        #expect(states.first == .idle(snapA))
        #expect(states.contains(.loading(previous: snapA)))
        #expect(states.last == .idle(snapB))
    }

    @Test func failureKeepsPreviousSnapshotAndBacksOff() async throws {
        let h = makeHarness([.success(snapA), .failure(.server(503)), .success(snapB)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.clock.advance(by: 180)
        #expect(await h.coordinator.state == .failed(.server(503), previous: snapA))
        #expect(await h.provider.calls == 2)
        // Backoff ×2 : rien à +180 s, nouvelle requête à +360 s
        await h.clock.advance(by: 180)
        #expect(await h.provider.calls == 2)
        await h.clock.advance(by: 180)
        #expect(await h.provider.calls == 3)
        #expect(await h.coordinator.state == .idle(snapB))
    }

    @Test func pauseStopsRequests() async throws {
        let h = makeHarness([.success(snapA)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.coordinator.pause(reason: .sleep)
        await h.clock.advance(by: 3600)
        #expect(await h.provider.calls == 1)
    }

    @Test func resumeAfterLongPauseFetchesImmediately() async throws {
        let h = makeHarness([.success(snapA), .success(snapB)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.coordinator.pause(reason: .screenLocked)
        await h.clock.advance(by: 600)
        await h.coordinator.resume()
        await h.clock.settle()
        #expect(await h.provider.calls == 2)
        #expect(await h.coordinator.state == .idle(snapB))
    }

    @Test func resumeThenRefreshNowWithinMinimumGapIsCoalesced() async throws {
        let h = makeHarness([.success(snapA), .success(snapB)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.coordinator.pause(reason: .sleep)
        await h.clock.advance(by: 600)
        await h.coordinator.resume()      // → requête 2 immédiate
        await h.clock.settle()
        await h.clock.advance(by: 10)
        await h.coordinator.refreshNow()  // < 60 s après : différée, pas de 3e requête tout de suite
        await h.clock.settle()
        #expect(await h.provider.calls == 2)
        await h.clock.advance(by: 50)     // = 60 s après la requête 2
        #expect(await h.provider.calls == 3)
    }

    @Test func refreshNowAfterGapFetchesImmediately() async throws {
        let h = makeHarness([.success(snapA), .success(snapB)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.clock.advance(by: 90)
        await h.coordinator.refreshNow()
        await h.clock.settle()
        #expect(await h.provider.calls == 2)
    }

    @Test func unauthorizedStopsLoop() async throws {
        let h = makeHarness([.success(snapA), .failure(.unauthorized)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.clock.advance(by: 180)
        #expect(await h.coordinator.state == .reauthRequired(previous: snapA))
        await h.clock.advance(by: 3600)
        #expect(await h.provider.calls == 2)
        #expect(await h.clock.pendingSleepers == 0)
    }

    @Test func unsupportedStopsLoop() async throws {
        let h = makeHarness([.failure(.unsupported)])
        await h.coordinator.start()
        await h.clock.settle()
        #expect(await h.coordinator.state == .unsupported)
        await h.clock.advance(by: 3600)
        #expect(await h.provider.calls == 1)
    }

    @Test func stopEndsLoop() async throws {
        let h = makeHarness([.success(snapA)])
        await h.coordinator.start()
        await h.clock.settle()
        await h.coordinator.stop()
        await h.clock.advance(by: 3600)
        #expect(await h.provider.calls == 1)
    }
}
