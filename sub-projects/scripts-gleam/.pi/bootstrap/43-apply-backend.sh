#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/43-apply-backend.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add"
git add -N nix-configs/modules/deploy.nix

echo
echo "[$(date -Is)] gleam fmt + build"
cd scripts
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam build 2>&1 | tail -5
cd ..

echo
echo "[$(date -Is)] gleam test"
cd scripts
nix develop ../ --quiet --command gleam test 2>&1 | tail -3
cd ..

echo
echo "[$(date -Is)] sanity: nix eval sys.deploy.targetHost on each host"
for h in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
  echo -n "  $h targetHost: "
  nix eval --no-write-lock-file ".#nixosConfigurations.$h.config.sys.deploy.targetHost" 2>&1 | \
    grep -vE 'warning: Git|^$' | tail -1
done

echo
echo "[$(date -Is)] demo: deploy apply nixos nix-k8s-master (should refuse — targetHost is null)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy apply nixos nix-k8s-master 2>&1 | \
  grep -vE 'sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$' || echo "(expected non-zero exit)"
cd ..

echo
echo "[$(date -Is)] done"
