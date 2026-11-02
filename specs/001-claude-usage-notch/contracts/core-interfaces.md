# Contract: interfaces publiques de `NotchUsageCore`

**Feature**: `001-claude-usage-notch` | **Date**: 2026-11-01

Le package n'importe que Foundation. L'app fournit les implémentations qui touchent AppKit,
WebKit et Security. Tous les types sont `Sendable`. Signatures indicatives : les noms sont
contractuels, les détails de paramètres peuvent évoluer pendant l'implémentation.

## Protocoles fournis par l'app

```swift
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse   // status, headers, body
}

public protocol CredentialStore: Sendable {
    func read(_ key: CredentialKey) throws -> String?       // .oauthAccessToken, .webSessionKey
    func write(_ value: String, for key: CredentialKey) throws
    func delete(_ key: CredentialKey) throws
}

/// Lecture de l'entrée Trousseau de Claude Code. `interactive == false` ⇒ aucun dialogue.
public protocol ClaudeCodeCredentialSource: Sendable {
    func readRawJSON(interactive: Bool) async throws -> Data?
}

public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration, tolerance: Duration) async throws
}

public protocol SnapshotStore: Sendable {       // dernier relevé + registre d'alertes
    func loadSnapshot() throws -> UsageSnapshot?
    func saveSnapshot(_ snapshot: UsageSnapshot) throws
    func loadLedger() throws -> AlertLedger?
    func saveLedger(_ ledger: AlertLedger) throws
    func wipe() throws
}
```

## Protocoles fournis par le package

```swift
public protocol UsageProvider: Sendable {
    var method: ConnectionMethod { get }
    func fetch() async throws(FetchError) -> UsageSnapshot
}

public struct OAuthUsageProvider: UsageProvider   // init(http:, credentials:, clock:)
public struct WebUsageProvider: UsageProvider     // init(http:, credentials:, clock:)
                                                  // + resolveOrganization() async throws -> String

public enum UsageResponseParser {
    public static func parse(_ data: Data, now: Date) throws(ParseError) -> [UsageLimit]
}

public enum ClaudeCodeCredentialReader {
    public static func accessToken(from json: Data) throws(CredentialError) -> ClaudeCodeToken
    // ClaudeCodeToken { accessToken, subscriptionType, expiresAt? }
}

public struct RefreshPolicy: Sendable {
    public init(settings: RefreshSettings)
    public func delay(afterSuccess: Void) -> Duration                 // = interval
    public func delay(afterFailure: FetchError, previous: Duration) -> Duration
    // ×2 plafonné 15 min ; Retry-After prioritaire ; jamais < 60 s
}

public actor RefreshCoordinator {
    public init(provider: UsageProvider, policy: RefreshPolicy, evaluator: AlertEvaluator,
                store: SnapshotStore, clock: Clock)
    public var states: AsyncStream<FetchState> { get }
    public var alerts: AsyncStream<AlertEvent> { get }
    public func start() async
    public func pause(reason: PauseReason)       // .sleep, .screenLocked, .lowPower
    public func resume()                         // relevé immédiat si > interval depuis le dernier
    public func refreshNow() async               // action utilisateur
    public func stop() async
}

public struct AlertEvaluator: Sendable {
    public func evaluate(_ snapshot: UsageSnapshot, settings: AlertSettings,
                         ledger: AlertLedger) -> (ledger: AlertLedger, events: [AlertEvent])
    public func level(for snapshot: UsageSnapshot, settings: AlertSettings) -> AlertLevel
}

public enum NotchGeometry {
    /// Valeurs lues par l'app sur NSScreen, calcul pur et testable.
    public static func layout(screenWidth: CGFloat, safeAreaTop: CGFloat,
                              auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) -> NotchLayout
    // NotchLayout { mode: .notch | .pill, width, height, originX }
}

public enum DisplayStateReducer {
    public static func reduce(state: FetchState, settings: AlertSettings, layout: NotchLayout,
                              fullscreen: Bool, hover: Bool, pinned: Bool, now: Date) -> DisplayState
}

public enum Freshness {
    public static func of(_ snapshot: UsageSnapshot, now: Date, interval: Duration) -> FreshnessLevel
    // fresh < 2×interval, aging ≥ 2×interval, stale ≥ 30 min
}
```

## Erreurs

```swift
public enum FetchError: Error, Sendable {
    case unauthorized, rateLimited(retryAfter: Duration?), server(Int), network(URLError.Code),
         challenge, emptyBody, malformed, credentialsUnavailable, unsupported
}
public enum ParseError: Error { case invalidJSON, noLimits }
public enum CredentialError: Error { case missingOAuthSection, invalidJSON }
```

## Garanties

- Aucune fonction du package ne journalise une valeur de jeton ou de cookie. Les erreurs
  portent des codes, jamais de corps de réponse brut.
- `RefreshCoordinator` n'émet jamais deux requêtes à moins de 60 s d'intervalle, y compris
  après `resume()` et `refreshNow()`.
- `AlertEvaluator.evaluate` est pure : même entrée ⇒ même sortie.
