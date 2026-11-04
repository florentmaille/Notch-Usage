#!/usr/bin/env bash
# Release signée et notarisée : scripts/release.sh <version>
# Prérequis : certificat "Developer ID Application" dans le Trousseau, profil notarytool
# (`xcrun notarytool store-credentials notchusage`).
# Produit le zip attendu par le cask (scripts/cask/notch-usage.rb.template), app agrafée (staple).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version>}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-notchusage}"
OUT=build/release
ARCHIVE=build/NotchUsage.xcarchive
APP="$ARCHIVE/Products/Applications/NotchUsage.app"
ZIP="$OUT/NotchUsage-$VERSION.zip"

rm -rf "$OUT" && mkdir -p "$OUT"
scripts/build-app.sh "$ARCHIVE"

echo "→ codesign"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" \
  --entitlements App/NotchUsage/Resources/NotchUsage.entitlements "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "→ notarytool"
# notarytool n'accepte pas une .app nue : on soumet un zip, puis on agrafe le ticket sur l'app et on rezippe.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo "$SHA  $(basename "$ZIP")" > "$ZIP.sha256"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__SHA256__/$SHA/g" scripts/cask/notch-usage.rb.template > "$OUT/notch-usage.rb"
echo "Zip : $ZIP"
echo "SHA256 : $SHA"
echo "Cask : $OUT/notch-usage.rb (à copier dans le tap florentmaille/homebrew-tap)"
