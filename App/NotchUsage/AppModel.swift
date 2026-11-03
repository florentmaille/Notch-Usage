import AppKit
import Foundation
import NotchUsageCore
import Observation
import SwiftUI
import os

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
    @ObservationIgnored private(set) lazy var connection = ConnectionManager(credentials: credentials, claudeCode: ClaudeCodeKeychainReader(), http: http, snapshots: snapshots, defaults: defaults,
                                                                                     log: { Log.auth.notice("\($0, privacy: .public)") })
    @ObservationIgnored private let power = PowerObserver()
    @ObservationIgnored let screens = ScreenObserver()
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
    @ObservationIgnored private let notifier = SignalNotifier()
    private(set) var fetchState: FetchState = .idle(nil)
    /// Dernier état émis par le coordinateur (`fetchState` peut garder un échec pendant une nouvelle tentative).
    @ObservationIgnored private var lastReceivedState: FetchState = .idle(nil)
    private(set) var display: DisplayState
    /// Ce que l'encoche repliée montre sans survol (005), dérivé de `display`.
    private(set) var signal: NotchSignal
    private(set) var layout: NotchLayout
    /// Incrémenté à chaque alerte émise : déclenche une animation brève (T058).
    /// Battements du halo (006) : incrémenté sur le tick de 30 s selon `signal.pulse`, jamais remis à zéro.
    /// Battements du halo (006) : `BeatCounter` sur le tick de 30 s, jamais remis à zéro.
    private var beatCounter = BeatCounter()
    var beat: Int { beatCounter.beats }
    /// Raisons de pause en cours (veille, verrou, économie d'énergie) : le tick n'y recalcule rien.
    @ObservationIgnored private var pausedReasons: Set<PauseReason> = []
    /// Réglages d'alerte lus par le hook du coordinateur à chaque relevé : un changement de seuil ne redémarre rien.
    @ObservationIgnored private let alertSettingsBox: OSAllocatedUnfairLock<AlertSettings>
    var hover = false { didSet { recompute() } }
    var pinned = false { didSet { recompute() } }
    var fullscreen = false { didSet { recompute() } }
    var showSettings = false { didSet { recompute() } }
    /// Hauteur idéale du contenu déplié, mesurée par la vue (hors réglages).
    @ObservationIgnored private var expandedContentHeight: CGFloat = NotchPanelController.expandedHeight
    var isConnecting = false
    /// Renouvellement de Claude Code en cours (011) : libellé du bouton.
    private(set) var isRenewing = false
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

    init() {
        let defaults = UserDefaults.standard
        var settings = RefreshSettings()
        if defaults.object(forKey: Self.intervalKey) != nil {
            settings.interval = .seconds(defaults.double(forKey: Self.intervalKey))
        }
        refreshSettings = settings
        let storedAlerts = defaults.data(forKey: Self.alertsKey).flatMap { try? JSONDecoder().decode(AlertSettings.self, from: $0) } ?? AlertSettings()
        alertSettings = storedAlerts
        alertSettingsBox = OSAllocatedUnfairLock(initialState: storedAlerts)
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
    /// Mode démo (build Debug) : voir `AppModel+Demo.swift`.
    @ObservationIgnored var demoState: FetchState?
    @ObservationIgnored var demoForecasts: [String: Forecast] = [:]
    @ObservationIgnored var demoObservers: [any NSObjectProtocol] = []
    #endif

    func start() {
        #if DEBUG
        installDemoHook()
        #endif
        // Les versions antérieures à 0.4.1 laissaient le cookie de session sur disque (007).
        Task { await BrowserLoginWindow.purgeBrowserData() }
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
                self?.tick()
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
        // Appelé à la terminaison : le processus s'arrête, inutile d'attendre l'arrêt du coordinateur.
        coordinator = nil
        #if DEBUG
        demoObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        demoObservers = []
        #endif
        power.stop()
        screens.stop()
        fullscreenObserver.stop()
        panel?.close()
        panel = nil
    }

    func applyScreen(_ target: ScreenObserver.Target) {
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
        let box = alertSettingsBox
        let c = RefreshCoordinator(provider: connection.makeProvider(for: account), policy: RefreshPolicy(settings: refreshSettings),
                                   store: snapshots, clock: SystemClock(),
                                   alertHook: { snapshot, ledger in evaluator.evaluate(snapshot, settings: box.withLock { $0 }, ledger: ledger ?? AlertLedger()) })
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
                guard self != nil else { return }
                Log.refresh.notice("alert \(event.level.rawValue, privacy: .public) on \(event.limitID, privacy: .public)")
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

    /// Tick de 30 s : avance l'heure, recalcule, puis compte un battement d'après le rythme lu *avant* le recalcul,
    /// pour que le tick qui fait entrer l'état imminent ne batte pas (006, R3). Une minute = un tick sur deux.
    /// Tick de 30 s : rien pendant une pause (veille, verrou) ; sinon recalcul puis cadence du battement d'après le
    /// rythme lu avant le recalcul (006, R3).
    func tick() {
        guard pausedReasons.isEmpty else { return }
        let rhythm = signal.pulse
        recompute()
        beatCounter.tick(rhythm: rhythm)
    }

    private func pause(_ reason: PauseReason) {
        pausedReasons.insert(reason)
        let c = coordinator
        Task { await c?.pause(reason: reason) }
    }

    private func resume(_ reason: PauseReason) {
        pausedReasons.remove(reason)
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

    /// Renouvelle la session de Claude Code en lançant son CLI en arrière-plan, puis reconnecte (011).
    func renewClaudeCodeSession() {
        guard !isConnecting else { return }
        isConnecting = true
        isRenewing = true
        connectionError = nil
        Task {
            let outcome = await ClaudeCodeRenewer.renew()
            Log.auth.notice("Claude Code renewal: \(String(describing: outcome), privacy: .public)")
            isRenewing = false
            isConnecting = false
            switch outcome {
            case .renewed:
                connectWithClaudeCode()
            case .notFound:
                connectionError = String(localized: "Claude Code was not found on this Mac. Run claude in Terminal, or sign in with your browser.")
            case .notLoggedIn:
                connectionError = String(localized: "Claude Code is signed out. Run claude in Terminal and sign in, or use your browser.")
            case .timedOut:
                connectionError = String(localized: "Claude Code did not answer in time. Try again, or run claude in Terminal.")
            case .failed:
                connectionError = String(localized: "Claude Code could not renew its session. Run claude in Terminal, or sign in with your browser.")
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
                if case ConnectionError.fetch(.unauthorized) = error { await BrowserLoginWindow.purgeBrowserData() }
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
        Task { await BrowserLoginWindow.purgeBrowserData() }
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

    func setNotificationsEnabled(_ enabled: Bool) {
        alertSettings.notifications = enabled
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

    /// Les nouveaux seuils s'appliquent au relevé suivant (US2 sc. 4) : le hook lit la boîte, sans redémarrage.
    private func saveAlertSettings() {
        if let data = try? JSONEncoder().encode(alertSettings) { defaults.set(data, forKey: Self.alertsKey) }
        let current = alertSettings
        alertSettingsBox.withLock { $0 = current }
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

    func recompute() {
        now = Date()
        var connected = account != nil && account?.status != .disconnected
        var state: FetchState = (account?.status == .expired) ? .reauthRequired(previous: nil) : fetchState
        #if DEBUG
        if let demo = demoState { state = demo; connected = true }
        #endif
        // Pastille et point d'alerte suivent la limite portée par l'encoche : la plus menaçante (008).
        let level = state.snapshot.flatMap { HeadlinePicker.pick(in: $0, forecasts: forecasts, settings: alertSettings, now: now) }
            .map { alertEvaluator.level(for: $0, settings: alertSettings) } ?? .none
        display = DisplayStateReducer.reduce(state: state, connected: connected, settings: refreshSettings, alertLevel: level,
                                             layout: layout, fullscreen: fullscreen, hover: hover, pinned: pinned, now: now,
                                             forecasts: forecasts, alertSettings: alertSettings)
        #if DEBUG
        if demoState != nil { display.forecasts = demoForecasts }
        #endif
        signal = NotchSignal.make(display: display, now: now, language: AppLanguage.current, strings: .app)
        notifier.notifyIfNeeded(signal: signal, display: display, enabled: alertSettings.notifications, now: now)
        panel?.contentHeight = expandedContentHeight
        panel?.showsSettings = showSettings
        // Dans l'encoche, seule la bande élargit le panneau ; le liseré seul reste à la largeur de l'encoche.
        // Île repliée (012) : oreille gauche toujours, droite seulement avec une donnée.
        let ear = NotchPanelController.earWidth
        panel?.apply(display, ears: (ear, signal.island.trailing == nil ? 0 : ear))
    }

    func setExpandedContentHeight(_ height: CGFloat) {
        guard !showSettings, height > 40 else { return }
        let clamped = min(height.rounded(.up), 480)
        guard abs(clamped - expandedContentHeight) > 0.5 else { return }
        expandedContentHeight = clamped
        recompute()
    }
}
