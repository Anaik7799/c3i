#!/usr/bin/env bash
set -e

# SIL-6 Entrypoint: Environment Sanitization
# Context: NixOS Container Runtime

echo ">>> [ENTRYPOINT] INITIALIZING CONTAINER ENVIRONMENT..."

# 1. Ensure Rust/Cargo is in PATH (Critical for LineageAuth)
export PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin:$PATH

# 2. Verify Toolchain
echo ">>> [ENTRYPOINT] PATH: $PATH"
if command -v cargo &> /dev/null; then
    echo ">>> [ENTRYPOINT] RUST TOOLCHAIN VERIFIED: $(which cargo)"
    cargo --version
else
    echo ">>> [ENTRYPOINT] ERROR: CARGO NOT FOUND. COMPILATION WILL FAIL."
    ls -la /root/.nix-profile/bin || echo "Nix profile bin not found"
fi

# 3. Setup Tailscale (if needed)
if [ -f "/workspace/scripts/containers/tailscale-entrypoint.sh" ]; then
    echo ">>> [ENTRYPOINT] STARTING TAILSCALE SIDE CAR..."
    # Source the tailscale logic but run in background or foreground depending on config
    # We use a subshell to avoid polluting this scope, or run it if it handles daemonization
    # For now, let's assume it sets up the daemon and backgrounds it
    bash /workspace/scripts/containers/tailscale-entrypoint.sh &
    
    # Wait a moment for socket
    sleep 2
fi

# 4. Execute Command
echo ">>> [ENTRYPOINT] EXECUTING CMD: $@"
exec "$@"
