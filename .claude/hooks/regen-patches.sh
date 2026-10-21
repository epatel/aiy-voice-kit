#!/bin/bash
# PostToolUse hook (Edit|Write): after an edit under port/python/src/,
# regenerate port/python.patch so the diff against upstream never goes stale.
# Fails open: anything missing means do nothing.
f=$(python3 -I -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' 2>/dev/null) || exit 0
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
case "$f" in
  "$root"/port/python/src/*|port/python/src/*) ;;
  *) exit 0 ;;
esac
[ -x "$root/port/make-patches.sh" ] || exit 0
"$root/port/make-patches.sh" >/dev/null 2>&1 || true
exit 0
