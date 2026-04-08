# Architectural Specification: HA Seamless Upgrade & Fractal Impact Analysis

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE / SIL-6 FORMAL METHODS
**Compliance**: SC-ULTRA-001, SC-MATH-003, SC-FMEA-001, SC-STAMP-001

## 1. Mathematical Preliminaries & State Space ($\Sigma_{HA}$)

To guarantee 100% service uptime during development evolution, the Cognitive Plane (`cepaf_gleam`) and the Motor Strip (`sa-plan-daemon`) are redefined as distributed, fault-tolerant state machines.

**State Space Definitions**:
*   $\mathcal{N}_{active} \in \{N_{primary}, N_{backup}\}$: The active nodes capable of processing OODA intents.
*   $\mathcal{L}_{lock} \in \mathbb{B}$: The distributed Zenoh mutex granting write access to `Smriti.db`.
*   $\mathcal{V}_{clock} \in \mathbb{N}^k$: The version vector representing the CRDT state of the node.

**Ultrathink Invariant (SC-ULTRA-004)**:
$$ \forall t : (|\mathcal{N}_{active}| \ge 1) \wedge (|\{n \in \mathcal{N}_{active} \mid \text{HoldsLock}(n)\}| = 1) $$

## 2. Fractal Layer x Component Impact Analysis

A seamless upgrade (taking down Primary, upgrading it, and bringing it back) ripples through the fractal hierarchy.

| Fractal Layer | Component | Impact Analysis | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **L7 (Federation)** | Telegram/GChat Gateways | Inbound webhooks/long-polls might drop if the active listener restarts. | Gateways subscribe to Zenoh via Anycast. Zenoh router automatically routes messages to the Standby listener. |
| **L5 (Cognitive)** | Gleam Cortex (`cepaf_gleam`) | In-flight reasoning sessions (LLM context) will be lost if terminated. | **Graceful Drain**: Primary Cortex stops accepting new intents and finishes active OODA loops before yielding the lock. |
| **L4 (Motor)** | Rust Daemon (`sa-plan`) | `Smriti.db` write locks will conflict if both instances attempt I/O. | **Leader Election**: Backup node remains Read-Only until Zenoh lock is explicitly transferred. |
| **L1 (Transport)** | Zenoh Mesh | Subscriptions will churn during container restarts. | Zenoh Quorum (3 routers) maintains pub/sub topology. |
| **L0 (Substrate)** | Podman Containers | IP addresses and port bindings will change during redeployment. | **Zero-IP Routing**: Rely strictly on Zenoh Key Expressions, eliminating IP/Port dependency. |

## 3. Formal Mathematical Structures

### 3.1 TLA+ Deadlock Analysis
We model the Handover Protocol in TLA+ to ensure no two nodes claim Primary simultaneously (Split-Brain) and no state exists where neither is Primary (Deadlock).
*   **Property**: `[] (PrimaryAlive \/ BackupAlive)`
*   **Property**: `[] ~(PrimaryHoldsLock /\ BackupHoldsLock)`

### 3.2 Agda State Consistency Proofs
Agda will be used to mathematically prove that the CRDT vector clock of the Backup is strictly $\ge$ the Primary before the `GrantLeadership` contract is fulfilled, guaranteeing zero data loss.

### 3.3 Quint OODA Halt Verification
Quint will simulate the 50ms SLA constraint. During the $T_{drain}$ phase, the system must buffer incoming intents and flush them to the Backup within the SLA.

## 4. Failure Mode and Effects Analysis (FMEA)

| Component | Failure Mode | Local Effect | System Effect | RPN | Mitigation (AOR) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `LeaderElection` | Split-Brain (Network Partition). | Both nodes write to DB. | Database corruption. | 100 | **AOR-HA-001**: SQLite PRAGMA locking strictly tied to Zenoh lease TTL. |
| `DrainPhase` | LLM inference hangs > 30s during drain. | Upgrade blocks indefinitely. | Stale binary running. | 60 | **AOR-HA-002**: Hard timeout on `DrainContainer` action. Force-kill after 30s. |
| `SyncPhase` | Backup container fails to start. | Primary cannot yield. | No HA available. | 80 | **AOR-HA-003**: Rollback upgrade if Backup fails health checks for > 5s. |

## 5. Agent Operating Rules (AOR-HA)
*   **AOR-HA-001** ($\mathbf{F}$): A node SHALL NOT execute `mcp_sys` or `mcp_file` actions unless it holds the `LeaderLease`.
*   **AOR-HA-002** ($\mathbf{O}$): The `sa-plan` upgrade CLI MUST perform a health check on the Backup container before sending the `SIGTERM` to the Primary.
