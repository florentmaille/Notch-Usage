#!/usr/bin/env bash
# Contrôle du catalogue de textes (feature 002, FR-008) : synchronise Localizable.xcstrings avec les
# textes extraits par la dernière build, puis échoue si un texte n'a pas de traduction française.
# Usage : scripts/check-localizations.sh [DerivedData]   (défaut : .build/DerivedData)
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED="${1:-.build/DerivedData}"
CATALOG="App/NotchUsage/Resources/Localizable.xcstrings"
DATA=$(find "$DERIVED" -name '*.stringsdata' -path '*NotchUsage.build*' -print -quit)
if [ -z "$DATA" ]; then
  echo "Aucun .stringsdata sous $DERIVED : lancez d'abord la build de l'app." >&2
  exit 2
fi
DIR=$(dirname "$DATA")
find "$DIR" -name '*.stringsdata' -print0 | xargs -0 xcrun xcstringstool sync "$CATALOG" --stringsdata
python3 - "$CATALOG" <<'PY'
import json, sys
strings = json.load(open(sys.argv[1]))["strings"]
missing = [k for k, v in strings.items()
           if v.get("extractionState") != "stale"
           and v.get("localizations", {}).get("fr", {}).get("stringUnit", {}).get("state") != "translated"]
stale = [k for k, v in strings.items() if v.get("extractionState") == "stale"]
print(f"{len(strings)} texts, {len(missing)} without French translation, {len(stale)} stale")
for k in missing: print(f"  missing fr: {k!r}")
for k in stale: print(f"  stale: {k!r}")
sys.exit(1 if missing or stale else 0)
PY
