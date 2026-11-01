import AppKit
import Foundation
import NotchUsageCore
import Observation
import SwiftUI

/// Relie NotchUsageCore à l'UI : réglages, compte, états de relevé, interaction, écran, énergie.
@MainActor
@Observable
final class AppModel {
    // Dépendances
    @ObservationIgnored let credentials = KeychainCredentialStore()
    @ObservationIgnored let snapshots = FileSnapshotStore()
    @ObservationIgnored let http = URLSessionHTTPClient()
    @ObservationIgnored let defaults = UserDefaults.standard
    @ObservationIgnored private(set) lazy var connection = ConnectionManager(credentials: credentials, claudeCode: ClaudeCodeKeychainReader(), http: http, snapshots: snapshots, defaults: defaults)
    @ObservationIgnored private let power = PowerObserver()
    @ObservationIgnored private let screens = ScreenObserver()
    @ObservationIgnored private var panel: NotchPanelController?
    @ObservationIgnored private var coordinator: RefreshCoordinator?
    @ObservationIgnored private var stateTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var loginWindow: BrowserLoginWindow?

    // État
    private(set) var account: Account?
    private(set) var refreshSettings: RefreshSettings
    private(set) var fetchState: FetchState = .idle(nil)
    private(set) var display: DisplayState
    private(set) var layout: NotchLayout
    var hover = false { didSet { recompute() } }
    var pinned = false { didSet { recompute() } }
    var fullscreen = false { didSet { recompute() } }
    var showSettings = false
    var isConnecting = false
    var connectionError: String?
    var claudeCodeAvailable = false
    var now = Date()

    private static let accountKey = "account"
    private static let intervalKey = "refreshIntervalSeconds"
    private static let launchAtLoginKey = "launchAtLogin"

    init() {
        let defaults = UserDefaults.standard
        var settings = RefreshSettings()
        if defaults.object(forKey: Self.intervalKey) != nil {
            settings.interval = .seconds(defaults.double(forKey: Self.intervalKey))
        }
        settings.launchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
        refreshSettings = settings
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
        screens.onChange = { [weak self] target in self?.applyScreen(target) }
        screens.start()
        power.onPause = { [weak self] reason in self?.pause(reason) }
        power.onResume = { [weak self] reason in self?.resume(reason) }
        power.start()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30), tolerance: .seconds(5))
                self?.now = Date()
                self?.recompute()
            }
        }
        if let account, account.status == .connected { startCoordinator(for: account) }
        recompute()
    }

    func stop() {
        tickTask?.cancel()
        stateTask?.cancel()
        let c = coordinator
        Task { await c?.stop() }
        coordinator = nil
        power.stop()
        screens.stop()
        panel?.close()
        panel = nil
    }

    private func applyScreen(_ target: ScreenObserver.Target) {
        layout = target.layout
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
        let old = coordinator
        Task { await old?.stop() }
        let c = RefreshCoordinator(provider: connection.makeProvider(for: account), policy: RefreshPolicy(settings: refreshSettings),
                                   store: snapshots, clock: SystemClock(), alertHook: nil)
        coordinator = c
        let stream = c.states
        stateTask = Task { [weak self] in
            for await state in stream {
                guard let self else { return }
                self.fetchState = state
                self.recompute()
                if case .reauthRequired = state { await self.handleReauth() }
            }
        }
        Task { await c.start() }
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
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        Task {
            defer { isConnecting = false }
            do {
                let account = try await connection.connectWithClaudeCode()
                setAccount(account)
                startCoordinator(for: account)
            } catch {
                connectionError = error.localizedDescription
                Log.auth.error("Claude Code connection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func connectWithBrowser() {
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
        display = DisplayStateReducer.reduce(state: state, connected: connected, settings: refreshSettings, alertLevel: .none,
                                             layout: layout, fullscreen: fullscreen, hover: hover, pinned: pinned, now: now)
        panel?.apply(display)
    }
}
