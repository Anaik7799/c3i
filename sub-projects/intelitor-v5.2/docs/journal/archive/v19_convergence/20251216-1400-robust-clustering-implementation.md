# Journal: Robust Distributed Clustering Implementation

**Date**: 2025-12-16 14:00 CEST
**Topic**: Robust Distributed Clustering & Preflight Systems
**Frameworks**: SOPv5.11, STAMP, TDG, AOR
**Author**: Gemini (Cybernetic Architect)
**Status**: IMPLEMENTED & VERIFIED

---

## 1.0 Executive Summary

This journal documents the implementation of a production-grade, robust distributed clustering system using `libcluster`. The implementation strictly adheres to the **SOPv5.11 Cybernetic Framework**, implementing specific **STAMP safety constraints** for process lifecycle management, ensuring **TDG compliance** for test environments, and defining **Agent Operating Rules (AOR)** for startup/shutdown procedures.

The system transitions from a static, fragile development setup to a dynamic, network-aware, self-healing distributed architecture capable of operating across Localhost, Tailscale, and Kubernetes environments without code changes.

---

## 2.0 SOPv5.11 Alignment & Cybernetic Integration

This implementation directly addresses **Phase 2 (Container Infrastructure)** and **Phase 3 (Agent Architecture)** of the SOPv5.11 deployment plan.

### 2.1 OODA Loop Implementation (Startup Cycle)
The `start_cluster.sh` script implements a closed-loop cybernetic control system:
1.  **Observe**: Detect network environment (Tailscale vs Localhost) and system state (Port availability, Dependencies).
2.  **Orient**: Configure node names (`app-1@vm-1.tail...` vs `app-1@127.0.0.1`) and topology strategy.
3.  **Decide**: Proceed with startup or Halt immediately (Jidoka) if preflight checks fail.
4.  **Act**: Launch processes, monitor PIDs, and poll health endpoints.

---

## 3.0 STAMP Safety Analysis (System Theoretic Accident Model and Processes)

The implementation introduces and satisfies specific safety constraints to prevent hazardous system states.

### 3.1 Constraints Satisfied
| ID | Constraint | Implementation Detail |
|----|------------|-----------------------|
| **SC-OPS-001** | System SHALL NOT start if required dependencies (elixir, epmd) are missing. | `check_dependency` function in `start_cluster.sh`. |
| **SC-OPS-002** | System SHALL NOT attempt to bind to ports already in use (4000/4001). | `check_port_free` function using `lsof`/`ss`. |
| **SC-OPS-003** | System SHALL detect process death during startup phase. | PID monitoring loop in `wait_for_health`. |
| **SC-OPS-004** | System SHALL ensure graceful termination of all child processes on exit. | `trap cleanup SIGINT SIGTERM EXIT` with `terminate_process`. |
| **SC-NET-001** | Node names SHALL resolve resolvable DNS names or IP addresses. | Dynamic `cluster_env.sh` detection logic. |
| **SC-OBS-001** | Startup logs SHALL be persisted to file, not just console. | Redirection to `data/logs/cluster/*.log`. |

### 3.2 Hazard Analysis (Mitigations)
*   **Hazard**: Zombie BEAM processes holding ports after script exit.
    *   **Mitigation**: `cleanup()` function sends SIGTERM, waits 10s, then sends SIGKILL.
*   **Hazard**: Split-brain due to network misconfiguration.
    *   **Mitigation**: Shared `cluster_env.sh` ensures `start_cluster.sh` and `remote_console.sh` always agree on the naming schema.
*   **Hazard**: Silent startup failure (process dies but script waits).
    *   **Mitigation**: `kill -0 $PID` check inside the health polling loop triggers immediate exit.

---

## 4.0 Test-Driven Generation (TDG) Compliance

### 4.1 Consistency Invariant
**Rule**: Testing environment must mirror production topology.

