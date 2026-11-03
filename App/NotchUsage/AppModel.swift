import AppKit
import Foundation
import NotchUsageCore
import Observation
import SwiftUI

/// Relie NotchUsageCore à l'UI : réglages, compte, états de relevé, alertes, interaction, écran, énergie.
@MainActor
@Observable
final class AppModel {
    // Dépendances
    @ObservationIgnored let credentials = AppCredentialStore()
    @ObservationIgnored let snapshots = FileSnapshotStore()
    @ObservationIgnored let http = URLSessionHTTPClient()
    @ObservationIgnored let defaults = UserDefaults.standard
    @ObservationIgnored let alertEvaluator = AlertEvaluator()
    @ObservationIgnored private(set) lazy var connection = ConnectionManager(credentials: credentials, claudeCode: ClaudeCodeKeychainReader(), http: http, snapshots: snapshots, defaults: defaults)
    @ObservationIgnored private let power = PowerObserver()
    @ObservationIgnored private let screens = ScreenObserver()
    @ObservationIgnored private let fullscreenObserver = FullscreenObserver()
    @ObservationIgnored private var panel: NotchPanelController?
    @ObservationIgnored private var coordinator: RefreshCoordinator?
    @ObservationIgnored private var stateTask: Task<Void, Never>?
    @ObservationIgnored private var alertTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var loginWindow: BrowserLoginWindow?

    // État
    private(set) var account: Account?
    private(set) var refreshSettings: RefreshSettings
    private(set) var alertSettings: AlertSettings
    private(set) var headlineChoice: HeadlineChoice
    private(set) var fetchState: FetchState = .idle(nil)
    /// Dernier état émis par le coordinateur (`fetchState` peut garder un échec pendant une nouvelle tentative).
    @ObservationIgnored private var lastReceivedState: FetchState = .idle(nil)
    private(set) var display: DisplayState
    /// Ce que l'encoche repliée montre sans survol (005), dérivé de `display`.
    private(set) var signal: NotchSignal
    private(set) var layout: NotchLayout
    /// Incrémenté à chaque alerte émise : déclenche une animation brève (T058).
    private(set) var alertPulse = 0
    var hover = false { didSet { recompute() } }
    var pinned = false { didSet { recompute() } }
    var fullscreen = false { didSet { recompute() } }
    var showSettings = false { didSet { recompute() } }
    /// Hauteur idéale du contenu déplié, mesurée par la vue (hors réglages).
    @ObservationIgnored private var expandedContentHeight: CGFloat = NotchPanelController.expandedHeight
    var isConnecting = false
    var connectionError: String?
    /// Prévisions affichées (003), stabilisées par l'hystérésis ; recalculées à chaque relevé réussi.
    private(set) var forecasts: [String: Forecast] = [:]
    @ObservationIgnored private var history = UsageHistory()
    @ObservationIgnored private var debouncer = ForecastDebouncer()
    @ObservationIgnored private var lastRecordedAt: Date?
    var claudeCodeAvailable = false
    var launchAtLoginStatus: LaunchAtLogin.Status = .disabled
    var now = Date()

    private static let accountKey = "account"
    private static let intervalKey = "refreshIntervalSeconds"
    private static let alertsKey = "alertSettings"
    private static let headlineKey = "headlineLimit"

    init() {
        let defaults = UserDefaults.standard
        var settings = RefreshSettings()
        if defaults.object(forKey: Self.intervalKey) != nil {
            settings.interval = .seconds(defaults.double(forKey: Self.intervalKey))
        }
        refreshSettings = settings
        if let data = defaults.data(forKey: Self.alertsKey), let a = try? JSONDecoder().decode(AlertSettings.self, from: data) {
            alertSettings = a
        } else {
            alertSettings = AlertSettings()
        }
        headlineChoice = HeadlineChoice(storedValue: defaults.string(forKey: Self.headlineKey))
        if let data = defaults.data(forKey: Self.accountKey), let a = try? JSONDecoder().decode(Account.self, from: data) {
            account = a
        }
        let initialLayout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        layout = initialLayout
        let initialDisplay = DisplayStateReducer.reduce(state: .idle(nil), connected: false, settings: settings, alertLevel: .none,
                                                        layout: initialLayout, fullscreen: false, hover: false, pinned: false, now: Date())
        display = initialDisplay
        signal = NotchSignal.make(display: initialDisplay, now: Date(), language: AppLanguage.current, strings: .app)
    }

