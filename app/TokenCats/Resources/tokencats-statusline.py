#!/usr/bin/env python3
"""TokenCats status-line wrapper for Claude Code.

Claude Code pipes a JSON status to this command. When it carries `rate_limits`, the 5-hour and weekly
windows are merged into claude-limits.json for the notch app. Then this process becomes the user's own
status-line command (exec) with the same input, so its output, exit code and signals are exactly as before.
Saving never gets in the way of the user's status line.
"""
import json
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.environ.get("TOKENCATS_LIMITS", os.path.join(HERE, "claude-limits.json"))
ORIGINAL = os.environ.get("TOKENCATS_STATUSLINE_ORIGINAL", os.path.join(HERE, "statusline-original.json"))
# Ours under either name: never exec ourselves. The second is the name before the TokenCats rename.
MARKERS = ("tokencats-statusline.py", "notch-companion-statusline.py")
WINDOWS = ("five_hour", "seven_day")
REFRESH_SECONDS = 60


def merge(previous, incoming):
    """Several Claude sessions report the same windows. Within one window usage only grows, so keep the
    later window (larger resets_at) and, for the same window, the larger percentage. A window a session no
    longer reports is kept; the app shows it as reset once resets_at passes."""
    merged = {key: previous[key] for key in WINDOWS if isinstance(previous.get(key), dict)}
    for key, new in incoming.items():
        old = merged.get(key)
        old_resets = old.get("resets_at") if old else None
        if not isinstance(old_resets, (int, float)) or new["resets_at"] > old_resets:
            merged[key] = new
        elif new["resets_at"] == old_resets:
            merged[key] = {"used_percentage": max(new["used_percentage"], old.get("used_percentage", 0)),
                           "resets_at": new["resets_at"]}
    return merged


def save_snapshot(raw):
    status = json.loads(raw)
    limits = status.get("rate_limits") if isinstance(status, dict) else None
    if not isinstance(limits, dict):
        return
    incoming = {}
    for key in WINDOWS:
        window = limits.get(key)
        if isinstance(window, dict):
            used, resets = window.get("used_percentage"), window.get("resets_at")
            if isinstance(used, (int, float)) and isinstance(resets, (int, float)):
                incoming[key] = {"used_percentage": used, "resets_at": resets}
    if not incoming:
        return
    now = int(time.time())
    try:
        with open(SNAPSHOT) as handle:
            previous = json.load(handle)
    except Exception:
        previous = None
    if not isinstance(previous, dict):
        previous = {}
    windows = merge(previous, incoming)
    unchanged = {key: previous[key] for key in WINDOWS if key in previous} == windows
    if unchanged and now - int(previous.get("updated_at", 0)) < REFRESH_SECONDS:
        return
    descriptor, temporary = tempfile.mkstemp(dir=os.path.dirname(SNAPSHOT), prefix=".claude-limits-")
    with os.fdopen(descriptor, "w") as handle:
        json.dump(dict(windows, updated_at=now), handle)
    os.replace(temporary, SNAPSHOT)


def original_command():
    try:
        with open(ORIGINAL) as handle:
            line = json.load(handle).get("statusLine")
    except Exception:
        return None
    command = line.get("command") if isinstance(line, dict) else None
    if not isinstance(command, str) or not command.strip() or any(marker in command for marker in MARKERS):
        return None
    return command


def become(command, raw):
    """Replace this process with the original command, its stdin holding the same bytes."""
    descriptor, path = tempfile.mkstemp(prefix="notch-statusline-")
    os.unlink(path)
    view = memoryview(raw)
    while view:
        view = view[os.write(descriptor, view):]
    os.lseek(descriptor, 0, os.SEEK_SET)
    os.dup2(descriptor, 0)
    os.close(descriptor)
    sys.stdout.flush()
    os.execv("/bin/sh", ["/bin/sh", "-c", command])


def main():
    raw = sys.stdin.buffer.read()
    try:
        save_snapshot(raw)
    except Exception:
        pass
    command = original_command()
    if command is None:
        return 0
    become(command, raw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
