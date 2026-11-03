import AppKit
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
        let model = AppModel()
        appModel = model
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel?.stop()
    }
}
