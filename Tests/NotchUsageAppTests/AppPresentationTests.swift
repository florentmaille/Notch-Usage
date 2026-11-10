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
        let errors: [ConnectionError] = [.claudeCodeUnavailable, .claudeCodeAccessDenied, .claudeCodeMalformed, .claudeCodeExpired(.max),
                                         .claudeCodeRenewalFailed(.notFound), .claudeCodeRenewalFailed(.notLoggedIn),
                                         .claudeCodeRenewalFailed(.timedOut), .claudeCodeRenewalFailed(.failed), .invalidSessionKey,
                                         .fetch(.unauthorized), .fetch(.unsupported), .fetch(.challenge), .fetch(.malformed)]
        for e in errors { #expect(!(e.errorDescription ?? "").isEmpty) }
        // Accès refusé et session introuvable ne se disent pas de la même façon ; les quatre échecs du CLI non plus.
        #expect(ConnectionError.claudeCodeAccessDenied.errorDescription != ConnectionError.claudeCodeUnavailable.errorDescription)
        #expect(Set(errors.compactMap(\.errorDescription)).count == errors.count)
    }

    @Test func islandTintsFollowTheEdgeColours() {
        #expect(NotchSignal.Island.Tint.calm.edge == nil)
        #expect(NotchSignal.Island.Tint.near.color == NotchSignal.Edge.near.color)
        #expect(NotchSignal.Island.Tint.exhausted.edge?.hasHalo == true && NotchSignal.Island.Tint.far.edge?.hasHalo == false)
        // L'île tient dans l'encoche et deux oreilles : au plus 104 pt de plus (012, SC-002).
        #expect(2 * NotchPanelController.earWidth <= 104)
    }

    /// Plein écran : la bande de survol est le haut de l'île qu'elle fait réapparaître. Plus large, le pointeur
    /// posé au bout de la bande se retrouvait hors de l'île, qui se refermait puis se rouvrait en boucle.
    @Test func fullscreenStripIsTheTopOfTheIslandItReveals() {
        let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let layout = NotchLayout.fallback
        let widths: [(left: CGFloat, right: CGFloat)] = [(52, 0), (52, 52), (52, 116)]
        for ears in widths {
            let island = NotchPanelController.islandFrame(layout: layout, ears: ears, screen: screen, hidden: false)
            let strip = NotchPanelController.islandFrame(layout: layout, ears: ears, screen: screen, hidden: true)
            #expect(island.contains(strip))
            #expect(strip.width == island.width && strip.height == NotchPanelController.hiddenStripHeight && strip.maxY == screen.maxY)
            #expect(island.width == layout.width + ears.left + ears.right && island.height == layout.height)
        }
    }

    /// La carte prend la hauteur de son contenu tant qu'elle tient au-dessus du Dock ; au-delà, elle s'arrête à 8 pt.
    @Test func cardHeightFollowsItsContentUpToTheScreen() {
        // Réglages « Avancé » dépliés en français : 600 pt, sous une encoche de 32 pt et 6 pt d'écart.
        #expect(CardLayout.height(measured: 599.4, top: 944, floor: 70) == 600)
        #expect(CardLayout.height(measured: 600, top: 500, floor: 70) == 422)
        #expect(CardLayout.height(measured: 600, top: 100, floor: 70) == CardLayout.minimumHeight)
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
        // Fichiers de données en 600, comme le fil d'événements et les sessions.
        for name in ["snapshot.json", "history.json", "weekly.json"] {
            #expect(try fm.attributesOfItem(atPath: dir.appending(path: name).path)[.posixPermissions] as? Int == 0o600)
        }

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

    /// App fermée, le script n'écrit rien : le texte des conversations ne reste pas sur disque jusqu'au prochain
    /// lancement. (Les autres tests tournent dans l'hôte de test, un processus `NotchUsage` : le script y écrit.)
    @Test func hookScriptWritesNothingWhileTheAppIsNotRunning() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notch usage fermée \(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let script = dir.appending(path: "claude-hook.sh"), events = dir.appending(path: "claude-events.jsonl")
        try ClaudeHookScript.contents(eventsPath: events.path, appProcess: "NotchUsageAbsent").write(to: script, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        #expect(Self.runHook(ClaudeHooksInstaller.command(for: script.path), payload: Self.payload(session: "closed", bytes: 1_000)) == 0)
        #expect(!fm.fileExists(atPath: events.path))
        #expect(ClaudeHookScript.contents(eventsPath: events.path).contains("/usr/bin/pgrep -x 'NotchUsage' "))
    }

    /// App en marche mais fichier non vidé (suivi bloqué) : passé le plafond il repart de zéro au lieu de grossir sans fin.
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

    /// Une attente en cours survit au redémarrage de l'app : le suivi est écrit sur disque (droits 600), relu au
    /// lancement sans les sessions dont le processus a disparu, et le fichier s'efface quand plus rien n'est suivi.
    @Test func claudeSessionsSurviveARestartOnDisk() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notchusage-sessions-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appending(path: "claude-sessions.json")
        let at = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        func request(_ session: String, pid: Int32) -> ClaudeHookEvent {
            ClaudeHookEvent(kind: .permissionRequest, sessionID: session, cwd: "/tmp/projet", sessionTitle: nil, toolName: "Write",
                            promptID: "p", pid: pid, receivedAt: at)
        }
        // Notre propre processus vit ; le pid 1 du second est remplacé par un pid qui n'existe pas.
        let alive = ProcessInfo.processInfo.processIdentifier
        let tracker = ClaudeSessionTracker().reduce(request("vivante", pid: alive)).reduce(request("terminée", pid: 2_000_000_000))
        ClaudeSessionsFile.save(tracker, to: url)
        #expect(try fm.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int == 0o600)
        #expect(ClaudeSessionsFile.load(from: url) == tracker)

        let boot = try #require(ProcessLiveness.bootDate)
        #expect(boot < Date())
        let restored = try #require(ClaudeSessionsFile.load(from: url)).restored(now: Date(), bootedAt: boot, alive: ProcessLiveness.isAlive)
        #expect(Set(restored.sessions.keys) == ["vivante"])
        #expect(restored.sessions["vivante"]?.waiting?.kind == .approval)

        ClaudeSessionsFile.save(ClaudeSessionTracker(), to: url)
        #expect(!fm.fileExists(atPath: url.path) && ClaudeSessionsFile.load(from: url) == nil)
    }

    // MARK: Suivi Claude Code, sans processus ni fichier réels

    /// Suivi isolé d'`AppModel` : horloge, processus, préférences et fichier de sessions sont fournis par le test.
    private func following(dir: URL, now: Date, notifies: Bool, alive: @escaping (Int32) -> Bool) -> (ClaudeFollowing, UserDefaults, String) {
        let suite = "notchusage.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(notifies, forKey: ClaudeFollowing.notifiesKey)
        var environment = ClaudeFollowing.Environment()
        environment.defaults = defaults
        environment.sessionsURL = dir.appending(path: "claude-sessions.json")
        environment.now = { now }
        environment.bootDate = { now.addingTimeInterval(-3600) }
        environment.isAlive = alive
        environment.startedAt = { _ in nil }
        // 101 : le shell qui a lancé le hook ; 500 : le processus de la session, dans le Terminal.
        environment.sessionProcess = { $0 == 101 ? 500 : $0 }
        environment.originApp = { $0 == 500 ? "com.apple.Terminal" : nil }
        return (ClaudeFollowing(environment: environment), defaults, suite)
    }

    private func hookEvent(_ kind: ClaudeHookEvent.Kind, session: String = "s1", tool: String? = "Write", pid: Int32? = 101, at: Date) -> ClaudeHookEvent {
        ClaudeHookEvent(kind: kind, sessionID: session, cwd: "/tmp/projet", sessionTitle: nil, toolName: tool, promptID: "p1", pid: pid, receivedAt: at)
    }

    /// Une demande de permission devient une attente rattachée au processus de la session, notifiée une fois,
    /// écrite sur disque ; le tour terminé puis le clic l'effacent ; la session disparaît avec son processus.
    @Test func claudeFollowingTracksNotifiesAndPersistsASession() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notchusage-following-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: 1_762_776_000)
        var alive: Set<Int32> = [500]
        let (following, defaults, suite) = following(dir: dir, now: now, notifies: true, alive: { alive.contains($0) })
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = dir.appending(path: "claude-sessions.json")
        var changes = 0
        var notified: [(name: String, kind: ClaudeWaitingKind, id: String)] = []
        following.onChange = { changes += 1 }
        following.notify = { notified.append(($0, $1, $2)) }

        following.handle([hookEvent(.permissionRequest, at: now)])
        let session = try #require(following.sessions.sessions["s1"])
        #expect(session.originPID == 500 && session.originApp == "com.apple.Terminal")
        #expect(session.waiting?.kind == .approval && following.visibleSessions.waiting.count == 1)
        #expect(notified.count == 1 && notified.first?.kind == .approval && notified.first?.id == "s1-p1" && notified.first?.name == "projet")
        #expect(changes == 1)
        #expect(ClaudeSessionsFile.load(from: url) == following.sessions)

        // Permission accordée, tour terminé : coche, sans nouvelle notification ; le clic l'efface.
        following.handle([hookEvent(.postToolUse, at: now), hookEvent(.stop, tool: nil, at: now)])
        #expect(following.sessions.sessions["s1"]?.waiting?.kind == .done && notified.count == 1)
        following.clearDone()
        #expect(following.sessions.waiting.isEmpty && changes == 3)

        // Terminal fermé : au survol suivant la session disparaît, et le fichier avec elle.
        alive = []
        following.expireDeadSessions()
        #expect(following.sessions.isEmpty && !fm.fileExists(atPath: url.path))
    }

    /// Au lancement, les attentes écrites avant la fermeture reviennent, sans celles dont le processus a disparu ;
    /// réglage de notification éteint, rien n'est notifié.
    @Test func claudeFollowingRestoresPendingSessionsAndStaysQuietWhenAskedTo() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "notchusage-following-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: 1_762_776_000)
        let (first, defaults, suite) = following(dir: dir, now: now, notifies: false, alive: { _ in true })
        defer { defaults.removePersistentDomain(forName: suite) }
        var notified = 0
        first.notify = { _, _, _ in notified += 1 }
        first.handle([hookEvent(.permissionRequest, session: "vivante", at: now),
                      hookEvent(.permissionRequest, session: "terminée", pid: 900, at: now)])
        #expect(notified == 0 && first.sessions.waiting.count == 2)

        // Nouvelle instance, comme après un redémarrage de l'app : le processus 900 n'existe plus.
        let (second, defaults2, suite2) = following(dir: dir, now: now.addingTimeInterval(120), notifies: false, alive: { $0 == 500 })
        defer { defaults2.removePersistentDomain(forName: suite2) }
        #expect(second.sessions.isEmpty)
        second.restoreSessions()
        #expect(second.sessions.waiting.map(\.id) == ["vivante"])
        #expect(second.sessions.sessions["vivante"]?.waiting?.kind == .approval)
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
        model.surfaceWillOpen(.popover)
        #expect(!model.showSettings)
        // La carte d'une pastille qui s'ouvre referme l'île et ramène aux limites, comme le popover.
        model.hover = true
        model.showSettings = true
        model.surfaceWillOpen(.capsule(screenID: "dell"))
        #expect(!model.hover && !model.showSettings)
    }

    /// Surfaces sans fenêtre ni écran : rien à ouvrir, aucune adaptation de l'île, et la hauteur mesurée du contenu
    /// n'est retenue que si elle change vraiment (une mesure transitoire sous 40 pt est ignorée).
    @Test func surfacesWithoutScreensHoldNothing() {
        let surfaces = Surfaces()
        #expect(!surfaces.hasIsland && !surfaces.islandCarriesPercent)
        #expect(surfaces.layout == .fallback)
        #expect(!surfaces.setContentHeight(20))
        #expect(surfaces.setContentHeight(599.4))
        #expect(!surfaces.setContentHeight(600))
        #expect(surfaces.setContentHeight(410))
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
