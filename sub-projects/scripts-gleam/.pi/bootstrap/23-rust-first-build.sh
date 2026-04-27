#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/23-rust-first-build.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] ensure rust-toolchain.toml is seen by the flake"
git add -N rust-toolchain.toml Cargo.toml crates/ flake.nix

echo
echo "[$(date -Is)] rustc + cargo versions (should honor rust-toolchain.toml)"
nix develop --quiet --command rustc --version
nix develop --quiet --command cargo --version

echo
echo "[$(date -Is)] cargo fmt --check"
nix develop --quiet --command cargo fmt --all -- --check || {
  echo "  (fmt would change files; applying)"
  nix develop --quiet --command cargo fmt --all
}

echo
echo "[$(date -Is)] cargo clippy -D warnings"
nix develop --quiet --command cargo clippy --workspace --all-targets --all-features -- -D warnings

echo
echo "[$(date -Is)] cargo nextest run"
nix develop --quiet --command cargo nextest run --workspace

echo
echo "[$(date -Is)] sysctl smoke test"
nix develop --quiet --command cargo run --quiet -p sysctl -- version
nix develop --quiet --command cargo run --quiet -p sysctl -- hostname nix-k8s-master
if nix develop --quiet --command cargo run --quiet -p sysctl -- hostname 'Foo!' 2>/tmp/sysctl-stderr; then
  echo "  ERROR: sysctl accepted an invalid hostname"
  exit 1
else
  echo "  expected rejection: $(cat /tmp/sysctl-stderr)"
fi

echo
echo "[$(date -Is)] done"
