#!/bin/bash
# Prime the nix devshell: fetch flake inputs, build all derivations, warm the store.
set -euo pipefail

source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/05-nix-develop-prime.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] nix flake metadata"
nix flake metadata --no-write-lock-file || true

echo "[$(date -Is)] nix flake lock (generate flake.lock)"
nix flake lock

echo "[$(date -Is)] building devshell (this will fetch erlang/gleam/rust/node)"
# --accept-flake-config: trust substituters declared in the flake
# --print-build-logs: show what's being built
nix develop --command bash -c '
  set -e
  echo
  echo "=== inside devshell ==="
  gleam --version
  erl -eval "erlang:display(erlang:system_info(otp_release)), halt()." -noshell | tr -d \"\\\"\"
  rustc --version
  cargo --version
  node --version
  pnpm --version
  rebar3 --version
  elixir --version | head -1
  echo "=== OK ==="
'

echo "[$(date -Is)] done"
