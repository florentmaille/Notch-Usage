#!/usr/bin/env bash
# Signe les builds Debug avec le premier certificat « Apple Development » du trousseau : macOS reconnaît
# alors l'app d'une build à l'autre et ne redemande plus l'accès au trousseau.
set -euo pipefail
cd "$(dirname "$0")/.."
identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)
if [[ -z "$identity" ]]; then
  if security find-identity -p codesigning | grep -q "Apple Development:"; then
    # Certificat présent mais chaîne incomplète : cas courant sur un trousseau ancien.
    echo "Certificat Apple Development invalide : installez l'intermédiaire Apple WWDR G3" >&2
    echo "(https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer, double-clic, trousseau « session »)." >&2
  else
    echo "Aucun certificat Apple Development. Xcode → Réglages → Comptes → Gérer les certificats → + → Apple Development." >&2
  fi
  exit 1
fi
cat > Config/Local.xcconfig <<XC
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = $identity
XC
echo "Builds Debug signées avec : $identity"
