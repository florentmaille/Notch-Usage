import AppKit
// Spike 018 (manuel) : l'item « réel » de barre de menus suit-il la barre active, et ce changement est-il notifié ?
// Lancer : swiftc main.swift -o /tmp/spike018 && /tmp/spike018   puis cliquer dans une fenêtre de chaque écran, tour à tour, pendant 45 s.
func name(_ s: NSScreen?) -> String { s.map { $0.safeAreaInsets.top > 0 ? "NOTCH" : "EXT(\(Int($0.frame.width)))" } ?? "nil" }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let item = NSStatusBar.system.statusItem(withLength: 60)
item.button?.title = "SPIKE"
let t0 = Date()
func log(_ m: String) { print(String(format: "%5.1fs ", Date().timeIntervalSince(t0)) + m); fflush(stdout) }
var observed: NSWindow?
var last = ""
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
    if let w = item.button?.window, observed !== w {
        observed = w
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: w, queue: .main) { _ in
            log("NOTIF didChangeScreen -> \(name(w.screen))")
        }
        log("observe window on \(name(w.screen))")
    }
    let now = "\(name(item.button?.window?.screen)) x=\(Int(item.button?.window?.frame.minX ?? -1))"
    if now != last { log("poll: item on \(now)"); last = now }
    if Date().timeIntervalSince(t0) > 45 { t.invalidate(); app.terminate(nil) }
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
    let a = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.localizedName ?? "?"
    log("NOTIF didActivateApplication \(a)")
}
app.run()
