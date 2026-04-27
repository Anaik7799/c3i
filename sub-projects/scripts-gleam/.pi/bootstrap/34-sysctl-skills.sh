#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/34-sysctl-skills.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add new Rust files so cargo can see them"
git add -N crates/sysctl/src/skills.rs

echo
echo "[$(date -Is)] cargo fmt"
nix develop --quiet --command cargo fmt --all

echo
echo "[$(date -Is)] cargo clippy -D warnings"
nix develop --quiet --command cargo clippy --workspace --all-targets --all-features -- -D warnings

echo
echo "[$(date -Is)] cargo nextest run"
nix develop --quiet --command cargo nextest run --workspace

echo
echo "[$(date -Is)] live demo: sysctl skills list (table)"
nix develop --quiet --command cargo run --quiet -p sysctl -- skills list

echo
echo "[$(date -Is)] live demo: sysctl skills list --json (JSON)"
nix develop --quiet --command cargo run --quiet -p sysctl -- skills list --json

echo
echo "[$(date -Is)] done"
