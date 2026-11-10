# Signing and notarizing a stable release

Stable releases must be signed with a Developer ID and notarized by Apple (constitution, *Distribution*).
Previews (`-preview`) are not. Steps 1 to 3 are done once on the Mac that publishes releases.

## 1. Join the Apple Developer Program

[developer.apple.com/programs](https://developer.apple.com/programs/), €99 a year. A free Apple ID only gives an
*Apple Development* certificate, which cannot be used for notarization.

## 2. Create the Developer ID Application certificate

Xcode → Settings → Accounts → select the team → **Manage Certificates…** → **+** → **Developer ID Application**.
Check it is in the Keychain:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## 3. Store the notarization credentials

Create an app-specific password at [account.apple.com](https://account.apple.com) (Sign-In and Security →
App-Specific Passwords), then store it under the `notchusage` profile. `notarytool` asks for the password:

```bash
xcrun notarytool store-credentials notchusage --apple-id "<your Apple ID>" --team-id "<your Team ID>"
```

The password stays in the Keychain; it is never written to the repository.

## 4. Publish

Write `docs/release-notes/<version>.md` with `__SHA256__` where the checksum goes. In its install section, remove
the *Open Anyway* instructions, which are no longer needed. Then:

```bash
scripts/publish.sh 0.6.1 --stable
```

- **Before anything else**, the script checks the certificate and the profile.
- **Signing**: it signs the app with the hardened runtime, notarizes it, staples the ticket and checks it with
  `spctl`.
- **Publication**: it then publishes a full release, not a pre-release, and removes the *not notarized* caveat from
  the Homebrew cask.

`DRY_RUN=1 scripts/publish.sh 0.6.1 --stable` signs and notarizes without committing or pushing anything.
