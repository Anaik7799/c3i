#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/26-commit-nix-rust.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] gleam fmt + full test run before commit"
cd scripts
nix develop ../ --quiet --command gleam format src test
cd ..

cd /mnt/c/dev/elixir/sys
echo
echo "[$(date -Is)] cargo fmt --all"
nix develop --quiet --command cargo fmt --all

echo
echo "[$(date -Is)] git add -A"
git add -A

echo
echo "=== staged stat ==="
git diff --cached --stat

echo
echo "[$(date -Is)] split into 2 commits: nix + rust"
# Unstage rust to commit nix first
git reset -- Cargo.toml Cargo.lock rust-toolchain.toml crates/

echo
echo "--- commit 1: nix ---"
git diff --cached --stat
git commit -m 'feat(nix-configs): real NixOS modules + 3 nixosConfigurations

- modules/base.nix: reusable baseline (hardened sshd, nftables, chrony,
  passwordless-wheel ops user, weekly nix-gc, flakes enabled, minimal
  base package set). Exposes typed options under sys.base.*.
- k3s/server.nix: K3s control-plane module. Opens 6443/2379/2380/10250
  TCP and 8472/51820 UDP; disables traefik+servicelb by default so
  downstream ingress choices are explicit.
- k3s/agent.nix: K3s worker module with the minimal firewall surface.
- hosts/nas1/{nix-k8s-master,nix-k8s-worker-1,nix-k8s-worker-2}/
  configuration.nix: one-liner wiring per VM. sshAuthorizedKeys +
  hardware-configuration.nix still TODO (Phase 1 install-time work).
- flake.nix: export nixosConfigurations.{nix-k8s-master,
  nix-k8s-worker-1, nix-k8s-worker-2} alongside the devshell. All
  three evaluate cleanly (hostName, services.k3s.role, firewall ports
  verified via nix eval).'

echo
echo "--- commit 2: rust ---"
git add Cargo.toml Cargo.lock rust-toolchain.toml crates/
# Also pick up any fmt changes to the scripts/src tree that happened
# during this run (tests.gleam was extended to also run cargo nextest).
git add scripts/src/sys_scripts/commands/tests.gleam
git diff --cached --stat
git commit -m 'feat(rust): cargo workspace + sysctl placeholder crate

- rust-toolchain.toml pins stable with clippy/rustfmt/rust-analyzer
  (minimal profile). The flake already honors rust-toolchain.toml via
  rust-overlay.fromRustupToolchainFile when present.
- Cargo.toml workspace: shared [workspace.package], strict lints
  (deny unwrap_used/expect_used/panic, warn pedantic+nursery with
  correct -1 priority so specific allows work).
- crates/sysctl: idiomatic FP-leaning Rust starter:
    * domain.rs defines HostName newtype (RFC 1123 label validation)
    * error.rs uses thiserror with Io(#[from])
    * main.rs is a thin clap wrapper over a pure run() function
    * 7 example tests + 3 proptest properties (any-valid-label,
      roundtrip, uppercase-rejection). cargo nextest: 10/10 pass.
    * cargo clippy -D warnings clean.
- scripts/src/.../commands/tests.gleam: `sys test` now autodetects
  Cargo.toml and runs `cargo nextest run --workspace` after the
  Gleam suite. Gleam stays the orchestrator.'

echo
echo "=== final log ==="
git log --oneline
