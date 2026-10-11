#!/usr/bin/env python3
"""TokenCats hook: forwards Claude Code / Codex hook events to the app.

Pattern adapted from Notchi (https://github.com/sk-ruban/notchi, GPL-3.0).
Contract: observe only. Never wait for a reply, never print, always exit 0.
"""
import json
import os
import socket
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# The app listens next to this script (its support folder), or under ~/.tokencats when that path is too long
# for a socket address (SocketServer.resolvedSocketPath).
SOCKET_PATH = os.environ.get("TOKENCATS_SOCKET") or next(
    (path for path in (os.path.join(HERE, "companion.sock"), os.path.expanduser("~/.tokencats/companion.sock"))
     if os.path.exists(path)),
    os.path.join(HERE, "companion.sock"),
)
FIRE_AND_FORGET_TIMEOUT = 0.3
SUMMARY_KEYS = ("command", "file_path", "path", "pattern", "url", "description")


def summarize(tool_input):
    if not isinstance(tool_input, dict):
        return ""
    for key in SUMMARY_KEYS:
        value = tool_input.get(key)
        if isinstance(value, str) and value.strip():
            return " ".join(value.split())[:80]
    return ""


def main():
    provider = sys.argv[1] if len(sys.argv) > 1 else "claude"
    if not os.path.exists(SOCKET_PATH):
        # The app is closed. Still read the whole input: leaving a large payload unread would hand the agent a
        # broken pipe.
        try:
            sys.stdin.buffer.read()
        except Exception:
            pass
        return
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    debug_log = os.environ.get("TOKENCATS_DEBUG_LOG")
    if debug_log:
        with open(debug_log, "a") as handle:
            handle.write(json.dumps({"provider": provider, "input": data}) + "\n")

    event = data.get("hook_event_name", "")
    payload = {
        "provider": provider,
        "session_id": data.get("session_id", ""),
        "event": event,
        "cwd": data.get("cwd") or os.getcwd(),
        "tool": data.get("tool_name"),
        "tool_summary": summarize(data.get("tool_input")),
        "orca_terminal": os.environ.get("ORCA_TERMINAL_HANDLE"),
        "ts": time.time(),
        "hook_ppid": os.getppid(),
    }

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.settimeout(FIRE_AND_FORGET_TIMEOUT)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(payload).encode())
        sock.shutdown(socket.SHUT_WR)
    finally:
        sock.close()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
