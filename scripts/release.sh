#!/usr/bin/env bash
# Release signée et notarisée : scripts/release.sh <version>
# Prérequis : certificat "Developer ID Application" dans le Trousseau, profil notarytool
# (`xcrun notarytool store-credentials notchusage`), `brew install create-dmg` facultatif.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version>}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-notchusage}"
OUT=build/release
ARCHIVE=build/NotchUsage.xcarchive
APP="$ARCHIVE/Products/Applications/NotchUsage.app"
DMG="$OUT/NotchUsage-$VERSION.dmg"

rm -rf "$OUT" && mkdir -p "$OUT"
scripts/build-app.sh "$ARCHIVE"

echo "→ codesign"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" \
  --entitlements App/NotchUsage/Resources/NotchUsage.entitlements "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "→ DMG"
STAGING="$OUT/dmg"
mkdir -p "$STAGING" && cp -R "$APP" "$STAGING/" && ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Notch Usage" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "→ notarytool"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
sed -e "s/__VERSION__/$VERSION/g" -e "s/__SHA256__/$SHA/g" scripts/cask/notch-usage.rb.template > "$OUT/notch-usage.rb"
echo "DMG : $DMG"
echo "SHA256 : $SHA"
echo "Cask : $OUT/notch-usage.rb (à copier dans le tap florentmaille/homebrew-tap)"
