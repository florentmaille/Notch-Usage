import Foundation
import NotchUsageCore
import Observation

/// Suivi des sessions Claude Code (017), sorti d'`AppModel` : le réglage et ses entrées dans
/// `~/.claude/settings.json`, le lecteur du fil d'événements, les sessions en attente (conservées sur disque) et la
/// notification facultative. Ni fenêtre ni écran ici : le modèle de l'app branche `onChange` et `notify`.
@MainActor
@Observable
final class ClaudeFollowing {
    /// Ce dont le suivi dépend hors de lui (processus, horloge, fichier, préférences), remplaçable dans les tests.
    struct Environment {
        var defaults: UserDefaults = .standard
        var sessionsURL: URL = ClaudeSessionsFile.defaultURL
        var now: () -> Date = { Date() }
        var bootDate: () -> Date? = { ProcessLiveness.bootDate }
        var isAlive: (Int32) -> Bool = { ProcessLiveness.isAlive($0) }
        /// Processus de la session à partir de celui qui a lancé le hook (un shell, parfois).
        var sessionProcess: (Int32) -> Int32 = { ProcessLiveness.sessionProcess(from: $0) }
        /// Identifiant de bundle de l'application qui porte la fenêtre de la session.
        var originApp: (Int32) -> String? = { ProcessLiveness.originApp(of: $0)?.bundleIdentifier }
    }

    static let followsKey = "followsClaudeCode"
    static let notifiesKey = "notifiesClaudeAttention"

    @ObservationIgnored private let environment: Environment
    /// Les sessions ou le réglage ont changé : l'app recalcule ce qu'elle affiche.
    @ObservationIgnored var onChange: () -> Void = {}
    /// Demande de notification pour une approbation ou une question (nom de la session, nature, identifiant).
    @ObservationIgnored var notify: (String, ClaudeWaitingKind, String) -> Void = { _, _, _ in }
    @ObservationIgnored private var watcher: ClaudeEventsWatcher?
    @ObservationIgnored private var arrivalTask: Task<Void, Never>?

    /// Écrites sur disque à chaque changement : une attente en cours survit au redémarrage de l'app.
    private(set) var sessions = ClaudeSessionTracker() {
        didSet { if sessions != oldValue { ClaudeSessionsFile.save(sessions, to: environment.sessionsURL) } }
    }
    private(set) var follows: Bool
    private(set) var notifiesAttention: Bool
    private(set) var hooksStatus: ClaudeSettingsFile.Status = .absent
    var hooksError: String?

    #if DEBUG
    /// Sessions du mode démo (captures) : affichées à la place des vraies, jamais écrites sur disque.
    @ObservationIgnored var demoSessions: ClaudeSessionTracker?
    #endif

    init(environment: Environment = Environment()) {
        self.environment = environment
        follows = environment.defaults.bool(forKey: Self.followsKey)
        notifiesAttention = environment.defaults.bool(forKey: Self.notifiesKey)
    }

    /// Sessions montrées : celles de la démo en build Debug, sinon les vraies.
    var visibleSessions: ClaudeSessionTracker {
        #if DEBUG
        if let demoSessions { return demoSessions }
        #endif
        return sessions
    }

    // MARK: Cycle de vie

    /// Au lancement de l'app : statut des entrées, puis lecteur si le réglage est actif.
    func start() {
        refreshHooksStatus()
        if follows {
            migrateLegacyHooks()
            startWatcher()
        }
    }

    func stop() {
        arrivalTask?.cancel()
        watcher?.stop()
        watcher = nil
    }

    private func startWatcher() {
        guard watcher == nil else { return }
        do {
            try ClaudeHookScript.ensure()
        } catch {
            Log.app.error("claude hook script: \(error.localizedDescription, privacy: .public)")
        }
        restoreSessions()
        let watcher = ClaudeEventsWatcher(url: ClaudeHookScript.eventsURL) { [weak self] events in self?.handle(events) }
        self.watcher = watcher
        watcher.start()
    }

    /// Attentes d'avant le redémarrage de l'app : relues sans les sessions dont le processus a disparu. Les
    /// événements écrits pendant la fermeture s'appliquent ensuite par-dessus, au démarrage du lecteur.
    func restoreSessions() {
        guard let saved = ClaudeSessionsFile.load(from: environment.sessionsURL) else { return }
        sessions = saved.restored(now: environment.now(), bootedAt: environment.bootDate() ?? .distantPast, alive: environment.isAlive)
        Log.app.notice("claude sessions restored: \(self.sessions.waiting.count, privacy: .public) waiting")
    }

    private func stopWatcher() {
        watcher?.stop()
        watcher = nil
        arrivalTask?.cancel()
        sessions = ClaudeSessionTracker()
    }

