# Journal Entry: Tailscale HA Architecture Pivot

**Date**: 2025-12-17 11:30:00 CEST
**Author**: Cybernetic Architect (Gemini)
**Context**: Architecture Refinement / Security Enhancement
**Reference**: docs/architecture/20251217-HA-cluster-transition-specification.md

## 🔄 Strategic Pivot: The Tailscale Mesh

### The Trigger
The requirement to use **Tailscale** for node naming and remote connectivity introduces a paradigm shift in how we handle "Network Physics". We are moving from a location-based trust model (VPC/Subnet) to an identity-based trust model (Zero Trust / Tailscale Identity).

### The Decision
We have updated the HA Transition Specification (v1.1.0) to center on **Tailscale** as the networking substrate. This simplifies the encryption layer (WireGuard handles it) but adds complexity to the startup lifecycle (Tailscale authentication and IP resolution).

### Key Architectural Updates
1.  **Node Identity**: Nodes are now identified by their Tailscale IPs (100.x.y.z) or MagicDNS names, rather than Pod IPs.
2.  **Transport Security**: We rely on WireGuard encryption provided by the Tailscale mesh, potentially removing the need for complex Erlang `inet_tls` configuration (though `inet_tls` remains a defense-in-depth option).
3.  **Discovery**: Peer discovery leverages Tailscale's MagicDNS or API, providing a flat mesh topology regardless of physical location (Hybrid Cloud ready).

### Implementation Implications
*   **Container**: Must include `tailscale` binary or run alongside a sidecar.
*   **Startup Script**: Needs to `tailscale up` before starting the BEAM.
*   **Safety**: ACLs (Access Control Lists) in Tailscale become the primary firewall mechanism.

### Risk Assessment Update
*   **Risk**: Dependency on Tailscale Control Plane.
*   **Mitigation**: WireGuard tunnels are P2P and persist during control plane outages.
*   **Risk**: Ephemeral Node Cleanup.
*   **Mitigation**: Use "Ephemeral" Auth Keys so nodes are automatically removed from the Tailnet when they go offline.

This pivot aligns `Indrajaal` with modern Zero Trust principles.

---
*Signed: Executive Director Agent*
