#!/usr/bin/env bash
# install_apalache.sh — install Apalache TLA+ model checker
# STAMP: SC-BOOTSTRAP-005, SC-FRAC-RRF-002
# ZK: [zk-3346fc607a1ef9e6] (no Stub-That-Lies — verify install actually completed)
#
# Why this script: nixpkgs does NOT package apalache-mc as of nixpkgs rev
# 0726a0ecb6d4e08f6adced58726b95db924cef57 (2026-04 channel). devenv.nix
# can install Agda + stdlib + tlaplus + tlaps but Apalache must come from
# the official GitHub release.
#
# This script codifies what Wave 4 Stream K did manually so future installs
# are reproducible. Idempotent: skips re-download if binary already present.
#
# Usage: ./scripts/install_apalache.sh [VERSION]
#   VERSION — defaults to 0.57.0 (the version Stream K verified)

set -euo pipefail

VERSION="${1:-0.57.0}"
INSTALL_DIR="${APALACHE_INSTALL_DIR:-$HOME/.local/opt/apalache-${VERSION}}"
BIN_PATH="${INSTALL_DIR}/bin/apalache-mc"
TARBALL_URL="https://github.com/apalache-mc/apalache/releases/download/v${VERSION}/apalache-${VERSION}.tgz"
TMPDIR_PROBE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_PROBE"' EXIT

# === idempotence: skip if installed and working ===
if [ -x "$BIN_PATH" ]; then
  if "$BIN_PATH" version 2>/dev/null | grep -q "$VERSION"; then
    echo "[apalache] already installed at $BIN_PATH ($VERSION) — skipping"
    echo "[apalache] PATH: export PATH=\"$INSTALL_DIR/bin:\$PATH\""
    exit 0
  fi
fi

# === preflight: java required ===
if ! command -v java >/dev/null 2>&1; then
  echo "[apalache] ERROR: java not found on PATH" >&2
  echo "[apalache] Apalache requires JRE 17+. Install via: nix-shell -p jdk21" >&2
  exit 1
fi

# === download + extract ===
echo "[apalache] downloading v${VERSION} from ${TARBALL_URL}"
mkdir -p "$(dirname "$INSTALL_DIR")"
TARBALL="${TMPDIR_PROBE}/apalache.tgz"

# Use curl with retry; fail loudly if download fails (no Stub-That-Lies)
if ! curl --fail --location --retry 3 --retry-delay 2 \
        --output "$TARBALL" "$TARBALL_URL"; then
  echo "[apalache] ERROR: download failed from $TARBALL_URL" >&2
  echo "[apalache] Check network or try a different version" >&2
  exit 2
fi

# Verify tarball is non-empty and looks like a tar
if [ ! -s "$TARBALL" ]; then
  echo "[apalache] ERROR: downloaded tarball is empty" >&2
  exit 3
fi

echo "[apalache] extracting to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1

# === verify install ===
if [ ! -x "$BIN_PATH" ]; then
  echo "[apalache] ERROR: bin/apalache-mc not present after extract" >&2
  echo "[apalache] Tarball layout may have changed; inspect: $INSTALL_DIR" >&2
  exit 4
fi

# Functional verification: actually run the binary
echo "[apalache] verifying with: $BIN_PATH version"
if ! "$BIN_PATH" version; then
  echo "[apalache] ERROR: binary present but failed to run" >&2
  echo "[apalache] Likely cause: incompatible Java version (need JRE 17+)" >&2
  exit 5
fi

echo ""
echo "[apalache] === INSTALL OK ==="
echo "[apalache] binary: $BIN_PATH"
echo "[apalache] add to shell: export PATH=\"$INSTALL_DIR/bin:\$PATH\""
echo ""
echo "[apalache] usage example:"
echo "  apalache-mc check --inv=DaemonHealthBounded --length=5 specs/tla/HookSubsystem.tla"
echo ""
echo "[apalache] note: TLA+ specs must declare any model values (e.g. NONE) in their .cfg file"
echo "[apalache] see docs/journal/20260429-apalache-model-check-results.md for HookSubsystem.tla notes"
