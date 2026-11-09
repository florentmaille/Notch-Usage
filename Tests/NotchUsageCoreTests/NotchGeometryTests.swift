import Foundation
import Testing
@testable import NotchUsageCore

@Suite("NotchGeometry")
struct NotchGeometryTests {
    @Test func builtInDisplayWithNotch() {
        let l = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)
        #expect(l?.width == 312)
        #expect(l?.height == 32)
        #expect(l?.originX == 600)
    }

    /// 018 : plus de pilule, un écran sans encoche n'a pas d'île.
    @Test func displayWithoutNotchHasNoLayout() {
        #expect(NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil) == nil)
        #expect(NotchGeometry.layout(screenWidth: 2560, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil) == nil)
    }

    @Test func safeAreaWithoutAuxiliaryAreasHasNoLayout() {
        #expect(NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: nil, auxRightWidth: nil) == nil)
    }
}
