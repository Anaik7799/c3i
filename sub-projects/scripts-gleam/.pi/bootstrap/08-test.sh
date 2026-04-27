#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/08-test.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys/scripts

echo "[$(date -Is)] gleam deps download"
nix develop ../ --quiet --command gleam deps download

echo "[$(date -Is)] gleam test"
nix develop ../ --quiet --command gleam test

echo "[$(date -Is)] done"
