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
    private var retry: DispatchWorkItem?

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
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        s.setEventHandler { [weak self, weak s] in
            MainActor.assumeIsolated {
                // Fichier supprimé ou remplacé (nettoyage, dossier recréé) : le descripteur suit l'ancien fichier, on
                // rouvre le chemin. Sans cela plus aucun événement n'arrivait jusqu'au relancement de l'app.
                if let data = s?.data, !data.isDisjoint(with: [.delete, .rename]) { self?.restart() } else { self?.readNew() }
            }
        }
        let fd = fd
        s.setCancelHandler { Darwin.close(fd) }
        source = s
        s.resume()
        // Rattrapage de ce qui s'est accumulé app fermée, puis fichier vidé.
        readNew()
    }

    func stop() {
        // Ce qui n'a pas été lu ne le sera plus par cette instance : rien ne reste sur disque après l'arrêt.
        if fd >= 0 { ftruncate(fd, 0) }
        close()
    }

    /// Rouvre le fichier à son chemin (recréé s'il manque) et reprend la lecture depuis le début.
    func restart() {
        close()
        start()
    }

    private func close() {
        retry?.cancel()
        retry = nil
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
        if pending.isEmpty, offset > 0 { truncateIfConsumed() }
        if !events.isEmpty { onEvents(events) }
    }

    /// Troncature sous le verrou du script (`lockf`, donc `flock`) : hors verrou, un hook qui écrivait entre la
    /// relecture de la taille et la troncature perdait son événement. Verrou pris par un hook : nouvelle lecture
    /// un peu plus tard, que ce hook écrive encore ou non.
    private func truncateIfConsumed() {
        let lock = open(url.path + ".lock", O_RDWR | O_CREAT, 0o600)
        guard lock >= 0 else { return }
        defer { Darwin.close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            retry?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.readNew() }
            retry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            return
        }
        defer { flock(lock, LOCK_UN) }
        var st = stat()
        if fstat(fd, &st) == 0, Int(st.st_size) == offset, ftruncate(fd, 0) == 0 { offset = 0 }
    }
}
