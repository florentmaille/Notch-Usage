import AppKit

/// Panneau non activant collé au bord haut de l'écran (R5). `canBecomeKey` est vrai pour
/// recevoir Échap et la saisie dans les réglages sans activer l'app (`.nonactivatingPanel`).
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isFloatingPanel = true
        // Après `isFloatingPanel`, qui remet le niveau à `.floating` (3) : sous la barre de menus (24),
        // le panneau ne recevrait ni survol ni clic dans la bande de l'encoche.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        isMovable = false
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        // Fond toujours noir : en apparence claire, les contrôles natifs (stepper, champ) y seraient invisibles.
        appearance = NSAppearance(named: .darkAqua)
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit repousse par défaut les fenêtres sous la barre de menus : le panneau doit couvrir l'encoche.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
