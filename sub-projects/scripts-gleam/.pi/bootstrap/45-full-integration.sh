#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/45-full-integration.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add new files so nix sees them"
git add -N \
  nix-configs/modules/deploy.nix \
  nix-configs/modules/secrets.nix \
  flake.nix flake.lock 2>/dev/null || true

echo
echo "[$(date -Is)] nix flake lock (pick up sops-nix input)"
nix flake lock 2>&1 | tail -10

echo
echo "[$(date -Is)] gleam fmt"
cd scripts
nix develop ../ --quiet --command gleam format src test
cd ..

echo
echo "[$(date -Is)] sys check --fast (for pre-commit budget)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check --fast
cd ..

echo
echo "[$(date -Is)] sys check (full, includes nix eval for every host)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check
cd ..

echo
echo "[$(date -Is)] deploy plan nixos nix-k8s-master (should still work)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master 2>&1 | \
  grep -vE '^sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$'
cd ..

echo
echo "[$(date -Is)] done"
