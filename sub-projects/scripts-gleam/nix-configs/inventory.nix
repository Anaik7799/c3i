# Inventory — single source of truth for host IPs, roles, and SSH
# endpoints across the workspace. Imported into every
# nixosConfiguration via `specialArgs = { inherit inventory; }` in
# flake.nix (see plans/design.md P2.W2).
#
# Consumed by:
#   - modules/deploy.nix : defaults sys.deploy.targetHost from here
#   - scripts/.../commands/inventory.gleam : read-only CLI listing
#
# Update this file as LAN/tailnet addresses are confirmed. Commits
# that mutate it must also pass `sys check`.
#
# Field conventions:
#   lanAddr       — IP on the physical LAN; null until DHCP lease observed.
#   tailscaleAddr — 100.x.y.z address; null until tailscale up succeeds.
#   role          — free-form tag describing primary purpose.
#   sshUser       — account for admin access (expects key-only auth).

{
  hosts = {
    nix-k8s-master = {
      lanAddr = null;       # populate with the master's DHCP lease
      tailscaleAddr = null; # populate after P2 tailscale up
      role = "k3s-server";
      sshUser = "root";
    };

    nix-k8s-worker-1 = {
      lanAddr = null;
      tailscaleAddr = null;
      role = "k3s-agent";
      sshUser = "root";
    };

    nix-k8s-worker-2 = {
      lanAddr = null;
      tailscaleAddr = null;
      role = "k3s-agent";
      sshUser = "root";
    };
  };

  hypervisors = {
    nas-1 = {
      lanAddr = "192.168.1.219"; # from journal/2026-04-22-summary.md
      kind = "xcp-ng";
      tailscale = true;          # authenticated on dom0
    };

    nuc-1 = {
      lanAddr = null;
      kind = "proxmox";
      tailscale = null; # unknown
    };
  };
}
