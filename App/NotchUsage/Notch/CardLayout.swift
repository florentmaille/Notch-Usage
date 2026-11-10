import AppKit

/// Carte flottante de l'île et de la pastille : hauteur de son contenu, bornée par la place sous son bord haut.
/// Un plafond fixe (480 pt) coupait le titre et « Retour » des réglages dès que « Avancé » était déplié.
enum CardLayout {
    static let bottomMargin: CGFloat = 8
    static let minimumHeight: CGFloat = 120

    /// `top` : bord haut de la carte ; `floor` : bas de la zone utile de l'écran (au-dessus du Dock).
    static func height(measured: CGFloat, top: CGFloat, floor: CGFloat) -> CGFloat {
        min(measured.rounded(.up), max(minimumHeight, top - floor - bottomMargin))
    }
}

/// Un menu ouvert depuis une carte (Langue, icône de barre) recouvre le pointeur : la carte reçoit une sortie alors
/// que l'utilisateur choisit encore. Tant qu'il est ouvert, la carte ne se referme pas.
@MainActor
final class MenuTracking {
    private(set) var isActive = false
    var onEnd: (() -> Void)?
    private var observers: [any NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isActive = true }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isActive = false
                    self?.onEnd?()
                }
            },
        ]
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }
}
