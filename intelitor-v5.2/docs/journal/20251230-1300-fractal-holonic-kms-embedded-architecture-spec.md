# Fractal Holonic Knowledge Management System - Embedded Database Architecture

**Date**: 2025-12-30T13:00:00+01:00
**Version**: 1.0.0 — Embedded Edition
**Status**: ARCHITECTURE SPECIFICATION
**Alignment**: Indrajaal Grand Unification Principles

---

## Executive Summary

This document presents the architecture for a Fractal Holonic Knowledge Management System built entirely on embedded databases. The system requires zero external infrastructure—each holon carries its own database, enabling true autonomous operation, seamless swarming, and edge deployment.

### Embedded-First Design Philosophy

- **Zero Infrastructure**: No external database servers, message brokers, or cache clusters
- **Portable Holons**: Each knowledge unit carries its complete state in embedded databases
- **Swarm-Ready**: Holons can detach, operate offline, and merge back seamlessly
- **Edge-Native**: Runs on laptops, Raspberry Pi, air-gapped environments
- **Single-Binary Deployment**: Entire system deployable as one executable

### Embedded Database Stack

| Database | Purpose |
|----------|---------|
| **SQLite** | Primary OLTP store for holon metadata, relationships, and content |
| **DuckDB** | Analytical processing, metrics aggregation, and reporting |
| **sqlite-vss** | Vector similarity search for semantic queries |
| **Elixir ETS/DETS** | In-memory caching and persistent term storage |
| **Khepri (Ra)** | Distributed consensus for cluster coordination |

### System Composition (Aligned with Indrajaal)

- **50 Autonomous Agents** (1 Executive, 10 Domain, 15 Functional, 24 Workers)
- **5 VSM Systems** implementing Stafford Beer's Viable System Model
- **7 Fractal Layers** (Function → Module → Agent → Container → Node → Cluster → Federation)
- **OODA Cybernetic Loop** with <100ms cycle time
- **Bio-Inspired Holon Architecture** with vital signs, membrane, and autopoiesis
- **PRAJNA C3I Cockpit** with Dark Cockpit principles (NASA-STD-3000)

---

## Part 1: Embedded Database Architecture

### 1.1 Design Rationale

Traditional knowledge management systems rely on external database servers, creating infrastructure dependencies that conflict with the holonic principle of autonomous operation. By using embedded databases exclusively, each holon becomes a self-contained unit capable of independent operation.

**Benefits of Embedded-Only Architecture:**

- **Portability**: Entire knowledge base fits in a directory, easily moved or backed up
- **Simplicity**: No database administration, connection pooling, or cluster management
- **Reliability**: No network partitions between app and database
- **Performance**: Zero network latency for database operations
- **Swarm Capability**: Holons can detach with their data and operate independently
- **Edge Deployment**: Runs anywhere—laptops, containers, IoT devices, air-gapped systems
- **Cost**: No database licensing, hosting, or operational costs

### 1.2 Database Role Separation

The embedded stack separates concerns between OLTP, OLAP, and specialised workloads:

