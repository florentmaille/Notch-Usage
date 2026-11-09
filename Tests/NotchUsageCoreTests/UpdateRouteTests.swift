import Foundation
import Testing
@testable import NotchUsageCore

@Suite("UpdateRoute (020)")
struct UpdateRouteTests {
    let installed = "/Applications/NotchUsage.app"

    @Test func homebrewOnAppleSilicon() {
        #expect(UpdateRoute.decide(appPath: installed, existingCaskrooms: ["/opt/homebrew/Caskroom/notch-usage"]) == .homebrew(prefix: "/opt/homebrew"))
    }

    @Test func homebrewOnIntel() {
        #expect(UpdateRoute.decide(appPath: installed, existingCaskrooms: ["/usr/local/Caskroom/notch-usage"]) == .homebrew(prefix: "/usr/local"))
    }

    @Test func copyElsewhereGoesToTheReleasesPage() {
        let caskroom: Set<String> = ["/opt/homebrew/Caskroom/notch-usage"]
        #expect(UpdateRoute.decide(appPath: "/Users/me/Downloads/NotchUsage.app", existingCaskrooms: caskroom) == .releasesPage)
        #expect(UpdateRoute.decide(appPath: "/Users/me/Library/Developer/Xcode/DerivedData/x/Build/Products/Debug/NotchUsage.app",
                                   existingCaskrooms: caskroom) == .releasesPage)
    }

    @Test func noCaskroomGoesToTheReleasesPage() {
        #expect(UpdateRoute.decide(appPath: installed, existingCaskrooms: []) == .releasesPage)
    }

    @Test func caskroomCandidatesCoverBothPrefixes() {
        #expect(UpdateRoute.caskroomCandidates == ["/opt/homebrew/Caskroom/notch-usage", "/usr/local/Caskroom/notch-usage"])
    }

    @Test func scriptUpdatesTheTapThenTheCaskThenRelaunches() {
        let script = UpdateRoute.script(prefix: "/opt/homebrew", appPath: installed)
        let lines = script.split(separator: "\n").map(String.init)
        #expect(lines.first == "#!/bin/zsh")
        #expect(script.contains("export PATH=\"/opt/homebrew/bin:$PATH\""))
        let update = lines.firstIndex { $0.contains("brew update && brew upgrade --cask notch-usage") }
        let relaunch = lines.firstIndex { $0 == "open \"/Applications/NotchUsage.app\"" }
        #expect(update != nil && relaunch != nil && update! < relaunch!)
    }

    @Test func releasesPage() {
        #expect(UpdateRoute.releasesURL.absoluteString == "https://github.com/florentmaille/Notch-Usage/releases/latest")
    }
}
