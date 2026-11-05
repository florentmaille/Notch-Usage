#!/bin/sh
# Spike 017 : retire le serveur MCP « notch-usage-chat » de l'app Claude et ses fichiers, puis relance l'app.
# À lancer depuis Terminal.app.
set -eu
CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CONTAINER="$HOME/Library/Application Support/NotchUsage"

if [ "${__CFBundleIdentifier:-}" = "com.anthropic.claudefordesktop" ]; then
  echo "Lancez ce script depuis Terminal.app : il doit quitter l'app Claude." >&2; exit 1
fi
osascript -e 'tell application id "com.anthropic.claudefordesktop" to quit' >/dev/null 2>&1 || true
i=0; while pgrep -xq Claude && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
pgrep -xq Claude && { echo "L'app Claude ne s'est pas fermée. Quittez-la, puis relancez ce script." >&2; exit 1; }
/usr/bin/python3 -I - "$CONFIG" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
d.get("mcpServers", {}).pop("notch-usage-chat", None)
open(path, "w").write(json.dumps(d, indent=2, ensure_ascii=False))
PY
rm -f "$CONTAINER/notch_chat_mcp.py" "$CONTAINER/chat-mcp-spike.log"
open -b com.anthropic.claudefordesktop
echo "Serveur retiré."
