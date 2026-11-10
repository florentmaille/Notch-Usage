import Foundation

public enum PauseReason: Sendable, Hashable {
    case sleep
    case screenLocked
    case lowPower
}

/// Boucle de rafraîchissement : planification, pause/reprise, états, persistance.
/// Garantie : jamais deux requêtes à moins de `RefreshSettings.minimumInterval`.
public actor RefreshCoordinator {
    public nonisolated let states: AsyncStream<FetchState>
    private let stateContinuation: AsyncStream<FetchState>.Continuation

    private let provider: any UsageProvider
    private var policy: RefreshPolicy
    private let store: any SnapshotStore
    private let clock: any Clock

    public private(set) var state: FetchState = .idle(nil)
    private var loopTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var pauseReasons: Set<PauseReason> = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []
    private var lastRequestAt: Date?
    private var lastDelay: Duration
    private var stopped = false
    /// Délai demandé par `resume`/`refreshNow` pour la prochaine itération (court-circuite le délai planifié).
    private var overrideDelay: Duration?

    /// `pausedFor` : motifs de pause déjà en cours à la création (économie d'énergie au lancement, verrou pendant un
    /// changement de réglage). Sans eux, un coordinateur neuf relevait pendant la pause de l'app.
    public init(provider: any UsageProvider, policy: RefreshPolicy, store: any SnapshotStore, clock: any Clock,
                pausedFor reasons: Set<PauseReason> = []) {
        self.provider = provider
        self.policy = policy
        self.store = store
        self.clock = clock
        self.pauseReasons = reasons
        self.lastDelay = policy.delayAfterSuccess()
        (states, stateContinuation) = AsyncStream.makeStream(of: FetchState.self, bufferingPolicy: .unbounded)
    }

    // MARK: - Cycle de vie

    public func start() {
        guard loopTask == nil, !stopped else { return }
        if let cached = try? store.loadSnapshot() {
            publish(.idle(cached))
            // Cache récent (relevé de validation, redémarrage après réglage) : il compte comme
            // dernière requête, le premier relevé attend l'échéance normale (FR-009).
            let age = clock.now.timeIntervalSince(cached.fetchedAt)
            let interval = policy.delayAfterSuccess().timeInterval
            if age >= 0, age < interval {
                lastRequestAt = cached.fetchedAt
                overrideDelay = .seconds(interval - age)
            }
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

    /// Nouvel intervalle (curseur des réglages) sans recréer le coordinateur : dernière requête, backoff et pauses
    /// restent en place, donc aucune rafale et jamais deux requêtes à moins de `minimumInterval`.
    public func update(policy: RefreshPolicy) {
        guard policy != self.policy else { return }
        self.policy = policy
        // Seul un sommeil d'après succès se replanifie : nouvelle échéance = dernier relevé + nouvel intervalle.
        // Relevé en vol, backoff d'erreur ou pause : le prochain délai lira la nouvelle politique.
        guard sleepTask != nil, case .idle = state, let last = lastRequestAt else { return }
        let interval = policy.delayAfterSuccess().timeInterval
        let remaining = interval - clock.now.timeIntervalSince(last)
        overrideDelay = .seconds(min(interval, max(0, remaining)))
        sleepTask?.cancel()
    }

    // MARK: - Boucle

    private func requestSoon() {
        // Relevé en vol : il suffit, et un délai posé maintenant s'ajouterait après le sommeil normal.
        if case .loading = state, !stopped { return }
        let gap = lastRequestAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let minimum = RefreshSettings.minimumInterval.timeInterval
        // Écart négatif : l'horloge a reculé, on ne fait pas attendre le temps reculé en plus.
        overrideDelay = gap < 0 || gap >= minimum ? .zero : .seconds(minimum - gap)
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
            // Arrêt (déconnexion, changement de compte) pendant la requête : le relevé n'est ni publié ni réécrit
            // sur disque après l'effacement.
            guard !stopped else { return .terminal }
            try? store.saveSnapshot(snapshot)
            publish(.idle(snapshot))
            return .scheduled(policy.delayAfterSuccess())
        } catch {
            guard !stopped else { return .terminal }
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
