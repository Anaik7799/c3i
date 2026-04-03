# Database Architecture Comprehensive Analysis

**Date**: 2026-01-17 12:00 CEST
**Author**: Claude Opus 4.5
**Version**: 21.3.0-SIL6
**STAMP**: SC-DB-*, SC-HOLON-*, SC-REG-*, SC-ASH3-*

---

## Executive Summary

This document provides a complete analysis of all databases used across the Indrajaal Elixir application and CEPAF F# infrastructure. It covers runtime access control mechanisms, data purposes, sharing requirements, and identifies architectural patterns for single-entity vs multi-entity access.

**Key Finding**: The DuckDB file locking issue in tests is caused by multiple processes attempting to access a single-writer database. This analysis provides the architectural guidance for proper database access patterns.

---

## 1. Complete Database Inventory

### 1.1 Database Stack Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL DATABASE ARCHITECTURE                           │
│                         Version 21.3.0-SIL6                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐     │
│  │ PostgreSQL  │   │   SQLite    │   │   DuckDB    │   │ TimescaleDB │     │
│  │     17      │   │     3       │   │   (F#)      │   │ (Extension) │     │
│  ├─────────────┤   ├─────────────┤   ├─────────────┤   ├─────────────┤     │
│  │ Business    │   │ Holon KMS   │   │ Immutable   │   │ Time-Series │     │
│  │ Domain Data │   │ State       │   │ Register    │   │ Analytics   │     │
│  │ (151+ Ash)  │   │ (per holon) │   │ + History   │   │ (Hypertable)│     │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘     │
│         │                 │                 │                 │             │
│         │    ELIXIR       │    ELIXIR       │      F#         │   ELIXIR    │
│         │                 │                 │                 │             │
│  ┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐     │
│  │Indrajaal.   │   │Indrajaal.   │   │Cepaf.       │   │TimescaleDB  │     │
│  │Repo         │   │KMSRepo      │   │Smriti.*     │   │Integration  │     │
│  │(AshPostgres)│   │(Ecto.SQLite)│   │(DuckDB.NET) │   │(PostgreSQL) │     │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘     │
│                                                                              │
│  ┌─────────────┐                                                            │
│  │ Oban Queue  │   Background job processing via PostgreSQL                 │
│  │ (PostgreSQL)│   Queues: default(10), events(50), video(5)               │
│  └─────────────┘                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Database Technology Matrix

| Database | Version | Adapter | Language | Port/Path | Pool Size |
|----------|---------|---------|----------|-----------|-----------|
| PostgreSQL | 17.x | AshPostgres.DataLayer | Elixir | 5433 | 20 dev / 10 prod |
| SQLite | 3.x | Ecto.Adapters.SQLite3 | Elixir | `data/holons/{id}/` | 1 per holon |
| DuckDB | 1.2.0 | DuckDB.NET.Data | F# | `data/holons/*.duckdb` | 1 (single writer) |
| TimescaleDB | 2.x | PostgreSQL extension | Elixir | Same as PostgreSQL | Shared with PG |
| Oban | 2.x | PostgreSQL backend | Elixir | PostgreSQL tables | N/A (queue) |

---

## 2. Detailed Database Analysis

### 2.1 PostgreSQL (Primary Business Database)

#### Configuration
```elixir
# config/runtime.exs
config :indrajaal, Indrajaal.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5433")),
  database: System.get_env("POSTGRES_DB", "indrajaal_#{config_env()}"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
  queue_target: 5000,
  queue_interval: 5000
```

#### Repository Implementation
```elixir
# lib/indrajaal/repo.ex
defmodule Indrajaal.Repo do
  use AshPostgres.Repo, otp_app: :indrajaal

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", "pg_trgm", "btree_gist", "pgcrypto"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
```

#### Purpose
- **151+ Ash Resources**: All business domain entities
- **Domains**: Accounts, Alarms, Devices, Sites, Access Control, Video, Analytics
- **ACID Transactions**: Full transactional support
- **Multi-tenant**: Tenant isolation via actor policies

#### Access Control Mechanism
```elixir
# Per SC-ASH3-001: Access tenant via query.tenant (NOT context)
# Per SC-ASH3-004: Pass actor to for_update

# Example Resource Policy
policies do
  policy action_type(:read) do
    authorize_if expr(tenant_id == ^actor(:tenant_id))
  end

  policy action_type(:create) do
    authorize_if actor_present()
    authorize_if expr(tenant_id == ^actor(:tenant_id))
  end

  policy action_type(:update) do
    authorize_if relates_to_actor_via(:created_by_id)
  end
end

# Actor-based changes
change set_attribute(:created_by_id, actor(:id))
change set_attribute(:updated_by_id, actor(:id))
```

#### Concurrency Model
- **Connection Pool**: 20 connections (dev), 10 connections (prod)
- **MVCC**: Multi-Version Concurrency Control for reads
- **Advisory Locks**: For distributed coordination
- **Timeout**: 30s default query timeout

---

### 2.2 SQLite (Holon KMS State)

#### Configuration
```elixir
# lib/indrajaal/kms_repo.ex
defmodule Indrajaal.KMSRepo do
  use Ecto.Repo,
    otp_app: :indrajaal,
    adapter: Ecto.Adapters.SQLite3
end

# config/config.exs
config :indrajaal, Indrajaal.KMSRepo,
  database: "data/holons/kms.sqlite",
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory
```

#### Purpose (Per SC-HOLON-001 to SC-HOLON-020)
- **Holon Real-Time State**: Current state of each holon
- **Knowledge Graph**: KMS semantic relationships
- **Version Vectors**: Conflict-free replication support
- **Portable State**: Single file = entire holon state

#### Access Control Mechanism
```
FILESYSTEM ISOLATION (Not application-level)

data/holons/
├── holon-001/
│   └── kms.sqlite    ← Only holon-001 processes access this
├── holon-002/
│   └── kms.sqlite    ← Only holon-002 processes access this
└── holon-003/
    └── kms.sqlite    ← Only holon-003 processes access this
```

**Key Constraints (AOR-HOLON-*):**
- AOR-HOLON-001: ALL holon real-time state MUST be stored in SQLite
- AOR-HOLON-003: Holon state MUST be fully portable via single file copy
- AOR-HOLON-008: Each holon maintains isolated SQLite files
- AOR-HOLON-009: SQLite is ONLY authoritative source of holon state

#### Concurrency Model
- **Single Writer**: One process per holon SQLite file
- **WAL Mode**: Write-Ahead Logging for crash safety
- **No Shared Access**: Complete filesystem isolation
- **Version Vectors**: For replication conflict resolution

---

### 2.3 DuckDB (Immutable Register & History)

#### Configuration (F#)
```xml
<!-- lib/cepaf/src/Cepaf.Smriti.Semantic/Cepaf.Smriti.Semantic.fsproj -->
<PackageReference Include="DuckDB.NET.Data" Version="1.2.0" />
```

```fsharp
// Cepaf.Smriti.Semantic/DuckDBStore.fs
let openConnection (path: string) =
    let conn = new DuckDBConnection($"Data Source={path}")
    conn.Open()
    conn
```

#### Elixir Integration (Prajna ImmutableState)
```elixir
# lib/indrajaal/cockpit/prajna/immutable_state.ex
defmodule Indrajaal.Cockpit.Prajna.ImmutableState do
  use GenServer

  @duckdb_path Application.compile_env(:indrajaal, :prajna_register_path,
    "/tmp/indrajaal_prajna_register.duckdb")

  def init(opts) do
    case open_duckdb(@duckdb_path) do
      {:ok, conn} -> {:ok, %{conn: conn, ...}}
      {:error, reason} -> {:stop, {:init_failed, reason}}
    end
  end
end
```

#### Purpose

**A. Immutable Register (Global)**
- **Audit Trail**: All state mutations across all holons
- **Ed25519 Signatures**: Cryptographic block signing
- **SHA3-256 Hash Chain**: Integrity verification
- **Append-Only**: No deletions or modifications ever

**B. Holon Evolution History (Per Holon)**
- **Lineage Tracking**: Complete evolution record
- **Analytics Queries**: OLAP-optimized columnar storage
- **Version History**: Every state change recorded

#### Access Control Mechanism

```
CRYPTOGRAPHIC + SINGLE-WRITER

┌─────────────────────────────────────────────────────────────────┐
│                  DUCKDB ACCESS ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐                                       │
│  │   ImmutableState     │  ← SINGLE GenServer (Elixir)          │
│  │   GenServer          │     Exclusive file access             │
│  └──────────┬───────────┘                                       │
│             │                                                    │
│             │ append_block(data, signature)                      │
│             ▼                                                    │
│  ┌──────────────────────┐                                       │
│  │  prajna_register     │  ← DuckDB File                        │
│  │  .duckdb             │     FILE LOCK (OS-level)              │
│  └──────────────────────┘                                       │
│                                                                  │
│  VERIFICATION:                                                   │
│  ├─ Ed25519 signature on every block                            │
│  ├─ SHA3-256 hash chain linking blocks                          │
│  ├─ Capability tokens for privileged operations                 │
│  └─ Reed-Solomon error correction                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Constraints (AOR-REG-*):**
- AOR-REG-001: ALL state mutations via immutable register
- AOR-REG-002: Verify hash chain integrity on every startup
- AOR-REG-003: Every block MUST be Ed25519 signed
- AOR-REG-006: Verify capability token before privileged actions

#### Concurrency Model
- **SINGLE WRITER ONLY**: DuckDB does not support concurrent connections
- **File Locking**: OS-level exclusive lock on .duckdb file
- **Append-Only**: No update/delete operations
- **Read Replicas**: Can create read-only copies for analytics

**THIS IS THE ROOT CAUSE OF THE TEST FAILURE:**
```
Multiple beam.smp processes trying to open:
  /tmp/indrajaal_test_prajna_register.duckdb

DuckDB Error: "Conflicting lock is held by PID XXXXX"
```

---

### 2.4 TimescaleDB (Time-Series Analytics)

#### Configuration
```elixir
# Integrated as PostgreSQL extension
# No separate configuration needed

# lib/indrajaal/alarms/timescaledb_integration.ex
defmodule Indrajaal.Alarms.TimescaleDBIntegration do
  @moduledoc """
  TimescaleDB integration for alarm time-series data.
  Provides hypertable creation and time-based queries.
  """
end
```

#### Purpose
- **Alarm Events**: High-volume alarm time-series
- **Authentication Logs**: Login/logout events
- **Authorization Logs**: Permission checks
- **Metrics Data**: System performance metrics
- **Real-Time Analytics**: Sub-10ms query response

#### Hypertables
```sql
-- Created via migrations
SELECT create_hypertable('alarm_events', 'triggered_at');
SELECT create_hypertable('authentication_logs', 'timestamp');
SELECT create_hypertable('authorization_logs', 'timestamp');
SELECT create_hypertable('property_test_metrics', 'recorded_at');
```

#### Access Control Mechanism
- Same as PostgreSQL (Ash policies, actor-based)
- Tenant isolation via `tenant_id` column
- Time-based partitioning for performance

#### Concurrency Model
- Same as PostgreSQL (MVCC, connection pool)
- Automatic chunk management
- Compression policies for old data

---

### 2.5 Oban (Background Job Queue)

#### Configuration
```elixir
# config/config.exs
config :indrajaal, Oban,
  repo: Indrajaal.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    events: 50,
    video: 5
  ],
  notifier: Oban.Notifiers.Postgres
