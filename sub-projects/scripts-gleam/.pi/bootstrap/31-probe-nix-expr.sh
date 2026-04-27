#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

EXPR='let f = builtins.getFlake (toString /mnt/c/dev/elixir/sys); c = f.nixosConfigurations.nix-k8s-worker-1.config; p = f.nixosConfigurations.nix-k8s-worker-1.pkgs; in {hostName = c.networking.hostName;system = p.system;stateVersion = c.system.stateVersion;k3sRole = c.services.k3s.role;tcpPorts = c.networking.firewall.allowedTCPPorts;udpPorts = c.networking.firewall.allowedUDPPorts;}'

echo '=== raw nix eval ===' >> "$OUT"
nix eval --no-write-lock-file --impure --json --expr "$EXPR" 2>&1 | head -40 >> "$OUT" || echo "(exit $?)" >> "$OUT"
