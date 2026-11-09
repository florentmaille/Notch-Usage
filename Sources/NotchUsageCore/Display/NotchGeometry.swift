import Foundation

public struct NotchLayout: Sendable, Equatable {
    public let width: CGFloat
    public let height: CGFloat
    /// Abscisse du bord gauche, dans le repère de l'écran.
    public let originX: CGFloat

    public init(width: CGFloat, height: CGFloat, originX: CGFloat) {
        self.width = width
        self.height = height
        self.originX = originX
    }

    /// Encoche d'un MacBook Pro 14 pouces : sert au réducteur tant qu'aucun écran à encoche n'est connecté (018).
    public static let fallback = NotchLayout(width: 185, height: 32, originX: 664)
}

/// Calcul pur à partir des valeurs lues sur NSScreen (R5). Sans encoche, pas d'île (018 : la pilule est retirée).
public enum NotchGeometry {
    public static func layout(screenWidth: CGFloat, safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) -> NotchLayout? {
        guard safeAreaTop > 0, let l = auxLeftWidth, let r = auxRightWidth, screenWidth - l - r > 0 else { return nil }
        return NotchLayout(width: screenWidth - l - r, height: safeAreaTop, originX: l)
    }
}
