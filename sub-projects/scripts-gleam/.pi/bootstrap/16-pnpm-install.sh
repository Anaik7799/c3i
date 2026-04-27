#!/bin/bash
# Replace the ad-hoc `npm install` node_modules + package-lock.json with
# a pnpm-managed setup that uses the Nix-pinned node/pnpm versions.
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/16-pnpm-install.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

echo "[$(date -Is)] removing old npm-managed cruft"
rm -rf node_modules package-lock.json

echo "[$(date -Is)] pnpm install (via nix devshell)"
nix develop --quiet --command pnpm install --silent

echo "[$(date -Is)] verifying skillfish is executable"
nix develop --quiet --command pnpm exec skillfish --version || {
  echo "(skillfish --version not supported; trying --help)"
  nix develop --quiet --command pnpm exec skillfish --help | head -20
}

echo "[$(date -Is)] done"
