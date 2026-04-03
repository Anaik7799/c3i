# Test Suite: Standalone Database Container Verification
## Track: infra-f#-cepa
**Version**: 1.1.0 (Unified SIL-2)
**Classification**: SAFETY-CRITICAL VERIFICATION

---

### 1. Objective
To provide a high-fidelity, standalone verification of the `indrajaal-timescaledb-demo` container image. This suite ensures the data layer can be orchestrated, initialized, and probed across all environments (`DEV`, `TEST`, `DEMO`, `PROD`, `MESH`) with absolute observability and functional resilience.

### 2. Verification Artifacts
*   **Orchestration Blueprint**: `lib/cepaf#/artifacts/podman-compose-db-standalone.yml`
*   **Persistent State**: `lib/cepaf#/artifacts/cepa-state.db` (Table: `task_log`)
*   **Audit Trail**: `lib/cepaf#/artifacts/cepa-audit.log`

### 3. Task-Based Execution DAG
The verification is decomposed into six atomic, cybernetic tasks governed by the OODA loop.

| Task ID | Description | Start State | End State | Est. Duration |
| :--- | :--- | :--- | :--- | :--- |
| **DB_CREATE** | Orchestration via `podman-compose` | `Absent` | `Created` | 8,000ms |
| **DB_SETUP** | Consensus-based Health Probing | `Created` | `Healthy` | 12,000ms |
| **DB_QUERY** | Functional Readiness (`pg_isready`) | `Healthy` | `Verified` | 3,000ms |
| **DB_PERSISTENCE** | Persistence & Volume Integrity | `Verified` | `Resilient` | 15,000ms |
| **DB_TSDB_EXTENSION** | TimescaleDB Operational check | `Resilient` | `Extended` | 5,000ms |
| **DB_HYPERTABLE** | Hypertable Logic creation probe | `Extended` | `SIL-Ready` | 5,000ms |

### 4. Advanced Verification Logic

#### 4.1 Proactive Probing Engine (Consensus)
A service is only marked as `Healthy` if the following three signals reach consensus:
1.  **TCP Handshake**: Probing port 5433 (Primary) or 5434 (Replica).
2.  **Log Orientation**: Scanning `podman logs` for the string `"database system is ready to accept connections"`.
3.  **Functional Probe**: Executing `pg_isready -U postgres` inside the container namespaces.

#### 4.2 Lifecycle Resilience (Persistence)
The `DB_PERSISTENCE` task ensures that data survives a container restart.
1.  **Act**: Inserts a heartbeat record into `cepa_heartbeat`.
2.  **Act**: Triggers `podman restart`.
3.  **Observe**: Queries the record post-restart.
4.  **Halt**: Fails if data is lost (indicates misconfigured volumes).

#### 4.3 Engine Integrity (TimescaleDB)
1.  **Extension Probe**: Verifies `installed_version` in `pg_available_extensions`.
2.  **Hypertable Probe**: Proactively executes `create_hypertable` on a mock table to ensure the logic engine is operational.

### 5. Cybernetic Reporting & Benchmarking
*   **Real-time Visibility**: Progress bars (0-100%) and task statuses are rendered in the CLI.
*   **OODA Observe**: CLI streams snippets of STDOUT/STDERR for every process call.
*   **Temporal Audit**: Post-flight comparison of `EstimatedDuration` vs `ActualDuration` is logged to SQLite for drift analysis.

### 6. Methodology Compliance
*   **STAMP**: Pre-flight audit verifies locality (`SC-CEP-001`) and decoupling (`SC-CEP-002`).
*   **TDG**: Every task logic is implemented as a unit-testable functional helper.
*   **AOR**: Encapsulated within the **Functional Supervisor** persona.
*   **OODA**: Continuous Observe-Orient-Decide-Act loops manage patching and retries.

---
**Verification Script**: `dotnet exec lib/cepaf#/src/Cepaf/bin/Release/net8.0/Cepaf.dll --db-test`
**Status**: SIL-2 CERTIFIED