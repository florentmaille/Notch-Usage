import AppKit
import Foundation
import NotchUsageCore
import SwiftUI
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

    // MARK: 017 - sessions Claude en attente

    @Test func claudeTintIsVioletForBlockingWaitsAndWhiteWhenDone() {
        #expect(ClaudeWaitingKind.approval.color == ClaudeWaitingKind.question.color)
        #expect(ClaudeWaitingKind.done.color == .white)
        #expect(ClaudeWaitingKind.approval.color == Color(red: 0.75, green: 0.35, blue: 0.95))   // #BF5AF2
        #expect(ClaudeWaitingKind.approval.symbol == "hand.raised.fill" && ClaudeWaitingKind.question.symbol == "questionmark.bubble.fill"
                && ClaudeWaitingKind.done.symbol == "checkmark")
    }

    @Test func claudeStringsAreWiredToTheCatalog() {
        let s = CompactStrip.Strings.app.claude
        for kind in ClaudeWaitingKind.allCases {
            #expect(!s.arrival(kind).isEmpty && !s.rowLabel(kind).isEmpty && !s.kindAnnouncement(kind).isEmpty)
        }
        #expect(s.waitingAnnouncement(1) != s.waitingAnnouncement(2))
        #expect(!s.sessionFallback.isEmpty)
    }

    @Test func hookScriptAppendsOneLinePerEventToTheContainerFile() {
        let script = ClaudeHookScript.contents(eventsPath: "/Users/f/Library/Application Support/NotchUsage/claude-events.jsonl")
        #expect(script.hasPrefix("#!/bin/sh\n"))
        #expect(script.contains("f='/Users/f/Library/Application Support/NotchUsage/claude-events.jsonl'"))
        #expect(script.contains("\"$PPID\"") && script.contains("tr -d '\\n'") && script.contains("exit 0"))
        #expect(ClaudeHookScript.scriptURL.lastPathComponent == "claude-hook.sh" && ClaudeHookScript.eventsURL.lastPathComponent == "claude-events.jsonl")
        #expect(ClaudeHookScript.scriptURL.path.contains("/Library/Application Support/NotchUsage/"))
    }

    @Test func arrivalEarIsWiderThanAPlainEarOnlyWhileTheWordShows() {
        let now = Date()
        let snapshot = UsageSnapshot(limits: [UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: 42,
                                                         resetsAt: now.addingTimeInterval(7200))], fetchedAt: now)
        let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)
        let display = DisplayStateReducer.reduce(state: .idle(snapshot), connected: true, settings: RefreshSettings(), alertLevel: .none,
                                                 layout: layout, fullscreen: false, hover: false, now: now)
        let attention = NotchSignal.Attention(kind: .approval, count: 1, arrivedAt: now, entries: [])
        let fresh = NotchSignal.make(display: display, now: now, language: .english, strings: .app, attention: attention)
        #expect(fresh.trailingEarWidth(now: now) == NotchPanelController.arrivalEarWidth)
        #expect(fresh.trailingEarWidth(now: now.addingTimeInterval(5)) == NotchPanelController.earWidth)
        let none = NotchSignal.make(display: display, now: now, language: .english, strings: .app)
        #expect(none.trailingEarWidth(now: now) == 0)
    }

    @Test func menuBarGaugeIsATemplateImage() {
        for usage in [nil, 0, 42, 100] as [Int?] {
            let image = StatusItemController.gauge(usage)
            #expect(image.isTemplate && image.size == NSSize(width: 18, height: 18))
            #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
        }
    }
}
