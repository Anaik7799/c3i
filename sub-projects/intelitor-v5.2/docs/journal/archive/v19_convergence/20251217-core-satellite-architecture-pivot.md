# Journal Entry: Strategic Architecture Pivot - Core-Satellite Hybrid

**Date**: 2025-12-17 12:45:00 CEST
**Author**: Cybernetic Architect (Gemini)
**Context**: Architecture Refinement / High Availability / Elasticity
**Reference**: docs/architecture/20251217-HA-FLAME-hybrid-architecture.md

## 🚀 The Core-Satellite Paradigm Shift

### 1. The Context: Monolith Constraints
Our previous architecture was a **Robust Monolith**. We scaled vertically ("make the box bigger"). While this achieved zero-defect quality for single-node deployments, it hit a ceiling on resilience and elasticity.
*   **Resilience Gap**: If the single node dies (hardware failure, OOM), the entire system goes dark.
*   **Elasticity Gap**: We provision for peak load. If 90% of the time we only need 10% capacity, we waste 90% of resources. Conversely, if load spikes 10x, the monolith chokes.

### 2. The Decision: Two Planes of Existence
We have decided to split the application into two distinct "planes" of existence, unified by a common identity mesh.

#### Plane A: The HA Core (The "Immortal" Mesh)
*   **Technology**: `libcluster` + `Tailscale` + `PgBouncer`
*   **Topology**: 3 Nodes (Minimum)
*   **Role**:
    *   Maintains the WebSocket connections (Phoenix Channels).
    *   Holds the distributed consistency (Cluster Sentinel).
    *   Manages the "Source of Truth" (Database transactions).
*   **Philosophy**: "This never goes down." We use Quorum logic to ensure data safety even if a node vanishes.

#### Plane B: The FLAME Satellites (The "Mortal" Workforce)
*   **Technology**: `FLAME` (Fleeting Lambda Application for Modular Execution)
*   **Topology**: 0 to $\infty$ Nodes
*   **Role**:
    *   Performs heavy lifting: ML Inference, Video Transcoding, Report Generation.
    *   Exists *only* for the duration of the function call.
*   **Philosophy**: "Born to die." These nodes are ephemeral. If one crashes, the Core simply spawns another.

### 3. The Enabler: Identity-Based Networking (Tailscale)
Previously, clustering required complex VPC peering, NAT traversal, and firewall rules.
*   **The Fix**: By using **Tailscale**, we flatten the network. A FLAME runner spawned in a Kubernetes cluster can securely talk to a Core node running on a Raspberry Pi in a closet, as long as they share the same Tailnet Identity.
*   **Security**: WireGuard handles the encryption. We trust the *Identity*, not the *IP*.

### 4. Risk Assessment (Pre-Mortem)

#### Risk: Cold Start Latency
*   **Scenario**: User requests a report. A FLAME runner must boot.
*   **Impact**: 5-10s delay.
*   **Mitigation**:
    *   **AOT Compilation**: Ensure runners are pre-compiled in the container image.
    *   **Warm Pool**: Keep `min: 1` runners active for critical paths.

#### Risk: "Thundering Herd" on Core
*   **Scenario**: 1000 FLAME runners try to connect to the DB simultaneously.
*   **Impact**: DB connection exhaustion.
*   **Mitigation**:
    *   **PgBouncer**: Mandatory middleware to multiplex connections.
    *   **Backpressure**: `FLAME.Pool` limits max concurrency.

### 5. Conclusion
This architecture transforms `Indrajaal` from a "Server Application" into a "Distributed Organism". The Core provides the brain and stability; the Satellites provide the muscle and reach.

---
*Signed: Executive Director Agent*
