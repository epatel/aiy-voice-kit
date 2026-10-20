#!/bin/bash
# Regenerates port/python.patch: the diff of this port against Google's upstream
# snapshot in docs/aiyprojects-raspbian/src.
#
# port/python/ holds only the parts that apply to the Voice HAT, so files that are
# only upstream (vision, assistant, Voice/Vision Bonnet hardware) are not listed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$ROOT/docs/aiyprojects-raspbian"
cd "$ROOT"

[[ -d "$UPSTREAM" ]] || { echo "missing $UPSTREAM" >&2; exit 1; }

# Stable output: no file timestamps, and one fixed form for the per-file diff
# lines, so the patch only changes when the code does.
diff -ru -x __pycache__ -x '*.egg-info' docs/aiyprojects-raspbian/src port/python/src \
  | grep -v '^Only in docs/' \
  | sed -E -e 's/^((---|\+\+\+) [^[:space:]]+)[[:space:]].*$/\1/' \
           -e 's#^diff .* (docs/aiyprojects-raspbian/[^ ]+) (port/[^ ]+)$#diff -ru \1 \2#' \
  > port/python.patch || true
