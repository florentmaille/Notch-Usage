import AppKit
import Foundation
import NotchUsageCore
import os
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

    /// La déconnexion efface les données de consommation, pas le dossier : le script des hooks Claude Code et son
    /// fil d'événements y vivent aussi, et les hooks restent installés (017).
    @Test func wipeRemovesUsageDataAndKeepsTheClaudeHookFiles() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notchusage-wipe-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: dir) }
        let store = FileSnapshotStore(directory: dir)
        try store.saveSnapshot(UsageSnapshot(limits: [], fetchedAt: Date()))
        // Registre d'alertes laissé par une version jusqu'à 0.6.1 : plus écrit, mais toujours effacé.
        try "{}".write(to: dir.appending(path: "alerts.json"), atomically: true, encoding: .utf8)
        try store.saveHistory(UsageHistory())
        try store.saveHourlyHistory(HourlyHistory())
        for name in ["claude-hook.sh", "claude-events.jsonl"] {
            try "".write(to: dir.appending(path: name), atomically: true, encoding: .utf8)
        }
        #expect(try fm.contentsOfDirectory(atPath: dir.path).count == 6)

        try store.wipe()
        #expect(try Set(fm.contentsOfDirectory(atPath: dir.path)) == ["claude-hook.sh", "claude-events.jsonl"])
        #expect(try store.loadSnapshot() == nil && store.loadHistory() == nil && store.loadHourlyHistory() == nil)
        // Rien à effacer : pas d'erreur.
        try store.wipe()
    }

    /// La commande écrite dans `~/.claude/settings.json` cite le chemin réel du script, qui contient une espace.
    @Test func hookCommandQuotesTheRealScriptPath() {
        let path = ClaudeHookScript.scriptURL.path
        #expect(path.contains(" "))
        #expect(ClaudeHooksInstaller.command(for: path) == "[ ! -x '\(path)' ] || exec '\(path)'")
    }

    // MARK: Script de hook, exécuté pour de vrai

    /// Dossier jetable au nom piégé (espace, apostrophe), avec le script généré par l'app et sa commande installée.
    private func hookSandbox() throws -> (dir: URL, events: URL, command: String) {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notch usage d'essai \(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let script = dir.appending(path: "claude-hook.sh"), events = dir.appending(path: "claude-events.jsonl")
        try ClaudeHookScript.contents(eventsPath: events.path).write(to: script, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return (dir, events, ClaudeHooksInstaller.command(for: script.path))
    }

    /// Lance la commande comme Claude Code : `/bin/sh -c <commande>`, payload du hook sur l'entrée standard.
    private nonisolated static func runHook(_ command: String, payload: Data) -> Int32 {
        let process = Process(), input = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardInput = input
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return -1 }
        try? input.fileHandleForWriting.write(contentsOf: payload)
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Payload d'un `PostToolUse`, indenté comme Claude Code peut l'envoyer, avec une sortie d'outil volumineuse.
    private nonisolated static func payload(session: String, bytes: Int) -> Data {
        let object: [String: Any] = ["hook_event_name": "PostToolUse", "session_id": session, "cwd": "/tmp/projet", "tool_name": "Read",
                                     "tool_response": String(repeating: "lorem ipsum ", count: bytes / 12)]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])) ?? Data()
    }

    /// Sessions ou outils en parallèle : chaque événement reste une ligne entière, lisible, rattachée au processus
    /// qui a lancé le hook. Sans verrou, les trois écritures de chaque hook s'entremêlaient.
    @Test func hookScriptKeepsConcurrentEventsOnSeparateLines() throws {
        let sandbox = try hookSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox.dir) }
        let count = 8
        let statuses = OSAllocatedUnfairLock(initialState: [Int32]())
        let command = sandbox.command
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let status = Self.runHook(command, payload: Self.payload(session: "session-\(i)", bytes: 100_000))
            statuses.withLock { $0.append(status) }
        }
        #expect(statuses.withLock { $0 } == Array(repeating: 0, count: count))

        let lines = try String(contentsOf: sandbox.events, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == count)
        let events = lines.compactMap { ClaudeHookEvent.decode(line: $0, readAt: Date()) }
        #expect(Set(events.map(\.sessionID)) == Set((0..<count).map { "session-\($0)" }))
        #expect(events.allSatisfy { $0.kind == .postToolUse && $0.toolName == "Read" && $0.pid == ProcessInfo.processInfo.processIdentifier })
        let mode = try FileManager.default.attributesOfItem(atPath: sandbox.events.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    /// App fermée, le fichier n'est plus vidé : passé le plafond il repart de zéro au lieu de grossir sans fin.
    @Test func hookScriptStartsOverPastTheSizeCap() throws {
        let sandbox = try hookSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox.dir) }
        try Data(repeating: 0x78, count: ClaudeHookScript.eventsFileCap + 1).write(to: sandbox.events)
        #expect(Self.runHook(sandbox.command, payload: Self.payload(session: "after-cap", bytes: 1_000)) == 0)
        let lines = try String(contentsOf: sandbox.events, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 1)
        #expect(lines.first.flatMap { ClaudeHookEvent.decode(line: $0, readAt: Date()) }?.sessionID == "after-cap")
        // Sous le plafond, rien n'est effacé.
        #expect(Self.runHook(sandbox.command, payload: Self.payload(session: "next", bytes: 1_000)) == 0)
        #expect(try String(contentsOf: sandbox.events, encoding: .utf8).split(separator: "\n").count == 2)
    }

    // MARK: Modèle, sans fenêtre

    /// `hover = false` referme l'île quand le popover ou une carte s'ouvre : s'il ramenait aussi aux limites, les
    /// réglages ouverts hors de l'île (Mac sans encoche, capot fermé) se refermaient aussitôt.
    @Test func settingsOnlyResetWhenTheIslandReallyOpensOrCloses() {
        let model = AppModel()
        model.showSettings = true
        model.hover = false
        #expect(model.showSettings)
        model.hover = true
        #expect(!model.showSettings)
        model.showSettings = true
        model.hover = false
        #expect(!model.showSettings)
        // Sans île : « Réglages » du menu les montre dans le popover, qui s'ouvre sinon sur les limites.
        model.openSettingsFromMenu()
        #expect(model.showSettings)
        model.popoverWillOpen()
        #expect(!model.showSettings)
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
