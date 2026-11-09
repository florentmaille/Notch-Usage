import Foundation

/// Cadre de fenêtre en points, coordonnées CGWindowList (origine en haut à gauche).
/// Le core n'importe que Foundation, qui n'expose pas la géométrie de CGRect.
public struct WindowFrame: Sendable, Equatable {
    public var x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var area: Double { width * height }

    func intersection(_ o: WindowFrame) -> WindowFrame? {
        let nx = max(x, o.x), ny = max(y, o.y)
        let w = min(maxX, o.maxX) - nx, h = min(maxY, o.maxY) - ny
        return w > 0 && h > 0 ? WindowFrame(x: nx, y: ny, width: w, height: h) : nil
    }

    public func overlaps(_ o: WindowFrame) -> Bool { intersection(o) != nil }

    func union(_ o: WindowFrame) -> WindowFrame {
        let nx = min(x, o.x), ny = min(y, o.y)
        return WindowFrame(x: nx, y: ny, width: max(maxX, o.maxX) - nx, height: max(maxY, o.maxY) - ny)
    }
}

/// Détection du plein écran sans API privée ni permission (R6).
///
/// Sur un Mac à encoche, une app en plein écran s'arrête sous l'encoche et peut se composer de
/// plusieurs fenêtres (Chrome) : même zone qu'une fenêtre agrandie. Ce qui distingue l'espace plein
/// écran, c'est qu'aucune autre app n'y a de fenêtre visible.
public enum FullscreenHeuristic {
    /// Bande haute tolérée : barre de menus ou encoche.
    static let topBand = 45.0
    static let tolerance = 2.0
    /// En dessous (50 × 50 pt), une fenêtre est ignorée : bulles, fenêtres techniques.
    static let minimumArea = 2_500.0

    /// Fenêtres système de l'écran, lues sans permission (app propriétaire et niveau, jamais le nom).
    public struct SpaceSignals: Sendable, Equatable {
        /// Fond « Fullscreen Backdrop » de WindowManager (niveau du bureau + 1) : propre aux espaces plein écran.
        public var fullscreenBackdrop: Bool
        /// Fond d'écran dessiné par WindowManager (niveau du bureau - 1) : ce macOS sait signaler le plein écran.
        public var windowManagerWallpaper: Bool
        /// Bureau du Finder (icônes) : jamais affiché dans un espace plein écran.
        public var desktopShown: Bool

        public init(fullscreenBackdrop: Bool = false, windowManagerWallpaper: Bool = false, desktopShown: Bool = false) {
            self.fullscreenBackdrop = fullscreenBackdrop
            self.windowManagerWallpaper = windowManagerWallpaper
            self.desktopShown = desktopShown
        }
    }

    /// Une fenêtre agrandie seule sur l'écran (Teams, retour utilisateur) a la même forme qu'un plein écran : les
    /// fenêtres système tranchent d'abord, la forme ne sert qu'en dernier recours. Vérifié le 2026-11-09 sur macOS 27
    /// avec une vraie fenêtre plein écran : fond plein écran présent, bureau du Finder absent ; l'inverse au retour.
    public static func isFullscreen(screen: WindowFrame, frontmost: [WindowFrame], others: [WindowFrame],
                                    signals: SpaceSignals = SpaceSignals()) -> Bool {
        if signals.fullscreenBackdrop { return true }
        // Ce macOS dessine le fond plein écran : son absence suffit, icônes du bureau masquées ou non.
        if signals.windowManagerWallpaper { return false }
        if signals.desktopShown { return false }
        let parts = frontmost.compactMap { visiblePart($0, in: screen) }
        guard let first = parts.first else { return false }
        let union = parts.dropFirst().reduce(first) { $0.union($1) }
        let coversWidth = union.x <= screen.x + tolerance && union.maxX >= screen.maxX - tolerance
        guard coversWidth, union.maxY >= screen.maxY - tolerance else { return false }
        // Couvre aussi la bande haute : impossible pour une fenêtre agrandie, c'est du plein écran.
        if union.y <= screen.y + tolerance { return true }
        guard union.y <= screen.y + topBand else { return false }
        return !others.contains { visiblePart($0, in: screen) != nil }
    }

    private static func visiblePart(_ frame: WindowFrame, in screen: WindowFrame) -> WindowFrame? {
        guard let part = frame.intersection(screen), part.area >= minimumArea else { return nil }
        return part
    }
}
