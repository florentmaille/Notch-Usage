import Foundation
import Testing
@testable import NotchUsageCore

@Suite("ScreenRoles (018)")
struct ScreenRolesTests {
    static func macBook(id: String = "mb", main: Bool) -> ScreenDescriptor {
        ScreenDescriptor(id: id, width: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600, isMain: main)
    }
    static func external(id: String = "ext", width: CGFloat = 1920, main: Bool) -> ScreenDescriptor {
        ScreenDescriptor(id: id, width: width, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil, isMain: main)
    }

    @Test func macBookAlone() {
        let r = ScreenRoles.assign([Self.macBook(main: true)])
        #expect(r.island?.id == "mb")
        #expect(r.island?.layout.width == 312)
        #expect(r.plain.isEmpty)
        #expect(!r.hasPlainScreen)
    }

    @Test func externalMainKeepsIslandOnMacBook() {
        let r = ScreenRoles.assign([Self.external(main: true), Self.macBook(main: false)])
        #expect(r.island?.id == "mb")
        #expect(r.plain == [PlainScreen(id: "ext", capsuleEligible: true)])
        #expect(r.hasPlainScreen)
    }

    @Test func narrowSecondaryExternalIsNotEligible() {
        let r = ScreenRoles.assign([Self.macBook(main: true), Self.external(width: 1440, main: false)])
        #expect(r.plain == [PlainScreen(id: "ext", capsuleEligible: false)])
    }

    @Test func lidClosedHasNoIsland() {
        let r = ScreenRoles.assign([Self.external(main: true)])
        #expect(r.island == nil)
        #expect(r.hasPlainScreen)
    }

    @Test func macWithoutNotchKeepsOrder() {
        let r = ScreenRoles.assign([Self.external(id: "a", width: 2560, main: true), Self.external(id: "b", width: 1280, main: false)])
        #expect(r.island == nil)
        #expect(r.plain.map(\.id) == ["a", "b"])
        #expect(r.plain.map(\.capsuleEligible) == [true, false])
    }

    @Test func twoNotchedScreensPreferMain() {
        let r = ScreenRoles.assign([Self.macBook(id: "1", main: false), Self.macBook(id: "2", main: true)])
        #expect(r.island?.id == "2")
        #expect(r.plain.isEmpty)
        let none = ScreenRoles.assign([Self.macBook(id: "1", main: false), Self.macBook(id: "2", main: false)])
        #expect(none.island?.id == "1")
    }

    @Test func capsuleThresholdIsInclusive() {
        #expect(ScreenRoles.assign([Self.external(width: 1700, main: true)]).plain.first?.capsuleEligible == true)
        #expect(ScreenRoles.assign([Self.external(width: 1699, main: true)]).plain.first?.capsuleEligible == false)
    }

    @Test func safeAreaWithoutAuxiliaryAreasIsPlain() {
        let s = ScreenDescriptor(id: "x", width: 1512, safeAreaTop: 32, auxLeftWidth: nil, auxRightWidth: nil, isMain: true)
        #expect(ScreenRoles.assign([s]).island == nil)
    }

    @Test func isNotchedHelper() {
        let r = ScreenRoles.assign([Self.macBook(main: false), Self.external(main: true)])
        #expect(r.isIsland("mb"))
        #expect(!r.isIsland("ext"))
        #expect(!r.isIsland(nil))
    }
}
