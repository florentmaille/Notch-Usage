import AppKit
import NotchUsageCore
import Observation
import SwiftUI

/// Surfaces de l'app : île de l'écran à encoche, item de barre de menus, pastilles des écrans sans encoche (018).
/// Suit les écrans, crée ou retire les surfaces selon les réglages (`SurfacePlan`),
/// leur applique ce que le modèle a calculé et n'en laisse qu'une ouverte à la fois (FR-010). Le modèle garde
/// l'état d'interaction (survol, réglages affichés) et décide de ce qui s'affiche ; rien de cela ici.
@MainActor
@Observable
final class Surfaces {
    /// Surface qui s'ouvre : les autres se referment.
    enum Surface: Equatable {
        case island
        case popover
        case capsule(screenID: String)
    }

    /// Item de barre de menus (014, 018) : automatique (écran sans encoche connecté), toujours ou jamais.
    private(set) var menuBarIconMode: MenuBarIconMode = Surfaces.loadMenuBarIconMode()
    /// Pastille centrée sur les écrans sans encoche d'au moins 1700 pt (018, C′), désactivée par défaut (FR-011).
    private(set) var showsCenterCapsule = UserDefaults.standard.bool(forKey: Surfaces.capsuleKey)

    /// Encoche de l'écran de l'île ; sans île, celle du dernier écran connu ou d'un MacBook Pro 14 pouces.
    @ObservationIgnored private(set) var layout = NotchLayout.fallback
    /// Rôle des écrans connectés (018) : île sur l'écran à encoche, item enrichi sur les autres.
    @ObservationIgnored private var roles: ScreenRoles = .empty
    @ObservationIgnored private var screensByID: [String: NSScreen] = [:]

    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let screens = ScreenObserver()
    @ObservationIgnored private let fullscreenObserver = FullscreenObserver()
    @ObservationIgnored private var island: NotchPanelController?
    @ObservationIgnored private var statusItem: StatusItemController?
    @ObservationIgnored private var capsules: [String: CapsulePanelController] = [:]
    /// Écran de la barre de menus active, lu sur la fenêtre de l'item (R4) : lui seul s'y adapte (FR-022).
    @ObservationIgnored private var activeBarScreenID: String?
    /// Hauteur idéale du contenu déplié, mesurée par la vue.
    @ObservationIgnored private var contentHeight = NotchPanelController.expandedHeight

    private static let legacyMenuBarKey = "showsMenuBarIcon"
    private static let menuBarModeKey = "menuBarIconMode"
    private static let capsuleKey = "showsCenterCapsule"

    #if DEBUG
    /// Mode démo (build Debug) : voir `AppModel+Demo.swift`.
    @ObservationIgnored private var demoNoNotch = false
    @ObservationIgnored private var demoNotchOnly = false
    @ObservationIgnored var demoActiveBar: String?
    #endif

