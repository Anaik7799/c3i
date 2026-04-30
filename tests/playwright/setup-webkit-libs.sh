#!/usr/bin/env bash
# Idempotently symlink Nix-built ABI-pinned libs into the Playwright WebKit
# bundle's lib dirs so the vendored MiniBrowser wrapper finds them.
#
# Authority: SC-PLANNING-EVO-004 (cross-browser Playwright), SC-MUDA-001
# (one closed-set fix vs piecemeal LD_LIBRARY_PATH chasing).
#
# Why we patch WebKit's bundle and not LD_LIBRARY_PATH at runtime:
# the wrapper at $WEBKIT/minibrowser-{wpe,gtk}/MiniBrowser unconditionally
# overrides LD_LIBRARY_PATH to "${MYDIR}/lib:${MYDIR}/sys/lib", discarding
# anything the caller exports.  Symlinking into ${MYDIR}/lib survives.
#
# Usage: ./setup-webkit-libs.sh
# Prereq: nix-shell, nix-build available; webkit-2191 already downloaded
# via `npx playwright install webkit` against @playwright/test 1.54.1.

set -euo pipefail

WEBKIT_VER="webkit-2191"
WEBKIT_ROOT="$HOME/.cache/ms-playwright/$WEBKIT_VER"

if [[ ! -d "$WEBKIT_ROOT" ]]; then
  echo "ERROR: $WEBKIT_ROOT not found — run 'npx playwright install webkit' first" >&2
  exit 1
fi

echo "Building Nix dependency closure (cached after first run)..."
ICU=$(nix-build '<nixpkgs>' -A icu74 --no-out-link 2>/dev/null | tail -1)
LIBXML2=$(nix-build '<nixpkgs>' -A libxml2_13.out --no-out-link 2>/dev/null | tail -1)
LIBJXL=$(nix-build -E 'with import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-23.11.tar.gz") {}; libjxl' --no-out-link 2>/dev/null | tail -1)
LIBEVENT=$(nix-build '<nixpkgs>' -A libevent --no-out-link 2>/dev/null | tail -1)
LIBAVIF=$(nix-build '<nixpkgs>' -A libavif --no-out-link 2>/dev/null | tail -1)
LIBMANETTE=$(nix-build '<nixpkgs>' -A libmanette --no-out-link 2>/dev/null | tail -1)
GST=$(nix-build '<nixpkgs>' -A gst_all_1.gst-plugins-bad --no-out-link 2>/dev/null | tail -1)

echo "ICU=$ICU"
echo "LIBXML2=$LIBXML2"
echo "LIBJXL=$LIBJXL"
echo "LIBEVENT=$LIBEVENT"
echo "LIBAVIF=$LIBAVIF"
echo "LIBMANETTE=$LIBMANETTE"
echo "GST=$GST"

link_into() {
  local LIBDIR="$1"
  ln -sf "$ICU/lib/libicudata.so.74" "$LIBDIR/libicudata.so.74"
  ln -sf "$ICU/lib/libicui18n.so.74" "$LIBDIR/libicui18n.so.74"
  ln -sf "$ICU/lib/libicuuc.so.74"   "$LIBDIR/libicuuc.so.74"
  ln -sf "$LIBXML2/lib/libxml2.so.2" "$LIBDIR/libxml2.so.2"
  ln -sf "$LIBJXL/lib/libjxl.so.0.8" "$LIBDIR/libjxl.so.0.8"
  ln -sf "$LIBAVIF/lib/libavif.so.16" "$LIBDIR/libavif.so.16"
  ln -sf "$LIBEVENT/lib/libevent-2.1.so.7" "$LIBDIR/libevent-2.1.so.7"
  ln -sf "$LIBMANETTE/lib/libmanette-0.2.so.0" "$LIBDIR/libmanette-0.2.so.0"
  ln -sf "$GST/lib/libgstcodecparsers-1.0.so.0" "$LIBDIR/libgstcodecparsers-1.0.so.0"
}

link_into "$WEBKIT_ROOT/minibrowser-wpe/lib"
link_into "$WEBKIT_ROOT/minibrowser-gtk/lib"

echo "Verifying ldd (using the same LD_LIBRARY_PATH the wrapper sets)..."
verify_under_wrapper() {
  local LIBDIR="$1"
  local BIN="$2"
  local SYS="$LIBDIR/../sys/lib"
  LD_LIBRARY_PATH="$LIBDIR:$SYS" ldd "$BIN" 2>&1 | grep -c "not found" || true
}
MISSING_WPE=$(verify_under_wrapper "$WEBKIT_ROOT/minibrowser-wpe/lib" "$WEBKIT_ROOT/minibrowser-wpe/bin/MiniBrowser")
MISSING_GTK=$(verify_under_wrapper "$WEBKIT_ROOT/minibrowser-gtk/lib" "$WEBKIT_ROOT/minibrowser-gtk/bin/MiniBrowser")
echo "WPE missing libs: $MISSING_WPE"
echo "GTK missing libs: $MISSING_GTK"

if [[ "$MISSING_WPE" != "0" || "$MISSING_GTK" != "0" ]]; then
  echo "WARNING: some libs still unresolved — investigate ldd output." >&2
  exit 2
fi

echo "OK — WebKit ready for Playwright runs."
