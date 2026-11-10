# Security policy

Notch Usage reads Claude credentials from the macOS Keychain, talks to `api.anthropic.com` and `claude.ai`, and,
with *Follow Claude Code* on, writes hook entries to `~/.claude/settings.json`. Reports about any of these are
welcome.

## Reporting a vulnerability

Please report privately, not in a public issue: on GitHub, open the repository's **Security** tab and click
**Report a vulnerability**. You will get an answer within a week.

Useful in a report: the app version (*Settings*, bottom line), the macOS version, what you observed and how to
reproduce it. Never include a session key, a token or the content of your Keychain.

## Scope

- Credentials: how the app reads, keeps and deletes the Claude Code token and the `claude.ai` session key.
- Network: any request to a host other than `api.anthropic.com` and `claude.ai`, or a secret sent anywhere else.
- Local files: what the app writes under `~/Library/Application Support/NotchUsage` and to
  `~/.claude/settings.json`, and the hook script Claude Code runs.
- Distribution: the release zip, its checksum and the Homebrew cask.

Out of scope: Anthropic's own services and Claude Code itself.

## Supported versions

Only the latest release receives fixes. Previews (`-preview`) are not notarized; check the SHA-256 published in
the release notes before opening a downloaded zip.
