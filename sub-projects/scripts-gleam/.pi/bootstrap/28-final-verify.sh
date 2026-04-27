#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== git log ==='
  git log --oneline
  echo
  echo '=== git status ==='
  git status --short
  echo
  echo '=== git remote -v ==='
  git remote -v
  echo
  echo '=== tree top level ==='
  git ls-tree --name-only HEAD | sort
  echo
  echo '=== nix flake show ==='
  nix flake show --no-write-lock-file 2>&1 | grep -E 'nixosConfigurations|devShells|default|master|worker' | head -20
  echo
  echo '=== all tests ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- test 2>&1 | tail -20
  cd ..
  echo
  echo '=== sys doctor ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- doctor 2>&1 | tail -15
} >> "$OUT" 2>&1
