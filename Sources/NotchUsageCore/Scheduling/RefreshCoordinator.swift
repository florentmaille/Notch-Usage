import Foundation

public enum PauseReason: Sendable, Equatable {
    case sleep
    case screenLocked
    case lowPower
}

/// Boucle de rafraîchissement : planification, pause/reprise, états, persistance.
/// Garantie : jamais deux requêtes à moins de `RefreshSettings.minimumInterval`.
public actor RefreshCoordinator {
    public nonisolated let states: AsyncStream<FetchState>
    public nonisolated let alerts: AsyncStream<AlertEvent>
    private let stateContinuation: AsyncStream<FetchState>.Continuation
    private let alertContinuation: AsyncStream<AlertEvent>.Continuation

    private let provider: any UsageProvider
    private let policy: RefreshPolicy
    private let store: any SnapshotStore
    private let clock: any Clock
    /// Hook d'évaluation des alertes, branché par l'app (US2). Retourne les événements à émettre.
    private let alertHook: (@Sendable (UsageSnapshot, AlertLedger?) -> (AlertLedger, [AlertEvent]))?

    public private(set) var state: FetchState = .idle(nil)
    private var ledger: AlertLedger?
    private var loopTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var pauseReasons: Set<PauseReason> = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []
    private var lastRequestAt: Date?
    private var lastDelay: Duration
    private var stopped = false
    /// Délai demandé par `resume`/`refreshNow` pour la prochaine itération (court-circuite le délai planifié).
    private var overrideDelay: Duration?

    public init(provider: any UsageProvider, policy: RefreshPolicy, store: any SnapshotStore, clock: any Clock,
                alertHook: (@Sendable (UsageSnapshot, AlertLedger?) -> (AlertLedger, [AlertEvent]))? = nil) {
        self.provider = provider
        self.policy = policy
        self.store = store
        self.clock = clock
        self.alertHook = alertHook
        self.lastDelay = policy.delayAfterSuccess()
        (states, stateContinuation) = AsyncStream.makeStream(of: FetchState.self, bufferingPolicy: .unbounded)
        (alerts, alertContinuation) = AsyncStream.makeStream(of: AlertEvent.self, bufferingPolicy: .unbounded)
    }

    // MARK: - Cycle de vie

    public func start() {
        guard loopTask == nil, !stopped else { return }
        ledger = try? store.loadLedger()
        if let cached = try? store.loadSnapshot() {
            publish(.idle(cached))
        }
        loopTask = Task { [weak self] in await self?.runLoop() }
    }

    public func stop() {
        stopped = true
        sleepTask?.cancel()
        loopTask?.cancel()
        loopTask = nil
        resumeWaiters.forEach { $0.resume() }
        resumeWaiters.removeAll()
        stateContinuation.finish()
        alertContinuation.finish()
    }

    public func pause(reason: PauseReason) {
        pauseReasons.insert(reason)
    }

    /// Relevé immédiat si plus d'un intervalle minimal s'est écoulé, sinon au terme de ce délai.
    public func resume(reason: PauseReason? = nil) {
        if let reason { pauseReasons.remove(reason) } else { pauseReasons.removeAll() }
        guard pauseReasons.isEmpty else { return }
        requestSoon()
        resumeWaiters.forEach { $0.resume() }
        resumeWaiters.removeAll()
    }

    /// Action utilisateur : même garantie de 60 s entre deux requêtes.
    public func refreshNow() {
        guard pauseReasons.isEmpty else { return }
        requestSoon()
    }

    public var isPaused: Bool { !pauseReasons.isEmpty }

    // MARK: - Boucle

    private func requestSoon() {
        let gap = lastRequestAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let minimum = RefreshSettings.minimumInterval.timeInterval
        overrideDelay = gap >= minimum ? .zero : .seconds(minimum - gap)
        sleepTask?.cancel()
    }

    private func runLoop() async {
        while !stopped, !Task.isCancelled {
            if !pauseReasons.isEmpty {
                await waitUntilResumed()
                if stopped { break }
            }
            if let delay = overrideDelay {
                overrideDelay = nil
                if delay > .zero { await interruptibleSleep(delay); continue }
            }
            let outcome = await fetchOnce()
            if stopped { break }
            switch outcome {
            case .scheduled(let delay):
                lastDelay = delay
                await interruptibleSleep(delay)
            case .terminal:
                return
            }
        }
    }

    private enum Outcome { case scheduled(Duration), terminal }

    private func fetchOnce() async -> Outcome {
        let previous = state.snapshot
        publish(.loading(previous: previous))
        lastRequestAt = clock.now
        do {
            let snapshot = try await provider.fetch()
            try? store.saveSnapshot(snapshot)
            publish(.idle(snapshot))
            if let alertHook {
                let (newLedger, events) = alertHook(snapshot, ledger)
                ledger = newLedger
                try? store.saveLedger(newLedger)
                events.forEach { alertContinuation.yield($0) }
            }
            return .scheduled(policy.delayAfterSuccess())
        } catch {
            switch error {
            case .unauthorized, .credentialsUnavailable:
                publish(.reauthRequired(previous: previous))
            case .unsupported:
                publish(.unsupported)
            default:
                publish(.failed(error, previous: previous))
            }
            if let delay = policy.delay(afterFailure: error, previous: lastDelay) {
                return .scheduled(delay)
            }
            return .terminal
        }
    }

    private func interruptibleSleep(_ delay: Duration) async {
        let clock = self.clock
        let task = Task { _ = try? await clock.sleep(for: delay, tolerance: delay / 10) }
        sleepTask = task
        await task.value
        sleepTask = nil
    }

    private func waitUntilResumed() async {
        await withCheckedContinuation { c in resumeWaiters.append(c) }
    }

    private func publish(_ s: FetchState) {
        state = s
        stateContinuation.yield(s)
    }
}
