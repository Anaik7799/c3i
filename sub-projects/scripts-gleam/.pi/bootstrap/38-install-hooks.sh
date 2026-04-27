#!/bin/bash
# Wire .githooks/ into this repo as the hooksPath. Run once per clone.
# Idempotent — sets git config unconditionally.
set -euo pipefail

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/38-install-hooks.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

echo "[$(date -Is)] marking .githooks/* executable"
chmod +x .githooks/pre-commit

echo "[$(date -Is)] git config core.hooksPath .githooks"
git config core.hooksPath .githooks

echo "[$(date -Is)] verifying"
git config --get core.hooksPath
ls -la .githooks/
