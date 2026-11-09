import Foundation

/// Ce que l'app lit d'un `NSScreen` (018, R1).
public struct ScreenDescriptor: Sendable, Equatable {
    public let id: String
    public let width: CGFloat
    public let safeAreaTop: CGFloat
    public let auxLeftWidth: CGFloat?
    public let auxRightWidth: CGFloat?
    /// Porte la barre de menus principale.
    public let isMain: Bool

    public init(id: String, width: CGFloat, safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?, isMain: Bool) {
        self.id = id
        self.width = width
        self.safeAreaTop = safeAreaTop
        self.auxLeftWidth = auxLeftWidth
        self.auxRightWidth = auxRightWidth
        self.isMain = isMain
    }
}

public struct IslandScreen: Sendable, Equatable {
    public let id: String
    public let layout: NotchLayout
}

public struct PlainScreen: Sendable, Equatable {
    public let id: String
    public let capsuleEligible: Bool

    public init(id: String, capsuleEligible: Bool) {
        self.id = id
        self.capsuleEligible = capsuleEligible
    }
}

/// Quel écran porte l'île, lesquels portent l'item enrichi et, en option, la pastille (FR-001 à FR-003, FR-012, FR-016).
public struct ScreenRoles: Sendable, Equatable {
    public static let capsuleMinWidth: CGFloat = 1700

    public let island: IslandScreen?
    public let plain: [PlainScreen]

    public init(island: IslandScreen?, plain: [PlainScreen]) {
        self.island = island
        self.plain = plain
    }

    public static let empty = ScreenRoles(island: nil, plain: [])

    public var hasPlainScreen: Bool { !plain.isEmpty }

    public func isIsland(_ id: String?) -> Bool { id != nil && island?.id == id }

    public static func assign(_ screens: [ScreenDescriptor]) -> ScreenRoles {
        var notched: [(ScreenDescriptor, NotchLayout)] = []
        var plain: [PlainScreen] = []
        for s in screens {
            if let layout = NotchGeometry.layout(screenWidth: s.width, safeAreaTop: s.safeAreaTop,
                                                 auxLeftWidth: s.auxLeftWidth, auxRightWidth: s.auxRightWidth) {
                notched.append((s, layout))
            } else {
                plain.append(PlainScreen(id: s.id, capsuleEligible: s.width >= capsuleMinWidth))
            }
        }
        // Plusieurs écrans à encoche (cas théorique) : celui de la barre principale, sinon le premier ; les autres n'ont rien.
        let chosen = notched.first(where: { $0.0.isMain }) ?? notched.first
        return ScreenRoles(island: chosen.map { IslandScreen(id: $0.0.id, layout: $0.1) }, plain: plain)
    }
}