```

#### Purpose
- **Async Processing**: Non-blocking operations
- **Event Handling**: 50 workers for event queue
- **Video Processing**: 5 workers for video tasks
- **Job Persistence**: Survives restarts

#### Access Control Mechanism
- **Unique Keys**: Prevent duplicate jobs
- **Queue Isolation**: Separate queues per domain
- **Worker Limits**: Per-queue concurrency control

#### Concurrency Model
- **PostgreSQL Backend**: Row-level locking
- **Multiple Workers**: Concurrent job processing
- **Transactional**: Jobs tied to database transactions

---

## 3. Access Control Matrix

### 3.1 Runtime Access Control Summary

| Database | Auth Method | Isolation Level | Actor Required | STAMP |
|----------|-------------|-----------------|----------------|-------|
| PostgreSQL | Ash Policies | Tenant + Actor | YES | SC-ASH3-001, SC-ASH3-004 |
| SQLite KMS | Filesystem | Per-Holon File | NO (implicit) | SC-HOLON-008 |
| DuckDB Register | Cryptographic | Single Process | YES (signature) | SC-REG-003 |
| DuckDB History | Append-Only | Per-Holon File | NO (implicit) | SC-HOLON-019 |
| TimescaleDB | Ash Policies | Tenant | YES | Same as PostgreSQL |
| Oban | Queue Locks | Queue Name | NO | N/A |

### 3.2 Actor Pattern Implementation

```elixir
# CORRECT: Pass actor for all Ash operations
Alarms.AlarmEvent.list_alarm_events(
  %{filter: %{tenant_id: %{eq: tenant_id}}},
  actor: %{tenant_id: tenant_id, is_system: true}
)