```
┌─────────────────────────────────────────────────────────────┐
│              EMBEDDED DATABASE ARCHITECTURE                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   SQLite    │  │   DuckDB    │  │ sqlite-vss  │        │
│  │   (OLTP)    │  │   (OLAP)    │  │  (Vectors)  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│        │                │                │                 │
│        ▼                ▼                ▼                 │
│  ┌─────────────────────────────────────────────────┐      │
│  │              Unified Query Layer                 │      │
│  │         (Elixir Ecto + DuckDB NIF)              │      │
│  └─────────────────────────────────────────────────┘      │
│        │                                                   │
│        ▼                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  ETS/DETS   │  │   Khepri    │  │   Mnesia    │        │
│  │  (Cache)    │  │ (Consensus) │  │ (Dist. KV)  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

| Database | Role | Use Cases |
|----------|------|-----------|
| SQLite | OLTP | Holon CRUD, relationships, metadata, content |
| DuckDB | OLAP | Analytics, aggregations, trend analysis, reporting |
| sqlite-vss | Vector Search | Semantic search, similarity queries, embeddings |
| ETS | Hot Cache | Frequently accessed holons, session state |
| DETS | Warm Cache | Persistent cache, survives restarts |
| Khepri | Consensus | Distributed coordination, leader election |
| Mnesia | Distributed KV | Cross-node replication, cluster state |

### 1.3 SQLite — Primary OLTP Store

SQLite serves as the primary transactional database for all holon operations. With WAL mode and proper configuration, it handles high concurrency while maintaining ACID guarantees.

**Configuration for High Performance:**

```sql
-- SQLite optimisation pragmas
PRAGMA journal_mode = WAL;          -- Write-Ahead Logging
PRAGMA synchronous = NORMAL;        -- Balance durability/speed
PRAGMA cache_size = -64000;         -- 64MB cache
PRAGMA mmap_size = 268435456;       -- 256MB memory-mapped I/O
PRAGMA temp_store = MEMORY;         -- In-memory temp tables
PRAGMA busy_timeout = 5000;         -- 5s lock wait
PRAGMA foreign_keys = ON;           -- Enforce referential integrity
```

**Schema Design:**

```sql
-- Core holon table
CREATE TABLE holons (
  id TEXT PRIMARY KEY,              -- UUID
  fqun TEXT UNIQUE NOT NULL,        -- Fully-Qualified Unique Name
  type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index')),
  name TEXT NOT NULL,
  parent_id TEXT REFERENCES holons(id),
  genome JSON NOT NULL,             -- Replication DNA
  vital_signs JSON DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
  membrane JSON DEFAULT '{}',       -- Access control
  payload JSON NOT NULL,            -- Content
  hlc_physical INTEGER NOT NULL,    -- HLC timestamp (μs)
  hlc_logical INTEGER NOT NULL,     -- HLC counter
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Hierarchical traversal index
CREATE INDEX idx_holons_parent ON holons(parent_id);
CREATE INDEX idx_holons_type ON holons(type);
CREATE INDEX idx_holons_hlc ON holons(hlc_physical, hlc_logical);

-- Full-text search
CREATE VIRTUAL TABLE holons_fts USING fts5(
  name, payload,
  content='holons',
  content_rowid='rowid'
);
```

**Relationship Tables:**

```sql
-- Holon relationships (graph edges)
CREATE TABLE holon_edges (
  source_id TEXT NOT NULL REFERENCES holons(id),
  target_id TEXT NOT NULL REFERENCES holons(id),
  relation TEXT NOT NULL,           -- 'contains','references','depends_on'
  weight REAL DEFAULT 1.0,
  metadata JSON DEFAULT '{}',
  PRIMARY KEY (source_id, target_id, relation)
);

-- Event log (append-only)
CREATE TABLE holon_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  holon_id TEXT NOT NULL,
  event_type TEXT NOT NULL,         -- 'created','updated','accessed','evolved'
  payload JSON,
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL,
  agent_id TEXT                     -- Which agent triggered
);
```

### 1.4 DuckDB — Analytical Processing

DuckDB provides columnar analytics without requiring data export. It can query SQLite directly or work on Parquet files for historical analysis.

**Integration Patterns:**

```sql
-- DuckDB querying SQLite directly
ATTACH 'holons.db' AS sqlite_db (TYPE SQLITE);

-- Analytical query: Holon health distribution
SELECT
  type,
  COUNT(*) as count,
  AVG(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as avg_health,
  AVG(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE)) as avg_stress
FROM sqlite_db.holons
GROUP BY type;

-- Time-series analysis from event log
SELECT
  strftime('%Y-%m-%d', datetime(hlc_physical/1000000, 'unixepoch')) as day,
  event_type,
  COUNT(*) as event_count
FROM sqlite_db.holon_events
WHERE hlc_physical > (strftime('%s', 'now') - 86400*30) * 1000000
GROUP BY day, event_type
ORDER BY day;
```

**Parquet Export for Long-Term Analytics:**

```sql
-- Export to Parquet for archival
COPY (
  SELECT * FROM sqlite_db.holon_events
  WHERE hlc_physical < (strftime('%s', 'now') - 86400*90) * 1000000
) TO 'archive/events_q3_2025.parquet' (FORMAT PARQUET);

