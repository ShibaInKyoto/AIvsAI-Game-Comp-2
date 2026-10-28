#!/usr/bin/env bash
# Runs Godot with the given arguments and fails if it exits non-zero or prints
# a script or shader error. Godot reports runtime script errors without
# changing its exit code, so CI checks the log as well.
set -uo pipefail
GODOT="${GODOT:-godot}"
log="$(mktemp)"
"$GODOT" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|SHADER ERROR|Parse Error" "$log"; then
  echo "::error::Godot reported script or shader errors"
  status=1
fi
rm -f "$log"
exit "$status"