    /// Les versions 0.5.4 à 0.6.1 écrivaient le chemin du script sans apostrophes : le shell le coupait à l'espace de
    /// « Application Support » et aucun événement n'arrivait. Le réglage est déjà actif : les entrées sont remplacées
    /// au lancement, sans clic. En cas d'échec, la note « Réparer » des réglages reste.
    private func migrateLegacyHooks() {
        let path = ClaudeHookScript.scriptURL.path
        guard ClaudeSettingsFile.hasLegacyEntries(scriptPath: path) else { return }
        do {
            try ClaudeHookScript.ensure()
            try ClaudeSettingsFile.install(scriptPath: path)
            Log.app.notice("claude hooks migrated to the quoted command")
        } catch {
            Log.app.error("claude hooks migration: \(error.localizedDescription, privacy: .public)")
        }
        refreshHooksStatus()
    }

    // MARK: Événements

    /// Réduit les événements reçus, résout l'application d'origine des sessions nouvelles, retire les sessions
    /// mortes, relance le libellé d'arrivée (4 s) et notifie si demandé.
    func handle(_ events: [ClaudeHookEvent]) {
        let previous = sessions.attention(now: environment.now())?.arrivedAt
        var tracker = sessions
        for event in events {
            // La vivacité se vérifie sur le processus de la session : si un shell a lancé le hook, on remonte à son
            // parent avant de réduire (le tracker ignore les événements sans type, on ne peut pas corriger après).
            let event = event.withPID(event.pid.map(environment.sessionProcess))
            tracker = tracker.reduce(event)
            if let session = tracker.sessions[event.sessionID], session.originApp == nil, let pid = event.pid {
                tracker = tracker.settingOrigin(app: environment.originApp(pid), for: event.sessionID)
            }
            if notifiesAttention, event.kind == .permissionRequest, let session = tracker.sessions[event.sessionID] {
                notify(session.displayName(fallback: CompactStrip.Strings.app.claude.sessionFallback),
                       event.isQuestion ? .question : .approval, "\(event.sessionID)-\(event.promptID ?? "")")
            }
        }
        let now = environment.now()
        sessions = tracker.expire(now: now, alive: environment.isAlive)
        if let arrived = sessions.attention(now: now)?.arrivedAt, arrived != previous, AttentionFormat.showsArrival(arrivedAt: arrived, now: now) {
            arrivalTask?.cancel()
            arrivalTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(AttentionFormat.arrivalDuration), tolerance: .milliseconds(50))
                guard !Task.isCancelled else { return }
                self?.onChange()
            }
        }
        Log.app.notice("claude events: \(events.count, privacy: .public) received, \(self.sessions.waiting.count, privacy: .public) waiting")
        onChange()
    }

    /// Au survol : les sessions dont le processus a disparu sont retirées (017, R7), jamais sur un timer.
    func expireDeadSessions() {
        sessions = sessions.expire(now: environment.now(), alive: environment.isAlive)
    }

    /// Clic sur une ligne du panneau ou du menu : l'application d'où vient la session passe devant ; l'attente reste.
    /// Faux si la session n'est plus suivie.
    @discardableResult
    func activateSession(_ id: String) -> Bool {
        guard let session = visibleSessions.sessions[id] else { return false }
        if let app = session.originApp { ProcessLiveness.activate(bundleID: app) }
        return true
    }

    /// Clic sur l'île ou la pastille, popover refermé : les « terminé » s'effacent, les attentes bloquantes restent
    /// (017, FR-002).
    func clearDone() {
        sessions = sessions.clearDone()
        #if DEBUG
        demoSessions = demoSessions?.clearDone()
        #endif
        onChange()
    }

    // MARK: Réglage

    func setFollows(_ enabled: Bool) {
        hooksError = nil
        do {
            if enabled {
                try ClaudeHookScript.ensure()
                try ClaudeSettingsFile.install(scriptPath: ClaudeHookScript.scriptURL.path)
            } else {
                try ClaudeSettingsFile.remove(scriptPath: ClaudeHookScript.scriptURL.path)
            }
        } catch {
            hooksError = error.localizedDescription
            Log.app.error("claude hooks: \(error.localizedDescription, privacy: .public)")
            refreshHooksStatus()
            onChange()
            return
        }
        follows = enabled
        environment.defaults.set(enabled, forKey: Self.followsKey)
        if enabled { startWatcher() } else { stopWatcher() }
        refreshHooksStatus()
        Log.app.notice("claude hooks \(enabled ? "installed" : "removed", privacy: .public)")
        onChange()
    }

    func setNotifiesAttention(_ enabled: Bool) {
        notifiesAttention = enabled
        environment.defaults.set(enabled, forKey: Self.notifiesKey)
    }

    /// Entrées modifiées à la main : réinstaller remet les manquantes sans doubler les présentes.
    func repairHooks() { setFollows(true) }

    func refreshHooksStatus() {
        hooksStatus = ClaudeSettingsFile.status(scriptPath: ClaudeHookScript.scriptURL.path)
    }
}
