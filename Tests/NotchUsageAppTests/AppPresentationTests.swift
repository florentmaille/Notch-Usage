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
        let layout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 32, auxLeftWidth: 600, auxRightWidth: 600)!
        let display = DisplayStateReducer.reduce(state: .idle(snapshot), connected: true, settings: RefreshSettings(), alertLevel: .none,
                                                 layout: layout, fullscreen: false, hover: false, now: now)
        let attention = NotchSignal.Attention(kind: .approval, count: 1, arrivedAt: now, entries: [])
        let fresh = NotchSignal.make(display: display, now: now, language: .english, strings: .app, attention: attention)
        #expect(fresh.trailingEarWidth(now: now) == NotchPanelController.arrivalEarWidth)
        #expect(fresh.trailingEarWidth(now: now.addingTimeInterval(5)) == NotchPanelController.earWidth)
        let none = NotchSignal.make(display: display, now: now, language: .english, strings: .app)
        #expect(none.trailingEarWidth(now: now) == 0)
    }

    // MARK: 018 - item de barre de menus

    static func bar(_ text: String?, attention: BarContent.Attention? = nil, badge: Bool = false, tint: NotchSignal.Island.Tint = .calm) -> BarContent {
        BarContent(gauge: .init(fraction: 0.42, tint: tint, beats: false), text: text, attention: attention, attentionAsBadge: badge, accessibility: "a")
    }

    @Test func compactItemKeepsThe014Size() {
        let c = Self.bar("42%").compact
        #expect(BarContentImage.size(for: c) == NSSize(width: 18, height: 18))
        #expect(BarContentImage.image(c).cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
    }

    @Test func richItemGrowsWithItsContent() {
        let ring = BarContentImage.size(for: Self.bar(nil)).width
        let text = BarContentImage.size(for: Self.bar("42%")).width
        let claude = BarContentImage.size(for: Self.bar("42%", attention: .init(kind: .approval, count: "2", arrivalWord: nil))).width
        #expect(ring == 14)
        #expect(text > ring + 5 && claude > text + 15)
        // Point violet sur la jauge : rien à droite.
        #expect(BarContentImage.size(for: Self.bar("8\u{2032}", attention: .init(kind: .approval, count: "", arrivalWord: nil), badge: true)).width
                == BarContentImage.size(for: Self.bar("8\u{2032}")).width)
    }

    @Test func widestSteadyItemStaysNarrow() {
        let widest = Self.bar("2:05", attention: .init(kind: .approval, count: "9+", arrivalWord: nil), tint: .far)
        #expect(BarContentImage.size(for: widest).width <= 90)
        let image = BarContentImage.image(widest)
        #expect(!image.isTemplate && image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
    }

    @Test func paletteFollowsTheMenuBar() {
        let dark = BarContentImage.palette(dark: true), light = BarContentImage.palette(dark: false)
        #expect(dark.mono == .white && light.mono == .black)
        #expect(dark.claude.hex == "BF5AF2" && light.claude.hex == "A43BD6")
        #expect(dark.far == light.far && dark.near == light.near && dark.red == light.red)
        #expect(dark.far.hex == "FF9F0A" && dark.near.hex == "FF6A1A" && dark.red.hex == "FF453A")
        #expect(dark.kind(.done) == .white && light.kind(.done) == .black)
    }
}

private extension NSColor {
    var hex: String {
        let c = usingColorSpace(.sRGB)!
        return String(format: "%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}
