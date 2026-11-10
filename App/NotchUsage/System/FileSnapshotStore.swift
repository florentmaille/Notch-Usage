import Foundation
import NotchUsageCore

/// Dernier relevé et historiques dans `~/Library/Application Support/NotchUsage/`.
final class FileSnapshotStore: SnapshotStore {
    private let directory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "NotchUsage", directoryHint: .isDirectory)
    }

    private var snapshotURL: URL { directory.appending(path: "snapshot.json") }
    /// Registre d'alertes des versions jusqu'à 0.6.1 : plus écrit ni lu, effacé au lancement et à la déconnexion.
    private var legacyLedgerURL: URL { directory.appending(path: "alerts.json") }
    private var historyURL: URL { directory.appending(path: "history.json") }
    private var hourlyURL: URL { directory.appending(path: "weekly.json") }

    func loadSnapshot() throws -> UsageSnapshot? { try load(snapshotURL) }
    func saveSnapshot(_ snapshot: UsageSnapshot) throws { try save(snapshot, to: snapshotURL) }
    func loadHistory() throws -> UsageHistory? { try load(historyURL) }
    func saveHistory(_ history: UsageHistory) throws { try save(history, to: historyURL) }
    func loadHourlyHistory() throws -> HourlyHistory? { try load(hourlyURL) }
    func saveHourlyHistory(_ history: HourlyHistory) throws { try save(history, to: hourlyURL) }

    /// Supprime les fichiers de données, pas le dossier : il porte aussi le script et le fil d'événements des hooks
    /// Claude Code (017), qui restent installés après une déconnexion.
    func wipe() throws {
        var failure: (any Error)?
        for url in [snapshotURL, legacyLedgerURL, historyURL, hourlyURL] where FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.removeItem(at: url) } catch { failure = failure ?? error }
        }
        if let failure { throw failure }
    }

    func removeLegacyFiles() {
        try? FileManager.default.removeItem(at: legacyLedgerURL)
    }

    private func load<T: Decodable>(_ url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
