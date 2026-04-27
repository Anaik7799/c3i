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
  echo '=== git status (should be clean or show only gitignored) ==='
  git status --short
  echo
  echo '=== tracked tree (top-level) ==='
  git ls-tree --name-only HEAD | sort
  echo
  echo '=== tracked under .pi/skills/ ==='
  git ls-tree -r --name-only HEAD -- .pi/skills | sort
  echo
  echo '=== full test suite ==='
  cd scripts
  nix develop ../ --quiet --command gleam test 2>&1 | tail -5
  echo
  echo '=== sys doctor ==='
  nix develop ../ --quiet --command gleam run -m sys_scripts -- doctor 2>&1 | tail -25
  echo
  echo '=== sys deploy (no args) ==='
  nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy 2>&1 | tail -25 || true
} >> "$OUT" 2>&1
