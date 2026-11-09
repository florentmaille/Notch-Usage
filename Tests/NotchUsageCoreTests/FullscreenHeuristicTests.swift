
import Foundation
import Testing
@testable import NotchUsageCore

/// Mesures relevées le 2026-11-02 sur un MacBook à encoche (1800×1169 pt, barre de menus 39 pt)
/// avec un écran externe à droite.
@Suite("FullscreenHeuristic")
struct FullscreenHeuristicTests {
    let screen = WindowFrame(x: 0, y: 0, width: 1800, height: 1169)
    let externalWindow = WindowFrame(x: 1800, y: 119, width: 1920, height: 1050)

    @Test func chromeFullscreenSplitWindows() {
        let chrome = [WindowFrame(x: 0, y: 39, width: 1800, height: 41), WindowFrame(x: 0, y: 80, width: 1800, height: 47),
                      WindowFrame(x: 0, y: 39, width: 1800, height: 124), WindowFrame(x: 0, y: 127, width: 1800, height: 1042)]
        #expect(FullscreenHeuristic.isFullscreen(screen: screen, frontmost: chrome, others: [externalWindow]))
    }

    @Test func maximizedWindowWithOtherAppVisibleIsNotFullscreen() {
        let chrome = [WindowFrame(x: 0, y: 39, width: 1800, height: 1130)]
        let teams = [WindowFrame(x: 0, y: 39, width: 1800, height: 1130), externalWindow]
        #expect(!FullscreenHeuristic.isFullscreen(screen: screen, frontmost: chrome, others: teams))
    }

    /// Retour utilisateur du 2026-11-09 : Teams agrandi, seul sur l'écran du Mac, était pris pour du plein écran.
    /// Le bureau du Finder, visible dans un espace normal, tranche.
    @Test func maximizedWindowAloneWithDesktopShownIsNotFullscreen() {
        let teams = [WindowFrame(x: 0, y: 39, width: 1800, height: 1130)]
        #expect(!FullscreenHeuristic.isFullscreen(screen: screen, frontmost: teams, others: [externalWindow], desktopShown: true))
        #expect(FullscreenHeuristic.isFullscreen(screen: screen, frontmost: teams, others: [externalWindow], desktopShown: false))
    }

    @Test func singleWindowCoveringWholeScreen() {
        #expect(FullscreenHeuristic.isFullscreen(screen: screen, frontmost: [screen], others: []))
    }

    @Test func partialWindowIsNotFullscreen() {
        let window = [WindowFrame(x: 100, y: 100, width: 1200, height: 800)]
        #expect(!FullscreenHeuristic.isFullscreen(screen: screen, frontmost: window, others: []))
    }

    @Test func frontmostOnOtherScreenOnly() {
        #expect(!FullscreenHeuristic.isFullscreen(screen: screen, frontmost: [externalWindow], others: []))
    }

    @Test func tinyOtherWindowsIgnored() {
        let chrome = [WindowFrame(x: 0, y: 39, width: 1800, height: 1130)]
        let tiny = [WindowFrame(x: 10, y: 10, width: 20, height: 20)]
        #expect(FullscreenHeuristic.isFullscreen(screen: screen, frontmost: chrome, others: tiny))
    }
}
