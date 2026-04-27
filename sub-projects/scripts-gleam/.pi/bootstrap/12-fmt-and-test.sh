#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/12-fmt-and-test.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam test

echo
echo '=== demo: deploy help / plan / apply ==='
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy || true
echo
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nas1 || true
echo
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy apply k8s prod || true
echo
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy apply k8s prod --execute || true
