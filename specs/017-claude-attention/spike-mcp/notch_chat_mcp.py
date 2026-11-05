#!/usr/bin/python3
"""Spike 017 : serveur MCP minimal (stdio) pour signaler la fin d'une réponse du chat Claude à Notch Usage.

L'app Claude lance ce script au démarrage. Le modèle appelle l'outil `notch_reply_done` en fin de réponse ;
le script ajoute alors un événement « Stop » au fichier lu par Notch Usage (même format que le hook de Claude
Code), et une ligne au journal du spike pour compter les appels. Bibliothèque standard seulement.
"""
import json
import os
import re
import sys
import time

CONTAINER = os.path.expanduser("~/Library/Application Support/NotchUsage")
EVENTS = os.path.join(CONTAINER, "claude-events.jsonl")
SPIKE_LOG = os.path.join(CONTAINER, "chat-mcp-spike.log")

TOOL = {
    "name": "notch_reply_done",
    "description": (
        "Call this tool exactly once, as the very last step of EVERY response you write in this conversation, "
        "after the answer itself. It lights a small signal in the user's MacBook notch to tell them you are done "
        "and waiting for them. Pass the title of this conversation as it appears in the Claude sidebar if you know "
        "it; otherwise a 2 to 5 word summary of the user's FIRST message, in the user's language, identical on every "
        "call of this conversation. Your answer is already visible when you call it: after the call, end your turn immediately "
        "without writing anything else, and never repeat or summarise your answer."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "conversation_title": {"type": "string", "description": "Short stable title of this conversation, 2 to 6 words."}
        },
        "required": ["conversation_title"],
    },
    "annotations": {"title": "Notch: reply done", "readOnlyHint": False, "destructiveHint": False, "openWorldHint": False},
}


def append(path, line):
    # Une seule écriture par ligne, comme le script de hook : le lecteur ne consomme que des lignes complètes.
    try:
        if not os.path.isdir(CONTAINER):
            return
        fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        try:
            os.write(fd, (line + "\n").encode("utf-8"))
        finally:
            os.close(fd)
    except OSError:
        pass


def describe(params):
    meta = params.get("_meta")
    if isinstance(meta, dict):
        meta = {k: (str(v)[:80] if not isinstance(v, (int, float, bool)) else v) for k, v in meta.items()}
    return {"keys": sorted(params.keys()), "meta": meta, "argument_keys": sorted((params.get("arguments") or {}).keys())}


def reply_done(args, params=None):
    title = str(args.get("conversation_title") or "").strip()[:60] or "Chat"
    slug = re.sub(r"[\W_]+", "-", title.lower()).strip("-") or "chat"
    now = time.time()
    event = {"hook_event_name": "Stop", "session_id": "chat-" + slug, "cwd": "", "session_title": title, "source": "claude-chat-mcp"}
    append(EVENTS, json.dumps({"ppid": os.getppid(), "ts": int(now), "event": event}, ensure_ascii=False))
    append(SPIKE_LOG, json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(now)), "title": title,
                                  "request": describe(params or {})}, ensure_ascii=False))
    # Le texte du résultat est lu par le modèle : « ok » seul l'amenait à réécrire toute sa réponse (spike, 18 h 24).
    return {"content": [{"type": "text", "text": "Signal sent. The user has already read your answer above. "
                                                 "End your turn now: write nothing more."}]}


def respond(msg_id, result=None, error=None):
    out = {"jsonrpc": "2.0", "id": msg_id}
    if error is not None:
        out["error"] = error
    else:
        out["result"] = result
    sys.stdout.write(json.dumps(out) + "\n")
    sys.stdout.flush()


def handle(msg):
    method, msg_id, params = msg.get("method"), msg.get("id"), msg.get("params") or {}
    if msg_id is None:
        return  # notification (initialized, cancelled…) : rien à répondre
    if method == "initialize":
        append(SPIKE_LOG, json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "initialize": {"clientInfo": params.get("clientInfo"),
                                      "capabilities": sorted((params.get("capabilities") or {}).keys())}}))
        respond(msg_id, {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": "notch-usage-chat", "version": "0.0.3-spike"},
        })
    elif method == "ping":
        respond(msg_id, {})
    elif method == "tools/list":
        respond(msg_id, {"tools": [TOOL]})
    elif method == "tools/call":
        if params.get("name") == TOOL["name"]:
            respond(msg_id, reply_done(params.get("arguments") or {}, params))
        else:
            respond(msg_id, error={"code": -32602, "message": "unknown tool"})
    elif method in ("resources/list", "prompts/list"):
        respond(msg_id, {method.split("/")[0]: []})
    else:
        respond(msg_id, error={"code": -32601, "message": "method not found"})


def main():
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            handle(json.loads(raw))
        except Exception as exc:  # ne jamais tomber : l'app Claude marquerait le serveur en échec
            sys.stderr.write("notch-usage-chat: %s\n" % exc)
            sys.stderr.flush()


if __name__ == "__main__":
    main()
