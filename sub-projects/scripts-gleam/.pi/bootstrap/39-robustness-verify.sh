#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/39-robustness-verify.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add new sources"
git add -N \
  scripts/src/sys_scripts/workspace.gleam \
  scripts/src/sys_scripts/commands/check.gleam \
  .githooks/pre-commit \
  .pi/bootstrap/38-install-hooks.sh

echo
echo "[$(date -Is)] gleam fmt"
cd scripts
nix develop ../ --quiet --command gleam format src test
cd ..

echo
echo "[$(date -Is)] cargo fmt"
nix develop --quiet --command cargo fmt --all

echo
echo "[$(date -Is)] gleam test"
cd scripts
nix develop ../ --quiet --command gleam test 2>&1 | tail -4
cd ..

echo
echo "[$(date -Is)] cargo nextest run (with new IO tests)"
nix develop --quiet --command cargo nextest run --workspace 2>&1 | tail -5

echo
echo "[$(date -Is)] install git hooks"
bash /mnt/c/dev/elixir/sys/.pi/bootstrap/38-install-hooks.sh 2>&1 | tail -8

echo
echo "[$(date -Is)] run sys check --fast (what the hook will run)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check --fast
cd ..

echo
echo "[$(date -Is)] demo: deploy plan nixos nix-k8s-master still works with workspace resolver"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master 2>&1 | \
  grep -vE '^sys devshell|^  gleam|^  erl|^  rustc|^  cargo|^  node|^  pnpm|^warning: Git tree|^   Compiled|^    Running|^$'
cd ..

echo
echo "[$(date -Is)] done"
