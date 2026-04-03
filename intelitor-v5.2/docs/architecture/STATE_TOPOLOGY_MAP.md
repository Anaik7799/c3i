# System State Topology Map (v21.3.0)

**Classification**: L4-OPERATIONAL
**Status**: VERIFIED
**Context**: Comprehensive inventory of all system memory and storage.

---

## 1.0 Persistent State (Durable)

### 1.1 Data Plane (PostgreSQL)
**Role**: Transactional Source of Truth (OLTP).
- **Primary**: `indrajaal-db1` (Port 5433)
- **Replica**: `indrajaal-db2` (Port 5434)
- **Volume**: `fractal-db1-data`, `fractal-db2-data`
- **Definition**: `lib/indrajaal/repo.ex`

### 1.2 Mnemonic Plane (KMS)
**Role**: Holon State & Vector Memory.
- **Engine**: SQLite (WAL Mode)
- **Artifacts**:
    - `data/kms/core.db`: System configuration & state.
    - `data/kms/holons.db`: Entity registry.
- **Access**: `Exqlite` (Elixir) / `System.Data.SQLite` (F#).

### 1.3 Analytical Plane (OLAP)
**Role**: Telemetry History & Large Datasets.
- **Engine**: DuckDB
- **Artifacts**:
    - `data/kms/analytics.duckdb`: OODA loop history.
    - `data/kms/telemetry.duckdb`: Sensor data.
- **Access**: `DuckDB.NET` (F#) / `duckdbex` (Elixir).

### 1.4 Infrastructure State
**Role**: Container Persistence.
- **Volumes**:
    - `fractal-obs-data`: SigNoz/ClickHouse data.
    - `fractal-app1-data`: Application uploads/state.
    - `fractal-app2-data`: Replica state.

---

## 2.0 Real-time State (Volatile)

### 2.1 High-Speed Cache (ETS)
**Role**: Microsecond-latency access for hot data.
**Count**: 47+ Named Tables.
**Key Tables**:
- `:task_registry`: Async task tracking.
- `:rate_limits`: API throttling counters.
- `:safety_violations`: STAMP constraint breaches.
- `:fractal_routing_rules`: Zenoh/Mesh routing table.

### 2.2 Distributed Cache (Cachex/Redis)
**Role**: Cluster-wide shared state.
- **Redis**: `indrajaal-redis` (via Redix).
- **Cachex**: Local in-memory caching with TTL.

### 2.3 Process State (GenServer)
**Role**: Active Actor State.
- **Agents**: 50+ GenServers holding operational context.
- **Guardian**: Safety rules engine.
- **Sentinel**: Immune system threat model.

---

## 3.0 State Flow (Metabolism)

1.  **Ingest**: Data enters via API (Real-time).
2.  **Process**: Validated by Guardian, cached in ETS.
3.  **Persist**: Flushed to PostgreSQL (Async) or SQLite (Sync).
4.  **Archive**: Telemetry batch-flushed to DuckDB (60s).
5.  **Sync**: 2oo3 Voting ensures consistency across nodes.
