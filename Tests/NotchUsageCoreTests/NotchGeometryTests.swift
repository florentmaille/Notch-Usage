import Foundation
import Testing
@testable import NotchUsageCore

@Suite("NotchGeometry")
struct NotchGeometryTests {
    @Test func builtInDisplayWithNotch() {
        let l = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)
        #expect(l.mode == .notch)
        #expect(l.width == 312)
        #expect(l.height == 32)
        #expect(l.originX == 600)
    }

    @Test func displayWithoutNotchIsPill() {
        let l = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        #expect(l.mode == .pill)
        #expect(l.width == 150)
        #expect(l.height == 28)
        #expect(l.originX == 681)
    }

    @Test func safeAreaWithoutAuxiliaryAreasIsPill() {
        let l = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: nil, auxRightWidth: nil)
        #expect(l.mode == .pill)
    }
}

@Suite("NotchGeometry - écrans externes (US3)")
struct NotchGeometryExternalTests {
    @Test func externalDisplayWithoutNotchCentersPill() {
        let l = NotchGeometry.layout(screenWidth: 2560, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        #expect(l.mode == .pill)
        #expect(l.originX == 1205)
    }

    @Test func builtInDisplayBackAsMainIsNotch() {
        let l = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)
        #expect(l.mode == .notch)
    }
}
