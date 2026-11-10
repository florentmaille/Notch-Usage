import Foundation
import NotchUsageCore

/// Lance `claude` en arrière-plan pour qu'il renouvelle son jeton (011). Sur clic seulement : la requête
/// compte dans la fenêtre de 5 h. Sortie lue pour le diagnostic, jamais journalisée (elle peut contenir un e-mail).
enum ClaudeCodeRenewer {
    static func renew() async -> ClaudeCLI.Outcome {
        let home = NSHomeDirectory(), user = NSUserName()
        guard let binary = ClaudeCLI.locate(home: home, path: ProcessInfo.processInfo.environment["PATH"],
                                            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .notFound
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: run(binary: binary, home: home, user: user))
            }
        }
    }

    /// Toutes les attentes sont bornées : un processus enfant de `claude` qui garderait la sortie ouverte après
    /// l'arrêt ne peut pas bloquer le bouton sur « Renouvellement… ». On attend la fin du processus, jamais la
    /// fin de la sortie.
    private static func run(binary: String, home: String, user: String) -> ClaudeCLI.Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ClaudeCLI.renewalArguments
        process.environment = ClaudeCLI.environment(home: home, user: user, binary: binary)
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        let output = OutputBuffer()
        let reader = pipe.fileHandleForReading
        reader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { handle.readabilityHandler = nil; output.finish() } else { output.append(chunk) }
        }
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do { try process.run() } catch {
            reader.readabilityHandler = nil
            return .failed
        }

        var timedOut = false
        if exited.wait(timeout: .now() + ClaudeCLI.timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 2)
            }
        }
        // Derniers octets : courte attente de la fin de sortie, sans dépendre d'éventuels processus enfants.
        output.waitForEnd(timeout: 0.5)
        reader.readabilityHandler = nil
        try? reader.close()

        if timedOut { return .timedOut }
        guard !process.isRunning, process.terminationReason == .exit else { return .failed }
        return ClaudeCLI.outcome(exitCode: process.terminationStatus, output: output.text)
    }
}

/// Sortie accumulée depuis le gestionnaire de lecture (autre file), protégée par un verrou.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let ended = DispatchSemaphore(value: 0)

    func append(_ chunk: Data) { lock.withLock { data.append(chunk) } }
    func finish() { ended.signal() }
    func waitForEnd(timeout: TimeInterval) { _ = ended.wait(timeout: .now() + timeout) }
    var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }
}
