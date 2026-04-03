{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "app-entrypoint" ''
  #!/bin/bash
  set -e
  # This script now correctly resides in the Nix store, with all paths resolved.
  /bin/bash /workspace/scripts/containers/tailscale-entrypoint.sh "$@"
''
