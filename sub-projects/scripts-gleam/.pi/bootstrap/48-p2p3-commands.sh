#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/48-p2p3-commands.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add new gleam sources"
git add -N scripts/src/sys_scripts/commands/inventory.gleam \
           scripts/src/sys_scripts/commands/secrets.gleam \
           nix-configs/inventory.nix \
           nix-configs/modules/tailscale.nix

echo
echo "[$(date -Is)] gleam fmt + test"
cd scripts
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam test 2>&1 | tail -4
cd ..

echo
echo "[$(date -Is)] sys check --fast"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check --fast 2>&1 | tail -8
cd ..

echo
echo "[$(date -Is)] demo: sys inventory list (json, no tailscale addrs yet)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- inventory list 2>&1 | \
  grep -vE '^sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$'
cd ..

echo
echo "[$(date -Is)] demo: sys inventory show nix-k8s-master"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- inventory show nix-k8s-master 2>&1 | \
  grep -vE '^sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$'
cd ..

echo
echo "[$(date -Is)] demo: sys secrets list (expect 'not exist' — P3 not started)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- secrets list 2>&1 | \
  grep -vE '^sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$' || echo "(expected non-zero)"
cd ..

echo
echo "[$(date -Is)] done"
