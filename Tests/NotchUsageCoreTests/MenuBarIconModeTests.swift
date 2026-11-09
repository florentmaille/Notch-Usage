import Foundation
import Testing
@testable import NotchUsageCore

@Suite("MenuBarIconMode (018)")
struct MenuBarIconModeTests {
    @Test func migratesLegacyToggle() {
        #expect(MenuBarIconMode.migrate(legacy: true) == .always)
        #expect(MenuBarIconMode.migrate(legacy: false) == .automatic)
        #expect(MenuBarIconMode.migrate(legacy: nil) == .automatic)
    }

    @Test func visibility() {
        let withPlain = ScreenRoles.assign([ScreenDescriptor(id: "e", width: 1920, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil, isMain: true)])
        let notchOnly = ScreenRoles.assign([ScreenDescriptor(id: "m", width: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600, isMain: true)])
        #expect(MenuBarIconMode.always.isVisible(roles: notchOnly))
        #expect(!MenuBarIconMode.never.isVisible(roles: withPlain))
        #expect(MenuBarIconMode.automatic.isVisible(roles: withPlain))
        #expect(!MenuBarIconMode.automatic.isVisible(roles: notchOnly))
    }

    @Test func stableRawValues() {
        #expect(MenuBarIconMode.allCases.map(\.rawValue) == ["automatic", "always", "never"])
    }
}
