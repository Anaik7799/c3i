#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/29-deploy-plan-nixos.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts

echo "[$(date -Is)] gleam test"
nix develop ../ --quiet --command gleam test 2>&1 | tail -5

echo
echo "[$(date -Is)] demo: deploy plan nixos nix-k8s-master"
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master

echo
echo "[$(date -Is)] demo: deploy plan nixos nonexistent-host"
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nonexistent-host 2>&1 || echo "(expected non-zero exit)"

echo
echo "[$(date -Is)] demo: deploy plan k8s default (still stubbed)"
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan k8s default

echo
echo "[$(date -Is)] done"
