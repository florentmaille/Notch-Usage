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
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = ClaudeCLI.renewalArguments
                process.environment = ClaudeCLI.environment(home: home, user: user)
                process.currentDirectoryURL = FileManager.default.temporaryDirectory
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.standardInput = FileHandle.nullDevice
                do { try process.run() } catch { continuation.resume(returning: .failed); return }
                let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + ClaudeCLI.timeout, execute: deadline)
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                deadline.cancel()
                if process.terminationReason == .uncaughtSignal { continuation.resume(returning: .timedOut); return }
                continuation.resume(returning: ClaudeCLI.outcome(exitCode: process.terminationStatus,
                                                                 output: String(decoding: data, as: UTF8.self)))
            }
        }
    }
}