    // MARK: Cycle de vie

    #if DEBUG
    /// Mode démo (build Debug) : valeurs fictives pour les captures du README, sans compte ni réseau.
    /// `com.notchusage.debug.demo` objet "normal" | "warning" | "critical" | "reauth" | "off".
    @ObservationIgnored private var demoState: FetchState?
    @ObservationIgnored private var demoForecasts: [String: Forecast] = [:]

    private func installDemoHook() {
        DistributedNotificationCenter.default().addObserver(forName: .init("com.notchusage.debug.demo"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "off"
            MainActor.assumeIsolated { self?.applyDemo(mode) }
        }
        // `com.notchusage.debug.layout` objet "pill" | "notch" : simule un écran sans encoche pour les captures.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.notchusage.debug.layout"), object: nil, queue: .main) { [weak self] note in
            let mode = (note.object as? String) ?? "notch"
            MainActor.assumeIsolated {
                guard let self, let current = self.screens.current else { return }
                let layout = mode == "pill"
                    ? NotchGeometry.layout(screenWidth: current.screen.frame.width, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
                    : current.layout
                self.applyScreen(ScreenObserver.Target(screen: current.screen, layout: layout))
            }
        }
    }

    private func applyDemo(_ mode: String) {
        let now = Date()
        func snapshot(_ session: Double, _ weekly: Double, _ model: Double,
                      sessionReset: TimeInterval = 2 * 3600 + 14 * 60, age: TimeInterval = 0) -> UsageSnapshot {
            UsageSnapshot(limits: [
                UsageLimit(id: "session", kind: .rollingFiveHour, modelName: nil, utilization: session, resetsAt: now.addingTimeInterval(sessionReset)),
                UsageLimit(id: "weekly_all", kind: .weeklyAll, modelName: nil, utilization: weekly, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
                UsageLimit(id: "weekly_scoped:Fable", kind: .weeklyModel, modelName: "Fable", utilization: model, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
            ], fetchedAt: now.addingTimeInterval(-age))
        }
        demoForecasts = [:]
        switch mode {
        case "normal": demoState = .idle(snapshot(42, 27, 35))
        case "far":
            demoState = .idle(snapshot(55, 30, 28, sessionReset: 4 * 3600))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(125 * 60))]
        case "near":
            demoState = .idle(snapshot(78, 30, 28))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(40 * 60))]
        case "imminent":
            demoState = .idle(snapshot(92, 30, 28, sessionReset: 3600))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(8 * 60))]
        case "pace":
            // Historique synthétique passé par le vrai calcul : 29 → 55 % en 40 min, reset dans 4 h.
            let current = snapshot(55, 30, 28, sessionReset: 4 * 3600)
            var synthetic = UsageHistory()
            for (minutesAgo, pct) in [(40.0, 29.0), (30, 36), (20, 42), (10, 49)] {
                synthetic = synthetic.appending(snapshot(pct, 30, 28, sessionReset: 4 * 3600, age: minutesAgo * 60))
            }
            synthetic = synthetic.appending(current)
            demoState = .idle(current)
            demoForecasts = PaceForecaster.forecasts(history: synthetic, snapshot: current, now: now)
        case "warning": demoState = .idle(snapshot(83, 38, 64))
        case "critical":
            demoState = .idle(snapshot(97, 52, 71))
            demoForecasts = ["session": .blockAt(now.addingTimeInterval(50 * 60))]
        case "blocked": demoState = .idle(snapshot(100, 52, 71, sessionReset: 3600 + 2 * 60))
        case "offline": demoState = .failed(.network(.notConnectedToInternet), previous: snapshot(42, 27, 35, sessionReset: 3600 + 49 * 60, age: 25 * 60))
        case "reauth": demoState = .reauthRequired(previous: nil)
        default: demoState = nil
        }
        self.now = now
        recompute()
    }
    #endif

    func start() {
        #if DEBUG
        installDemoHook()
        #endif
        claudeCodeAvailable = connection.isClaudeCodeAvailable
        launchAtLoginStatus = LaunchAtLogin.status
        history = (try? snapshots.loadHistory()) ?? UsageHistory()
        screens.onChange = { [weak self] target in self?.applyScreen(target) }
        screens.start()
        fullscreenObserver.onChange = { [weak self] isFullscreen in self?.fullscreen = isFullscreen }
        fullscreenObserver.start()
        power.onPause = { [weak self] reason in self?.pause(reason) }
        power.onResume = { [weak self] reason in self?.resume(reason) }
        power.start()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30), tolerance: .seconds(5))
                self?.now = Date()
                self?.recompute()
                await self?.recoverIfExpired()
            }
        }
        if let account, account.status == .connected {
            if account.connectionMethod == .claudeCode {
                // Le jeton n'est qu'en mémoire : relecture silencieuse avant le premier relevé.
                Task {
                    if await connection.recoverClaudeCodeToken() { startCoordinator(for: account) } else { markExpired() }
                }
            } else {
                startCoordinator(for: account)
            }
        }
        recompute()
    }

    func stop() {
        tickTask?.cancel()
        stateTask?.cancel()
        alertTask?.cancel()
        let c = coordinator
        Task { await c?.stop() }
        coordinator = nil
        power.stop()
        screens.stop()
        fullscreenObserver.stop()
        panel?.close()
        panel = nil
    }

    private func applyScreen(_ target: ScreenObserver.Target) {
        layout = target.layout
        fullscreenObserver.screen = target.screen
        if let panel {
            panel.update(target: target)
        } else {
            let controller = NotchPanelController(target: target, rootView: AnyView(NotchRootView().environment(self)))
            controller.onHoverChange = { [weak self] inside in self?.hover = inside }
            controller.onToggleClick = { [weak self] in self?.togglePinned() }
            controller.onDismiss = { [weak self] in self?.dismiss() }
            panel = controller
        }
        recompute()
    }

    // MARK: Relevés

    private func startCoordinator(for account: Account) {
        stateTask?.cancel()
        alertTask?.cancel()
        let old = coordinator
        Task { await old?.stop() }
        let evaluator = alertEvaluator
        let settings = alertSettings
        let c = RefreshCoordinator(provider: connection.makeProvider(for: account), policy: RefreshPolicy(settings: refreshSettings),
                                   store: snapshots, clock: SystemClock(),
                                   alertHook: { snapshot, ledger in evaluator.evaluate(snapshot, settings: settings, ledger: ledger ?? AlertLedger()) })
        coordinator = c
        let states = c.states
        stateTask = Task { [weak self] in
            for await state in states {
                guard let self else { return }
                Self.logReading(state, previous: self.lastReceivedState)
                self.lastReceivedState = state
                if case .idle(let snapshot?) = state { self.record(snapshot) }
                self.fetchState = self.fetchState.displayed(next: state)
                self.recompute()
                if case .reauthRequired = state { await self.handleReauth() }
            }
        }
        let alerts = c.alerts
        alertTask = Task { [weak self] in
            for await event in alerts {
                guard let self else { return }
                Log.refresh.notice("alert \(event.level.rawValue, privacy: .public) on \(event.limitID, privacy: .public)")
                self.alertPulse += 1
            }
        }
        Task { await c.start() }
    }

    /// Historique et prévision (003) : un relevé par instantané distinct, prévision stabilisée par l'hystérésis.
    private func record(_ snapshot: UsageSnapshot) {
        guard snapshot.fetchedAt != lastRecordedAt else { return }
        lastRecordedAt = snapshot.fetchedAt
        history = history.appending(snapshot)
        try? snapshots.saveHistory(history)
        let previous = forecasts
        forecasts = debouncer.push(PaceForecaster.forecasts(history: history, snapshot: snapshot, now: Date()))
        for (id, forecast) in forecasts where previous[id] != forecast {
            Log.refresh.notice("forecast \(id, privacy: .public): \(String(describing: forecast), privacy: .public)")
        }
    }

    /// Une ligne par relevé terminé : permet de compter les requêtes (budget, veille) sans rien de sensible.
    private static func logReading(_ state: FetchState, previous: FetchState) {
        var wasLoading = false
        if case .loading = previous { wasLoading = true }
        switch state {
        case .idle(let snap?) where wasLoading:
            let summary = snap.limits.map { "\($0.id)=\(Int($0.utilization))" }.joined(separator: " ")
            Log.refresh.notice("reading ok: \(summary, privacy: .public)")
        case .failed(let error, _):
            Log.refresh.notice("reading failed: \(String(describing: error), privacy: .public)")
        case .reauthRequired:
            Log.refresh.notice("reading needs reauth")
        case .unsupported:
            Log.refresh.notice("reading unsupported plan")
        default:
            break
        }
    }

    private func handleReauth() async {
        guard var account, account.connectionMethod == .claudeCode else { markExpired(); return }
        if await connection.recoverClaudeCodeToken() {
            account.status = .connected
            setAccount(account)
            startCoordinator(for: account)
        } else {
            markExpired()
        }
    }

    /// Tant que le jeton de Claude Code est expiré, relit le Trousseau sans dialogue à chaque tick (30 s).
    private func recoverIfExpired() async {
        guard let account, account.connectionMethod == .claudeCode, account.status == .expired, !isConnecting else { return }
        await handleReauth()
    }

    private func markExpired() {
        guard var account else { return }
        account.status = .expired
        setAccount(account)
    }

    func refreshNow() {
        now = Date()
        let c = coordinator
        Task { await c?.refreshNow() }
    }

    private func pause(_ reason: PauseReason) {
        let c = coordinator
        Task { await c?.pause(reason: reason) }
    }

    private func resume(_ reason: PauseReason) {
        now = Date()
        let c = coordinator
        Task { await c?.resume(reason: reason) }
        recompute()
    }

    // MARK: Connexion

    func connectWithClaudeCode() {
        Log.auth.notice("connect requested: Claude Code (busy \(self.isConnecting))")
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        Task {
            defer { isConnecting = false }
            do {
                let account = try await connection.connectWithClaudeCode()
                setAccount(account)
                startCoordinator(for: account)
            } catch ConnectionError.claudeCodeExpired(let plan) {
                // Sans ce message, un nouvel essai sur l'écran de reconnexion ne change rien de visible.
                if account?.status == .expired {
                    connectionError = String(localized: "The Claude Code session is still expired. Run claude in Terminal, then try again.")
                }
                fetchState = .idle(nil)
                setAccount(Account(connectionMethod: .claudeCode, subscriptionType: plan, status: .expired,
                                   credentialRef: CredentialKey.oauthAccessToken.rawValue, connectedAt: Date()))
            } catch {
                connectionError = error.localizedDescription
                Log.auth.error("Claude Code connection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Reconnexion par la voie déjà choisie (étiquette « Sign in » de l'encoche).
    func reconnect() {
        if account?.connectionMethod == .browser || !claudeCodeAvailable { connectWithBrowser() } else { connectWithClaudeCode() }
    }

    func connectWithBrowser() {
        Log.auth.notice("connect requested: browser (window open \(self.loginWindow != nil))")
        connectionError = nil
        // Le panneau déplié passe au-dessus de la fenêtre de connexion : on le replie, au tour suivant
        // car le clic sur ce bouton épingle ensuite le panneau (NotchPanel.sendEvent).
        DispatchQueue.main.async { [weak self] in
            self?.dismiss()
            self?.hover = false
        }
        // Sans icône dans le Dock, ce bouton est le seul moyen de retrouver la fenêtre déjà ouverte.
        if let loginWindow { loginWindow.bringToFront(); return }
        let window = BrowserLoginWindow(
            onCaptured: { [weak self] key, org in
                self?.loginWindow = nil
                self?.applySessionKey(key, preferredOrganization: org)
            },
            onCancelled: { [weak self] in
                self?.loginWindow = nil
            })
        loginWindow = window
        window.show()
    }

    func applySessionKey(_ key: String, preferredOrganization: String? = nil) {
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        Task {
            defer { isConnecting = false }
            do {
                let account = try await connection.connectWithSessionKey(key, preferredOrganization: preferredOrganization)
                setAccount(account)
                startCoordinator(for: account)
            } catch {
                connectionError = error.localizedDescription
                Log.auth.error("browser connection failed: \(error.localizedDescription, privacy: .public)")
                if case ConnectionError.fetch(.unauthorized) = error { await BrowserLoginWindow.clearClaudeCookies() }
            }
        }
    }

    func signOut() {
        stateTask?.cancel()
        alertTask?.cancel()
        let c = coordinator
        Task { await c?.stop() }
        coordinator = nil
        connection.signOut()
        history = UsageHistory()
        debouncer = ForecastDebouncer()
        forecasts = [:]
        lastRecordedAt = nil
        Task { await BrowserLoginWindow.clearClaudeCookies() }
        setAccount(nil)
        fetchState = .idle(nil)
        lastReceivedState = .idle(nil)
        showSettings = false
        pinned = false
        recompute()
    }

    private func setAccount(_ account: Account?) {
        self.account = account
        if account?.status == .connected { connectionError = nil }
        if let account, let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: Self.accountKey)
        } else {
            defaults.removeObject(forKey: Self.accountKey)
        }
        recompute()
    }

    // MARK: Réglages

    func setRefreshInterval(seconds: Double) {
        refreshSettings.interval = .seconds(seconds)
        defaults.set(refreshSettings.interval.components.seconds, forKey: Self.intervalKey)
        restartIfConnected()
    }

    func setAlertsEnabled(_ enabled: Bool) {
        alertSettings.enabled = enabled
        saveAlertSettings()
    }

    func setWarningThreshold(_ value: Int) {
        alertSettings.setWarning(value)
        saveAlertSettings()
    }

    func setCriticalThreshold(_ value: Int) {
        alertSettings.setCritical(value)
        saveAlertSettings()
    }

    /// Les nouveaux seuils s'appliquent au cycle suivant (US2 sc. 4) : le hook capture la valeur.
    private func saveAlertSettings() {
        if let data = try? JSONEncoder().encode(alertSettings) { defaults.set(data, forKey: Self.alertsKey) }
        restartIfConnected()
        recompute()
    }

    func setHeadlineChoice(_ choice: HeadlineChoice) {
        headlineChoice = choice
        defaults.set(choice.storedValue, forKey: Self.headlineKey)
        recompute()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginStatus = LaunchAtLogin.set(enabled: enabled)
    }

    private func restartIfConnected() {
        if let account, account.status == .connected { startCoordinator(for: account) }
    }

    // MARK: Interaction

    func togglePinned() {
        pinned.toggle()
        if !pinned { showSettings = false }
    }

    func dismiss() {
        pinned = false
        showSettings = false
    }

    // MARK: Dérivation

    private func recompute() {
        var connected = account != nil && account?.status != .disconnected
        var state: FetchState = (account?.status == .expired) ? .reauthRequired(previous: nil) : fetchState
        #if DEBUG
        if let demo = demoState { state = demo; connected = true }
        #endif
        // Pastille et point d'alerte suivent la limite affichée, pas la plus haute de toutes (004).
        let level = state.snapshot.flatMap { headlineChoice.pick(in: $0, forecasts: forecasts) }
            .map { alertEvaluator.level(for: $0, settings: alertSettings) } ?? .none
        display = DisplayStateReducer.reduce(state: state, connected: connected, settings: refreshSettings, alertLevel: level,
                                             layout: layout, fullscreen: fullscreen, hover: hover, pinned: pinned, now: now,
                                             forecasts: forecasts, choice: headlineChoice)
        #if DEBUG
        if demoState != nil { display.forecasts = demoForecasts }
        #endif
        signal = NotchSignal.make(display: display, now: now, language: AppLanguage.current, strings: .app)
        panel?.contentHeight = expandedContentHeight
        panel?.showsSettings = showSettings
        // Dans l'encoche, seule la bande élargit le panneau ; le liseré seul reste à la largeur de l'encoche.
        let narrow = signal.isSilent || (display.mode == .notch && !signal.isBand)
        panel?.apply(display, narrow: narrow, edgePad: display.mode == .notch ? (signal.edge?.outerPad ?? 0) : 0)
    }

    func setExpandedContentHeight(_ height: CGFloat) {
        guard !showSettings, height > 40 else { return }
        let clamped = min(height.rounded(.up), 480)
        guard abs(clamped - expandedContentHeight) > 0.5 else { return }
        expandedContentHeight = clamped
        recompute()
    }
}
