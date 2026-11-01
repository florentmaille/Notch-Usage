import AppKit
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
    private let onCaptured: (String) -> Void
    private let onCancelled: () -> Void
    private var captured = false

    init(onCaptured: @escaping (String) -> Void, onCancelled: @escaping () -> Void) {
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
        window.level = .floating
        self.window = window
        self.webView = webView

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: Self.loginURL))
        checkCookies()
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
            if let session = cookies.first(where: { $0.name == "sessionKey" && $0.domain.hasSuffix("claude.ai") && $0.value.hasPrefix("sk-ant-sid01-") }) {
                self.captured = true
                Log.auth.notice("sessionKey captured from browser sign-in")
                let value = session.value
                self.close()
                self.onCaptured(value)
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
