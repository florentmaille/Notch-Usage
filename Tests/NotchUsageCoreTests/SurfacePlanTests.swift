import Foundation
import Testing
@testable import NotchUsageCore

/// Quelles surfaces existent selon les écrans et les réglages (018 : item et pastille ; 019 : île qui suit la barre).
@Suite("SurfacePlan (018, 019)")
struct SurfacePlanTests {
    let island = IslandScreen(id: "mac", layout: .fallback)
    let wide = PlainScreen(id: "dell", capsuleEligible: true)
    let narrow = PlainScreen(id: "small", capsuleEligible: false)

    func plan(island: Bool = true, plain: [PlainScreen] = [], _ mode: MenuBarIconMode = .automatic, capsule: Bool = false) -> SurfacePlan {
        SurfacePlan.make(roles: ScreenRoles(island: island ? self.island : nil, plain: plain), iconMode: mode, capsule: capsule)
    }

    @Test func aMacBookAloneOnlyHasItsIsland() {
        #expect(plan() == SurfacePlan(showsItem: false, capsuleScreens: []))
        #expect(plan(.always).showsItem)
        // L'option de la pastille ne crée rien sans écran sans encoche.
        #expect(plan(capsule: true).capsuleScreens.isEmpty)
    }

    @Test func aPlainScreenBringsTheItemUnlessNever() {
        #expect(plan(plain: [wide]).showsItem)
        #expect(plan(island: false, plain: [narrow]).showsItem)
        #expect(!plan(plain: [wide], .never).showsItem)
    }

    @Test func capsulesGoOnWidePlainScreensWhenTheOptionIsOn() {
        #expect(plan(plain: [wide, narrow]).capsuleScreens.isEmpty)
        #expect(plan(plain: [wide, narrow], capsule: true).capsuleScreens == ["dell"])
        #expect(plan(island: false, plain: [narrow], capsule: true).capsuleScreens.isEmpty)
    }

    /// À côté d'un écran sans encoche, l'île porte le pourcentage au calme, que l'on travaille sur le Mac ou sur
    /// l'autre écran (retour utilisateur, 2026-11-10 : elle s'effaçait quand on travaillait ailleurs). Le MacBook
    /// seul garde l'île de la 012.
    @Test func nextToAPlainScreenTheIslandAlwaysCarriesTheDetail() {
        #expect(ScreenRoles(island: island, plain: [wide]).islandCarriesPercent)
        #expect(ScreenRoles(island: island, plain: [narrow]).islandCarriesPercent)
        #expect(!ScreenRoles(island: island, plain: []).islandCarriesPercent)
        #expect(!ScreenRoles(island: nil, plain: [wide]).islandCarriesPercent)
    }
}
