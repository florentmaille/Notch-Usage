import Foundation

public enum DisplayMode: Sendable, Equatable {
    case notch
    case pill
}

public struct NotchLayout: Sendable, Equatable {
    public let mode: DisplayMode
    public let width: CGFloat
    public let height: CGFloat
    /// Abscisse du bord gauche, dans le repère de l'écran.
    public let originX: CGFloat
}

/// Calcul pur à partir des valeurs lues sur NSScreen (R5).
public enum NotchGeometry {
    public static let pillSize = CGSize(width: 150, height: 28)

    public static func layout(screenWidth: CGFloat, safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) -> NotchLayout {
        if safeAreaTop > 0, let l = auxLeftWidth, let r = auxRightWidth, screenWidth - l - r > 0 {
            return NotchLayout(mode: .notch, width: screenWidth - l - r, height: safeAreaTop, originX: l)
        }
        return NotchLayout(mode: .pill, width: pillSize.width, height: pillSize.height, originX: ((screenWidth - pillSize.width) / 2).rounded())
    }
}
