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
  echo '=== git status (clean except gitignored/new bootstrap) ==='
  git status --short
  echo
  echo '=== tree top-level ==='
  git ls-tree --name-only HEAD | sort
  echo
  echo '=== nix-configs/ ==='
  git ls-tree -r --name-only HEAD -- nix-configs
  echo
  echo '=== docs/ ==='
  git ls-tree -r --name-only HEAD -- docs
  echo
  echo '=== skillfish exec check ==='
  nix develop --quiet --command pnpm exec skillfish --version 2>&1 | grep -v '^$' | tail -3
  echo
  echo '=== gleam test ==='
  cd scripts
  nix develop ../ --quiet --command gleam test 2>&1 | tail -5
} >> "$OUT" 2>&1
