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
        let model = AppModel()
        appModel = model
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel?.stop()
    }
}
