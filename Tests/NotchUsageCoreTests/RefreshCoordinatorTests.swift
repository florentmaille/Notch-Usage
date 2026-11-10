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

    func makeHarness(_ results: [Result<UsageSnapshot, FetchError>], cached: UsageSnapshot? = nil, interval: Duration = .seconds(180),
                     pausedFor reasons: Set<PauseReason> = []) -> Harness {
        let provider = StubUsageProvider(results)
        let store = MemorySnapshotStore(snapshot: cached)
        let clock = TestClock()
        let c = RefreshCoordinator(provider: provider, policy: RefreshPolicy(settings: RefreshSettings(interval: interval)), store: store, clock: clock,
                                   pausedFor: reasons)
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
        let old = makeSnapshot([("session", 10)], fetchedAt: .iso("2026-11-01T09:00:00Z"))
        let h = makeHarness([.success(snapB)], cached: old)
        await h.coordinator.start()
        await h.clock.settle()
        let states = await h.collector.waitUntil { $0.last == .idle(self.snapB) }
        #expect(states.first == .idle(old))
        #expect(states.contains(.loading(previous: old)))
        #expect(states.last == .idle(snapB))
    }

    /// FR-009 : un cache plus récent que l'intervalle (ex. relevé de validation à la connexion)
    /// ne déclenche pas de requête immédiate ; le premier relevé tombe à l'échéance normale.
    @Test func freshCacheDefersFirstFetch() async throws {
        let recent = makeSnapshot([("session", 10)], fetchedAt: .iso("2026-11-01T09:59:30Z"))
        let h = makeHarness([.success(snapB)], cached: recent)
        await h.coordinator.start()
        await h.clock.settle()
        #expect(await h.provider.calls == 0)
        #expect(await h.coordinator.state == .idle(recent))
        await h.clock.advance(by: 149)
        #expect(await h.provider.calls == 0)
        await h.clock.advance(by: 1)
        #expect(await h.provider.calls == 1)
    }

    @Test func refreshNowRespectsGapSinceFreshCache() async throws {
        let recent = makeSnapshot([("session", 10)], fetchedAt: .iso("2026-11-01T09:59:30Z"))
        let h = makeHarness([.success(snapB)], cached: recent)
        await h.coordinator.start()
        await h.clock.settle()
        await h.coordinator.refreshNow()
        await h.clock.settle()
        #expect(await h.provider.calls == 0)
        await h.clock.advance(by: 30)
        #expect(await h.provider.calls == 1)
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

    /// Un coordinateur créé pendant une pause (économie d'énergie au lancement, verrou pendant un changement de
    /// réglage) montre le cache mais ne relève rien avant la reprise, puis relève aussitôt.
    @Test func createdPausedWaitsForResume() async throws {
        let old = makeSnapshot([("session", 10)], fetchedAt: .iso("2026-11-01T09:00:00Z"))
        let h = makeHarness([.success(snapB)], cached: old, pausedFor: [.lowPower, .screenLocked])
        await h.coordinator.start()
        await h.clock.settle()
        #expect(await h.coordinator.isPaused)
        #expect(await h.coordinator.state == .idle(old))
        #expect(await h.provider.calls == 0)
        // Un motif levé sur deux : toujours en pause.
        await h.coordinator.resume(reason: .screenLocked)
        await h.clock.settle()
        #expect(await h.provider.calls == 0)
        await h.coordinator.resume(reason: .lowPower)
        await h.clock.settle()
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

@Suite("RefreshCoordinator alerts", .serialized)
struct RefreshCoordinatorAlertTests {
    @Test func alertHookRunsOnEachSnapshotAndPersistsLedger() async throws {
        let provider = StubUsageProvider([.success(makeSnapshot([("session", 50)])), .success(makeSnapshot([("session", 85)])), .success(makeSnapshot([("session", 86)]))])
        let store = MemorySnapshotStore()
        let clock = TestClock()
        let evaluator = AlertEvaluator()
        let settings = AlertSettings()
        let c = RefreshCoordinator(provider: provider, policy: RefreshPolicy(settings: RefreshSettings()), store: store, clock: clock,
                                   alertHook: { snapshot, ledger in evaluator.evaluate(snapshot, settings: settings, ledger: ledger ?? AlertLedger()) })
        actor Collector { var events: [AlertEvent] = []; func add(_ e: AlertEvent) { events.append(e) } }
        let collector = Collector()
        let stream = c.alerts
        Task { for await e in stream { await collector.add(e) } }
        await c.start()
        await clock.settle()
        await clock.advance(by: 180)
        await clock.advance(by: 180)
        for _ in 0..<50 { if await collector.events.count == 1 { break }; await Task.yield() }
        #expect(await collector.events == [AlertEvent(limitID: "session", level: .warning)])
        #expect(store.ledger?.entries["session"]?.firedLevels == [.warning])
        #expect(await provider.calls == 3)
    }
}
