# Notch Usage

Your Claude Pro/Max limits, in the notch.

Notch Usage is a tiny macOS menu-less app that shows how much of your Claude subscription you
have used: the 5-hour window, the weekly limit, and per-model weekly limits (Fable, …), each with
its reset time. A compact gauge stays next to the notch; hover to expand, click to pin. It warns
you at 80 % and 95 % so you are never cut off mid-task.

_Screenshot coming with the first release._

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon or Intel. Works with or without a notch (a pill is
  shown at the top of the main display when there is no notch).
- A Claude **Pro** or **Max** subscription.
- To build from source: Xcode 16+, [xcodegen](https://github.com/yonaskolb/XcodeGen).

## Install

Releases (signed and notarized DMG, Homebrew cask in `florentmaille/homebrew-tap`) will come
with 0.1.0. Until then, build from source:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -configuration Debug build
```

Run the core tests with `swift test`. `scripts/build-app.sh` produces a Release archive and
`scripts/release.sh <version>` signs, notarizes and packages a DMG (Developer ID required).

## Connecting your account

Two options, in this order:

1. **Use your Claude Code session.** If Claude Code is installed and signed in, Notch Usage can
   read its access token from the macOS Keychain (you will see a system prompt the first time).
   The token is only ever used to read usage; Notch Usage never refreshes it, so Claude Code keeps
   working. When the token expires, open Claude Code once and Notch Usage picks up the new one.
2. **Sign in with your browser.** A small window opens `claude.ai`; once you are signed in, the
   session cookie is stored in the app's own Keychain entry and the window closes.

Sign out from the panel at any time: credentials and cached data are deleted.

## Privacy

- The only hosts the app talks to are `api.anthropic.com` and `claude.ai`.
- No telemetry, no analytics, no crash reporting.
- Secrets live in the macOS Keychain only. They never appear in logs.
- The last reading is cached locally so the panel stays useful while offline, and is wiped on
  sign-out.

## Alerts

The notch turns amber at **80 %** and red at **95 %** of any limit (thresholds adjustable in
Settings, alerts can be turned off). Each threshold fires once per limit and per reset period,
so a value hovering around 80 % does not nag you. In full-screen apps the gauge hides; a small
dot stays visible while an alert is active, and hovering the top edge brings the panel back.

## Rate limits and refresh cadence

The usage endpoint is shared with Claude Code's own polling, and Anthropic rate-limits it
aggressively. Notch Usage refreshes every **3 minutes** by default (adjustable between 1 and
15 minutes), backs off exponentially on errors, and pauses while the Mac sleeps, the screen is
locked, or Low Power Mode is on.

## ⚠️ Risk note, please read

Anthropic does not document a public API for subscription usage. Notch Usage relies on the same
undocumented endpoints that Claude Code and the `claude.ai` usage page use, and it identifies
itself the way Claude Code does when using your Claude Code session. Anthropic's Consumer Terms
restrict automated access outside the official API, and Anthropic may change or block these
endpoints at any time.

Known enforcement so far has targeted third-party tools that run **inference** through consumer
subscriptions. Notch Usage only **reads** usage figures, locally, and sends nothing anywhere else.
That is a grey area, not an explicit permission. You use this app at your own risk.

## Troubleshooting

| Symptom | What to do |
|---|---|
| macOS asks for your Keychain password when the app starts | That is the Claude Code credential entry. Click **Always Allow**. With unsigned (ad hoc) builds the prompt returns after each rebuild. |
| "Reconnect required" after using the Claude Code session | Open Claude Code once; it refreshes its token and Notch Usage picks it up. |
| Browser sign-in shows a "Just a moment" / Cloudflare page | Finish the check in the sign-in window, or paste your session key manually in Settings. |
| Nothing shows on an external display | The pill appears at the top of the **main** display. Check Displays → Arrange. |

## License

MIT, see [LICENSE](LICENSE).