# CORRECT: Actor in changeset operations
Ash.Changeset.for_update(resource, :update, params, actor: actor)

# INCORRECT: Missing actor (causes Ash.Error.Forbidden)
Alarms.AlarmEvent.list_alarm_events(%{filter: %{...}})
```

---

## 4. Shared vs Single-Entity Access

### 4.1 Access Pattern Classification

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DATABASE ACCESS PATTERN MATRIX                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   SHARED ACCESS (Multi-Concurrent)       SINGLE-ENTITY (Exclusive)          │
│   ════════════════════════════════       ══════════════════════════         │
│                                                                              │
│   ┌─────────────────────────────┐       ┌─────────────────────────────┐    │
│   │      PostgreSQL             │       │    SQLite (per holon)       │    │
│   │  ┌─────┐ ┌─────┐ ┌─────┐   │       │  ┌─────────────────────┐    │    │
│   │  │ C1  │ │ C2  │ │ C3  │   │       │  │   Holon Process     │    │    │
│   │  └──┬──┘ └──┬──┘ └──┬──┘   │       │  │   (exclusive)       │    │    │
│   │     │       │       │      │       │  └──────────┬──────────┘    │    │
│   │     └───────┼───────┘      │       │             │               │    │
│   │             ▼              │       │             ▼               │    │
│   │     ┌─────────────┐        │       │     ┌─────────────┐         │    │
│   │     │  Pool (20)  │        │       │     │ kms.sqlite  │         │    │
│   │     │  MVCC       │        │       │     │ (WAL mode)  │         │    │
│   │     └─────────────┘        │       │     └─────────────┘         │    │
│   └─────────────────────────────┘       └─────────────────────────────┘    │
│                                                                              │
│   ┌─────────────────────────────┐       ┌─────────────────────────────┐    │
│   │      TimescaleDB            │       │    DuckDB Register          │    │
│   │  (Same as PostgreSQL)       │       │  ┌─────────────────────┐    │    │
│   │  Hypertable partitions      │       │  │  ImmutableState     │    │    │
│   │  allow parallel queries     │       │  │  GenServer          │    │    │
│   └─────────────────────────────┘       │  │  (SINGLE PROCESS)   │    │    │
│                                          │  └──────────┬──────────┘    │    │
│   ┌─────────────────────────────┐       │             │               │    │
│   │      Oban Queue             │       │             ▼               │    │
│   │  ┌─────┐ ┌─────┐ ┌─────┐   │       │     ┌─────────────┐         │    │
│   │  │ W1  │ │ W2  │ │ W3  │   │       │     │  .duckdb    │         │    │
│   │  └──┬──┘ └──┬──┘ └──┬──┘   │       │     │  FILE LOCK  │         │    │
│   │     │       │       │      │       │     └─────────────┘         │    │
│   │     └───────┼───────┘      │       └─────────────────────────────┘    │
│   │             ▼              │                                          │
│   │     ┌─────────────┐        │       ┌─────────────────────────────┐    │
│   │     │  Job Queue  │        │       │    DuckDB History           │    │
│   │     │  (PG locks) │        │       │  (per holon, append-only)   │    │
│   │     └─────────────┘        │       │  Same pattern as Register   │    │
│   └─────────────────────────────┘       └─────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 State Sharing Requirements

| State Type | Must Share? | Database | Reason |
|------------|-------------|----------|--------|
| User Accounts | YES | PostgreSQL | Multi-user authentication |
| Tenant Data | YES | PostgreSQL | Business operations |
| Alarm Events | YES | PostgreSQL + TimescaleDB | Real-time monitoring |
| Holon KMS State | NO | SQLite | Per-holon isolation |
| Audit Trail | YES (writes) | DuckDB Register | Compliance logging |
| Evolution History | NO | DuckDB History | Per-holon lineage |
| Background Jobs | YES | Oban/PostgreSQL | Worker distribution |
| Session Cache | YES | (Future Redis) | Session sharing |

### 4.3 Single-Entity Access Requirements

| Component | Why Single-Entity? | Implementation |
|-----------|-------------------|----------------|
| SQLite per Holon | Holon state sovereignty | Filesystem isolation |
| DuckDB Register | File locking limitation | ImmutableState GenServer |
| DuckDB History | Append-only lineage | Per-holon F# service |

---

## 5. Architectural Patterns

### 5.1 PostgreSQL Multi-Tenant Pattern

```elixir
# All 151+ resources follow this pattern
defmodule Indrajaal.Alarms.AlarmEvent do
  use Indrajaal.BaseResource

  postgres do
    table "alarm_events"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :tenant_id, :uuid, allow_nil?: false
    # ... other attributes
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end
  end
