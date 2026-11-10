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
        #expect(plan() == SurfacePlan(showsItem: false, capsuleScreens: [], tracksActiveBar: false))
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

    /// Avec l'item, la barre active se lit sur sa fenêtre. Sans lui, elle n'est suivie que si une surface s'y
    /// adapte : une pastille, ou l'île quand un écran sans encoche est branché (019).
    @Test func theActiveBarIsTrackedOnlyWithoutTheItemAndWithSomethingToAdapt() {
        #expect(!plan(plain: [wide], capsule: true).tracksActiveBar)
        #expect(plan(plain: [wide], .never).tracksActiveBar)
        #expect(plan(island: false, plain: [wide], .never, capsule: true).tracksActiveBar)
        #expect(!plan(island: false, plain: [wide], .never).tracksActiveBar)
        #expect(!plan(island: false, plain: [narrow], .never, capsule: true).tracksActiveBar)
        #expect(!plan(.never).tracksActiveBar)
    }

    /// 019 : barre active vue de l'île. Au survol, l'île réapparaît entière même si l'on travaille ailleurs.
    @Test func theIslandFollowsTheActiveBarOnlyNextToAPlainScreen() {
        let both = ScreenRoles(island: island, plain: [wide])
        #expect(both.islandBar(active: "mac", hover: false) == .island)
        #expect(both.islandBar(active: "dell", hover: false) == .elsewhere)
        #expect(both.islandBar(active: "dell", hover: true) == .island)
        // Barre active inconnue, MacBook seul ou pas d'île : l'île de la 012, sans adaptation.
        #expect(both.islandBar(active: nil, hover: true) == nil)
        #expect(ScreenRoles(island: island, plain: []).islandBar(active: "mac", hover: false) == nil)
        #expect(ScreenRoles(island: nil, plain: [wide]).islandBar(active: "dell", hover: false) == nil)
    }
}
