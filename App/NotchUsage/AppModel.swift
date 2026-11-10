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
    /// Battements du halo (006) : `BeatCounter` sur le tick de 30 s, jamais remis à zéro.
    private var beatCounter = BeatCounter()
    var beat: Int { beatCounter.beats }
    /// Raisons de pause en cours (veille, verrou, économie d'énergie) : le tick n'y recalcule rien.
    @ObservationIgnored private var pausedReasons: Set<PauseReason> = []
    /// Survol de l'encoche (013 : seule façon d'ouvrir le panneau). En le quittant, on revient aux limites.
    var hover = false {
        didSet {
            // Seul un vrai changement ramène aux limites : `hover = false` sert aussi à refermer l'île quand le
            // popover ou une carte s'ouvre, et ne doit pas fermer les réglages qu'ils affichent.
            if hover != oldValue { showSettings = false }
            // Au survol, les sessions dont le processus a disparu sont retirées (017, R7) : jamais sur un timer.
            if hover { claudeSessions = claudeSessions.expire(now: Date(), alive: ProcessLiveness.isAlive) }
            if hover { statusItem?.closePopover(); capsules.values.forEach { $0.dismissCard() } }
            recompute()
        }
    }
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
    /// Un relevé par heure sur 8 jours (021) : courbe de la semaine.
    @ObservationIgnored private var hourlyHistory = HourlyHistory()
    /// Courbe de la limite hebdomadaire (021), `nil` sans limite hebdomadaire toutes modèles.
    private(set) var weekCurve: WeekCurve.State?
    @ObservationIgnored private var debouncer = ForecastDebouncer()
    @ObservationIgnored private var lastRecordedAt: Date?
    var claudeCodeAvailable = false
    var launchAtLoginStatus: LaunchAtLogin.Status = .disabled
    /// Item de barre de menus (014, 018) : automatique (écran sans encoche connecté), toujours ou jamais.
    private(set) var menuBarIconMode: MenuBarIconMode = AppModel.loadMenuBarIconMode()
    @ObservationIgnored private var statusItem: StatusItemController?
    /// Barre active sans item (icône sur « Jamais ») : clic et changement d'app.
    @ObservationIgnored private let barTracker = ActiveBarTracker()
    /// Rôle des écrans connectés (018) : île sur l'écran à encoche, item enrichi sur les autres.
    @ObservationIgnored private(set) var screenRoles: ScreenRoles = .empty
    /// Écran de la barre de menus active, lu sur la fenêtre de l'item (R4) : compact sur l'écran de l'île.
    @ObservationIgnored private var activeBarScreenID: String?
    private(set) var barContent: BarContent?
    /// Pastille centrée sur les écrans sans encoche d'au moins 1700 pt (018, C′), désactivée par défaut (FR-011).
    private(set) var showsCenterCapsule = UserDefaults.standard.bool(forKey: AppModel.capsuleKey)
    @ObservationIgnored private var capsules: [String: CapsulePanelController] = [:]
    @ObservationIgnored private var screensByID: [String: NSScreen] = [:]
    var now = Date()
    // Sessions Claude Code en attente (017) : fil d'événements des hooks, réglages, statut des entrées installées.
    @ObservationIgnored private var claudeWatcher: ClaudeEventsWatcher?
    @ObservationIgnored private var arrivalTask: Task<Void, Never>?
    private(set) var claudeSessions = ClaudeSessionTracker()
    private(set) var followsClaudeCode = UserDefaults.standard.bool(forKey: AppModel.followsClaudeKey)
    private(set) var notifiesClaudeAttention = UserDefaults.standard.bool(forKey: AppModel.notifiesClaudeKey)
    private(set) var claudeHooksStatus: ClaudeSettingsFile.Status = .absent
    var claudeHooksError: String?
    fileprivate static let followsClaudeKey = "followsClaudeCode"
    fileprivate static let notifiesClaudeKey = "notifiesClaudeAttention"

    private static let accountKey = "account"
    private static let legacyPurgeKey = "legacyBrowserDataPurged"
    private static let intervalKey = "refreshIntervalSeconds"
    private static let alertsKey = "alertSettings"
    fileprivate static let legacyMenuBarKey = "showsMenuBarIcon"
    fileprivate static let menuBarModeKey = "menuBarIconMode"
    fileprivate static let capsuleKey = "showsCenterCapsule"

    /// Lu une fois : l'ancien booléen de la 014 devient un mode, puis disparaît (R8).
    private static func loadMenuBarIconMode() -> MenuBarIconMode {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: menuBarModeKey), let mode = MenuBarIconMode(rawValue: raw) { return mode }
        let legacy = defaults.object(forKey: legacyMenuBarKey) == nil ? nil : defaults.bool(forKey: legacyMenuBarKey)
        let mode = MenuBarIconMode.migrate(legacy: legacy)
        defaults.set(mode.rawValue, forKey: menuBarModeKey)
        defaults.removeObject(forKey: legacyMenuBarKey)
        return mode
    }

    init() {
        let defaults = UserDefaults.standard
        var settings = RefreshSettings()
        if defaults.object(forKey: Self.intervalKey) != nil {
            settings.interval = .seconds(defaults.double(forKey: Self.intervalKey))
        }
        refreshSettings = settings
        let storedAlerts = defaults.data(forKey: Self.alertsKey).flatMap { try? JSONDecoder().decode(AlertSettings.self, from: $0) } ?? AlertSettings()
        alertSettings = storedAlerts
        if let data = defaults.data(forKey: Self.accountKey), let a = try? JSONDecoder().decode(Account.self, from: data) {
            account = a
        }
        let initialLayout = NotchLayout.fallback
        layout = initialLayout
        let initialDisplay = DisplayStateReducer.reduce(state: .idle(nil), connected: false, settings: settings, alertLevel: .none,
                                                        layout: initialLayout, fullscreen: false, hover: false, now: Date())
        display = initialDisplay
        signal = NotchSignal.make(display: initialDisplay, now: Date(), language: AppLanguage.current, strings: .app)
    }

    // MARK: Cycle de vie

    #if DEBUG
    /// Mode démo (build Debug) : voir `AppModel+Demo.swift`.
    @ObservationIgnored var demoState: FetchState?
    @ObservationIgnored var demoForecasts: [String: Forecast] = [:]
    @ObservationIgnored var demoObservers: [any NSObjectProtocol] = []
    @ObservationIgnored var demoClaude: ClaudeSessionTracker?
    @ObservationIgnored var demoNoNotch = false
    @ObservationIgnored var demoNotchOnly = false
    @ObservationIgnored var demoActiveBar: String?
    @ObservationIgnored var demoHourly: HourlyHistory?
    #endif

    func start() {
        #if DEBUG
        installDemoHook()
        #endif
        // Les versions antérieures à 0.4.1 laissaient le cookie de session sur disque (007) : purge une seule fois.
        // À chaque lancement, elle démarrait WebKit et laissait son processus réseau en vie pour rien.
        if !defaults.bool(forKey: Self.legacyPurgeKey) {
            Task { [defaults] in
                await BrowserLoginWindow.purgeBrowserData()
                defaults.set(true, forKey: Self.legacyPurgeKey)
            }
        }
        claudeCodeAvailable = connection.isClaudeCodeAvailable
        launchAtLoginStatus = LaunchAtLogin.status
        refreshClaudeHooksStatus()
        if followsClaudeCode {
            migrateLegacyClaudeHooks()
            startClaudeWatcher()
        }
        snapshots.removeLegacyFiles()
        history = (try? snapshots.loadHistory()) ?? UsageHistory()
        hourlyHistory = (try? snapshots.loadHourlyHistory()) ?? HourlyHistory()
        screens.onChange = { [weak self] snapshot in self?.applyScreens(snapshot) }
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
        statusItem?.remove()
        statusItem = nil
        barTracker.stop()
        capsules.values.forEach { $0.close() }
        capsules = [:]
        tickTask?.cancel()
        stateTask?.cancel()
        arrivalTask?.cancel()
        claudeWatcher?.stop()
        claudeWatcher = nil
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

    /// Configuration d'écrans (018, R1) : l'île sur l'écran à encoche seulement, fermée sans lui ; l'item selon le réglage.
    func applyScreens(_ snapshot: ScreenObserver.Snapshot) {
        var snapshot = snapshot
        #if DEBUG
        if demoNoNotch { snapshot = Self.withoutNotch(snapshot) }
        // Démo `notchonly` : comme un MacBook seul, les écrans sans encoche sont ignorés (captures du README).
        if demoNotchOnly { snapshot = ScreenObserver.Snapshot(roles: ScreenRoles(island: snapshot.roles.island, plain: []), screens: snapshot.screens) }
        #endif
        screenRoles = snapshot.roles
        screensByID = snapshot.screens
        statusItem?.closePopover()
        if let target = snapshot.island {
            layout = target.layout
            fullscreenObserver.screen = target.screen
            if let panel {
                panel.update(target: target)
            } else {
                let controller = NotchPanelController(target: target, rootView: AnyView(NotchRootView().environment(self)),
                                                      cardView: AnyView(NotchCardView().environment(self)))
                controller.onHoverChange = { [weak self] inside in self?.hover = inside }
                controller.onDismiss = { [weak self] in self?.dismiss() }
                panel = controller
            }
        } else {
            // Capot fermé, Mac sans encoche : pas d'île, et plus de pilule (FR-002).
            hover = false
            panel?.close()
            panel = nil
            fullscreenObserver.screen = nil
        }
        syncCapsules()
        syncStatusItem()
        recompute()
    }

    /// Une pastille par écran sans encoche assez large, si l'option est active (FR-012, FR-016).
    private func syncCapsules() {
        let wanted = showsCenterCapsule ? screenRoles.plain.filter(\.capsuleEligible).map(\.id) : []
        for (id, capsule) in capsules where !wanted.contains(id) {
            capsule.close()
            capsules[id] = nil
        }
        for id in wanted {
            guard let screen = screensByID[id] else { continue }
            if let capsule = capsules[id] {
                capsule.update(screen: screen)
            } else {
                let capsule = CapsulePanelController(screenID: id, screen: screen, model: self)
                capsule.onTap = { [weak self] in self?.clearDoneSessions() }
                capsule.onCardOpen = { [weak self] in
                    guard let self else { return }
                    self.hover = false
                    self.showSettings = false
                    self.statusItem?.closePopover()
                    for (other, c) in self.capsules where other != id { c.dismissCard() }
                }
                capsules[id] = capsule
            }
        }
    }

    func setShowsCenterCapsule(_ shown: Bool) {
        showsCenterCapsule = shown
        defaults.set(shown, forKey: Self.capsuleKey)
        syncCapsules()
        syncStatusItem()
        recompute()
    }

    /// Apparence de la barre de menus, lue sur l'item quand il existe (R6) ; sinon celle du système.
    private var menuBarIsDark: Bool {
        let appearance = statusItem?.buttonAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    #if DEBUG
    /// Mode démo `nonotch` : tous les écrans passent sans encoche.
    static func withoutNotch(_ snapshot: ScreenObserver.Snapshot) -> ScreenObserver.Snapshot {
        let descriptors = NSScreen.screens.enumerated().map { ScreenObserver.descriptor($1, isMain: $0 == 0, forceNoNotch: true) }
        return ScreenObserver.Snapshot(roles: ScreenRoles.assign(descriptors), screens: snapshot.screens)
    }
    #endif

    /// Crée ou retire l'item selon le réglage et les écrans (FR-018). Sans item (« Jamais ») mais avec pastille ou île
    /// à adapter (018, 019), `ActiveBarTracker` suit la barre active : aucune sonde, donc aucun trou dans la barre.
    private func syncStatusItem() {
        let visible = menuBarIconMode.isVisible(roles: screenRoles)
        let wantsTracking = !visible && (!capsules.isEmpty || (screenRoles.hasPlainScreen && screenRoles.island != nil))
        if wantsTracking {
            barTracker.onChange = { [weak self] id in
                guard let self else { return }
                self.activeBarScreenID = id
                self.recompute()
            }
            barTracker.start()
            activeBarScreenID = barTracker.screenID
        } else {
            barTracker.stop()
        }
        if !visible, let item = statusItem {
            item.remove()
            statusItem = nil
            if !wantsTracking { activeBarScreenID = nil }
        }
        if visible, statusItem == nil {
            let item = StatusItemController(model: self)
            item.onActiveScreenChange = { [weak self] id in
                guard let self else { return }
                self.activeBarScreenID = id
                self.recompute()
            }
            statusItem = item
        }
    }

    #if DEBUG
    func debugOpenPopover() { statusItem?.openPopover() }
    func debugItemSnapshot() {
        statusItem?.debugSnapshot()
        capsules.values.forEach { $0.debugSnapshot() }
    }
    func debugCapsuleHover(_ inside: Bool) { capsules.values.forEach { $0.debugHover(inside) } }
    #endif

    /// Ouvrir le popover referme l'île ; ouvrir l'île referme le popover (FR-010).
    func popoverWillOpen() {
        hover = false
        showSettings = false
        capsules.values.forEach { $0.dismissCard() }
    }

    // MARK: Relevés

    private func startCoordinator(for account: Account) {
        stateTask?.cancel()
        let old = coordinator
        Task { await old?.stop() }
        // Les pauses en cours sont transmises à la création : `pause(_:)` n'a touché que l'ancien coordinateur.
        let c = RefreshCoordinator(provider: connection.makeProvider(for: account), policy: RefreshPolicy(settings: refreshSettings),
                                   store: snapshots, clock: SystemClock(), pausedFor: pausedReasons)
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
        Task { await c.start() }
    }

    /// Historique et prévision (003) : un relevé par instantané distinct, prévision stabilisée par l'hystérésis.
    private func record(_ snapshot: UsageSnapshot) {
        guard snapshot.fetchedAt != lastRecordedAt else { return }
        lastRecordedAt = snapshot.fetchedAt
        history = history.appending(snapshot)
        try? snapshots.saveHistory(history)
        hourlyHistory = hourlyHistory.appending(snapshot)
        try? snapshots.saveHourlyHistory(hourlyHistory)
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
        let c = coordinator
        let store = snapshots
        // Un relevé en vol peut encore être écrit avant l'arrêt effectif : second effacement une fois le
        // coordinateur arrêté, sauf si un compte a été reconnecté entre-temps.
        Task { [weak self] in
            await c?.stop()
            if self?.account == nil { try? store.wipe() }
        }
        coordinator = nil
        connection.signOut()
        history = UsageHistory()
        hourlyHistory = HourlyHistory()
        debouncer = ForecastDebouncer()
        forecasts = [:]
        lastRecordedAt = nil
        Task { await BrowserLoginWindow.purgeBrowserData() }
        setAccount(nil)
        fetchState = .idle(nil)
        lastReceivedState = .idle(nil)
        showSettings = false
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
        // Le coordinateur garde sa dernière requête : glisser le curseur ne déclenche aucune rafale. Le réglage est
        // lu à l'exécution, le dernier cran l'emporte quel que soit l'ordre des tâches.
        let c = coordinator
        Task { [weak self] in
            guard let self else { return }
            await c?.update(policy: RefreshPolicy(settings: self.refreshSettings))
        }
        recompute()
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

    /// Les nouveaux seuils s'appliquent aussitôt : le recalcul les lit, sans redémarrer le coordinateur.
    private func saveAlertSettings() {
        if let data = try? JSONEncoder().encode(alertSettings) { defaults.set(data, forKey: Self.alertsKey) }
        recompute()
    }

    func setMenuBarIconMode(_ mode: MenuBarIconMode) {
        menuBarIconMode = mode
        defaults.set(mode.rawValue, forKey: Self.menuBarModeKey)
        syncStatusItem()
        recompute()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginStatus = LaunchAtLogin.set(enabled: enabled)
    }

    // MARK: Claude Code (017)

    /// Sessions montrées : celles de la démo en build Debug, sinon les vraies.
    var visibleClaudeSessions: ClaudeSessionTracker {
        #if DEBUG
        if let demoClaude { return demoClaude }
        #endif
        return claudeSessions
    }

    private func startClaudeWatcher() {
        guard claudeWatcher == nil else { return }
        do {
            try ClaudeHookScript.ensure()
        } catch {
            Log.app.error("claude hook script: \(error.localizedDescription, privacy: .public)")
        }
        let watcher = ClaudeEventsWatcher(url: ClaudeHookScript.eventsURL) { [weak self] events in self?.handleClaudeEvents(events) }
        claudeWatcher = watcher
        watcher.start()
    }

    /// Les versions 0.5.4 à 0.6.1 écrivaient le chemin du script sans apostrophes : le shell le coupait à l'espace de
    /// « Application Support » et aucun événement n'arrivait. Le réglage est déjà actif : les entrées sont remplacées
    /// au lancement, sans clic. En cas d'échec, la note « Réparer » des réglages reste.
    private func migrateLegacyClaudeHooks() {
        let path = ClaudeHookScript.scriptURL.path
        guard ClaudeSettingsFile.hasLegacyEntries(scriptPath: path) else { return }
        do {
            try ClaudeHookScript.ensure()
            try ClaudeSettingsFile.install(scriptPath: path)
            Log.app.notice("claude hooks migrated to the quoted command")
        } catch {
            Log.app.error("claude hooks migration: \(error.localizedDescription, privacy: .public)")
        }
        refreshClaudeHooksStatus()
    }

    private func stopClaudeWatcher() {
        claudeWatcher?.stop()
        claudeWatcher = nil
        arrivalTask?.cancel()
        claudeSessions = ClaudeSessionTracker()
    }

    /// Réduit les événements reçus, résout l'application d'origine des sessions nouvelles, retire les sessions
    /// mortes, relance le libellé d'arrivée (4 s) et notifie si demandé.
    private func handleClaudeEvents(_ events: [ClaudeHookEvent]) {
        let previous = claudeSessions.attention(now: Date())?.arrivedAt
        var tracker = claudeSessions
        for event in events {
            // La vivacité se vérifie sur le processus de la session : si un shell a lancé le hook, on remonte à son
            // parent avant de réduire (le tracker ignore les événements sans type, on ne peut pas corriger après).
            let event = event.withPID(event.pid.map(ProcessLiveness.sessionProcess(from:)))
            tracker = tracker.reduce(event)
            if let session = tracker.sessions[event.sessionID], session.originApp == nil, let pid = event.pid {
                tracker = tracker.settingOrigin(app: ProcessLiveness.originApp(of: pid)?.bundleIdentifier, for: event.sessionID)
            }
            if notifiesClaudeAttention, event.kind == .permissionRequest, let session = tracker.sessions[event.sessionID] {
                notifier.notifyClaude(name: session.displayName(fallback: CompactStrip.Strings.app.claude.sessionFallback),
                                      kind: event.isQuestion ? .question : .approval, id: "\(event.sessionID)-\(event.promptID ?? "")")
            }
        }
        let now = Date()
        claudeSessions = tracker.expire(now: now, alive: ProcessLiveness.isAlive)
        if let arrived = claudeSessions.attention(now: now)?.arrivedAt, arrived != previous, AttentionFormat.showsArrival(arrivedAt: arrived, now: now) {
            arrivalTask?.cancel()
            arrivalTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(AttentionFormat.arrivalDuration), tolerance: .milliseconds(50))
                guard !Task.isCancelled else { return }
                self?.recompute()
            }
        }
        Log.app.notice("claude events: \(events.count, privacy: .public) received, \(self.claudeSessions.waiting.count, privacy: .public) waiting")
        recompute()
    }

    /// Clic sur une ligne du panneau ou du menu : l'application d'où vient la session passe devant ; l'attente reste.
    func activateSession(_ id: String) {
        guard let session = visibleClaudeSessions.sessions[id] else { return }
        if let app = session.originApp { ProcessLiveness.activate(bundleID: app) }
        hover = false
    }

    /// Clic sur l'île : les « terminé » s'effacent, les attentes bloquantes restent (017, FR-002).
    func clearDoneSessions() {
        claudeSessions = claudeSessions.clearDone()
        #if DEBUG
        demoClaude = demoClaude?.clearDone()
        #endif
        recompute()
    }

    func setFollowsClaudeCode(_ enabled: Bool) {
        claudeHooksError = nil
        do {
            if enabled {
                try ClaudeHookScript.ensure()
                try ClaudeSettingsFile.install(scriptPath: ClaudeHookScript.scriptURL.path)
            } else {
                try ClaudeSettingsFile.remove(scriptPath: ClaudeHookScript.scriptURL.path)
            }
        } catch {
            claudeHooksError = error.localizedDescription
            Log.app.error("claude hooks: \(error.localizedDescription, privacy: .public)")
            refreshClaudeHooksStatus()
            recompute()
            return
        }
        followsClaudeCode = enabled
        defaults.set(enabled, forKey: Self.followsClaudeKey)
        if enabled { startClaudeWatcher() } else { stopClaudeWatcher() }
        refreshClaudeHooksStatus()
        Log.app.notice("claude hooks \(enabled ? "installed" : "removed", privacy: .public)")
        recompute()
    }

    func setNotifiesClaudeAttention(_ enabled: Bool) {
        notifiesClaudeAttention = enabled
        defaults.set(enabled, forKey: Self.notifiesClaudeKey)
    }

    /// Entrées modifiées à la main : réinstaller remet les manquantes sans doubler les présentes.
    func repairClaudeHooks() { setFollowsClaudeCode(true) }

    func refreshClaudeHooksStatus() {
        claudeHooksStatus = ClaudeSettingsFile.status(scriptPath: ClaudeHookScript.scriptURL.path)
    }

    // MARK: Interaction

    /// « Réglages » du menu de la barre : le pointeur est loin de l'encoche, le panneau reste ouvert jusqu'à son survol.
    func openSettingsFromMenu() {
        // Sans île (capot fermé, Mac sans encoche), les réglages s'ouvrent dans le popover de l'item.
        // L'ouverture ramène aux limites (popover comme île) : les réglages se demandent après.
        guard let panel else {
            statusItem?.openPopover()
            showSettings = true
            return
        }
        hover = true
        showSettings = true
        panel.holdOpen()
    }

    /// Ouvre le panneau sans survol : app rouverte depuis le Finder ou Spotlight, ou action VoiceOver sur l'île. La
    /// carte prend le clavier. Sans île, le popover de l'item ; sans aucune surface (icône sur « Jamais », ni île
    /// ni pastille), l'icône revient : c'est la seule sortie de cet état depuis l'interface.
    func openPanel() {
        if let panel {
            hover = true
            panel.holdOpen()
            return
        }
        if statusItem == nil, capsules.isEmpty, menuBarIconMode == .never {
            setMenuBarIconMode(.automatic)
            Log.app.notice("reopened without any surface: menu bar icon restored")
        }
        // La fenêtre d'un item tout juste créé n'existe qu'au tour suivant de la boucle.
        DispatchQueue.main.async { [weak self] in self?.statusItem?.openPopover() }
    }

    /// Échap : referme le panneau ouvert au survol.
    func dismiss() {
        hover = false
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
                                             layout: layout, fullscreen: fullscreen, hover: hover, now: now,
                                             forecasts: forecasts, alertSettings: alertSettings)
        #if DEBUG
        if demoState != nil { display.forecasts = demoForecasts }
        #endif
        let base = NotchSignal.make(display: display, now: now, language: AppLanguage.current, strings: .app,
                                    attention: visibleClaudeSessions.attention(now: now))
        // Courbe de la semaine (021) : prévision hebdomadaire de la 016, recalculée si le modèle ne l'a pas encore.
        var hourly = hourlyHistory
        #if DEBUG
        if let demo = demoHourly, demoState != nil { hourly = demo }
        #endif
        if display.content == .limits, let weekly = display.limits.first(where: { $0.kind == .weeklyAll }) {
            let forecast = display.forecasts[weekly.id]
                ?? PaceForecaster.weeklyForecast(utilization: weekly.utilization, resetsAt: weekly.resetsAt, now: now)
            weekCurve = WeekCurve.make(limit: weekly, history: hourly, forecast: forecast, now: now)
        } else {
            weekCurve = nil
        }
        notifier.notifyIfNeeded(signal: base, display: display, enabled: alertSettings.notifications, now: now)
        // Barre de menus active : écran de l'île ou écran sans encoche (R4). Sert à l'item, à la pastille et à l'île.
        var activeBar = activeBarScreenID
        #if DEBUG
        if let forced = demoActiveBar { activeBar = forced == "notch" ? screenRoles.island?.id : "external" }
        #endif
        // 019 : avec un écran sans encoche branché, l'île montre le chiffre quand on travaille sur le Mac et se
        // replie sur la jauge ailleurs, comme la pastille. Le MacBook seul garde l'île de la 012.
        var islandBar: NotchSignal.ActiveBar?
        if screenRoles.hasPlainScreen, screenRoles.island != nil, let activeBar {
            islandBar = screenRoles.isIsland(activeBar) ? .island : .elsewhere
        }
        // Survol de l'encoche : l'île réapparaît au-dessus de la carte, même si la barre active est ailleurs (le
        // pointeur ne déplace pas la barre de menus, seul un clic le fait ; retour utilisateur).
        if hover, islandBar == .elsewhere { islandBar = .island }
        signal = base.adapted(to: islandBar, strings: .app)
        panel?.contentHeight = expandedContentHeight
        // Île repliée (012) : oreille gauche toujours, droite seulement avec une donnée ; élargie le temps du mot
        // d'arrivée d'une session Claude (017).
        panel?.apply(display, ears: (NotchPanelController.earWidth, signal.trailingEarWidth(now: now)))
        // Item (018) : compact quand la barre active est celle de l'écran de l'île (FR-022). Dérivé du signal avant
        // adaptation : le point Claude de la 017 et l'échéance restent ceux de la limite.
        let bar = BarContent.make(signal: base, now: now, strings: .app)
        barContent = bar
        statusItem?.update(content: screenRoles.isIsland(activeBar) ? bar.compact : bar.menuBarItem, beat: beat,
                           reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if !capsules.isEmpty {
            let dark = menuBarIsDark
            for capsule in capsules.values {
                // Comme l'item : anneau seul quand la barre active est celle de l'écran à encoche (retour utilisateur).
                capsule.apply(content: screenRoles.isIsland(activeBar) ? bar.compact : bar, dark: dark, beat: beat, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                capsule.refreshCard()
            }
        }
    }

    func setExpandedContentHeight(_ height: CGFloat) {
        guard height > 40 else { return }
        let clamped = min(height.rounded(.up), 480)
        guard abs(clamped - expandedContentHeight) > 0.5 else { return }
        expandedContentHeight = clamped
        // Hors de la passe de mise en page qui a produit la mesure : redimensionner la fenêtre pendant cette passe
        // laissait la vue racine à l'ancienne hauteur (réglages coupés, 013).
        Task { @MainActor [weak self] in self?.recompute() }
    }
}
