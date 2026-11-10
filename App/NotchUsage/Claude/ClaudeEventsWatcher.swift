import Foundation
import NotchUsageCore

/// Lit le fichier d'événements au fil des écritures du script (017, R1) : un `DispatchSource` sur le descripteur,
/// aucune cadence. Lecture incrémentale depuis l'offset, lignes complètes seulement ; le fichier est vidé une
/// fois tout consommé, pour que le texte des conversations n'y reste que quelques secondes (R2).
@MainActor
final class ClaudeEventsWatcher {
    private let url: URL
    private let onEvents: @MainActor ([ClaudeHookEvent]) -> Void
    private var fd: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var offset = 0
    private var pending = Data()
    private(set) var dropped = 0

    init(url: URL, onEvents: @escaping @MainActor ([ClaudeHookEvent]) -> Void) {
        self.url = url
        self.onEvents = onEvents
    }

    func start() {
        guard source == nil else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        fd = open(url.path, O_RDWR)
        guard fd >= 0 else {
            Log.app.error("claude events: cannot open \(self.url.path, privacy: .public)")
            return
        }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend], queue: .main)
        s.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.readNew() }
        }
        let fd = fd
        s.setCancelHandler { close(fd) }
        source = s
        s.resume()
        // Rattrapage de ce qui s'est accumulé app fermée, puis fichier vidé.
        readNew()
    }

    func stop() {
        // Ce qui n'a pas été lu ne le sera plus par cette instance : rien ne reste sur disque après l'arrêt.
        if fd >= 0 { ftruncate(fd, 0) }
        source?.cancel()
        source = nil
        fd = -1
        offset = 0
        pending = Data()
    }

    private func readNew() {
        guard fd >= 0 else { return }
        var st = stat()
        guard fstat(fd, &st) == 0 else { return }
        let size = Int(st.st_size)
        if size < offset {
            // Vidé ou remplacé ailleurs : on repart du début.
            offset = 0
            pending = Data()
        }
        var events: [ClaudeHookEvent] = []
        if size > offset {
            var chunk = Data(count: size - offset)
            let n = chunk.withUnsafeMutableBytes { pread(fd, $0.baseAddress, size - offset, off_t(offset)) }
            guard n > 0 else { return }
            pending.append(chunk.prefix(n))
            offset += n
            let readAt = Date()
            while let newline = pending.firstIndex(of: 0x0A) {
                let line = String(decoding: pending[pending.startIndex..<newline], as: UTF8.self)
                pending = Data(pending[(newline + 1)...])
                if let event = ClaudeHookEvent.decode(line: Substring(line), readAt: readAt) {
                    events.append(event)
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    dropped += 1
                    Log.app.notice("claude events: dropped an unreadable line (\(self.dropped, privacy: .public) so far)")
                }
            }
        }
        // Tout consommé : le fichier est vidé, pour que le texte des conversations n'y reste pas (R2). La taille est
        // relue juste avant : si le script a écrit entre-temps, on garde le fichier et on le lira au prochain événement.
        if pending.isEmpty, offset > 0, fstat(fd, &st) == 0, Int(st.st_size) == offset {
            if ftruncate(fd, 0) == 0 { offset = 0 }
        }
        if !events.isEmpty { onEvents(events) }
    }
}