*   **Implementation**: `test/test_helper.exs` modified to auto-detect the network environment (Tailscale/Local) and start the test node using the *exact same logic* as the application startup.
*   **Verification**: Tests run in distributed mode (`:longnames`), enabling valid testing of `libcluster` topologies, `Phoenix.PubSub`, and distributed ETS tables.

---

## 5.0 Agent Operating Rules (AOR)

The startup scripts function as autonomous "Operational Agents" with strict behavioral rules.

### 5.1 AOR-OPS-001: The Preflight Mandate
> **Formal**: $\mathbf{O}(\text{Start}) \implies \text{Preflight}(\text{Deps} \wedge \text{Ports})$
> 
> **Natural**: The Operation Agent (Startup Script) MUST verify all dependencies and resource availability BEFORE attempting execution. Failure leads to immediate halt.

### 5.2 AOR-OPS-002: The Health Consensus Rule
> **Formal**: $\mathbf{O}(\text{Status}=\text{Running}) \iff (\text{PID}_{alive} \wedge \text{HTTP}_{200})$
> 
> **Natural**: A service is considered "Running" ONLY if the process exists AND the application layer returns a valid Health Check response.

### 5.3 AOR-OPS-003: The Logging Integrity Rule
> **Formal**: $\forall \text{log\_entry} : \text{Persist}(\text{File}) \wedge \text{Timestamp}$
> 
> **Natural**: All operational events must be timestamped and persisted to disk to ensure auditability during failures.

---

## 6.0 Operational Logic & Architecture

### 6.1 Dynamic Topology Strategy
The system now employs a **Strategy Pattern** for clustering, defined in `config/runtime.exs`:

```elixir
cond do
  System.get_env("KUBERNETES_SERVICE_HOST") ->
    # Strategy: Kubernetes (DNS/Headless Service)
    # Scalability: Unlimited (Auto-discovery)
  true ->
    # Strategy: EPMD (Local/Tailscale)
    # Scalability: defined by host list, robust across networks
    # Config: Uses NODE_HOST env var derived from cluster_env.sh
end
```

### 6.2 Process Lifecycle Management
The `start_cluster.sh` script acts as a localized Supervisor:
1.  **Init**: Sources environment, verifies state.
2.  **Spawn**: Forks processes (`&`), captures PIDs.
3.  **Monitor**: Enters a health-polling loop.
4.  **Supervise**: If a child dies during monitor phase, Supervisor (script) terminates self and remaining children.
5.  **Terminate**: On signal, executes orderly shutdown sequence.

---

## 7.0 Verification & Artifacts

### 7.1 Created Artifacts
*   `scripts/cluster/cluster_env.sh`: Shared network logic.
*   `scripts/cluster/start_cluster.sh`: Robust startup agent.
*   `scripts/cluster/remote_console.sh`: Connectivity tool.
*   `docs/guides/clustering_operations.md`: Operational manual.
*   `podman-compose-cluster.yml`: Container orchestration definition.

### 7.2 Validation
*   **Tailscale**: Verified automatic detection of `*.ts.net` domains.
*   **Localhost**: Verified fallback to `127.0.0.1` when offline.
*   **Shutdown**: Verified clean exit on `Ctrl+C`.
*   **Remote Shell**: Verified `iex` connection to running nodes.

---

## 8.0 Cybernetic System Integration Analysis

This system is not merely a set of utility scripts; it is a **Cybernetic Control System** that strictly implements the architectural axioms defined in `CLAUDE.md`.

### 8.1 The OODA Loop Implementation (Cybernetic Control)
The `start_cluster.sh` script functions as an autonomous **Cybernetic Agent**, executing a continuous **OODA Loop** (Observe, Orient, Decide, Act) to ensure system stability.

*   **OBSERVE (Sensing):**
    *   **Network:** Scans the environment (`tailscale status`, `ip -4`) to detect the network fabric.
    *   **Resources:** Probes the OS for open ports (`lsof -i :4000`) and required binaries (`check_dependency`).
    *   **Lifecycle:** Continuously monitors child PIDs (`kill -0 $pid`) to detect crashes instantly.
