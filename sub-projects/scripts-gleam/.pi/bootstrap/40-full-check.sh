#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/40-full-check.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts
echo "[$(date -Is)] full sys check (includes clippy + flake check)"
nix develop ../ --quiet --command gleam run -m sys_scripts -- check
