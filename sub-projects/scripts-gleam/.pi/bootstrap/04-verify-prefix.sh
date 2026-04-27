#!/bin/bash
set -euo pipefail
out=/mnt/c/dev/elixir/sys/.pi/bootstrap/04-verify-prefix.log
: > "$out"
{
  echo "=== PATH (should contain /nix/...) ==="
  echo "$PATH" | tr ':' '\n' | head -20
  echo
  echo "=== nix ==="
  command -v nix
  nix --version
  echo
  echo "=== experimental-features ==="
  cat /etc/nix/nix.conf 2>/dev/null || echo "(no /etc/nix/nix.conf)"
} >> "$out" 2>&1
