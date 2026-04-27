#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/07-build-scripts.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts

echo "[$(date -Is)] gleam deps download"
nix develop ../ --quiet --command gleam deps download

echo "[$(date -Is)] gleam build"
nix develop ../ --quiet --command gleam build

echo "[$(date -Is)] gleam run -- doctor"
nix develop ../ --quiet --command gleam run -m sys_scripts -- doctor

echo "[$(date -Is)] done"
