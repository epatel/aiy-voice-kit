#!/bin/bash
# From the Mac: copies port/ to a Pi and runs install.sh.
#
#   port/deploy.sh pi@voice-kit.local [install.sh options]
#
# Needs SSH key login and passwordless sudo.
set -euo pipefail

HOST="${1:?usage: $0 user@host [install.sh options]}"
shift
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rsync -a --delete --exclude __pycache__ --exclude '*.egg-info' "$ROOT/port/" "$HOST:voice-kit-port/"
# Quote each option for the remote shell (e.g. --echo-args "--greeting Hello there").
# macOS has bash 3.2: no ${*@Q}, and "$@" is an error under set -u when empty.
ARGS=""
[[ $# -gt 0 ]] && printf -v ARGS ' %q' "$@"
ssh -t "$HOST" "cd voice-kit-port && sudo ./install.sh$ARGS"
