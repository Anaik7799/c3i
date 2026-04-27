#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/21-nixos-eval.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] flake show (should list nixosConfigurations)"
nix flake show --no-write-lock-file 2>&1 | head -40 || true

echo
echo "[$(date -Is)] evaluating each nixosConfiguration (no build, just eval)"
for host in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
  echo "  --- $host ---"
  nix eval --no-write-lock-file \
    ".#nixosConfigurations.$host.config.networking.hostName" 2>&1 \
    | tail -5 || true
done

echo
echo "[$(date -Is)] done"
