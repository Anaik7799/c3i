{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "app-entrypoint" ''
  set -e
  # This script now correctly resides in the Nix store, with all paths resolved.
  # SC-FIX-001: Use /bin/sh instead of /bin/bash for NixOS container compatibility
  # NixOS containers have /bin/sh -> nix store bash, but no /bin/bash symlink
  if [ -f "/workspace/scripts/containers/tailscale-entrypoint.sh" ]; then
    /bin/sh /workspace/scripts/containers/tailscale-entrypoint.sh "$@"
  else
    echo "[ENTRYPOINT] No tailscale script found, executing command directly..."
    exec "$@"
  fi
''
