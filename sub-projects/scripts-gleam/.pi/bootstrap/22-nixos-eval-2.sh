#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/22-nixos-eval-2.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] intent-to-add so Nix flake sees the new files"
git add -N nix-configs flake.nix

echo
echo "[$(date -Is)] evaluating each nixosConfiguration (no build, just eval)"
for host in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
  echo "--- $host ---"
  echo -n "  hostName         : "
  nix eval --raw --no-write-lock-file \
    ".#nixosConfigurations.$host.config.networking.hostName"
  echo
  echo -n "  services.openssh : "
  nix eval --no-write-lock-file \
    ".#nixosConfigurations.$host.config.services.openssh.enable"
  echo -n "  services.k3s     : "
  nix eval --no-write-lock-file \
    ".#nixosConfigurations.$host.config.services.k3s.enable"
  echo -n "  k3s role         : "
  nix eval --raw --no-write-lock-file \
    ".#nixosConfigurations.$host.config.services.k3s.role"
  echo
  echo -n "  firewall tcp     : "
  nix eval --no-write-lock-file \
    ".#nixosConfigurations.$host.config.networking.firewall.allowedTCPPorts"
  echo
done

echo
echo "[$(date -Is)] done"
