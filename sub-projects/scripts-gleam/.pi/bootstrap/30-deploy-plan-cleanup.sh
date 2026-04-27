#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/30-deploy-plan-cleanup.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts

echo "[$(date -Is)] gleam fmt + test"
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam test 2>&1 | tail -3

echo
echo "=== happy path ==="
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-worker-1

echo
echo "=== error path ==="
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos does-not-exist 2>&1 || echo "(exit \$?)"
