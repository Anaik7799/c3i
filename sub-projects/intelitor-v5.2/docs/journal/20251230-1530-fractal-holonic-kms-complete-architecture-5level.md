# Fractal Holonic KMS - Complete Architecture & Implementation Plan
**Date**: 2025-12-30T15:30:00+01:00
**Version**: 1.0.0
**Status**: Phase 0-2 Complete, Phase 3-5 Pending
**STAMP Compliance**: SC-KMS-001, SC-KMS-002, SC-KMS-003, SC-KMS-004

---

## Level 1: Executive Summary

### 1.1 What is KMS?
The **Fractal Holonic Knowledge Management System** is a dual-database architecture providing:
- **SQLite** for OLTP (transactions, CRUD, FTS5 search)
- **DuckDB** for OLAP (analytics, aggregations, Parquet archival)
- **Cross-runtime access** from both Elixir (Phoenix) and F# (CEPAF Cockpit)

### 1.2 Key Design Decisions
| Decision | Rationale |
|----------|-----------|
| SQLite + DuckDB only | User requirement: No ETS/DETS/Khepri |
| File-based databases | Portable, cross-runtime, easy backup |
| JSON columns | Flexible schema for genome, payload, vital_signs |
| HLC timestamps | Causal ordering for distributed operations |
| FTS5 triggers | Auto-sync full-text index |

### 1.3 Implementation Status
```
Phase 0: Foundation     ████████████████████ 100%
Phase 1: Elixir API     ████████████████████ 100%
Phase 2: F# API         ████████████████████ 100%
Phase 3: UI Components  ██████████░░░░░░░░░░  50% (Ready, not wired)
Phase 4: Integration    ░░░░░░░░░░░░░░░░░░░░   0%
Phase 5: Advanced       ░░░░░░░░░░░░░░░░░░░░   0%
OVERALL                 █████████░░░░░░░░░░░  45%
```

