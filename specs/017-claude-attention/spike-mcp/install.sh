#!/bin/sh
# Spike 017 : déclare le serveur MCP « notch-usage-chat » dans l'app Claude, puis la relance.
# À lancer depuis Terminal.app, pas depuis l'app Claude : le script la quitte.
set -eu
CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CONTAINER="$HOME/Library/Application Support/NotchUsage"
SERVER="$CONTAINER/notch_chat_mcp.py"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "${__CFBundleIdentifier:-}" = "com.anthropic.claudefordesktop" ]; then
  echo "Lancez ce script depuis Terminal.app : il doit quitter l'app Claude." >&2; exit 1
fi
[ -f "$CONFIG" ] || { echo "Config introuvable : $CONFIG" >&2; exit 1; }

echo "1/4 Fermeture de l'app Claude…"
osascript -e 'tell application id "com.anthropic.claudefordesktop" to quit' >/dev/null 2>&1 || true
i=0; while pgrep -xq Claude && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
pgrep -xq Claude && { echo "L'app Claude ne s'est pas fermée. Quittez-la, puis relancez ce script." >&2; exit 1; }

echo "2/4 Sauvegarde de la config…"
BACKUP="$CONFIG.before-notch-spike-$(date +%Y%m%d-%H%M%S)"
cp -p "$CONFIG" "$BACKUP"

echo "3/4 Installation du serveur dans le conteneur de Notch Usage…"
mkdir -p "$CONTAINER"
cp "$HERE/notch_chat_mcp.py" "$SERVER"
chmod 700 "$SERVER"
/usr/bin/python3 -I - "$CONFIG" "$SERVER" <<'PY'
import json, sys
path, server = sys.argv[1], sys.argv[2]
d = json.load(open(path))
d.setdefault("mcpServers", {})["notch-usage-chat"] = {"command": "/usr/bin/python3", "args": ["-I", server]}
# Même format que l'app Claude : indentation 2, sans retour à la ligne final.
open(path, "w").write(json.dumps(d, indent=2, ensure_ascii=False))
PY

echo "4/4 Relance de l'app Claude…"
open -b com.anthropic.claudefordesktop
echo "Fait. Sauvegarde : $BACKUP"
