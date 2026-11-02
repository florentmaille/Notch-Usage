import Foundation
import NotchUsageCore

/// Dernier relevé et registre d'alertes dans `~/Library/Application Support/NotchUsage/`.
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
    private var ledgerURL: URL { directory.appending(path: "alerts.json") }
    private var historyURL: URL { directory.appending(path: "history.json") }

    func loadSnapshot() throws -> UsageSnapshot? { try load(snapshotURL) }
    func saveSnapshot(_ snapshot: UsageSnapshot) throws { try save(snapshot, to: snapshotURL) }
    func loadLedger() throws -> AlertLedger? { try load(ledgerURL) }
    func saveLedger(_ ledger: AlertLedger) throws { try save(ledger, to: ledgerURL) }
    func loadHistory() throws -> UsageHistory? { try load(historyURL) }
    func saveHistory(_ history: UsageHistory) throws { try save(history, to: historyURL) }

    func wipe() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
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
