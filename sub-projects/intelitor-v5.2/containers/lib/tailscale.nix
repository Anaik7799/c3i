{ pkgs }:

let
  tailscale = pkgs.tailscale;
in
{
  # The tailscale package itself, to be added to container contents
  package = tailscale;

  # Wrapper function
  # originalEntrypoint: The path or string of the command to run after Tailscale starts
  # name: Name for the wrapper script (default: "entrypoint-with-tailscale")
  wrap = originalEntrypoint: 
    pkgs.writeShellScriptBin "entrypoint-with-tailscale" ''
      set -e

      # =============================================================================
      # Nix-Native Tailscale Wrapper
      # Goal: Ensure container can talk to the Tailscale Mesh
      # =============================================================================

      # Configuration
      TS_AUTHKEY="''${TS_AUTHKEY:-}"
      TS_HOSTNAME="''${TS_HOSTNAME:-$(hostname)}"
      TS_ROUTES="''${TS_ROUTES:-}"
      TS_STATE_DIR="/var/lib/tailscale"
      TS_SOCKET="/var/run/tailscale/tailscaled.sock"

      log() {
          echo "[Tailscale-Wrapper] $1"
      }

      start_tailscale() {
          log "Starting Tailscale daemon..."
          
          # Ensure directories exist (requires write access to /var or volume mount)
          mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

          # Check for /dev/net/tun
          if [ ! -c /dev/net/tun ]; then
              log "⚠️  /dev/net/tun not found. Trying to create it..."
              mkdir -p /dev/net
              mknod /dev/net/tun c 10 200 || log "❌ Failed to create /dev/net/tun. Userspace networking might be required."
          fi

          # Start tailscaled in background
          # We prefer userspace networking for container compatibility
          
          if [ -c /dev/net/tun ]; then
              log "✅ /dev/net/tun exists. Using kernel networking."
              ${tailscale}/bin/tailscaled --state=''${TS_STATE_DIR}/tailscaled.state --socket=''${TS_SOCKET} &
          else
              log "⚠️  Using userspace networking (tun=userspace-networking)."
              ${tailscale}/bin/tailscaled --tun=userspace-networking --state=''${TS_STATE_DIR}/tailscaled.state --socket=''${TS_SOCKET} &
          fi

          # Wait for socket
          log "Waiting for tailscaled socket..."
          # Simple wait loop
          for i in {1..20}; do
              if [ -S ''${TS_SOCKET} ]; then
                  break
              fi
              sleep 0.5
          done
          
          if [ ! -S ''${TS_SOCKET} ]; then
             log "❌ Timed out waiting for tailscaled socket."
             # We don't exit here to allow the main app to potentially try, 
             # but mesh networking will be broken.
          fi
      }

      configure_tailscale() {
          if [ -z "$TS_AUTHKEY" ]; then
              log "⚠️  TS_AUTHKEY not provided. Skipping 'tailscale up'. (Node might already be logged in if state persisted)"
              return
          fi

          log "Authenticating with Tailscale..."
          UP_ARGS="--authkey=''${TS_AUTHKEY} --hostname=''${TS_HOSTNAME} --accept-dns=true"
          
          if [ -n "$TS_ROUTES" ]; then
              UP_ARGS="''${UP_ARGS} --advertise-routes=''${TS_ROUTES}"
          fi

          # Attempt up
          ${tailscale}/bin/tailscale up ''${UP_ARGS}
          
          log "✅ Tailscale is UP. IP: $(${tailscale}/bin/tailscale ip -4)"
      }

      # Main Logic
      start_tailscale
      configure_tailscale

      # Handoff to original entrypoint
      log "🚀 Executing original entrypoint: ${originalEntrypoint}"
      
      # If originalEntrypoint is a path (like /bin/docker-entrypoint), execute it
      # If it's a string command, we might need eval, but usually it's a path in Nix context
      exec ${originalEntrypoint}/bin/docker-entrypoint "$@"
    '';
}
