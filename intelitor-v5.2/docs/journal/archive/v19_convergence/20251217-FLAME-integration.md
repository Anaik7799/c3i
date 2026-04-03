# Journal Entry: The FLAME Architecture Shift

**Date**: 2025-12-17 12:15:00 CEST
**Author**: Cybernetic Architect (Gemini)
**Context**: Architecture Upgrade / Elastic Scalability
**Reference**: docs/architecture/20251217-HA-FLAME-hybrid-architecture.md

## 🔥 Strategic Pivot: The "Hybrid Core-Satellite" Model

### The Trigger
The directive to "use FLAME on all aspects of the system" fundamentally changes our scaling strategy. We are moving away from a monolithic "scale the whole app" approach to a granular "scale the function" approach.

### The Decision
We have adopted **FLAME (Fleeting Lambda Application for Modular Execution)**. This allows `Indrajaal` to treat heavy compute operations (Video, AI, Analytics) as ephemeral "Satellite" workloads that orbit the persistent "Core" HA Mesh.

### Key Architectural Updates
1.  **Compute Plane Separation**: Infrastructure is now split into "Always-On Core" (HA Mesh) and "On-Demand Satellites" (FLAME Runners).
2.  **Elasticity**: We can now scale intelligence analysis to 1000 concurrent streams without provisioning 1000 permanent servers. The runners exist only while processing a frame/threat.
3.  **Isolation**: A crash in a Video Processing Runner cannot take down the Web Server or Alarm Manager. This significantly enhances **STAMP Safety Constraints** regarding fault isolation.

### Implementation Risks (Pre-Mortem)
*   **Risk**: Boot Latency. If Runners take >5s to boot, user experience suffers.
*   **Mitigation**: Use aggressive AOT (Ahead-of-Time) compilation and keep a "warm pool" if necessary (min > 0).
*   **Risk**: Network Partition. Runner cannot connect back to Parent.
*   **Mitigation**: Tailscale Mesh ensures flat connectivity; FLAME Backends manage the tunnel.

This architecture positions `Indrajaal` as a true "Cloud Native 2.0" application.

---
*Signed: Executive Director Agent*
