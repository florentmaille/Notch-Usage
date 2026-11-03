<p align="center">
  <img src="docs/images/hero.jpg" alt="Notch Usage: Claude usage limits shown in the MacBook notch" width="100%">
</p>

<h1 align="center">Notch Usage</h1>

<p align="center">
  <strong>Your Claude Pro, Max or Team limits, live in the MacBook notch.</strong><br>
  Silent when all is well. A coloured edge when a block is coming. Hover for the details.
</p>

<p align="center">
  <a href="https://github.com/florentmaille/Notch-Usage/actions/workflows/ci.yml"><img src="https://github.com/florentmaille/Notch-Usage/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

---

Ever been cut off by Claude in the middle of a task? Notch Usage keeps your subscription limits one
glance away: the **5-hour window**, the **weekly limit** and the **per-model weekly limits**, each
with its reset time and, for the 5-hour window, a forecast of when you will hit the wall.

It is native Swift, local-first, free of telemetry, and uses about 25 MB of memory.

## How it reads

<p align="center">
  <img src="docs/images/states.png" alt="Notch states: all clear, hover, block predicted in 2 h, in 40 min, in 8 min, limit reached, offline" width="820">
</p>

| State | What you see |
|---|---|
| All clear | Nothing. The notch is your Mac's notch. |
| Hover | Time to reset and usage of the limit most likely to block you, then the full panel. Click to pin it. |
| A block is coming | A coloured edge around the notch: amber two hours out, orange under an hour, red with a halo under 30 minutes. |
| Limit reached | Red edge; the panel shows when the limit comes back. |
| Offline or stale reading | A grey strip with the last reading; the countdown keeps running. |

The edge has one meaning, "a block is coming", and its colour says how soon. Nothing else in the
notch carries that meaning, and the notch never widens without text to show.

## Features

- **Forecast, not just a percentage.** From your pace over the last hour, Notch Usage projects when the 5-hour window reaches 100 %. The panel shows "At this pace: blocked at 16:40"; the edge follows the same forecast.
- **Thresholds as a fallback.** When no forecast is possible (weekly limits, first readings), crossing 80 % or 95 % lights the same edge. Thresholds are adjustable; one alert per limit and per reset period.
- **Choose the limit shown.** Automatic shows the limit predicted to run out first, otherwise the 5-hour window. Or pin the weekly limit, or one model, in Settings.
- **Every limit, one hover away.** 5-hour window, weekly, per model, with "resets in 2h 14m" and the exact time.
- **Works everywhere.** A pill at the top of displays without a notch, out of the way in full-screen apps, with a small dot while an alert is active.
- **Two ways to connect.** Reuse your Claude Code session, or sign in to claude.ai in a small window.
- **Frugal.** Refreshes every 3 minutes, backs off on errors, pauses during sleep, screen lock and Low Power Mode. Under 1 % CPU.
- **Private.** Talks only to `api.anthropic.com` and `claude.ai`. No analytics, no crash reporting, secrets in the macOS Keychain only.
- **Accessible.** Every limit is announced by VoiceOver in one sentence, in the silent state too.
- **English and French.** Follows your Mac's language, or pick one in Settings.

## Install

With [Homebrew](https://brew.sh):

```bash
brew install --cask florentmaille/tap/notch-usage
```

Or **download the [latest preview](https://github.com/florentmaille/Notch-Usage/releases)**, unzip it and move
**NotchUsage.app** to Applications. The preview is not notarized yet: the first time, open it, then click
**Open Anyway** in System Settings → Privacy & Security. Step-by-step instructions are in the release notes.

Requirements: macOS 14 (Sonoma) or later, Apple Silicon or Intel, and a Claude **Pro**, **Max** or **Team**
subscription.

To build from source (Xcode 16 or later):

```bash
brew install xcodegen
git clone https://github.com/florentmaille/Notch-Usage.git && cd Notch-Usage
xcodegen generate
xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -configuration Release build
```

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

<img src="docs/images/settings.png" alt="Settings: language, limit shown in the notch, refresh interval, alerts" width="440" align="right">

- **Language**: system, English or French.
- **Limit shown**: Automatic, or a pinned limit. The edge and the hover strip follow this choice.
- **Refresh every**: 1 to 15 minutes, 3 by default.
- **Alerts**: on or off, warning and critical thresholds.
- **Session key**: paste a `claude.ai` session key manually if the browser sign-in is blocked.
- **Open at login**.

<br clear="right">

## Privacy

- The only hosts the app talks to are `api.anthropic.com` and `claude.ai`.
- No telemetry, no analytics, no crash reporting.
- Secrets live in the macOS Keychain only. They never appear in logs. The browser sign-in window keeps its cookies in memory and discards everything once the session key is captured.
- The last reading and the last two hours of readings (for the forecast) are cached locally, and wiped on sign-out.

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
| The edge is hard to see on your wallpaper | It is drawn with a dark outline for light or warm wallpapers. If it still blends in, hover: the strip and panel carry the same information. |
| Nothing shows on an external display | The pill appears at the top of the display that holds the menu bar. Check Displays → Arrange. |

## Development

The logic lives in `NotchUsageCore`, a Swift package with no dependency beyond Foundation and 200+ tests:

```bash
swift test
```

The app (`App/NotchUsage`) is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
Debug builds are signed ad hoc, so macOS asks for Keychain access again after each build. With an Apple Development
certificate (free with an Apple ID, Xcode → Settings → Accounts), run `scripts/setup-local-signing.sh` once to sign
Debug builds with it and keep Keychain access across builds.

`scripts/demo.swift` drives a Debug build through its demo states (`normal`, `far`, `near`, `imminent`, `blocked`,
`offline`, …) and captures the notch; the README images come from it.

Each feature is specified, planned and validated with [GitHub Spec Kit](https://github.com/github/spec-kit) in
[`specs/`](specs): the notch itself (001), the forecast (003), the limit shown (004) and the silent notch with its
deadline edge (005). `scripts/release.sh <version>` signs, notarizes and packages a DMG (Developer ID required).

## License

MIT, see [LICENSE](LICENSE).
