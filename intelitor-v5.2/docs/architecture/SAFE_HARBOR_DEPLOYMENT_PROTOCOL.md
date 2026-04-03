# SAFE HARBOR DEPLOYMENT PROTOCOL (v1.0.0)

**Classification**: L5-SPINE (Strategic Mandate)
**Status**: ACTIVE
**Framework**: SIL-6 Biomorphic Mesh
**Objective**: Zero-Downtime Evolution via "Sandboxed Mira"

---

## 1.0 The "Safe Harbor" Concept
To ensure **Axiom 0 (Functional State Invariant)** is never violated during upgrades, the system employs a **Biological Molting Strategy**. No active cell (`app-1`, `app-2`) is ever modified directly. Instead, a new cell ("Candidate") is grown in a safe harbor (Sandbox), verified, and then assimilated ("Mira").

---

## 2.0 The 4-Stage "Mira" Cycle

### Stage 1: Incubation (Sandboxed Materialization)
**Objective**: Spin up the new code in isolation without taking traffic.
- **Action**: Launch `indrajaal-app-candidate` on Port 4003.
- **Configuration**: Connects to `fractal-mesh` network but is NOT added to the Load Balancer (Nginx) or Service Discovery (Consul/DNS) rotation initially.
- **State**: `STARTING` -> `ISOLATED`.

### Stage 2: Qualification (The 2oo3 Vote)
**Objective**: Verify the Candidate is metabolic and compatible.
- **Tests**:
    1.  **Metabolic Check**: `sa-health` probe on Port 4003.
    2.  **Logic Check**: `sa-verify` (FPPS Consensus).
    3.  **Cluster Check**: Can it join the `libcluster` mesh?
- **Safety Gate**: If ANY check fails, the Candidate is **Apoptosed** (Killed). The live system remains untouched.

### Stage 3: Mira (The Migration)
**Objective**: Seamlessly swap the Shadow for the Substance.
- **Strategy**: Rolling Update (Biomorphic Replacement).
    1.  **Drain**: Send `SIGTERM` to `indrajaal-app-2` (Replica). Wait for drain.
    2.  **Promote**: Rename/Alias `indrajaal-app-candidate` to assume the `app-2` role/traffic.
    3.  **Stabilize**: Wait 30s for mesh convergence.
    4.  **Repeat**: If successful, repeat for `indrajaal-app-1` (Primary).

### Stage 4: Homeostasis (Cleanup)
**Objective**: Return to steady state.
- **Action**: Remove old containers.
- **State**: `STABLE`.

---

## 3.0 Safety Constraints (SC-DEP)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DEP-001 | **No Naked Deploys**: All updates MUST pass through the Safe Harbor. | CRITICAL | Deployment Script |
| SC-DEP-002 | **Quorum Lock**: Updates are FORBIDDEN if the mesh is currently degraded (< 3 healthy nodes). | HIGH | Pre-flight Check |
| SC-DEP-003 | **Rollback Prime**: The previous container MUST be kept as a "Ghost" until the new one is 100% verified. | CRITICAL | Orchestrator Logic |
| SC-DEP-004 | **Data Separation**: Schema migrations MUST be backward-compatible (Expand/Contract pattern). | HIGH | Migration Linter |

---

## 4.0 Agent Operating Rules (AOR-DEP)

- **AOR-DEP-001**: $\mathbf{O}(\text{Upgrade} \implies \text{Incubate})$
- **AOR-DEP-002**: $\mathbf{O}(\text{Fail} \implies \text{Apoptose})$
- **AOR-DEP-003**: $\mathbf{F}(\text{DirectMutation})$

---

## 5.0 The "sa-deploy" Orchestrator
The `sa-deploy.fsx` script implements this protocol. It is the **only** authorized mechanism for system evolution.
