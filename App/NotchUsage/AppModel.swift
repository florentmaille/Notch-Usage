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
    private(set) var fetchState: FetchState = .idle(nil)
    private(set) var display: DisplayState
    private(set) var layout: NotchLayout
    /// Incrémenté à chaque alerte émise : déclenche une animation brève (T058).
    private(set) var alertPulse = 0
    var hover = false { didSet { recompute() } }
    var pinned = false { didSet { recompute() } }
    var fullscreen = false { didSet { recompute() } }
    var showSettings = false
    var isConnecting = false
    var connectionError: String?
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
        if let data = defaults.data(forKey: Self.alertsKey), let a = try? JSONDecoder().decode(AlertSettings.self, from: data) {
            alertSettings = a
        } else {
            alertSettings = AlertSettings()
        }
        if let data = defaults.data(forKey: Self.accountKey), let a = try? JSONDecoder().decode(Account.self, from: data) {
            account = a
        }
        let initialLayout = NotchGeometry.layout(screenWidth: 1512, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil)
        layout = initialLayout
        display = DisplayStateReducer.reduce(state: .idle(nil), connected: false, settings: settings, alertLevel: .none,
                                             layout: initialLayout, fullscreen: false, hover: false, pinned: false, now: Date())
    }

    // MARK: Cycle de vie

    func start() {
        claudeCodeAvailable = connection.isClaudeCodeAvailable
        launchAtLoginStatus = LaunchAtLogin.status
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
                Self.logReading(state, previous: self.fetchState)
                self.fetchState = state
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
        guard loginWindow == nil else { return }
        connectionError = nil
        let window = BrowserLoginWindow(
            onCaptured: { [weak self] key in
                self?.loginWindow = nil
                self?.applySessionKey(key)
            },
            onCancelled: { [weak self] in
                self?.loginWindow = nil
            })
        loginWindow = window
        window.show()
    }

    func applySessionKey(_ key: String) {
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        Task {
            defer { isConnecting = false }
            do {
                let account = try await connection.connectWithSessionKey(key)
                setAccount(account)
                startCoordinator(for: account)
            } catch {
                connectionError = error.localizedDescription
                Log.auth.error("browser connection failed: \(error.localizedDescription, privacy: .public)")
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
        setAccount(nil)
        fetchState = .idle(nil)
        showSettings = false
        pinned = false
        recompute()
    }

    private func setAccount(_ account: Account?) {
        self.account = account
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
        let connected = account != nil && account?.status != .disconnected
        let state: FetchState = (account?.status == .expired) ? .reauthRequired(previous: nil) : fetchState
        let level = state.snapshot.map { alertEvaluator.level(for: $0, settings: alertSettings) } ?? .none
        display = DisplayStateReducer.reduce(state: state, connected: connected, settings: refreshSettings, alertLevel: level,
                                             layout: layout, fullscreen: fullscreen, hover: hover, pinned: pinned, now: now)
        panel?.apply(display)
    }
}
