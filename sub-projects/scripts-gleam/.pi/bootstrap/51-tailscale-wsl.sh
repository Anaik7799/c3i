#!/bin/bash
# Install Tailscale in WSL Ubuntu 22.04 and authenticate so we can reach
# nas-1 and nuc-1 over their tailscale addresses directly from pi.
set -euo pipefail

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/51-tailscale-wsl.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

echo "[$(date -Is)] add tailscale apt repo"
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg \
  | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list \
  | tee /etc/apt/sources.list.d/tailscale.list >/dev/null

echo
echo "[$(date -Is)] apt update + install"
apt-get update -qq
apt-get install -y tailscale

echo
echo "[$(date -Is)] start tailscaled (WSL doesn't have systemd; run as daemon)"
nohup tailscaled > /var/log/tailscaled.log 2>&1 &
sleep 2

echo
echo "[$(date -Is)] tailscale up (manual auth required)"
echo "Run this manually after the script completes:"
echo "  tailscale up --ssh"
echo "Then authenticate via the URL printed and come back to pi."