-- Query across Parquet archives
SELECT * FROM read_parquet('archive/*.parquet')
WHERE event_type = 'evolved';
```

### 1.5 sqlite-vss — Vector Similarity Search

sqlite-vss provides semantic search capabilities directly within SQLite, enabling AI-powered discovery without external vector databases.

**Vector Table Setup:**

```sql
-- Load the extension
.load ./vector0
.load ./vss0

-- Create vector table
CREATE VIRTUAL TABLE holon_vectors USING vss0(
  embedding(1024)                   -- Voyage-3 dimensions
);

-- Mapping table to link vectors to holons
CREATE TABLE holon_vector_map (
  rowid INTEGER PRIMARY KEY,
  holon_id TEXT NOT NULL REFERENCES holons(id),
  chunk_index INTEGER DEFAULT 0,    -- For chunked content
  UNIQUE(holon_id, chunk_index)
);
```

**Semantic Search Query:**

```sql
-- Find similar holons
WITH query_embedding AS (
  SELECT ? AS vec                   -- Embedding from query text
)
SELECT
  h.id,
  h.name,
  h.type,
  v.distance
FROM holon_vectors v
JOIN holon_vector_map m ON v.rowid = m.rowid
JOIN holons h ON m.holon_id = h.id
WHERE vss_search(v.embedding, (SELECT vec FROM query_embedding))
LIMIT 10;
```

### 1.6 Elixir ETS/DETS — In-Memory Layer

Elixir's built-in ETS (Erlang Term Storage) and DETS (Disk-based ETS) provide zero-latency caching without external dependencies.

**ETS Configuration:**

```elixir
# Hot cache for frequently accessed holons
defmodule KMS.HolonCache do
  use GenServer

  def init(_) do
    table = :ets.new(:holon_cache, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
    {:ok, table}
  end

  def get(holon_id) do
    case :ets.lookup(:holon_cache, holon_id) do
      [{^holon_id, holon, expires_at}] when expires_at > now() -> {:ok, holon}
      _ -> :miss
    end
  end

  def put(holon_id, holon, ttl_ms \\ 300_000) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(:holon_cache, {holon_id, holon, expires_at})
  end
end
```

**DETS for Persistent Cache:**

```elixir
# Warm cache that survives restarts
defmodule KMS.PersistentCache do
  def init do
    {:ok, _} = :dets.open_file(:persistent_cache, [
      file: 'data/cache.dets',
      type: :set,
      auto_save: 60_000  # Auto-save every minute
    ])
  end

  def get(key), do: :dets.lookup(:persistent_cache, key)
  def put(key, value), do: :dets.insert(:persistent_cache, {key, value})
end
```

### 1.7 Khepri — Distributed Consensus

Khepri (built on Ra/Raft) provides distributed consensus for cluster coordination without external dependencies like etcd or Consul.

**Cluster Coordination:**

```elixir
# Khepri for distributed state
defmodule KMS.ClusterState do
  def start_link do
    Khepri.start(:kms_cluster, %{data_dir: "data/khepri"})
  end

  # Leader election for agents
  def elect_leader(agent_type) do
    Khepri.transaction(:kms_cluster, fn ->
      path = [:agents, agent_type, :leader]
      case Khepri.get(path) do
        {:ok, nil} -> Khepri.put(path, node())
        {:ok, existing} -> {:already_elected, existing}
      end
    end)
  end

  # Distributed locks for critical sections
  def with_lock(resource, fun) do
    Khepri.transaction(:kms_cluster, fn ->
      Khepri.put([:locks, resource], {node(), now()})
      result = fun.()
      Khepri.delete([:locks, resource])
      result
    end)
  end
end
```

---

## Part 2: File System Layout

### 2.1 Holon Data Directory Structure

Each holon or cluster maintains a self-contained data directory that can be easily backed up, moved, or shipped for swarm operations.

```
kms_data/
├── holons.db                    # Primary SQLite database
├── holons.db-wal                # WAL file (auto-managed)
├── holons.db-shm                # Shared memory (auto-managed)
├── vectors.db                   # sqlite-vss vector store
├── analytics/
│   ├── metrics.duckdb           # DuckDB analytics database
│   └── archive/
│       ├── events_2025_q1.parquet
│       ├── events_2025_q2.parquet
│       └── events_2025_q3.parquet
├── cache/
│   ├── hot.dets                 # DETS persistent cache
│   └── embeddings.dets          # Cached embeddings
├── khepri/                      # Distributed consensus data
│   ├── ra/
│   └── snapshots/
├── blobs/                       # Large binary content
│   ├── attachments/
│   └── exports/
├── logs/
│   ├── fractal/                 # Fractal log levels
│   │   ├── l3_agent.log
│   │   ├── l4_node.log
│   │   └── l5_cluster.log
│   └── ooda/                    # OODA cycle logs
└── config/
    ├── genome.json              # System genome
    └── constitution.json        # Invariants (Ω₁-Ω₇)
```

### 2.2 Swarm Cell — Minimal Portable Unit

When a holon detaches for swarming, it creates a minimal self-contained package:

```
swarm_cell_{holon_id}/
├── manifest.json                # Identity, genome, reconstruction recipe
├── holon.db                     # SQLite with just this holon + descendants
├── vectors.db                   # Subset of embeddings
├── payload/                     # Content blobs
└── checksum.sha256              # Integrity verification
```

**Manifest Structure:**

```json
{
  "identity": {
    "id": "hln_7x8k9m2n",
    "fqun": "kms/l3/knowledge/operations/incident_runbook@node-01#01HW",
    "checksum": "sha256:abc123..."
  },
  "genome": {
    "archetype": "runbook",
    "schema_version": "1.0.0",
    "replication_priority": "critical"
  },
  "vital_signs": {
    "health": 0.92,
    "stress": 0.15,
    "energy": 0.78
  },
  "reconstruction": {
    "home_origin": "https://kms.example.com",
    "peers": ["peer1.mesh.local", "peer2.mesh.local"],
    "last_sync_hlc": [1703952000000000, 42]
  }
}
```

### 2.3 Backup and Replication

Embedded databases enable simple, file-based backup strategies:

**Hot Backup (Online):**

```elixir
# SQLite online backup API
defmodule KMS.Backup do
  def hot_backup(source_db, dest_path) do
    {:ok, dest} = Exqlite.Sqlite3.open(dest_path)
    Exqlite.Sqlite3.execute(source_db, "VACUUM INTO '#{dest_path}'")
  end

  def incremental_backup do
    # Copy WAL file for point-in-time recovery
    File.cp!("holons.db-wal", "backups/wal_#{timestamp()}.wal")
  end
end
```

**Swarm Replication:**

```elixir
# Extract holon for swarm operation
defmodule KMS.SwarmExtract do
  def extract_holon(holon_id, output_dir) do
    # Create minimal SQLite with holon and descendants
    Exqlite.Sqlite3.execute(source, """
      ATTACH DATABASE '#{output_dir}/holon.db' AS export;

      INSERT INTO export.holons
      WITH RECURSIVE descendants AS (
        SELECT * FROM holons WHERE id = ?
        UNION ALL
        SELECT h.* FROM holons h
        JOIN descendants d ON h.parent_id = d.id
      )
      SELECT * FROM descendants;
    """, [holon_id])

    # Extract corresponding vectors
    extract_vectors(holon_id, output_dir)

    # Generate manifest
    write_manifest(holon_id, output_dir)
  end
end
```

---

## Part 3: Cybernetic Architecture

### 3.1 Viable System Model (VSM)

The knowledge organism implements Stafford Beer's Viable System Model using embedded databases for state management:

| System | Role | Embedded Implementation |
|--------|------|------------------------|
| S5 Policy | Identity | constitution.json — Invariants (Ω₁-Ω₇), immutable rules |
| S4 Intelligence | Future | DuckDB analytics — trends, predictions, Monte Carlo |
| S3 Control | Guard | SQLite quotas table — resource budgets, rate limits |
| S2 Coordination | Balance | Khepri consensus — anti-oscillation, gossip, dampening |
| S1 Operations | Doing | SQLite holons — CRUD, search, content management |

### 3.2 OODA Cybernetic Loop

The OODA loop operates on data from embedded databases with <100ms cycle time:

```
┌──────────────────────────────────────────────────────────────┐
│                    OODA CYCLE (<100ms)                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  OBSERVE (<25ms)           ORIENT (<25ms)                   │
│  ├─ ETS: Hot metrics       ├─ DuckDB: Pattern analysis      │
│  ├─ SQLite: Recent events  ├─ sqlite-vss: Similarity        │
│  └─ Khepri: Cluster state  └─ Local ML: Anomaly detection   │
│           │                          │                       │
│           ▼                          ▼                       │
│  DECIDE (<25ms)            ACT (<25ms)                      │
│  ├─ Rule engine            ├─ SQLite: Mutations             │
│  ├─ Priority queue         ├─ ETS: Cache updates            │
│  └─ Conflict resolution    └─ Khepri: Broadcast             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 3.3 Constitutional Invariants (Ω₁-Ω₇)

Stored in constitution.json and enforced by Guardian agent:

```json
{
  "invariants": [
    {"id": "Ω₁", "name": "Patient Mode", "rule": "never_interrupt_user_workflow"},
    {"id": "Ω₂", "name": "Container Isolation", "rule": "agents_in_isolated_containers"},
    {"id": "Ω₃", "name": "Zero-Defect", "rule": "health_metrics_converge_healthy"},
    {"id": "Ω₄", "name": "TDG", "rule": "tests_before_code"},
    {"id": "Ω₅", "name": "FPPS Consensus", "rule": "five_method_agreement_critical"},
    {"id": "Ω₆", "name": "Mandatory Gates", "rule": "all_quality_gates_pass"},
    {"id": "Ω₇", "name": "Non-Aggression", "rule": "human_safety_privacy_first"}
  ],
  "enforcement": "guardian_agent",
  "violation_action": "halt_and_escalate"
}
```

---

## Part 4: Bio-Inspired Holon Architecture

### 4.1 Holon Lifecycle

Each holon follows a biological lifecycle with vital signs stored in SQLite:

```
┌─────────────────────────────────────────────────────────────┐
│                    HOLON LIFECYCLE                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    SPAWN ──→ ACTIVE ──→ HEALING ──┬──→ MITOSIS (scale)     │
│     ↑          │          │       │                         │
│     │          ↓          ↓       └──→ APOPTOSIS (archive)  │
│     └──────────┴──────────┘                                 │
│                                                             │
│  vital_signs: {health, stress, energy} — stored in SQLite  │
│  health_check: <10ms query against local database          │
│  self_heal: Autonomous recovery via Evolution agent        │
│  mitosis: Extract swarm cell, replicate to new location    │
│  apoptosis: Archive to Parquet, remove from active DB      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Three-Layer Bio Architecture

| Layer | Component | Embedded Implementation |
|-------|-----------|------------------------|
| Bio | Vital Signs | SQLite JSON column — health, stress, energy (0.0-1.0) |
| Bio | Membrane | SQLite access_control table — rate limits, permissions |
| Bio | Autopoiesis | Oban jobs — scheduled self-maintenance tasks |
| Bio | Homeostasis | ETS counters — resource balance tracking |
| Immune | Antibody | SQLite threats table + pattern matching |
| Immune | Mara | Scheduled chaos tests with results in DuckDB |
| Neuro | Spine L1 | ETS rule cache — <5ms heuristic responses |
| Neuro | Spine L2 | DuckDB ML — anomaly detection, pattern recognition |
| Neuro | Spine L3 | OpenRouter API — LLM reasoning for complex decisions |

### 4.3 Health Propagation

Health flows bottom-up using recursive SQLite queries:

```sql
-- Calculate parent health from children
WITH RECURSIVE health_tree AS (
  -- Base: leaf nodes (no children)
  SELECT
    id, parent_id,
    json_extract(vital_signs, '$.health') as health,
    0 as level
  FROM holons
  WHERE id NOT IN (SELECT DISTINCT parent_id FROM holons WHERE parent_id IS NOT NULL)

  UNION ALL

  -- Recursive: propagate up
  SELECT
    h.id, h.parent_id,
    MIN(ht.health) as health,  -- Worst child determines parent
    ht.level + 1
  FROM holons h
  JOIN health_tree ht ON h.id = ht.parent_id
  GROUP BY h.id
)
SELECT * FROM health_tree ORDER BY level DESC;
```

---

## Part 5: Agent Mesh Architecture

### 5.1 Agent Hierarchy (50 Agents)

All agents store their state in local SQLite/ETS, coordinated via Khepri:

```
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTIVE AGENT (1)                      │
│          State: Khepri (distributed consensus)              │
├─────────────────────────────────────────────────────────────┤
│                   DOMAIN AGENTS (10)                        │
│          State: SQLite domain tables                        │
├─────────────────────────────────────────────────────────────┤
│                  FUNCTIONAL AGENTS (15)                     │
│          State: ETS for hot, SQLite for persistent          │
├─────────────────────────────────────────────────────────────┤
│                   WORKER AGENTS (24)                        │
│          State: ETS only (stateless preferred)              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Core 7-Agent Mesh

| Agent | Constraint | State Storage |
|-------|------------|---------------|
| OODA Controller | <100ms cycle | ETS (hot metrics), SQLite (events) |
| ACE | MAPE-K loop | SQLite (adaptation history) |
| Cortex | 50ms reflexes | ETS (L1), DuckDB (L2), OpenRouter (L3) |
| Fractal Logger | HLC timestamps | SQLite (L3-L5), Parquet (archive) |
| Guardian | SIL-2 safety | constitution.json (immutable) |
| Sentinel | 5s heartbeat | Khepri (cluster state) |
| KPI Dashboard | 30s refresh | DuckDB (aggregations) |

### 5.3 Agent State Management

```elixir
defmodule KMS.Agent.Base do
  @moduledoc "Base agent with embedded database state"

  defmacro __using__(opts) do
    quote do
      use GenServer

      # ETS for hot state
      def init(config) do
        table = :ets.new(__MODULE__, [:set, :protected])

        # Load persistent state from SQLite
        state = load_from_sqlite(__MODULE__)

        {:ok, %{ets: table, config: config, state: state}}
      end

      # Persist state changes to SQLite
      def handle_cast({:persist, key, value}, state) do
        :ets.insert(state.ets, {key, value})
        persist_to_sqlite(__MODULE__, key, value)
        {:noreply, state}
      end
    end
  end
end
```

---

## Part 6: Technology Stack

### 6.1 Complete Embedded Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Application | Elixir/Phoenix | Core runtime, web UI, LiveView |
| Application | F# (CEPAF) | Safety constraints, container ops |
| OLTP | SQLite + Exqlite | Holon CRUD, relationships, events |
| OLAP | DuckDB | Analytics, aggregations, Parquet |
| Vectors | sqlite-vss | Semantic search, embeddings |
| Hot Cache | ETS | In-memory, O(1) lookups |
| Warm Cache | DETS | Persistent, survives restarts |
| Consensus | Khepri (Ra/Raft) | Distributed coordination |
| Distributed KV | Mnesia | Cross-node replication |
| Jobs | Oban (SQLite) | Background processing |
| Pub/Sub | Phoenix.PubSub | In-process messaging |
| Mesh | Zenoh (optional) | Cross-node when clustered |
| AI Gateway | OpenRouter | Multi-model LLM access |
| Containers | Podman | Rootless isolation |
| Orchestration | Kubernetes | Cluster deployment |

### 6.2 Elixir Dependencies

```elixir
# mix.exs dependencies
defp deps do
  [
    # Core
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},

    # Embedded Databases
    {:exqlite, "~> 0.13"},           # SQLite NIF
    {:ecto_sqlite3, "~> 0.12"},      # Ecto adapter
    {:duckdbex, "~> 0.3"},           # DuckDB NIF

    # Distributed
    {:khepri, "~> 0.10"},            # Ra-based consensus

    # Background Jobs
    {:oban, "~> 2.17"},
    {:oban_sqlite, "~> 0.1"},        # SQLite backend for Oban

    # AI
    {:req, "~> 0.4"},                # HTTP client for OpenRouter

    # Observability
    {:opentelemetry, "~> 1.3"},
    {:telemetry_metrics, "~> 0.6"}
  ]
end
```

### 6.3 Single-Binary Deployment

The embedded architecture enables single-binary deployment via Burrito or Bakeware:

```elixir
# Build self-contained executable
mix release --overwrite

# Or with Burrito for true single binary
# config/config.exs
config :burrito,
  releases: [
    kms: [
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [linux: [os: :linux, cpu: :x86_64]],
        extra_files: [
          {"priv/sqlite_extensions", "extensions"},
          {"priv/constitution.json", "config/constitution.json"}
        ]
      ]
    ]
  ]

# Result: Single ~50MB executable
# ./kms_linux_x86_64 --data-dir ./kms_data
```

### 6.4 AI/ML Integration — OpenRouter

| Task Type | Primary Model | Fallback |
|-----------|---------------|----------|
| Complex Reasoning | Claude Sonnet 4 | GPT-4o |
| Fast Classification | Claude Haiku | GPT-4o-mini |
| Code Generation | Claude Sonnet 4 | DeepSeek Coder |
| Embeddings | Voyage-3 (1024d) | text-embedding-3-large |
| Long Context | Claude Sonnet 4 | Gemini Pro 1.5 |
| Summarization | Claude Haiku | GPT-4o-mini |

---

## Part 7: PRAJNA C3I Cockpit

### 7.1 Architecture

PRAJNA provides human-in-the-loop oversight with all state in embedded databases:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRAJNA C3I COCKPIT                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ AI COPILOT  │  │DARK COCKPIT │  │   SALIENCE  │        │
│  │(OpenRouter) │  │(NASA-STD)   │  │  (d-prime)  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│        │                │                │                 │
│        ▼                ▼                ▼                 │
│  ┌─────────────────────────────────────────────────┐      │
│  │          Phoenix LiveView (Real-time UI)         │      │
│  │    State: ETS (session) + SQLite (persistent)   │      │
│  └─────────────────────────────────────────────────┘      │
│        │                                                   │
│        ▼                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   SQLite    │  │   DuckDB    │  │    ETS      │        │
│  │  (Holons)   │  │ (Analytics) │  │  (Cache)    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Dark Cockpit Principles

| Principle | Implementation |
|-----------|----------------|
| Management by Exception | Gray backgrounds, color only for abnormal |
| Analog over Digital | Sparklines ▁▂▃▄▅▆▇█ from DuckDB time-series |
| Trend Vectors | ↑↑/↑/→/↓/↓↓ calculated via DuckDB window functions |
| Staleness Decay | Visual opacity based on HLC age |
| Two-Step Commit | SQLite transaction + confirmation |
| Salience Filtering | Score 0-100 with treatment mapping |

### 7.3 Salience Thresholds

- **0-20**: Suppressed (SQLite log only)
- **21-50**: Background (dim in UI)
- **51-80**: Foreground (LiveView popup)
- **81-99**: Alert (visual + audio)
- **100**: Emergency (blink + bell)

---

## Part 8: Deployment

### 8.1 Deployment Modes

The embedded architecture supports multiple deployment modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| Single Binary | One executable, all embedded | Edge, laptop, air-gapped |
| Container | Podman/Docker with volumes | Cloud, Kubernetes |
| Cluster | Multiple nodes + Khepri | High availability |
| Swarm | Distributed holons | Federated knowledge |

### 8.2 Single-Node Deployment

```bash
# Download and run
curl -L https://releases.kms.io/latest/kms_linux_x86_64 -o kms
chmod +x kms
./kms --data-dir ./kms_data --port 4000

# Data directory auto-initializes:
# kms_data/
#   holons.db, vectors.db, analytics/metrics.duckdb, ...
```

### 8.3 Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kms
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: kms
          image: kms:latest
          volumeMounts:
            - name: data
              mountPath: /app/kms_data
          env:
            - name: KMS_CLUSTER_NODES
              value: "kms-0,kms-1,kms-2"
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

### 8.4 Performance Targets

| Metric | Target | Achieved With |
|--------|--------|---------------|
| OODA Cycle | <100ms | ETS hot path, SQLite WAL |
| Holon Retrieval | <5ms | ETS cache hit |
| Holon Retrieval | <15ms | SQLite with index |
| Semantic Search | <50ms | sqlite-vss HNSW |
| Analytics Query | <200ms | DuckDB columnar |
| Full-Text Search | <20ms | SQLite FTS5 |
| Backup (10GB) | <30s | SQLite VACUUM INTO |

---

## Part 9: Stakeholder Use Cases

### 9.1 Developer Use Cases

- **Onboarding**: System landscape, guides, conventions — all in portable SQLite
- **Code Discovery**: Pattern hunting via sqlite-vss semantic search
- **Debugging**: Error investigation with DuckDB time-series analysis
- **Decision Archaeology**: ADRs with full-text search
- **Offline Access**: Work disconnected, sync later via swarm merge

### 9.2 Operations/SRE Use Cases

- **Incident Management**: Runbooks with step tracking in SQLite
- **Runbook Execution**: Offline-capable, logs to local database
- **Deployment**: Single binary to edge locations
- **Air-Gapped Environments**: Full functionality without network

### 9.3 Technical Leadership Use Cases

- **Architecture Decisions**: ADRs with DuckDB trend analysis
- **Technology Strategy**: Roadmaps with embedded versioning
- **Standards Governance**: Constitution enforcement via Guardian

### 9.4 Edge/IoT Use Cases

- **Raspberry Pi Deployment**: Full KMS on ARM with <100MB footprint
- **Factory Floor**: Air-gapped knowledge base for operators
- **Field Service**: Technicians carry full documentation offline
- **Sync on Connect**: Swarm merge when network available

---

## Part 10: Summary

### 10.1 Architecture Summary

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Philosophy | Embedded-Only | Zero infrastructure, portable |
| OLTP | SQLite | Battle-tested, single-file, ACID |
| OLAP | DuckDB | Columnar analytics, Parquet |
| Vectors | sqlite-vss | Semantic search in SQLite |
| Cache | ETS/DETS | Native Elixir, zero latency |
| Consensus | Khepri | Embedded Raft, no etcd |
| Application | Elixir + F# | Concurrency, safety |
| AI Gateway | OpenRouter | Multi-model access |
| Deployment | Single Binary | Burrito packaging |
| Control | OODA + VSM | Cybernetic adaptation |

### 10.2 Key Benefits

- **Zero Infrastructure**: No PostgreSQL, Redis, Elasticsearch to manage
- **Portable**: Copy directory = backup/migrate entire system
- **Offline-First**: Full functionality without network
- **Edge-Ready**: Runs on Raspberry Pi to data center
- **Swarm-Capable**: Holons detach and merge seamlessly
- **Simple Operations**: File-based backup, no DBA required
- **Cost Effective**: No database licensing or hosting

### 10.3 Trade-offs

- **Write Concurrency**: SQLite single-writer (mitigated by WAL + ETS buffering)
- **Dataset Size**: Practical limit ~100GB per node (mitigated by Parquet archival)
- **Cluster Coordination**: Khepri less mature than etcd (mitigated by Raft guarantees)

### 10.4 Implementation Phases

| Phase | Scope |
|-------|-------|
| Phase 1 | SQLite schema, Ecto adapter, basic CRUD |
| Phase 2 | sqlite-vss integration, semantic search |
| Phase 3 | DuckDB analytics, Parquet archival |
| Phase 4 | ETS/DETS caching layer |
| Phase 5 | Khepri clustering, swarm operations |
| Phase 6 | Agent mesh with embedded state |
| Phase 7 | PRAJNA LiveView cockpit |
| Phase 8 | Burrito single-binary packaging |

---

## Alignment with Indrajaal Components

This embedded KMS architecture fully aligns with the Indrajaal Grand Unification system:

| Indrajaal Component | KMS Embedded Equivalent |
|---------------------|------------------------|
| PostgreSQL + TimescaleDB | SQLite (OLTP) + DuckDB (OLAP) + Parquet (archive) |
| Ash Domains | SQLite tables with JSON payloads |
| 50-Agent Mesh | Same hierarchy with SQLite/ETS state |
| VSM (5 Systems) | Mapped to embedded databases |
| OODA Loop | Same <100ms cycle on ETS/SQLite |
| Fractal Logging (L1-L7) | SQLite + Parquet + DuckDB |
| HLC Timestamps | Same implementation, stored in SQLite |
| Zenoh Mesh | Optional for clustering, Khepri for consensus |
| PRAJNA Cockpit | Phoenix LiveView with SQLite backend |
| Bio Holon Lifecycle | SQLite vital_signs + ETS health |
| STAMP Constraints | constitution.json + Guardian agent |

---

**End of Document**

---

*Generated: 2025-12-30T13:00:00+01:00*
*Framework: Indrajaal Grand Unification + Embedded-First Design*
*Alignment: Full compatibility with current Indrajaal v20.0.0 components*