*   **ORIENT (Contextualizing):**
    *   Updates its internal model based on observations. If Tailscale is found, it orients the topology to `vm-1.tail...`. If offline, it re-orients to `127.0.0.1`.
    *   Satisfies **Axiom 2 (Container Isolation/Network Awareness)** by adapting to the environment rather than forcing a brittle config.
*   **DECIDE (Logic Gates):**
    *   **Jidoka (Autonomation):** Implements "Stop at First Defect." If a port is blocked, it halts immediately (Exit Code 1). It does not attempt a partial or broken startup.
*   **ACT (Execution):**
    *   Launches the BEAM instances.
    *   Engages the **Graceful Shutdown Protocol** (sending `SIGTERM`, waiting, then `SIGKILL`) to enforce **STAMP Safety Constraint SC-OPS-004**.

### 8.2 STAMP Safety Integration Details
The infrastructure explicitly mitigates hazards identified in the System-Theoretic Accident Model and Processes (STAMP):

| STAMP Hazard | Constraint (Safety Rule) | Implementation in System |
| :--- | :--- | :--- |
| **H-1**: Process Zombie State | **SC-OPS-004**: System SHALL ensure clean termination. | `trap cleanup SIGINT` logic in `start_cluster.sh` ensures no orphaned BEAM processes hold ports. |
| **H-2**: Network Partition | **SC-NET-001**: Nodes SHALL use resolvable DNS/IPs. | `cluster_env.sh` acts as the "Single Source of Truth," preventing split-brain where the console uses one IP and the app uses another. |
| **H-3**: Silent Failure | **SC-OBS-001**: Logs SHALL be persisted. | The startup agent redirects `stdout/stderr` to `data/logs/cluster/`, ensuring evidence is preserved for RCA (Root Cause Analysis). |
| **H-4**: Resource Contention | **SC-PRF-049**: Prevent resource exhaustion. | Preflight checks ensure ports are free before allocation, preventing "Address in Use" crashes. |

### 8.3 Telemetry & Dual Logging (Observability)
The system adheres to **Axiom 1 (Patient Mode/Observability)** and **Section 13.0 (Dual Logging)**:

1.  **File Logging (Local Persistence):**
    *   The startup script captures raw "Terminal" output and pipes it to `data/logs/cluster/app-X.log`. This ensures local logs are available for 5-Level RCA even if the telemetry backend fails.
2.  **SigNoz Integration (Distributed Tracing):**
    *   **Configuration:** `config/runtime.exs` is configured to send traces to the OTLP endpoint (`http://localhost:4317`).
    *   **Trace Context:** When `app-1` calls `app-2` (via Erlang distribution), OpenTelemetry (enabled in `application.ex`) propagates the **Trace Context**.
    *   **Result:** A single distributed trace in SigNoz spans across clustered nodes, allowing latency debugging across the mesh.

### 8.4 TDG (Test-Driven Generation) Alignment
The setup strictly follows **Axiom 4 (TDG)**:

*   **Consistency Invariant:** We modified `test/test_helper.exs` to use **the exact same logic** as `cluster_env.sh`.
*   **Result:** When running `mix test`, the test node joins the *same* distributed mesh (Tailscale or Local) as the development application. This ensures distributed tests (e.g., PubSub broadcasting) verify the actual network topology, not a mock.

### 8.5 AOR (Agent Operating Rules) Alignment
The scripts embody the **Cybernetic Architect** persona by following these operational rules:

*   **AOR-OPS-001 (The Preflight Mandate):** "I will not start if the environment is unsafe." (Implemented via dependency/port checks).
*   **AOR-OPS-002 (The Consensus Rule):** "A service is only 'Up' if it answers HTTP requests." (Implemented via `wait_for_health` polling).
*   **AOR-CAP-005 (State Grounding):** "I will base my decisions on the actual state of the system." (Dynamic detection of IP vs DNS).

---

**Signed**: Gemini (Cybernetic Architect)
**System State**: ROBUST