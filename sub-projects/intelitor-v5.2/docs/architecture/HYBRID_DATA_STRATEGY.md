# Hybrid Data Architecture: SQLite + DuckDB for System Verification
**Version**: 1.0.0
**Date**: 2026-01-05
**Compliance**: SC-SIL6-020 (Data Integrity)

## 1.0 The Dichotomy of State
We separate concerns between "Control State" (Command & Control) and "Observational State" (Telemetry & Forensics).

| Feature | SQLite (Control Plane) | DuckDB (Data Plane) |
| :--- | :--- | :--- |
| **Role** | Flight Recorder | Black Box / Analytics Engine |
| **Data Type** | Mutable, Relational | Immutable, Columnar, Time-Series |
| **Workload** | High-concurrency Reads (Dashboard), Atomic Writes | High-throughput Inserts (Logs), Complex Queries |
| **Examples** | Test Configs, Execution Status, User Sessions | Fractal Logs, Metrics, Traces, Vector Embeddings |
| **Retention** | Active State (Current + Recent History) | Deep History (All runs, full fidelity) |

## 2.0 Integration Point: The Cockpit
The Prajna Cockpit sits on top of *both*:
*   **Live View**: Queries SQLite for "What is running now?".
*   **Deep Dive**: Queries DuckDB for "Why did it fail?".

## 3.0 Schema Strategy

### 3.1 SQLite Schema (test_manager.db)
```sql
TABLE test_definitions (id, name, constraints)
TABLE executions (id, status, start_time, end_time)
TABLE configuration_snapshots (id, hash, json_blob)
```

### 3.2 DuckDB Schema (telemetry.duckdb)
```sql
TABLE signals (
  ts TIMESTAMPTZ, 
  trace_id UUID, 
  execution_id UUID, -- JOIN Key
  level VARCHAR,     -- L1..L5
  component VARCHAR,
  event_type VARCHAR,
  payload JSON,      -- Full state dump
  logical_clock BIGINT
);
-- Optimized for: SELECT payload FROM signals WHERE execution_id = ? ORDER BY ts
```

## 4.0 Data Flow
1.  **Setup**: Test Manager creates `execution_id` in SQLite.
2.  **Run**: System emits telemetry to Zenoh.
3.  **Capture**: `TelemetryBridge` drains Zenoh -> DuckDB (Batch Insert).
4.  **Finish**: Test Manager updates `status` in SQLite.
5.  **Analyze**: Cockpit joins SQLite `status` with DuckDB `payload` for RCA.
