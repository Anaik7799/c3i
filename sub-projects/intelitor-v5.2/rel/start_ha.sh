#!/bin/bash
# rel/start_ha.sh
# Task 22.1.1.2: Boot Script Orchestration for Tailscale + Elixir Release

set -e

echo "🚀 Starting Indrajaal HA Node with Tailscale Integration..."

# 1. Start Tailscale Daemon (Userspace Networking)
# We use userspace networking to avoid needing elevated privileges for /dev/net/tun
# if the container runtime allows it, or as a fallback.
# However, the task explicitly requested --tun=userspace-networking.

echo "🔌 Starting tailscaled (userspace networking)..."
# Start tailscaled in the background. 
# --tun=userspace-networking tells it to use gvisor instead of a real tun device.
# --socket=/var/run/tailscale/tailscaled.sock is standard.
tailscaled --tun=userspace-networking --socket=/var/run/tailscale/tailscaled.sock &
TAILSCALED_PID=$!

# Wait for socket to be created
echo "⏳ Waiting for tailscaled socket..."
until [ -S /var/run/tailscale/tailscaled.sock ]; do
    sleep 0.1
done
echo "✅ tailscaled is ready."

# 2. Authenticate with Tailscale (if TS_AUTH_KEY is provided)
if [ -n "$TS_AUTH_KEY" ]; then
    echo "🔑 Authenticating with Tailscale..."
    tailscale up --authkey="${TS_AUTH_KEY}" --hostname="${TS_HOSTNAME:-indrajaal-$(hostname)}"
    echo "✅ Authenticated as $(tailscale ip -4)"
else
    echo "⚠️  TS_AUTH_KEY not provided. Skipping auto-authentication."
    echo "   You may need to authenticate manually or mount state."
fi

# 3. Start Elixir Release
# usage: ./bin/indrajaal start
echo "✨ Starting Elixir Release..."
exec ./bin/indrajaal start