end
```

### 5.2 SQLite Holon Isolation Pattern

```elixir
# Each holon gets its own SQLite file
defmodule Indrajaal.KMS.HolonState do
  def get_repo(holon_id) do
    path = "data/holons/#{holon_id}/kms.sqlite"

    # Dynamic repo per holon
    {:ok, pid} = Indrajaal.KMSRepo.start_link(database: path)
    pid
  end
end
```

### 5.3 DuckDB Single-Writer Pattern

```elixir
# CRITICAL: Only ONE process can access DuckDB file
defmodule Indrajaal.Cockpit.Prajna.ImmutableState do
  use GenServer

  # Singleton pattern - only one instance allowed
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # All writes go through this single GenServer
  def append_block(data, signature) do
    GenServer.call(__MODULE__, {:append, data, signature})
  end

  # File is opened once and held by this process
  def init(opts) do
    case DuckDB.open(opts[:path]) do
      {:ok, conn} -> {:ok, %{conn: conn}}
      {:error, _} = err -> {:stop, err}
    end
  end
end
```

### 5.4 Test Isolation Pattern (FIX FOR DUCKDB ISSUE)

```elixir
# test/support/duckdb_test_helper.ex
defmodule Indrajaal.DuckDBTestHelper do
  @moduledoc """
  Ensures DuckDB tests use isolated files per test process.
  """

  def unique_duckdb_path do
    # Each test gets unique file
    "/tmp/indrajaal_test_#{:erlang.unique_integer([:positive])}.duckdb"
  end

  def setup_isolated_register(context) do
    path = unique_duckdb_path()

    # Override application config for this test
    Application.put_env(:indrajaal, :prajna_register_path, path)

    on_exit(fn ->
      # Cleanup after test
      File.rm(path)
      File.rm("#{path}.wal")
    end)

    Map.put(context, :duckdb_path, path)
  end