### 1.4 STAMP Safety Constraints
- **SC-KMS-001**: SQLite + DuckDB only (no ETS/DETS/Khepri)
- **SC-KMS-002**: Cross-runtime access (Elixir + F#)
- **SC-KMS-003**: Portable holons (directory copy = full backup)
- **SC-KMS-004**: OODA cycle <100ms on SQLite hot path

---

## Level 2: Architecture Overview

### 2.1 System Architecture Diagram
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         FRACTAL HOLONIC KMS ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────┐     ┌─────────────────────────────┐           │
│  │     ELIXIR RUNTIME          │     │       F# RUNTIME            │           │
│  │  (Phoenix/Indrajaal)        │     │    (CEPAF Cockpit)          │           │
│  ├─────────────────────────────┤     ├─────────────────────────────┤           │
│  │  Indrajaal.KMS              │     │  Cepaf.Knowledge            │           │
│  │  ├─ kms.ex (Main API)       │     │  ├─ SharedKMS.fs            │           │
│  │  ├─ sqlite.ex (OLTP)        │     │  ├─ SharedPaths.fs          │           │
│  │  ├─ analytics.ex (OLAP)     │     │  ├─ Ingestor.fs             │           │
│  │  └─ vectors.ex (Search)     │     │  ├─ Gardener.fs             │           │
│  │                             │     │  └─ OpenRouter.fs (AI)      │           │
│  │  Libraries:                 │     │  Libraries:                 │           │
│  │  • Exqlite (SQLite)         │     │  • Microsoft.Data.Sqlite    │           │
│  │  • Duckdbex (DuckDB)        │     │  • DuckDB.NET.Data.Full     │           │
│  └──────────────┬──────────────┘     └──────────────┬──────────────┘           │
│                 │                                   │                          │
│                 │      SHARED FILE-BASED DATABASES  │                          │
│                 └───────────────┬───────────────────┘                          │
│                                 │                                              │
│  ┌──────────────────────────────▼──────────────────────────────────────────┐   │
│  │                          data/kms/                                       │   │
│  ├──────────────────────────────────────────────────────────────────────────┤   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐   │   │
│  │  │    holons.db        │  │  analytics.duckdb   │  │ archive/*.parquet│   │   │
│  │  │    (SQLite)         │  │    (DuckDB)         │  │  (Historical)   │   │   │
│  │  ├─────────────────────┤  ├─────────────────────┤  └─────────────────┘   │   │
│  │  │ • holons            │  │ • Attached SQLite   │                        │   │
│  │  │ • holon_edges       │  │ • OLAP Aggregations │                        │   │
│  │  │ • holon_events      │  │ • JSON Analytics    │                        │   │
│  │  │ • holon_vectors     │  │ • Time-series       │                        │   │
│  │  │ • holons_fts (FTS5) │  │                     │                        │   │
│  │  └─────────────────────┘  └─────────────────────┘                        │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Model
```
HOLON SCHEMA
├── id: TEXT PRIMARY KEY (hln_xxxxxxxxxxxx)
├── fqun: TEXT UNIQUE (kms/l3/type/domain/name@runtime#id)
├── type: ENUM (knowledge|process|agent|artifact|index)
├── name: TEXT
├── parent_id: TEXT FK → holons(id)
├── genome: JSON (schema metadata, version, capabilities)
├── vital_signs: JSON {health: 0-1, stress: 0-1, energy: 0-1}
├── membrane: JSON (interface definitions, permissions)
├── payload: JSON (actual content/knowledge)
├── hlc_physical: INT (microseconds since epoch)
├── hlc_logical: INT (logical clock component)
├── created_at: TEXT (ISO8601)
└── updated_at: TEXT (ISO8601)

HOLON_EDGES (Graph Relationships)
├── source_id: TEXT FK → holons(id)
├── target_id: TEXT FK → holons(id)
├── relation: TEXT (contains, references, depends_on, etc.)
├── weight: REAL (0.0-1.0)
└── metadata: JSON

HOLON_EVENTS (Append-Only Log)
├── id: INTEGER PRIMARY KEY AUTOINCREMENT
├── holon_id: TEXT FK → holons(id)
├── event_type: TEXT (created, updated, accessed, etc.)
├── payload: JSON
├── hlc_physical: INT
├── hlc_logical: INT
├── agent_id: TEXT (optional)
└── created_at: TEXT

HOLON_VECTORS (Embeddings)
├── id: INTEGER PRIMARY KEY AUTOINCREMENT
├── holon_id: TEXT FK → holons(id) ON DELETE CASCADE
├── model: TEXT (voyage-3, etc.)
├── dimensions: INT
├── embedding: TEXT (JSON array of floats)
├── chunk_index: INT DEFAULT 0
├── created_at: TEXT
└── UNIQUE(holon_id, model, chunk_index)

HOLONS_FTS (FTS5 Virtual Table)
├── id: TEXT
├── name: TEXT
├── payload: TEXT
└── [Auto-synced via triggers on INSERT/UPDATE/DELETE]
```

### 2.3 File Locations
| Component | Path |
|-----------|------|
| **Elixir KMS** | `lib/indrajaal/kms/` |
| - Main API | `lib/indrajaal/kms/kms.ex` |
| - SQLite OLTP | `lib/indrajaal/kms/sqlite.ex` |
| - DuckDB OLAP | `lib/indrajaal/kms/analytics.ex` |
| - Vector Search | `lib/indrajaal/kms/vectors.ex` |
| **F# Knowledge** | `lib/cepaf/src/Cepaf.Knowledge/` |
| - Shared Access | `lib/cepaf/src/Cepaf.Knowledge/SharedKMS.fs` |
| - Paths | `lib/cepaf/src/Cepaf.Knowledge/SharedPaths.fs` |
| - Ingestion | `lib/cepaf/src/Cepaf.Knowledge/Ingestor.fs` |
| - Maintenance | `lib/cepaf/src/Cepaf.Knowledge/Gardener.fs` |
| - AI | `lib/cepaf/src/Cepaf.Knowledge/OpenRouter.fs` |
| **F# Cockpit UI** | `lib/cepaf/src/Cepaf/Cockpit/` |
| - Material3 | `lib/cepaf/src/Cepaf/Cockpit/Material3.fs` |
| - Prajna | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **Tests** | `test/indrajaal/kms/kms_test.exs` |
| **Data** | `data/kms/` |

---

## Level 3: Use Cases & API Reference

### 3.1 Elixir KMS API (`lib/indrajaal/kms/`)

#### 3.1.1 CRUD Operations
```elixir
# Create holon
{:ok, holon} = KMS.create_holon(%{
  type: :knowledge,
  name: "Authentication Flow",
  payload: %{content: "OAuth2 implementation guide..."}
})

# Get holon
{:ok, holon} = KMS.get_holon("hln_abc123def456")
{:ok, holon} = KMS.get_holon_by_fqun("kms/l3/knowledge/auth/oauth@local#1")

# Update holon
{:ok, updated} = KMS.update_holon("hln_abc123def456", %{
  payload: %{content: "Updated content..."},
  vital_signs: %{health: 0.9, stress: 0.1, energy: 0.8}
})

# Delete holon (cascades to edges, events, vectors)
:ok = KMS.delete_holon("hln_abc123def456")

# List holons
{:ok, holons} = KMS.list_holons(type: :knowledge, limit: 100)
```

#### 3.1.2 Relationships
```elixir
# Create edge
:ok = KMS.create_edge("hln_parent", "hln_child", "contains", weight: 1.0)

# Get direct children
{:ok, children} = KMS.get_children("hln_parent")

# Get all descendants (recursive CTE)
{:ok, descendants} = KMS.get_descendants("hln_parent")
```

#### 3.1.3 Search
```elixir
# Full-text search (FTS5)
{:ok, results} = KMS.search("OAuth2 authentication", limit: 10)

# Vector similarity search
{:ok, similar} = KMS.similarity_search(query_embedding,
  limit: 10,
  model: "voyage-3",
  threshold: 0.7
)

# Store embedding
:ok = KMS.store_embedding("hln_abc123", embedding_vector, model: "voyage-3")
```

#### 3.1.4 Analytics
```elixir
# Health report by type
{:ok, report} = KMS.health_report()
# => %{knowledge: %{count: 150, avg_health: 0.85}, ...}

# Entropy report (stale holons)
{:ok, stale} = KMS.entropy_report(threshold: 0.7)
# => [%{id: "hln_old", entropy: 0.82, days_stale: 45}, ...]

# Event statistics
{:ok, stats} = KMS.event_stats(days: 30)
# => [%{day: "2025-12-30", created: 15, updated: 42}, ...]

# Archive old events to Parquet
:ok = KMS.archive_events(days_old: 90)
```

#### 3.1.5 Swarm Operations
```elixir
# Extract portable swarm cell
{:ok, cell_path} = KMS.extract_swarm_cell("hln_root", "/tmp/cells/")
# => Creates self-contained SQLite with holon + descendants

# Merge swarm cell back
:ok = KMS.merge_swarm_cell("/tmp/cells/hln_root.db")
```

### 3.2 F# KMS API (`lib/cepaf/src/Cepaf.Knowledge/SharedKMS.fs`)

#### 3.2.1 CRUD Operations
```fsharp
// Get holon
let holon = SharedKMS.getHolon "hln_abc123"  // Option<Holon>
let holon = SharedKMS.getHolonByFqun "kms/l3/knowledge/..."

// List holons
let holons = SharedKMS.listHolons (Some Knowledge) 100

// Create holon
let newHolon = SharedKMS.createHolon "Auth Guide" Knowledge payload None

// Update vital signs
let success = SharedKMS.updateVitalSigns "hln_abc123"
  { Health = 0.9; Stress = 0.1; Energy = 0.8 }
```

#### 3.2.2 Search & Events
```fsharp
// Full-text search
let results = SharedKMS.search "OAuth2" 10

// Get children
let children = SharedKMS.getChildren "hln_parent"

// Log event
SharedKMS.logEvent "hln_abc123" "accessed" """{"user": "admin"}"""
```

#### 3.2.3 Analytics (DuckDB)
```fsharp
// Health report
let report = SharedKMS.getHealthReport()
// => seq<HealthReport>

// Entropy report
let stale = SharedKMS.getEntropyReport 0.7
// => seq<EntropyEntry>

// Event statistics
let stats = SharedKMS.getEventStats 30
// => seq<EventStats>
```

### 3.3 F# Advanced Modules

#### 3.3.1 Ingestor (TPL Dataflow Pipeline)
```fsharp
// 4-stage pipeline: Reader → Parser → Classifier → Writer
Ingestor.ingestDirectory "/docs/knowledge"
// Processes YAML frontmatter, classifies, stores as holons
```

#### 3.3.2 Gardener (Entropy Management)
```fsharp
// Calculate entropy for all holons
Gardener.recalculateEntropy()

// Entropy formula:
// S = clamp((dt × R_decay) / V_factor + Drift_git, 0.0, 1.0)
```

#### 3.3.3 OpenRouter (AI Integration)
```fsharp
// Auto-classify document
let classification = OpenRouter.autoClassifyAsync content

// Oracle consultation
let answer = OpenRouter.oracleConsultAsync query context

// Generate artifact
let doc = OpenRouter.generateArtifactAsync topic context template
```

---

## Level 4: UI Components & Integration Status

### 4.1 F# Cockpit UI Components (Material3.fs)

#### 4.1.1 TreeView (Hierarchical Browser)
```
┌─ TreeView ──────────────────────────────────┐
│ ▼ Root Holon                                │
│   ├─ ▶ Child 1                              │
│   ├─ ▼ Child 2                              │
│   │   ├─ Grandchild 1                       │
│   │   └─ Grandchild 2                       │
│   └─ ▶ Child 3                              │
│                                             │
│ Features:                                   │
│ • Recursive expansion/collapse              │
│ • Icon by holon type                        │
│ • Connector lines                           │
│ • Selection highlighting                    │
└─────────────────────────────────────────────┘
Status: ✅ Component ready, ⚠️ Not wired to KMS
```

#### 4.1.2 DataBrowser (Tabular View)
```
┌─ DataBrowser ───────────────────────────────────────────────┐
│ ID          │ Name            │ Type      │ Health │ Updated │
├─────────────┼─────────────────┼───────────┼────────┼─────────┤
│ hln_abc123  │ Auth Guide      │ knowledge │ 0.95   │ 2h ago  │
│ hln_def456  │ API Spec        │ artifact  │ 0.87   │ 1d ago  │
│ hln_ghi789  │ Deploy Process  │ process   │ 0.72   │ 5d ago  │
│                                                              │
│ Features: Sort, Filter, Paginate, Multi-select              │
└──────────────────────────────────────────────────────────────┘
Status: ✅ Component ready, ⚠️ Not wired to KMS
```

#### 4.1.3 SmartMetric (Health Dashboard)
```
┌─ SmartMetric ──────────────────────────────┐
│  Knowledge Holons                          │
│  ┌────────────────────────────────────┐    │
│  │ 156  ▲ 12%  ████████░░ 0.87       │    │
│  │      ↑↑↑↑↑↑↗↗↗→→↘                 │    │
│  └────────────────────────────────────┘    │
│                                            │
│ Features:                                  │
│ • Trend sparklines                         │
│ • Threshold indicators                     │
│ • Health color coding                      │
└────────────────────────────────────────────┘
Status: ✅ Component ready, ⚠️ Not wired to KMS
```

### 4.2 Prajna Bio-Holon Visualization (Prajna.fs)

```
┌─ Prajna Holon View ─────────────────────────────────────────┐
│                                                             │
│  ┌─────────────────┐     Lifecycle: ●Active                 │
│  │    ◉ Agent      │     ──────────────────                 │
│  │   ┌───────┐     │     Health:  ████████░░ 0.85           │
│  │   │ Core  │     │     Stress:  ██░░░░░░░░ 0.15           │
│  │   └───────┘     │     Energy:  ███████░░░ 0.72           │
│  │  ╱  │  ╲       │                                        │
│  │ ○   ○   ○      │     Membrane: Semi-permeable            │
│  │W1  W2  W3      │     Children: 3 workers                 │
│  └─────────────────┘                                        │
│                                                             │
│  States: Dormant → Awakening → Active → Stressed →          │
│          Healing → Apoptotic                                │
└─────────────────────────────────────────────────────────────┘
Status: ✅ Component ready, ⚠️ Not wired to KMS
```

### 4.3 Dashboard ViewModes

| ViewMode | Description | Status |
|----------|-------------|--------|
| `Dashboard` | Overview metrics grid | ✅ Ready |
| `NodeDetail` | Individual holon inspection | ✅ Ready |
| `AlarmCenter` | Health alerts & entropy warnings | ✅ Ready |
| `Topology` | Knowledge graph visualization | ✅ Ready |
| `Timeline` | Event history browser | ✅ Ready |
| `AiAssistant` | Oracle consultation interface | ✅ Ready |

### 4.4 Integration Status Matrix

| Component | KMS Wired | Route | Priority |
|-----------|-----------|-------|----------|
| Phoenix Controller | ❌ No | `/api/kms/*` | P1 |
| Phoenix LiveView | ❌ No | `/prajna/knowledge` | P1 |
| F# TreeView | ❌ No | (TUI) | P1 |
| F# DataBrowser | ❌ No | (TUI) | P1 |
| F# SmartMetric | ❌ No | (TUI) | P1 |
| Graphiti Integration | ❌ No | (Internal) | P1 |
| Runtime Holon Sync | ❌ No | (Internal) | P2 |

---

## Level 5: Implementation Details & Code Patterns

### 5.1 SQLite Schema (sqlite.ex)

```elixir
@schema """
-- Core holon storage
CREATE TABLE IF NOT EXISTS holons (
  id TEXT PRIMARY KEY,
  fqun TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index')),
  name TEXT NOT NULL,
  parent_id TEXT REFERENCES holons(id) ON DELETE SET NULL,
  genome TEXT NOT NULL DEFAULT '{}',
  vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
  membrane TEXT DEFAULT '{}',
  payload TEXT NOT NULL DEFAULT '{}',
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Graph relationships
CREATE TABLE IF NOT EXISTS holon_edges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
  target_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
  relation TEXT NOT NULL,
  weight REAL DEFAULT 1.0,
  metadata TEXT DEFAULT '{}',
  created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(source_id, target_id, relation)
);

-- Append-only event log
CREATE TABLE IF NOT EXISTS holon_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  holon_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload TEXT DEFAULT '{}',
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL DEFAULT 0,
  agent_id TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- FTS5 full-text search
CREATE VIRTUAL TABLE IF NOT EXISTS holons_fts USING fts5(
  id, name, payload,
  content='holons',
  content_rowid='rowid'
);

-- Auto-sync triggers
CREATE TRIGGER IF NOT EXISTS holons_ai AFTER INSERT ON holons BEGIN
  INSERT INTO holons_fts(id, name, payload) VALUES (new.id, new.name, new.payload);
END;

CREATE TRIGGER IF NOT EXISTS holons_au AFTER UPDATE ON holons BEGIN
  UPDATE holons_fts SET name = new.name, payload = new.payload WHERE id = new.id;
END;

CREATE TRIGGER IF NOT EXISTS holons_ad AFTER DELETE ON holons BEGIN
  DELETE FROM holons_fts WHERE id = old.id;
END;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_holons_type ON holons(type);
CREATE INDEX IF NOT EXISTS idx_holons_parent ON holons(parent_id);
CREATE INDEX IF NOT EXISTS idx_holons_updated ON holons(updated_at);
CREATE INDEX IF NOT EXISTS idx_edges_source ON holon_edges(source_id);
CREATE INDEX IF NOT EXISTS idx_edges_target ON holon_edges(target_id);
CREATE INDEX IF NOT EXISTS idx_events_holon ON holon_events(holon_id);
CREATE INDEX IF NOT EXISTS idx_events_time ON holon_events(hlc_physical);
"""

@pragmas """
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000;
PRAGMA mmap_size = 268435456;
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;
"""
```

### 5.2 DuckDB Analytics (analytics.ex)

```elixir
# Attach SQLite for cross-database queries
def attach_sqlite(conn, sqlite_path) do
  Duckdbex.query(conn, """
    ATTACH '#{sqlite_path}' AS holons_db (TYPE SQLITE, READ_ONLY)
  """)
end

# Health report aggregation
def health_report(duckdb_path, sqlite_path) do
  {:ok, conn} = Duckdbex.open(duckdb_path)
  attach_sqlite(conn, sqlite_path)

  query = """
  SELECT
    type,
    COUNT(*) as count,
    AVG(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as avg_health,
    AVG(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE)) as avg_stress,
    AVG(CAST(json_extract(vital_signs, '$.energy') AS DOUBLE)) as avg_energy,
    MIN(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as min_health,
    MAX(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as max_health
  FROM holons_db.holons
  GROUP BY type
  ORDER BY type
  """

  Duckdbex.query(conn, query)
end

# Entropy detection (stale holons)
def entropy_report(duckdb_path, sqlite_path, threshold) do
  query = """
  WITH entropy_calc AS (
    SELECT
      id, fqun, name, type,
      CAST(json_extract(vital_signs, '$.health') AS DOUBLE) as health,
      CAST(json_extract(vital_signs, '$.stress') AS DOUBLE) as stress,
      updated_at,
      -- Entropy formula: (1 - health) + stress + age_factor
      (1.0 - COALESCE(CAST(json_extract(vital_signs, '$.health') AS DOUBLE), 0.5)) +
      COALESCE(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE), 0.0) +
      LEAST(1.0, (julianday('now') - julianday(updated_at)) / 30.0) as entropy
    FROM holons_db.holons
  )
  SELECT id, fqun, name, type, health, stress, entropy, updated_at
  FROM entropy_calc
  WHERE entropy >= #{threshold}
  ORDER BY entropy DESC
  LIMIT 100
  """

  Duckdbex.query(conn, query)
end

# Archive to Parquet
def archive_events(duckdb_path, sqlite_path, archive_dir, days_old) do
  timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
  parquet_path = Path.join(archive_dir, "events_#{timestamp}.parquet")

  query = """
  COPY (
    SELECT * FROM holons_db.holon_events
    WHERE datetime(created_at) < datetime('now', '-#{days_old} days')
  ) TO '#{parquet_path}' (FORMAT PARQUET, COMPRESSION ZSTD)
  """

  Duckdbex.query(conn, query)
end
```

### 5.3 Vector Search (vectors.ex)

```elixir
# Store embedding
def store_embedding(holon_id, embedding, opts \\ []) do
  model = Keyword.get(opts, :model, "voyage-3")
  chunk_index = Keyword.get(opts, :chunk_index, 0)
  dimensions = length(embedding)
  embedding_json = Jason.encode!(embedding)

  query = """
  INSERT INTO holon_vectors (holon_id, model, dimensions, embedding, chunk_index)
  VALUES (?1, ?2, ?3, ?4, ?5)
  ON CONFLICT (holon_id, model, chunk_index) DO UPDATE SET
    dimensions = excluded.dimensions,
    embedding = excluded.embedding,
    created_at = datetime('now')
  """

  Exqlite.Sqlite3.execute(conn, query, [holon_id, model, dimensions, embedding_json, chunk_index])
end

# Cosine similarity search
def similarity_search(query_embedding, opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)
  model = Keyword.get(opts, :model, "voyage-3")
  threshold = Keyword.get(opts, :threshold, 0.0)

  # Get all embeddings
  {:ok, embeddings} = get_all_embeddings(model)

  # Compute similarities
  query_norm = vector_norm(query_embedding)

  results = embeddings
    |> Enum.map(fn %{holon_id: id, embedding: emb} ->
      %{holon_id: id, similarity: cosine_similarity(query_embedding, emb, query_norm)}
    end)
    |> Enum.filter(fn %{similarity: sim} -> sim >= threshold end)
    |> Enum.sort_by(& &1.similarity, :desc)
    |> Enum.take(limit)

  # Enrich with holon data
  Enum.map(results, fn %{holon_id: id, similarity: sim} ->
    {:ok, holon} = KMS.get_holon(id)
    %{holon_id: id, similarity: sim, holon: holon}
  end)
end

# Cosine similarity
defp cosine_similarity(vec1, vec2, norm1) do
  dot = Enum.zip(vec1, vec2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
  norm2 = vector_norm(vec2)

  if norm1 == 0 or norm2 == 0, do: 0.0, else: dot / (norm1 * norm2)
end

defp vector_norm(vec) do
  vec |> Enum.reduce(0.0, fn x, acc -> acc + x * x end) |> :math.sqrt()
end
```

### 5.4 F# SharedKMS Patterns

```fsharp
// Connection management
let private getSqliteConnection () =
    let conn = new SqliteConnection(getSqliteConnectionString())
    conn.Open()
    conn

let private getDuckDBConnection () =
    let conn = new DuckDBConnection(getDuckDBConnectionString())
    conn.Open()
    // Attach SQLite
    use cmd = conn.CreateCommand()
    cmd.CommandText <- $"ATTACH IF NOT EXISTS '{getSqlitePath()}' AS holons_db (TYPE SQLITE, READ_ONLY)"
    cmd.ExecuteNonQuery() |> ignore
    conn

// Holon CRUD with Dapper
let getHolon (holonId: string) : Holon option =
    use conn = getSqliteConnection()
    let sql = "SELECT * FROM holons WHERE id = @Id"
    let result = conn.QueryFirstOrDefault<Holon>(sql, {| Id = holonId |})
    if isNull (box result) then None else Some result

let createHolon (name: string) (holonType: HolonType) (payload: string) (parentId: string option) : Holon =
    use conn = getSqliteConnection()

    let holonId = $"hln_{Guid.NewGuid().ToString(\"N\").Substring(0, 13)}"
    let now = DateTime.UtcNow.ToString("o")
    let hlcPhysical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L
    let fqun = $"kms/l3/{holonType}/default/{name}@fsharp#{holonId}"

    let holon = {
        Id = holonId
        Fqun = fqun
        Type = holonType.ToString()
        Name = name
        ParentId = parentId
        Genome = """{"schema_version":"1.0.0"}"""
        VitalSigns = """{"health":1.0,"stress":0.0,"energy":1.0}"""
        Membrane = "{}"
        Payload = payload
        HlcPhysical = hlcPhysical
        HlcLogical = 0L
        CreatedAt = now
        UpdatedAt = now
    }

    let sql = """
        INSERT INTO holons (id, fqun, type, name, parent_id, genome, vital_signs,
                           membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
        VALUES (@Id, @Fqun, @Type, @Name, @ParentId, @Genome, @VitalSigns,
                @Membrane, @Payload, @HlcPhysical, @HlcLogical, @CreatedAt, @UpdatedAt)
    """

    conn.Execute(sql, holon) |> ignore
    holon

// DuckDB Analytics
let getHealthReport () : HealthReport seq =
    use conn = getDuckDBConnection()

    let sql = """
        SELECT
            type,
            COUNT(*) as count,
            AVG(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as avg_health,
            AVG(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE)) as avg_stress,
            AVG(CAST(json_extract(vital_signs, '$.energy') AS DOUBLE)) as avg_energy,
            MIN(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as min_health,
            MAX(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as max_health
        FROM holons_db.holons
        GROUP BY type
        ORDER BY type
    """

    conn.Query<HealthReport>(sql)
```

### 5.5 Data Flow Patterns

```
WRITE PATH (OLTP - SQLite):
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│ Create  │───►│ SQLite  │───►│ FTS5    │───►│ Events  │
│ Holon   │    │ Insert  │    │ Trigger │    │ Log     │
└─────────┘    └─────────┘    └─────────┘    └─────────┘

READ PATH (Mixed):
┌─────────┐    ┌─────────┐
│ Get     │───►│ SQLite  │ (Single holon lookup)
│ Holon   │    │ Query   │
└─────────┘    └─────────┘

┌─────────┐    ┌─────────┐    ┌─────────┐
│ Search  │───►│ SQLite  │───►│ FTS5    │ (Full-text search)
│ Query   │    │         │    │ Match   │
└─────────┘    └─────────┘    └─────────┘

┌─────────┐    ┌─────────┐    ┌─────────┐
│ Vector  │───►│ SQLite  │───►│ Elixir  │ (Cosine similarity)
│ Search  │    │ Vectors │    │ Compute │
└─────────┘    └─────────┘    └─────────┘

ANALYTICS PATH (OLAP - DuckDB):
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│ Health  │───►│ DuckDB  │───►│ ATTACH  │───►│ JSON    │
│ Report  │    │ Query   │    │ SQLite  │    │ Agg     │
└─────────┘    └─────────┘    └─────────┘    └─────────┘

ARCHIVAL PATH:
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Archive │───►│ DuckDB  │───►│ Parquet │ (ZSTD compressed)
│ Events  │    │ Export  │    │ Files   │
└─────────┘    └─────────┘    └─────────┘

SWARM PATH:
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Extract │───►│ SQLite  │───►│ Portable│ (Self-contained DB)
│ Cell    │    │ Export  │    │ .db     │
└─────────┘    └─────────┘    └─────────┘
```

---

## Appendix A: Git Commits

| Commit | Description | Files |
|--------|-------------|-------|
| `4bea016ea` | feat(kms): Add Fractal Holonic KMS with SQLite + DuckDB | kms.ex, sqlite.ex, analytics.ex, SharedKMS.fs, SharedPaths.fs |
| `831fdd6e8` | feat(kms): Add vector search support | vectors.ex |

## Appendix B: Dependencies

### Elixir (mix.exs)
```elixir
{:exqlite, "~> 0.23"},
{:duckdbex, "~> 0.3"},
```

### F# (Cepaf.Knowledge.fsproj)
```xml
<PackageReference Include="Dapper" Version="2.1.35" />
<PackageReference Include="DuckDB.NET.Data.Full" Version="1.4.3" />
<PackageReference Include="Microsoft.Data.Sqlite" Version="9.0.0" />
<PackageReference Include="YamlDotNet" Version="16.3.0" />
<PackageReference Include="System.Threading.Tasks.Dataflow" Version="8.0.0" />
```

## Appendix C: Next Steps Priority Matrix

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P1 | Create Phoenix KMS Controller | Medium | High |
| P1 | Create KMS LiveView at /prajna/knowledge | Medium | High |
| P1 | Wire F# TreeView to SharedKMS | Low | High |
| P1 | Integrate Graphiti → KMS | Medium | High |
| P2 | Add GraphQL API | Medium | Medium |
| P2 | Runtime Holon → KMS sync | Medium | Medium |
| P2 | Auto-embedding on create | Low | Medium |
| P3 | DuckDB vector search | High | Medium |
| P3 | Swarm federation | High | Low |
| P3 | AI gardening automation | Medium | Low |

---

**Document End**
