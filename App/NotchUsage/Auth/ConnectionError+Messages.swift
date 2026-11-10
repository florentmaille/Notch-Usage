import Foundation
import NotchUsageCore

/// Messages des échecs de connexion (catalogue de l'app). Les erreurs réseau distinguent l'absence de réseau,
/// le délai dépassé et un hôte injoignable (010).
extension ConnectionError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .claudeCodeUnavailable:
            return String(localized: "No Claude Code session found. Sign in to Claude Code first, or use the browser.")
        case .claudeCodeAccessDenied:
            return String(localized: "macOS did not let Notch Usage read the Claude Code session. Choose Always Allow in the Keychain dialog, or sign in with your browser.")
        case .claudeCodeRenewalFailed(let outcome):
            switch outcome {
            case .notFound:
                return String(localized: "Claude Code was not found on this Mac. Run claude in Terminal, or sign in with your browser.")
            case .notLoggedIn:
                return String(localized: "Claude Code is signed out. Run claude in Terminal and sign in, or use your browser.")
            case .timedOut:
                return String(localized: "Claude Code did not answer in time. Try again, or run claude in Terminal.")
            case .failed, .renewed:
                return String(localized: "Claude Code could not renew its session. Run claude in Terminal, or sign in with your browser.")
            }
        case .claudeCodeMalformed:
            return String(localized: "The Claude Code credentials could not be read. Open Claude Code once, then retry.")
        case .claudeCodeExpired:
            return String(localized: "Your Claude Code session has expired. Run claude in Terminal once to renew it: Notch Usage reconnects automatically.")
        case .invalidSessionKey:
            return String(localized: "That does not look like a Claude session key (it should start with sk-ant-sid).")
        case .fetch(let e):
            switch e {
            case .unauthorized: return String(localized: "Claude rejected the credentials. Try signing in again.")
            case .unsupported: return String(localized: "This Claude plan does not expose usage limits. Pro, Max or Team is required.")
            case .challenge: return String(localized: "claude.ai asked for a browser check. Open the sign-in window and complete it.")
            case .rateLimited: return String(localized: "Claude is rate-limiting usage requests. Try again in a few minutes.")
            case .network(let code):
                switch code {
                case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                    return String(localized: "No network connection.")
                case .timedOut:
                    return String(localized: "Claude did not answer in time. Try again.")
                default:
                    return String(localized: "Could not reach Claude. Check your connection and try again.")
                }
            default: return String(localized: "Could not read usage data. Try again.")
            }
        }
    }
}
