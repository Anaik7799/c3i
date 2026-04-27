#!/bin/bash
# Scaffold ./scripts/ as a Gleam project targeting Erlang.
# This is the "all scripting in Gleam" anchor directory.
set -euo pipefail

source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/06-scaffold-scripts.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

if [ -d scripts ]; then
  echo "[skip] scripts/ already exists"
  exit 0
fi

echo "[$(date -Is)] running: gleam new scripts (erlang target)"
nix develop --quiet --command gleam new scripts --name sys_scripts

echo "[$(date -Is)] listing result"
ls -la scripts/
cat scripts/gleam.toml

echo "[$(date -Is)] done"
