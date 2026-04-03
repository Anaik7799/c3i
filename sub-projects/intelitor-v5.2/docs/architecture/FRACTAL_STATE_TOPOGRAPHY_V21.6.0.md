# System State Topography Map (v21.6.0)

**Classification**: L4-OPERATIONAL
**Status**: VERIFIED
**Context**: Comprehensive inventory of all system memory and storage across 7 Fractal Levels.

---

## 1.0 Level 1: Cellular (In-Memory / Volatile)
**Substrate**: BEAM (Elixir)
**Role**: Microsecond-latency access for hot data.

### 1.1 High-Speed Cache (ETS)
**Count**: 47+ Named Tables.
**Key Tables**:
- `:task_registry`: Async task tracking.
- `:rate_limits`: API throttling counters.
- `:safety_violations`: STAMP constraint breaches.
- `:fractal_routing_rules`: Zenoh/Mesh routing table.
- `:connection_registry`: Real-time WebSocket tracking.

### 1.2 Application Cache (Cachex)
**Role**: Local in-memory caching with TTL.
**Usage**: `Indrajaal.Cache` wrapper for general application data.

---

## 2.0 Level 2: Component (Process State)
**Substrate**: BEAM (Elixir) / CLR (F#)
**Role**: Active Actor Context.

### 2.1 Elixir GenServers
- **Guardian**: Holds active safety rules and violation counters.
- **Sentinel**: Maintains threat model and immune response state.
- **HeartbeatMonitor**: Tracks last-seen timestamps for metabolic pulses.

### 2.2 F# Agents (CEPAF)
- **HealthCoordinator**: Maintains 2oo3 voting state and node health vectors.
- **OodaSupervisor**: Tracks current OODA loop phase and latency. [Updated Sprint 51] ScaleUp/ScaleDown actions are fully functional (real container scaling and agent pool management).

---

## 3.0 Level 3: Integration (Distributed Volatile)
**Substrate**: Redis / Zenoh
**Role**: Cluster-wide shared state and message buffering.

### 3.1 Redis (Redix)
- **Host**: `indrajaal-redis` (or localhost).
- **Usage**: Shared cache, PubSub channel backing.

### 3.2 Zenoh
- **Usage**: Distributed shared memory for control plane signals.
- **Topics**: `indrajaal/control/**`, `indrajaal/telemetry/**`.

---

## 4.0 Level 4: Operational (Persistent Storage)
**Substrate**: Container Volumes
**Role**: Durable Data Persistence.

### 4.1 Data Plane (PostgreSQL)
**Role**: Transactional Source of Truth (OLTP).
- **Primary**: `indrajaal-db1` (Port 5433).
- **Replica**: `indrajaal-db2` (Port 5434).
- **Volume**: `fractal-db1-data`, `fractal-db2-data`.
- **Definition**: `lib/indrajaal/repo.ex`.

### 4.2 Mnemonic Plane (KMS - SQLite)
**Role**: Holon State & Configuration.
- **Engine**: SQLite (WAL Mode).
- **Artifacts**:
    - `data/kms/core.db`: System configuration & state.
    - `data/kms/holons.db`: Entity registry.
- **Access**: `Exqlite` (Elixir) / `System.Data.SQLite` (F#).

### 4.3 Analytical Plane (OLAP - DuckDB)
**Role**: Telemetry History & Large Datasets.
- **Engine**: DuckDB.
- **Artifacts**:
    - `data/kms/analytics.duckdb`: OODA loop history.
    - `data/kms/telemetry.duckdb`: Sensor data.
- **Access**: `DuckDB.NET` (F#) / `duckdbex` (Elixir).

### 4.4 Infrastructure State
**Role**: Container Persistence.
- **Volumes**:
    - `fractal-obs-data`: SigNoz/ClickHouse data.
    - `fractal-app1-data`: Application uploads/state.
    - `fractal-app2-data`: Replica state.

---

## 5.0 Level 5: Evolutionary (Meta-State)
**Substrate**: Filesystem / Git
**Role**: System Identity and Evolution History.

- **Blueprints**: `docs/plans/`, `PROJECT_TODOLIST.md`.
- **Journal**: `docs/journal/`.
- **Codebase**: Git repository history (Immutable Audit).

---

## 6.0 Level 6: Cluster (Consensus State)
**Substrate**: Libcluster / CRDTs
**Role**: Mesh Topology and Agreement.

- **Libcluster**: Gossip protocol state for node discovery.
- **Phoenix.PubSub**: Distributed topic subscriptions.

---

## 7.0 Level 7: Federation (Inter-System Trust)
**Substrate**: Cryptographic Tokens
**Role**: Cross-System Verification.

- **Attestation Tokens**: Signed proofs of SIL-6 compliance.
- **Merkle Roots**: State verification hashes exposed via Zenoh.

---

## 8.0 State Flow (Metabolism)

1.  **Ingest**: Data enters via API (L1/L2).
2.  **Process**: Validated by Guardian, cached in ETS (L1).
3.  **Persist**: Flushed to PostgreSQL (Async) or SQLite (Sync) (L4).
4.  **Archive**: Telemetry batch-flushed to DuckDB (60s) (L4).
5.  **Sync**: 2oo3 Voting ensures consistency across nodes (L6).
6.  **Evolve**: Metrics update Evolutionary state (L5).