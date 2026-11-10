import AppKit
import NotchUsageCore
import SwiftUI

@main
struct NotchUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Aucune fenêtre principale : tout passe par le panneau d'encoche (FR-021).
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appModel: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Hôte des tests de l'app (010) : ni panneau, ni Trousseau, ni réseau.
        if NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        #if !DEBUG
        // Une seule instance (copie du zip lancée à côté de celle de Homebrew) : la plus récente cède la place et fait
        // ouvrir le panneau de l'autre. Les builds Debug restent libres de tourner à côté de la copie installée.
        if yieldToRunningInstance() { return }
        #endif
        let model = AppModel()
        appModel = model
        model.start()
    }

    /// App rouverte (Finder, Spotlight, `open`) alors qu'elle tourne : sans Dock ni fenêtre, c'est le seul geste
    /// qui ne dépend ni du survol ni de l'icône de la barre de menus. Le panneau s'ouvre et prend le clavier.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        appModel?.openPanel()
        return false
    }

    #if !DEBUG
    private func yieldToRunningInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated && $0 != current }
        let me = SingleInstance.Process(pid: current.processIdentifier, launchedAt: current.launchDate)
        guard SingleInstance.shouldYield(me: me, others: others.map { .init(pid: $0.processIdentifier, launchedAt: $0.launchDate) }) else { return false }
        Log.app.notice("another instance is running: this one quits")
        // Rouvrir la copie en place lui fait montrer son panneau (`applicationShouldHandleReopen`).
        if let url = others.first?.bundleURL { NSWorkspace.shared.open(url) }
        NSApp.terminate(nil)
        return true
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        appModel?.stop()
    }
}
