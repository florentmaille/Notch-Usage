import AppKit
import NotchUsageCore
import WebKit

/// Fenêtre de connexion claude.ai : capture le cookie `sessionKey` puis se ferme (R2, T044).
@MainActor
final class BrowserLoginWindow: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
    static let loginURL = URL(string: "https://claude.ai/login")!
    /// Hôtes autorisés : claude.ai, Anthropic, les fournisseurs d'identité et le challenge Cloudflare.
    static let allowedHostSuffixes = ["claude.ai", "anthropic.com", "accounts.google.com", "google.com", "gstatic.com",
                                      "appleid.apple.com", "apple.com", "cloudflare.com", "hcaptcha.com"]

    private var window: NSWindow?
    private var webView: WKWebView?
    /// Clé de session et organisation active (cookie `lastActiveOrg`, un UUID, non secret).
    private let onCaptured: (String, String?) -> Void
    private let onCancelled: () -> Void
    private var captured = false

    init(onCaptured: @escaping (String, String?) -> Void, onCancelled: @escaping () -> Void) {
        self.onCaptured = onCaptured
        self.onCancelled = onCancelled
    }

    func show() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 700), configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        config.websiteDataStore.httpCookieStore.add(self)

        let window = NSWindow(contentRect: webView.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "Sign in to Claude")
        window.contentView = webView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        // Niveau normal : l'utilisateur doit pouvoir passer à sa messagerie pour récupérer un code.
        // Sans cela, la fenêtre s'ouvre sur le bureau quand l'app au premier plan est en plein écran.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.window = window
        self.webView = webView

        bringToFront()
        webView.load(URLRequest(url: Self.loginURL))
        checkCookies()
    }

    /// Efface les cookies claude.ai du magasin WebKit : sans cela, un cookie périmé est recapturé
    /// aussitôt la fenêtre ouverte et chaque tentative échoue sans afficher la page de connexion.
    static func clearClaudeCookies() async {
        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let claude = records.filter { $0.displayName.hasSuffix("claude.ai") }
        guard !claude.isEmpty else { return }
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: claude)
        Log.auth.notice("claude.ai browser data cleared")
    }

    /// App sans Dock (LSUIElement) : l'activation peut être refusée, d'où `orderFrontRegardless`.
    func bringToFront() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func close() {
        webView?.configuration.websiteDataStore.httpCookieStore.remove(self)
        window?.delegate = nil
        window?.close()
        window = nil
        webView = nil
    }

    // MARK: Cookies

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in self.checkCookies() }
    }

    private func checkCookies() {
        guard !captured, let store = webView?.configuration.websiteDataStore.httpCookieStore else { return }
        store.getAllCookies { [weak self] cookies in
            guard let self, !self.captured else { return }
            if let session = cookies.first(where: { $0.name == "sessionKey" && $0.domain.hasSuffix("claude.ai") && SessionKeyFormat.isValid($0.value) }) {
                self.captured = true
                Log.auth.notice("sessionKey captured from browser sign-in")
                let value = session.value
                let org = cookies.first { $0.name == "lastActiveOrg" && $0.domain.hasSuffix("claude.ai") }?.value
                self.close()
                self.onCaptured(value, org)
            }
        }
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { checkCookies() }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let host = navigationAction.request.url?.host?.lowercased() else { return .cancel }
        let allowed = Self.allowedHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
        if !allowed { Log.auth.notice("blocked navigation to \(host, privacy: .public)") }
        return allowed ? .allow : .cancel
    }

    func windowWillClose(_ notification: Notification) {
        guard !captured else { return }
        webView?.configuration.websiteDataStore.httpCookieStore.remove(self)
        window = nil
        webView = nil
        onCancelled()
    }
}
