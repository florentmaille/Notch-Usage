import AppKit
import Darwin
import Foundation

/// Processus derrière une session Claude Code (017, R6 et R7) : vivacité par `kill(pid, 0)`, application d'origine
/// en remontant les parents jusqu'à une app visible (app Claude, Terminal, iTerm…). Jamais appelé sur un timer.
enum ProcessLiveness {
    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]

    static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    /// Parent et nom court d'un processus, par `sysctl` ; `nil` s'il n'existe plus.
    static func info(of pid: Int32) -> (ppid: Int32, name: String)? {
        var proc = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &proc, &size, nil, 0) == 0, size > 0 else { return nil }
        let name = withUnsafePointer(to: &proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        return (proc.kp_eproc.e_ppid, name)
    }

    /// Le hook est lancé par un shell enfant de `claude` : remonte les shells pour retenir le processus de la session.
    static func sessionProcess(from pid: Int32) -> Int32 {
        var current = pid
        for _ in 0..<4 {
            guard let info = info(of: current), shells.contains(info.name), info.ppid > 1 else { return current }
            current = info.ppid
        }
        return current
    }

    /// Première application ordinaire (menu, Dock) parmi les ancêtres : celle qui porte la fenêtre de la session.
    static func originApp(of pid: Int32) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<8 {
            if let app = NSRunningApplication(processIdentifier: current), app.bundleIdentifier != nil, app.activationPolicy == .regular {
                return app
            }
            guard let info = info(of: current), info.ppid > 1 else { return nil }
            current = info.ppid
        }
        return nil
    }

    @discardableResult
    static func activate(bundleID: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return false }
        return app.activate()
    }
}
