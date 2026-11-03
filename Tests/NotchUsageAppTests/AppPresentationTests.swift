import AppKit
import Foundation
import NotchUsageCore
import Testing
@testable import NotchUsage

/// Pièces de présentation de l'app, sans fenêtre (010) : messages d'erreur, rendu des paliers, libellés courts.
@MainActor
@Suite("App presentation (010)")
struct AppPresentationTests {
    @Test func networkErrorsAreDistinguished() {
        let offline = ConnectionError.fetch(.network(.notConnectedToInternet)).errorDescription
        let timeout = ConnectionError.fetch(.network(.timedOut)).errorDescription
        let unreachable = ConnectionError.fetch(.network(.cannotFindHost)).errorDescription
        #expect(offline != nil && timeout != nil && unreachable != nil)
        #expect(Set([offline, timeout, unreachable]).count == 3)
    }

    @Test func everyConnectionErrorHasAMessage() {
        let errors: [ConnectionError] = [.claudeCodeUnavailable, .claudeCodeMalformed, .claudeCodeExpired(.max), .invalidSessionKey,
                                         .fetch(.unauthorized), .fetch(.unsupported), .fetch(.challenge), .fetch(.malformed)]
        for e in errors { #expect(!(e.errorDescription ?? "").isEmpty) }
    }

    @Test func islandTintsFollowTheEdgeColours() {
        #expect(NotchSignal.Island.Tint.calm.edge == nil)
        #expect(NotchSignal.Island.Tint.near.color == NotchSignal.Edge.near.color)
        #expect(NotchSignal.Island.Tint.exhausted.edge?.hasHalo == true && NotchSignal.Island.Tint.far.edge?.hasHalo == false)
        // L'île tient dans l'encoche et deux oreilles : au plus 104 pt de plus (012, SC-002).
        #expect(2 * NotchPanelController.earWidth <= 104)
    }

    @Test func lighteningMovesTowardWhite() {
        let red = NotchSignal.Edge.imminent.rgb
        #expect(red.red == 1.0 && red.green < 0.3)
        #expect(NotchSignal.Edge.imminent.color(lightened: 0) == NotchSignal.Edge.imminent.color)
    }

    @Test func shortLabelsPerLimitKind() {
        let now = Date()
        let session = UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: 10, resetsAt: now)
        let fable = UsageLimit(id: "weekly_scoped:Fable", kind: .weeklyModel, modelName: "Fable", utilization: 10, resetsAt: now)
        #expect(!CompactStrip.Strings.app.shortLabel(session).isEmpty)
        #expect(CompactStrip.Strings.app.shortLabel(fable) == "Fable")
    }

    @Test func menuBarGaugeIsATemplateImage() {
        for usage in [nil, 0, 42, 100] as [Int?] {
            let image = StatusItemController.gauge(usage)
            #expect(image.isTemplate && image.size == NSSize(width: 18, height: 18))
            #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
        }
    }
}
