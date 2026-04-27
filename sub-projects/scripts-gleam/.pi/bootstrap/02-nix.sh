#!/bin/bash
# Install Nix via the Determinate Systems installer (single-user, no systemd).
# Safe to re-run: detects existing install.
# Note: must be run as a user with sudo; we're root in WSL so it's fine.
set -euo pipefail

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/02-nix.log
exec > >(tee "$LOG") 2>&1

if command -v nix >/dev/null 2>&1; then
  echo "[skip] nix already on PATH at: $(command -v nix)"
  nix --version
  exit 0
fi

# Even if nix isn't on PATH yet, the profile may still be installed.
if [ -e /nix/var/nix/profiles/default/bin/nix ]; then
  echo "[info] nix already installed at /nix but not on PATH. Skipping reinstall."
  /nix/var/nix/profiles/default/bin/nix --version
  exit 0
fi

echo "[$(date -Is)] downloading upstream Nix installer (nixos.org)"
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://nixos.org/nix/install \
  -o /tmp/nix-installer.sh
chmod +x /tmp/nix-installer.sh

echo "[$(date -Is)] running installer (single-user, no-daemon, non-interactive)"
# WSL has no systemd by default on most installs; the single-user install is simplest.
# '< /dev/null' keeps it non-interactive; the script supports --no-daemon --yes.
/tmp/nix-installer.sh --no-daemon --yes </dev/null

echo "[$(date -Is)] enabling flakes + nix-command globally"
mkdir -p /etc/nix
cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
sandbox = false
EOF

echo "[$(date -Is)] done"
