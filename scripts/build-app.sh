#!/usr/bin/env bash
# Génère le projet Xcode et produit une archive Release de NotchUsage.app.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE="${1:-build/NotchUsage.xcarchive}"
xcodegen generate
xcodebuild -project NotchUsage.xcodeproj -scheme NotchUsage -configuration Release \
  -destination 'platform=macOS' -archivePath "$ARCHIVE" archive | tail -3
echo "Archive : $ARCHIVE/Products/Applications/NotchUsage.app"
