#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== skillfish --help ==='
  nix develop --quiet --command pnpm exec skillfish --help 2>&1 || true
  echo
  echo '=== subcommand: list ==='
  nix develop --quiet --command pnpm exec skillfish list --help 2>&1 || true
  echo
  echo '=== subcommand: search ==='
  nix develop --quiet --command pnpm exec skillfish search --help 2>&1 || true
  echo
  echo '=== subcommand: install ==='
  nix develop --quiet --command pnpm exec skillfish install --help 2>&1 || true
  echo
  echo '=== subcommand: pack ==='
  nix develop --quiet --command pnpm exec skillfish pack --help 2>&1 || true
  echo
  echo '=== README head ==='
  head -80 node_modules/skillfish/README.md 2>&1 || true
} >> "$OUT"
