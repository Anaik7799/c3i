#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== git ==='
  git log --oneline | head -8
  echo
  echo '=== status (only this script should be dirty) ==='
  git status --short
  echo
  echo '=== remote ==='
  git remote -v
  git --git-dir=/root/git/sys.git log --oneline | head -5
  echo
  echo '=== gleam tests ==='
  cd scripts
  nix develop ../ --quiet --command gleam test 2>&1 | tail -3
  cd ..
  echo
  echo '=== rust tests ==='
  nix develop --quiet --command cargo nextest run --workspace 2>&1 | tail -3
  echo
  echo '=== deploy plan nixos nix-k8s-master (clean output, no warnings) ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master 2>&1 | grep -v 'Compiled in\|Running sys_scripts\|sys devshell\|  gleam\|  erl\|  rustc\|  cargo\|  node\|  pnpm\|warning: Git tree'
  cd ..
  echo
  echo '=== sysctl skills list ==='
  nix develop --quiet --command cargo run --quiet -p sysctl -- skills list 2>&1 | grep -v 'sys devshell\|  gleam\|  erl\|  rustc\|  cargo\|  node\|  pnpm\|warning: Git tree'
} >> "$OUT" 2>&1
