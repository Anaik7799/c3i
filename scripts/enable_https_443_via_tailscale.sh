#!/usr/bin/env bash
# One-time HTTPS-via-tailscale activation for c3i daemon on port 443.
# Requires sudo (to write tailscale serve config and bind :443).
set -euo pipefail

# Allow operator without sudo afterwards (one-time):
sudo tailscale set --operator="$USER" || true

# Add HTTPS path mapping: https://vm-1.tail55d152.ts.net/c3i → http://127.0.0.1:4200
sudo tailscale serve --bg --https=443 --set-path=/c3i http://127.0.0.1:4200

echo
echo "URLs now available:"
echo "  https://vm-1.tail55d152.ts.net/c3i/api/v1/status"
echo "  https://vm-1.tail55d152.ts.net/c3i/agentic"
echo "  https://vm-1.tail55d152.ts.net/c3i/task-id/1a92520c"
echo
tailscale serve status