end
```

---

## 6. STAMP Constraints by Database

### 6.1 PostgreSQL Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-DB-001 | Use BaseResource for all resources | Code review |
| SC-DB-005 | uuid_primary_key :id | Schema validation |
| SC-DB-012 | create_if_not_exists indexes | Migration check |
| SC-ASH3-001 | Access tenant via query.tenant | Ash policies |
| SC-ASH3-004 | Pass actor to for_update | Runtime check |

### 6.2 SQLite Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-HOLON-001 | Real-time state in SQLite | Architecture |
| SC-HOLON-003 | Portable via single file copy | Design |
| SC-HOLON-004 | Version vectors for replication | Implementation |
| SC-HOLON-008 | Isolated files per holon | Filesystem |
| SC-HOLON-009 | SQLite is authoritative source | Architecture |

### 6.3 DuckDB Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-HOLON-002 | Evolution history in DuckDB | Architecture |
| SC-HOLON-007 | Analytics via DuckDB | Query layer |
| SC-HOLON-011 | Complete lineage without gaps | Append-only |
| SC-HOLON-019 | Append-only immutable | No DELETE/UPDATE |
| SC-REG-001 | All mutations via register | Single GenServer |
| SC-REG-002 | Hash chain integrity on startup | Verification |
| SC-REG-003 | Ed25519 signature per block | Cryptographic |

---

## 7. Operational Recommendations

### 7.1 DuckDB Test Isolation Fix

**Problem**: Multiple test processes fighting for same DuckDB file lock.

**Solution**:
```elixir
# test/test_helper.exs
# Generate unique DuckDB path per test run
test_duckdb_path = "/tmp/indrajaal_test_#{System.system_time(:millisecond)}.duckdb"
Application.put_env(:indrajaal, :prajna_register_path, test_duckdb_path)

