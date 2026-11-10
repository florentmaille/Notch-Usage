import Foundation
@testable import NotchUsageCore

/// Client HTTP factice : enregistre les requêtes et rejoue des réponses dans l'ordre.
actor StubHTTPClient: HTTPClient {
    private(set) var requests: [URLRequest] = []
    private var queue: [Result<HTTPResponse, Error>]

    init(_ responses: [Result<HTTPResponse, Error>]) { queue = responses }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !queue.isEmpty else { fatalError("StubHTTPClient : plus de réponse en file") }
        return try queue.removeFirst().get()
    }

    func lastRequest() -> URLRequest? { requests.last }
}

extension HTTPResponse {
    static func ok(_ body: Data, contentType: String = "application/json", headers: [String: String] = [:]) -> HTTPResponse {
        var h = headers
        h["content-type"] = contentType
        return HTTPResponse(status: 200, headers: h, body: body)
    }
    static func status(_ code: Int, body: Data = Data(), headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: code, headers: headers, body: body)
    }
}

/// Magasin d'identifiants en mémoire.
final class MemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [CredentialKey: String]
    init(_ values: [CredentialKey: String] = [:]) { self.values = values }
    func read(_ key: CredentialKey) throws -> String? { lock.withLock { values[key] } }
    func write(_ value: String, for key: CredentialKey) throws { lock.withLock { values[key] = value } }
    func delete(_ key: CredentialKey) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// Persistance en mémoire du relevé et du registre d'alertes.
final class MemorySnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    var snapshot: UsageSnapshot?
    var ledger: AlertLedger?
    var history: UsageHistory?
    var hourly: HourlyHistory?
    private(set) var wiped = false
    init(snapshot: UsageSnapshot? = nil) { self.snapshot = snapshot }
    func loadSnapshot() throws -> UsageSnapshot? { lock.withLock { snapshot } }
    func saveSnapshot(_ s: UsageSnapshot) throws { lock.withLock { snapshot = s } }
    func loadLedger() throws -> AlertLedger? { lock.withLock { ledger } }
    func saveLedger(_ l: AlertLedger) throws { lock.withLock { ledger = l } }
    func loadHistory() throws -> UsageHistory? { lock.withLock { history } }
    func saveHistory(_ h: UsageHistory) throws { lock.withLock { history = h } }
    func loadHourlyHistory() throws -> HourlyHistory? { lock.withLock { hourly } }
    func saveHourlyHistory(_ h: HourlyHistory) throws { lock.withLock { hourly = h } }
    func wipe() throws { lock.withLock { snapshot = nil; ledger = nil; history = nil; hourly = nil; wiped = true } }
}

/// Fournisseur factice : séquence de résultats, compte les appels.
actor StubUsageProvider: UsageProvider {
    nonisolated let method: ConnectionMethod = .claudeCode
    private var results: [Result<UsageSnapshot, FetchError>]
    private(set) var calls = 0
    init(_ results: [Result<UsageSnapshot, FetchError>]) { self.results = results }
    func fetch() async throws(FetchError) -> UsageSnapshot {
        calls += 1
        let r = results.isEmpty ? results.last ?? .failure(.emptyBody) : results.removeFirst()
        if results.isEmpty, case .success = r { results = [r] } // dernier succès rejoué
        switch r {
        case .success(let s): return s
        case .failure(let e): throw e
        }
    }
}

/// Horloge pilotée par les tests : `sleep` suspend jusqu'à `advance`.
actor TestClock: Clock {
    private(set) var current: Date
    private var sleepers: [(id: UUID, deadline: Date, continuation: CheckedContinuation<Void, Error>)] = []

    init(start: Date = .iso("2026-11-01T10:00:00Z")) { current = start }

    nonisolated var now: Date {
        // Lecture synchrone demandée par le protocole : on passe par un snapshot non isolé.
        nowBox.value
    }
    private let nowBox = LockedBox<Date>(.iso("2026-11-01T10:00:00Z"))

    func sleep(for duration: Duration, tolerance: Duration) async throws {
        let deadline = current.addingTimeInterval(duration.seconds)
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                sleepers.append((id, deadline, c))
            }
        } onCancel: {
            Task { await self.cancelSleeper(id) }
        }
    }

    private func cancelSleeper(_ id: UUID) {
        guard let i = sleepers.firstIndex(where: { $0.id == id }) else { return }
        let s = sleepers.remove(at: i)
        s.continuation.resume(throwing: CancellationError())
    }

    /// Avance le temps et réveille les dormeurs échus, un par un, dans l'ordre des échéances.
    func advance(by seconds: TimeInterval) async {
        let target = current.addingTimeInterval(seconds)
        // La boucle peut ne pas encore dormir : sans cette attente, l'horloge avance à vide.
        for _ in 0..<500 {
            if !sleepers.isEmpty { break }
            await Task.yield()
        }
        while let next = sleepers.filter({ $0.deadline <= target }).min(by: { $0.deadline < $1.deadline }) {
            current = max(current, next.deadline)
            nowBox.value = current
            sleepers.removeAll { $0.id == next.id }
            next.continuation.resume()
            // Laisse la boucle réveillée faire son relevé et réarmer son sommeil avant de continuer.
            for _ in 0..<500 {
                await Task.yield()
                if !sleepers.isEmpty { break }
            }
            await settle()
        }
        current = target
        nowBox.value = current
        await settle()
    }

    /// Laisse les tâches en cours progresser jusqu'à leur prochain `sleep`.
    func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }

    var pendingSleepers: Int { sleepers.count }
}

final class LockedBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ v: T) { _value = v }
    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

extension Duration {
    var seconds: TimeInterval {
        let c = components
        return TimeInterval(c.seconds) + TimeInterval(c.attoseconds) / 1e18
    }
}

func makeSnapshot(_ pairs: [(String, Double)], fetchedAt: Date = .iso("2026-11-01T10:00:00Z"), resetsAt: Date? = .iso("2026-11-01T14:00:00Z")) -> UsageSnapshot {
    UsageSnapshot(limits: pairs.map { id, pct in
        let kind: LimitKind = id == "session" ? .rollingFiveHour : (id == "weekly_all" ? .weeklyAll : .weeklyModel)
        let model = kind == .weeklyModel ? String(id.dropFirst("weekly_scoped:".count)) : nil
        return UsageLimit(id: id, kind: kind, modelName: model, utilization: pct, resetsAt: resetsAt)
    }, fetchedAt: fetchedAt)
}

/// Entrée Trousseau de Claude Code factice : contenu fixe, compte les lectures et leur mode.
final class StubClaudeCodeSource: ClaudeCodeCredentialSource, @unchecked Sendable {
    private let lock = NSLock()
    var json: Data?
    var exists: Bool
    private(set) var reads: [Bool] = []
    init(json: Data?, exists: Bool = true) { self.json = json; self.exists = exists }
    func entryExists() -> Bool { exists }
    func readRawJSON(interactive: Bool) async throws -> Data? {
        lock.withLock { reads.append(interactive); return json }
    }
}
