# Journal Entry: Tailscale HA Mesh - The Zero Trust Network

**Date**: 2025-12-17 13:05:00 CEST
**Author**: Cybernetic Architect (Gemini)
**Context**: Networking / Security / HA
**Reference**: docs/architecture/20251217-HA-cluster-transition-specification.md

## 🛡️ The Zero Trust Mesh Strategy

### 1. The Problem: "The Wall is Broken"
Traditional perimeter security (Firewalls, VPCs) is brittle. Once an attacker is "inside", they have full access. For a Safety Critical system, we cannot rely on "Location" as a proxy for "Trust".

### 2. The Solution: Identity-Based Networking
We are adopting **Tailscale** to create an Overlay Mesh.
*   **Every Node** has a unique cryptographic identity.
*   **Every Packet** is encrypted (WireGuard).
*   **Every Connection** is authenticated (mTLS equivalent).

### 3. Impact on Erlang Clustering
Standard Erlang clustering relies on `epmd` (Erlang Port Mapper Daemon) and open TCP ports. In a hostile network, this is a vulnerability.
*   **Old Way**: Open ports 4369 + 9000-9100. Hope firewall rules hold.
*   **New Way**: Bind `epmd` ONLY to `tailscale0` interface.
    *   `vm.args`: `-kernel inet_dist_use_interface {100,x,y,z}`
    *   Result: The cluster is *invisible* to the underlying physical network. Only nodes with valid Tailscale keys can even *see* the port.

### 4. The "Magic" of MagicDNS
Tailscale provides **MagicDNS**, which gives us stable hostnames (`app-1`, `app-2`) even if underlying IPs change.
*   **Strategy**: We configure `libcluster` to discover peers using these MagicDNS names.
*   **Benefit**: We decouple "Service Discovery" from "Kubernetes DNS" or "AWS Route53". The mesh works across providers (Hybrid Cloud).

### 5. Implementation Pre-Reqs
*   **Container**: Needs `tailscale` binary.
*   **Auth Key**: Needs to be injected at runtime.
*   **State**: Needs `/var/lib/tailscale` persistence (or Ephemeral Nodes). We choose **Ephemeral Nodes** for statelessness.

This completes the security triad:
1.  **Code**: Zero-Defect (Mix).
2.  **Process**: STAMP (Governance).
3.  **Network**: Tailscale (Zero Trust).

---
*Signed: Domain Supervisor (Security & Infrastructure)*
