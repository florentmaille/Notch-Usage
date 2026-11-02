#!/usr/bin/env bash
# Signe les builds Debug avec le premier certificat « Apple Development » du trousseau : macOS reconnaît
# alors l'app d'une build à l'autre et ne redemande plus l'accès au trousseau.
set -euo pipefail
cd "$(dirname "$0")/.."
identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)
if [[ -z "$identity" ]]; then
  echo "Aucun certificat Apple Development. Xcode → Réglages → Comptes → Gérer les certificats → + → Apple Development." >&2
  exit 1
fi
cat > Config/Local.xcconfig <<XC
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = $identity
XC
echo "Builds Debug signées avec : $identity"