    /// Lu une fois : l'ancien booléen de la 014 devient un mode, puis disparaît (R8).
    private static func loadMenuBarIconMode() -> MenuBarIconMode {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: menuBarModeKey), let mode = MenuBarIconMode(rawValue: raw) { return mode }
        let legacy = defaults.object(forKey: legacyMenuBarKey) == nil ? nil : defaults.bool(forKey: legacyMenuBarKey)
        let mode = MenuBarIconMode.migrate(legacy: legacy)
        defaults.set(mode.rawValue, forKey: menuBarModeKey)
        defaults.removeObject(forKey: legacyMenuBarKey)
        return mode
    }

    // MARK: Cycle de vie

    func start(model: AppModel) {
        self.model = model
        screens.onChange = { [weak self] snapshot in self?.apply(snapshot) }
        screens.start()
        fullscreenObserver.onChange = { [weak self] isFullscreen in self?.model?.fullscreen = isFullscreen }
        fullscreenObserver.start()
    }

    func stop() {
        statusItem?.remove()
        statusItem = nil
        capsules.values.forEach { $0.close() }
        capsules = [:]
        screens.stop()
        fullscreenObserver.stop()
        island?.close()
        island = nil
    }

    // MARK: Écrans

    /// Configuration d'écrans (018, R1) : l'île sur l'écran à encoche seulement, fermée sans lui ; item et pastilles
    /// selon le plan.
    private func apply(_ snapshot: ScreenObserver.Snapshot) {
        guard let model else { return }
        var snapshot = snapshot
        #if DEBUG
        if demoNoNotch { snapshot = Self.withoutNotch(snapshot) }
        // Démo `notchonly` : comme un MacBook seul, les écrans sans encoche sont ignorés (captures du README).
        if demoNotchOnly { snapshot = ScreenObserver.Snapshot(roles: ScreenRoles(island: snapshot.roles.island, plain: []), screens: snapshot.screens) }
        #endif
        roles = snapshot.roles
        screensByID = snapshot.screens
        statusItem?.closePopover()
        if let target = snapshot.island {
            layout = target.layout
            fullscreenObserver.screen = target.screen
            if let island {
                island.update(target: target)
            } else {
                let controller = NotchPanelController(target: target, rootView: AnyView(NotchRootView().environment(model)),
                                                      cardView: AnyView(NotchCardView().environment(model)))
                controller.onHoverChange = { [weak self] inside in self?.model?.hover = inside }
                controller.onDismiss = { [weak self] in self?.model?.dismiss() }
                island = controller
            }
        } else {
            // Capot fermé, Mac sans encoche : pas d'île, et plus de pilule (FR-002).
            model.hover = false
            island?.close()
            island = nil
            fullscreenObserver.screen = nil
        }
        let plan = self.plan
        syncCapsules(plan)
        syncStatusItem(plan)
        model.recompute()
    }

    private var plan: SurfacePlan {
        SurfacePlan.make(roles: roles, iconMode: menuBarIconMode, capsule: showsCenterCapsule)
    }

    /// Une pastille par écran sans encoche assez large, si l'option est active (FR-012, FR-016).
    private func syncCapsules(_ plan: SurfacePlan) {
        guard let model else { return }
        for (id, capsule) in capsules where !plan.capsuleScreens.contains(id) {
            capsule.close()
            capsules[id] = nil
        }
        for id in plan.capsuleScreens {
            guard let screen = screensByID[id] else { continue }
            if let capsule = capsules[id] {
                capsule.update(screen: screen)
            } else {
                let capsule = CapsulePanelController(screenID: id, screen: screen, model: model)
                capsule.onTap = { [weak self] in self?.model?.claude.clearDone() }
                capsule.onCardOpen = { [weak self] in self?.model?.surfaceWillOpen(.capsule(screenID: id)) }
                capsules[id] = capsule
            }
        }
    }

    /// Crée ou retire l'item selon le plan (FR-018).
    private func syncStatusItem(_ plan: SurfacePlan) {
        if !plan.showsItem, let item = statusItem {
            item.remove()
            statusItem = nil
            activeBarScreenID = nil
        }
        if plan.showsItem, statusItem == nil, let model {
            let item = StatusItemController(model: model)
            item.onActiveScreenChange = { [weak self] id in self?.activeBarChanged(id) }
            statusItem = item
        }
    }

    private func activeBarChanged(_ id: String?) {
        activeBarScreenID = id
        model?.recompute()
    }

    // MARK: Réglages

    func setMenuBarIconMode(_ mode: MenuBarIconMode) {
        menuBarIconMode = mode
        defaults.set(mode.rawValue, forKey: Self.menuBarModeKey)
        syncStatusItem(plan)
        model?.recompute()
    }

    func setShowsCenterCapsule(_ shown: Bool) {
        showsCenterCapsule = shown
        defaults.set(shown, forKey: Self.capsuleKey)
        let plan = self.plan
        syncCapsules(plan)
        syncStatusItem(plan)
        model?.recompute()
    }

    // MARK: Rendu

    /// Écran de la barre de menus active : celui de l'île ou un écran sans encoche (R4).
    private var activeBar: String? {
        #if DEBUG
        if let forced = demoActiveBar { return forced == "notch" ? roles.island?.id : "external" }
        #endif
        return activeBarScreenID
    }

    /// À côté d'un écran sans encoche, l'île porte le pourcentage (019) : le modèle y adapte le signal de l'encoche.
    var islandBar: NotchSignal.ActiveBar? { roles.islandBar }

    /// Applique à chaque surface ce que le modèle vient de calculer. `bar` dérive du signal avant adaptation à la
    /// barre active : le point Claude de la 017 et l'échéance restent ceux de la limite.
    func render(display: DisplayState, trailingEar: CGFloat, bar: BarContent, beat: Int) {
        island?.contentHeight = contentHeight
        // Île repliée (012) : oreille gauche toujours, droite seulement avec une donnée ; élargie le temps du mot
        // d'arrivée d'une session Claude (017).
        island?.apply(display, ears: (NotchPanelController.earWidth, trailingEar))
        // Item : anneau seul quand la barre active est celle de l'écran de l'île, qui porte le détail (FR-022).
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        statusItem?.update(content: roles.isIsland(activeBar) ? bar.compact : bar.menuBarItem, beat: beat, reduceMotion: reduceMotion)
        guard !capsules.isEmpty else { return }
        let dark = menuBarIsDark
        for capsule in capsules.values {
            // Pastille : détail complet quel que soit l'écran où l'on travaille (retour utilisateur, 2026-11-10) ;
            // elle se réduisait à l'anneau quand la barre active était celle du Mac.
            capsule.apply(content: bar, dark: dark, beat: beat, reduceMotion: reduceMotion)
            capsule.refreshCard()
        }
    }

    /// Hauteur mesurée du contenu déplié ; vrai si elle a changé. La carte se borne elle-même à l'écran (`CardLayout`).
    func setContentHeight(_ height: CGFloat) -> Bool {
        guard height > 40 else { return false }
        let measured = height.rounded(.up)
        guard abs(measured - contentHeight) > 0.5 else { return false }
        contentHeight = measured
        return true
    }

    /// Apparence de la barre de menus, lue sur l'item quand il existe (R6) ; sinon celle du système.
    private var menuBarIsDark: Bool {
        let appearance = statusItem?.buttonAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: Ouverture

    /// Une seule surface ouverte à la fois (FR-010) : celle qui s'ouvre referme le popover et les cartes des autres.
    /// L'île, elle, se referme par le survol du modèle.
    func closeOthers(than surface: Surface) {
        if surface != .popover { statusItem?.closePopover() }
        for (id, capsule) in capsules where surface != .capsule(screenID: id) { capsule.dismissCard() }
    }

    var hasIsland: Bool { island != nil }

    /// Ouverture demandée (menu de la barre, app rouverte, VoiceOver) : la carte de l'île reste ouverte sans survol
    /// et prend le clavier.
    func holdIslandOpen() {
        island?.holdOpen()
    }

    func openPopover() {
        statusItem?.openPopover()
    }

    /// Icône sur « Jamais », ni île ni pastille : plus aucune surface. L'icône revient, c'est la seule sortie de cet
    /// état depuis l'interface.
    func restoreIconIfNothingShows() {
        guard island == nil, statusItem == nil, capsules.isEmpty, menuBarIconMode == .never else { return }
        setMenuBarIconMode(.automatic)
        Log.app.notice("reopened without any surface: menu bar icon restored")
    }

    #if DEBUG
    /// Mode démo `layout` : "nonotch" (aucun écran à encoche), "notchonly" (MacBook seul), sinon les écrans réels.
    func debugSetLayout(_ mode: String) {
        demoNoNotch = mode == "nonotch"
        demoNotchOnly = mode == "notchonly"
        apply(screens.current)
    }

    /// Mode démo `nonotch` : tous les écrans passent sans encoche.
    private static func withoutNotch(_ snapshot: ScreenObserver.Snapshot) -> ScreenObserver.Snapshot {
        let descriptors = NSScreen.screens.enumerated().map { ScreenObserver.descriptor($1, isMain: $0 == 0, forceNoNotch: true) }
        return ScreenObserver.Snapshot(roles: ScreenRoles.assign(descriptors), screens: snapshot.screens)
    }

    func debugOpenPopover() { statusItem?.openPopover() }
    func debugSnapshot() {
        statusItem?.debugSnapshot()
        capsules.values.forEach { $0.debugSnapshot() }
    }
    func debugCapsuleHover(_ inside: Bool) { capsules.values.forEach { $0.debugHover(inside) } }
    #endif
}