# Cleanup on exit
System.at_exit(fn _ ->
  File.rm(test_duckdb_path)
  File.rm("#{test_duckdb_path}.wal")
end)
```

### 7.2 Connection Pool Sizing

| Environment | PostgreSQL Pool | Recommendation |
|-------------|----------------|----------------|
| Development | 20 | Sufficient for local |
| Test | 10 | Reduce for parallel tests |
| Production | 10-50 | Scale with load |

### 7.3 Monitoring Queries

```sql
-- PostgreSQL connection usage
SELECT count(*) FROM pg_stat_activity WHERE datname = 'indrajaal_prod';

-- TimescaleDB chunk info
SELECT * FROM timescaledb_information.chunks
WHERE hypertable_name = 'alarm_events';

-- Oban job status
SELECT state, count(*) FROM oban_jobs GROUP BY state;
```

---

## 8. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  USER REQUEST                                                                │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────┐    actor: %{tenant_id: ..., user_id: ...}                  │
│  │   Phoenix   │◄──────────────────────────────────────────┐                │
│  │   Router    │                                           │                │
│  └──────┬──────┘                                           │                │
│         │                                                   │                │
│         ├──────────────────┬──────────────────┐            │                │
│         ▼                  ▼                  ▼            │                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │                │
│  │ Ash Domain  │    │ Prajna C3I  │    │ Oban Worker │    │                │
│  │ (Business)  │    │ (Control)   │    │ (Async)     │    │                │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    │                │
│         │                  │                  │            │                │
│         │                  │                  │            │                │
│  ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐    │                │
│  │             │    │             │    │             │    │                │
│  │ PostgreSQL  │    │   DuckDB    │    │ PostgreSQL  │    │                │
│  │ (Tenant     │    │ (Immutable  │    │ (Job Queue) │    │                │
│  │  Isolated)  │    │  Register)  │    │             │    │                │
│  │             │    │             │    │             │    │                │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │             │    │                │
│  │ │ Actor   │ │    │ │Ed25519  │ │    │             │    │                │
│  │ │ Policy  │ │    │ │Signature│ │    │             │    │                │
│  │ └─────────┘ │    │ └─────────┘ │    │             │    │                │
│  └─────────────┘    └─────────────┘    └─────────────┘    │                │
│                            │                               │                │
│                            │ append_block()                │                │
│                            ▼                               │                │
│                     ┌─────────────┐                        │                │
│                     │ImmutableState│◄───────────────────────┘               │
│                     │ GenServer    │  (SINGLE WRITER)                       │
│                     └──────┬───────┘                                        │
│                            │                                                 │
│                            ▼                                                 │
│                     ┌─────────────┐                                         │
│                     │ .duckdb     │                                         │
│                     │ FILE LOCK   │                                         │
│                     └─────────────┘                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Summary

### 9.1 Key Takeaways

1. **PostgreSQL** is the primary multi-tenant database with Ash policy-based access control
2. **SQLite** provides per-holon isolated state storage
3. **DuckDB** requires SINGLE-WRITER access via GenServer gateway
4. **TimescaleDB** extends PostgreSQL for time-series analytics
5. **Oban** uses PostgreSQL for reliable job queue persistence

### 9.2 Access Control Summary

| Database | Control Type | Sharing | STAMP |
|----------|-------------|---------|-------|
| PostgreSQL | Actor + Tenant Policies | Multi | SC-ASH3-* |
| SQLite | Filesystem Isolation | Single | SC-HOLON-* |
| DuckDB | Cryptographic + File Lock | Single | SC-REG-* |
| TimescaleDB | Actor + Tenant Policies | Multi | SC-ASH3-* |
| Oban | Queue Locks | Multi | N/A |

### 9.3 Action Items

1. **FIX**: DuckDB test isolation (unique paths per test)
2. **VERIFY**: All Ash queries pass actor
3. **MONITOR**: PostgreSQL connection pool usage
4. **DOCUMENT**: Holon SQLite file locations

---

## References

- CLAUDE.md Section 1.0 (Axiom Ω₇ Holon State Sovereignty)
- CLAUDE.md Section 9.0 (AOR-HOLON-001 to AOR-HOLON-020)
- CLAUDE.md Section 9.0 (AOR-REG-001 to AOR-REG-012)
- docs/architecture/HOLON_IMMUTABLE_REGISTER.md
- docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md
