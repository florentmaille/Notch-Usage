<p align="center">
  <img src="docs/images/hero.jpg" alt="Notch Usage: Claude usage limits shown in the MacBook notch" width="100%">
</p>

<h1 align="center">Notch Usage</h1>

<p align="center">
  <strong>Your Claude Pro, Max or Team limits, live in the MacBook notch.</strong><br>
  Native Swift. Local-first. No telemetry. Under 20 MB of memory.
</p>

<p align="center">
  <a href="https://github.com/florentmaille/Notch-Usage/actions/workflows/ci.yml"><img src="https://github.com/florentmaille/Notch-Usage/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

---

Ever been cut off by Claude in the middle of a task? Notch Usage keeps your subscription limits
one glance away: the **5-hour window**, the **weekly limit** and the **per-model weekly limits**
(Fable, …), each with its reset time. A compact gauge sits next to the notch. Hover to see
everything, click to pin.

## Features

- **Always in sight**: next to the notch, how much of your most constrained limit is used and when it resets.
- **Warned before the wall**: from your pace over the last hour, the notch predicts when the 5-hour window will run out ("blocked in 1h 10m", then "blocked at 16:40") long before any threshold. Over 80 % and 95 %, the percentage turns into an amber or red pill, so the alert is a shape, not just a colour.
- **Every limit, one hover away**: 5-hour window, weekly, per model, with "resets in 2h 14m", the exact time and "at this pace: blocked at 16:40".
- **Alerts before you hit the wall**: the notch turns amber at 80 % and red at 95 %. Thresholds are adjustable, one alert per limit and per reset period.
- **Works everywhere**: a pill at the top of displays without a notch, out of the way in full-screen apps, with a small dot while an alert is active.
- **Two ways to connect**: reuse your Claude Code session, or sign in to claude.ai in a small window.
- **Frugal**: refreshes every 3 minutes, backs off on errors, pauses during sleep, screen lock and Low Power Mode. 0.2 % CPU on average.
- **Private**: talks only to `api.anthropic.com` and `claude.ai`. No analytics, no crash reporting, secrets in the macOS Keychain only.
- **Accessible**: every limit is announced by VoiceOver in one sentence.
- **English and French**: follows your Mac's language, or pick one in Settings.

<p align="center">
  <img src="docs/images/states.png" alt="Notch states: normal, predicted block, warning, critical, limit reached, reconnect" width="720">
</p>

## Install

With [Homebrew](https://brew.sh):

```bash
brew install --cask florentmaille/tap/notch-usage
```

Or **download the [latest preview](https://github.com/florentmaille/Notch-Usage/releases)**, unzip it and move
**NotchUsage.app** to Applications. The preview is not notarized yet: the first time, open it, then click
**Open Anyway** in System Settings → Privacy & Security. Step-by-step instructions are in the release notes.

Signed and notarized builds will follow. To build from source:

```bash
brew install xcodegen
git clone https://github.com/florentmaille/Notch-Usage.git && cd Notch-Usage
xcodegen generate
xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -configuration Release build
```

Requirements: macOS 14 (Sonoma) or later, Apple Silicon or Intel, Xcode 16 or later to build.
A Claude **Pro**, **Max** or **Team** subscription.

## Connecting your account

Hover the notch and pick one:

1. **Use your Claude Code session.** If Claude Code is installed and signed in, Notch Usage reads its access
   token from the macOS Keychain (macOS asks you once). The token stays in memory, is only used to read usage,
   and is never refreshed, so Claude Code keeps working. When it expires, run any `claude` command:
   Notch Usage picks up the renewed token within a minute.
2. **Sign in with your browser.** A small window opens `claude.ai`. Once you are signed in, the session cookie
   is stored in the app's own Keychain entry and the window closes. Your active organization is used.

Sign out from the panel at any time: credentials and cached data are deleted.

## Settings

<img src="docs/images/settings.png" alt="Settings: refresh interval, alert thresholds, session key, open at login" width="440" align="right">

- **Refresh interval**: 1 to 15 minutes, 3 by default.
- **Alerts**: on or off, warning and critical thresholds.
- **Session key**: paste a `claude.ai` session key manually if the browser sign-in is blocked.
- **Open at login**.

<br clear="right">

## Privacy

- The only hosts the app talks to are `api.anthropic.com` and `claude.ai`.
- No telemetry, no analytics, no crash reporting.
- Secrets live in the macOS Keychain only. They never appear in logs.
- The last reading is cached locally so the panel stays useful while offline, and is wiped on sign-out.

## Rate limits and refresh cadence

The usage endpoint is shared with Claude Code's own polling, and Anthropic rate-limits it aggressively.
Notch Usage refreshes every **3 minutes** by default, never sends two requests less than 60 seconds apart,
backs off exponentially on errors, and pauses while the Mac sleeps, the screen is locked, or Low Power Mode is on.

## ⚠️ Risk note, please read

Anthropic does not document a public API for subscription usage. Notch Usage relies on the same
undocumented endpoints that Claude Code and the `claude.ai` usage page use, and it identifies
itself the way Claude Code does when using your Claude Code session. Anthropic's Consumer Terms
restrict automated access outside the official API, and Anthropic may change or block these
endpoints at any time.

Known enforcement so far has targeted third-party tools that run **inference** through consumer
subscriptions. Notch Usage only **reads** usage figures, locally, and sends nothing anywhere else.
That is a grey area, not an explicit permission. You use this app at your own risk.

Notch Usage is an independent project, not affiliated with or endorsed by Anthropic.

## Troubleshooting

| Symptom | What to do |
|---|---|
| macOS asks for your Keychain password | That is the Claude Code credential entry. Click **Always Allow**. Builds from source are not signed with a stable identity, so the prompt returns after each rebuild. |
| "Reconnect required" with the Claude Code session | Run any `claude` command: it renews its token and Notch Usage picks it up within a minute. |
| Browser sign-in shows a "Just a moment" check | Complete it in the sign-in window, or paste your session key in Settings. |
| Nothing shows on an external display | The pill appears at the top of the display that holds the menu bar. Check Displays → Arrange. |

## Development

The logic lives in `NotchUsageCore`, a Swift package with no dependency beyond Foundation and 128 tests:

```bash
swift test
```

The app (`App/NotchUsage`) is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
Debug builds are signed ad hoc, so macOS asks for Keychain access again after each build. With an Apple Development
certificate (free with an Apple ID, Xcode → Settings → Accounts), run `scripts/setup-local-signing.sh` once to sign
Debug builds with it and keep Keychain access across builds.
Specs, plan and validation results are in [`specs/001-claude-usage-notch`](specs/001-claude-usage-notch), written with
[GitHub Spec Kit](https://github.com/github/spec-kit). `scripts/release.sh <version>` signs, notarizes and packages
a DMG (Developer ID required).

## License

MIT, see [LICENSE](LICENSE).
