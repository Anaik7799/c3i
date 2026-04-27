#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/24-gleam-test-runs-rust.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts

echo "[$(date -Is)] gleam run -- test (should run gleam + rust)"
nix develop ../ --quiet --command gleam run -m sys_scripts -- test

echo
echo "[$(date -Is)] done"
