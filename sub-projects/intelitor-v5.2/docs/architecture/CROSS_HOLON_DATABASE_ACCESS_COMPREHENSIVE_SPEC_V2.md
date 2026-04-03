# Cross-Holon Database Access Comprehensive Specification v2.0
## Unified Elixir/F# Database Architecture with Zenoh Bridge
### Version 2.0.0-SIL6 | 2026-01-17

---

## Executive Summary

This specification defines the comprehensive architecture for holon-specific database access
in the Indrajaal biomorphic organism. Each holon (Elixir or F#) maintains its own isolated
SQLite and DuckDB databases with direct high-performance library access. Cross-holon
communication is exclusively via Zenoh pub/sub messaging.

**Key Principles**:
1. **Isolation**: Each holon owns its databases - no shared state
2. **Direct Access**: Native libraries for maximum performance
3. **Zenoh Bridge**: All cross-holon communication via Zenoh
4. **Concurrency**: OCC with version vectors, no locking
5. **Transaction Semantics**: Full ACID for local, 2PC for distributed
6. **Scalability**: Horizontal scaling via holon replication

---

## 1.0 Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          INDRAJAAL BIOMORPHIC ORGANISM                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         ELIXIR RUNTIME                                  │ │
│  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌───────────────┐ │ │
│  │  │ ex:l3:kms:srv:main   │  │ ex:l3:grd:agt:guard  │  │ ex:l4:snt:... │ │ │
│  │  ├──────────────────────┤  ├──────────────────────┤  ├───────────────┤ │ │
│  │  │ state.sqlite         │  │ state.sqlite         │  │ state.sqlite  │ │ │
│  │  │ analytics.duckdb     │  │ analytics.duckdb     │  │ analytics...  │ │ │
│  │  │ history.duckdb       │  │ history.duckdb       │  │ history...    │ │ │
│  │  │ vectors.sqlite       │  │ vectors.sqlite       │  │ vectors...    │ │ │
│  │  │ register.duckdb      │  │ register.duckdb      │  │ register...   │ │ │
│  │  │ cache.sqlite         │  │ cache.sqlite         │  │ cache...      │ │ │
│  │  └──────────┬───────────┘  └──────────┬───────────┘  └───────┬───────┘ │ │
│  │             │                         │                       │         │ │
│  │             │ Exqlite/Duckdbex        │ Exqlite/Duckdbex     │         │ │
│  │             │ (Direct Native)         │ (Direct Native)       │         │ │
│  │             ▼                         ▼                       ▼         │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│ │
│  │  │                  HolonDatabase GenServer                             ││ │
│  │  │     Pool Management | OCC | Transaction | Version Vectors           ││ │
│  │  └─────────────────────────────────────────────────────────────────────┘│ │
│  │                                   │                                      │ │
│  │                                   ▼                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│ │
│  │  │                    ZenohDatabaseBridge                               ││ │
│  │  │         Request Serialization | Topic Routing | Response Handling   ││ │
│  │  └─────────────────────────────────────────────────────────────────────┘│ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                       │
│                                      │ Zenoh Pub/Sub                        │
│                                      │ Topics: indrajaal/db/**              │
│                                      ▼                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      ZENOH MESH (7447, 7448, 7449)                      │ │
│  │              2oo3 Voting | FIFO Ordering | < 50ms Latency              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                       │
│                                      │ Zenoh Pub/Sub                        │
│                                      ▼                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                            F# RUNTIME                                   │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│ │
│  │  │                  ZenohCrossHolonBridge                               ││ │
│  │  │        Request Parsing | Database Routing | Response Serialization  ││ │
│  │  └─────────────────────────────────────────────────────────────────────┘│ │
│  │                                   │                                      │ │
│  │                                   ▼                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│ │
│  │  │                  HolonDatabase MailboxProcessor                      ││ │
│  │  │     Pool Management | OCC | Transaction | Version Vectors           ││ │
│  │  └─────────────────────────────────────────────────────────────────────┘│ │
│  │             │                         │                       │         │ │
│  │             │ Microsoft.Data.Sqlite   │ DuckDB.NET           │         │ │
│  │             │ (Direct Native)         │ (Direct Native)       │         │ │
│  │             ▼                         ▼                       ▼         │ │
│  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌───────────────┐ │ │
│  │  │ fs:l4:prj:agt:cockpit│  │ fs:l4:brg:srv:cepaf │  │ fs:l5:obs:... │ │ │
│  │  ├──────────────────────┤  ├──────────────────────┤  ├───────────────┤ │ │
│  │  │ state.sqlite         │  │ state.sqlite         │  │ state.sqlite  │ │ │
│  │  │ analytics.duckdb     │  │ analytics.duckdb     │  │ analytics...  │ │ │
│  │  │ history.duckdb       │  │ history.duckdb       │  │ history...    │ │ │
│  │  │ vectors.sqlite       │  │ vectors.sqlite       │  │ vectors...    │ │ │
│  │  │ register.duckdb      │  │ register.duckdb      │  │ register...   │ │ │
│  │  │ cache.sqlite         │  │ cache.sqlite         │  │ cache...      │ │ │
│  │  └──────────────────────┘  └──────────────────────┘  └───────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Database Stack Summary

| Runtime | Library | Database | Purpose |
|---------|---------|----------|---------|
| **Elixir** | Exqlite | SQLite | State, Vectors, Cache |
| **Elixir** | Duckdbex | DuckDB | Analytics, History, Register |
| **F#** | Microsoft.Data.Sqlite | SQLite | State, Vectors, Cache |
| **F#** | DuckDB.NET | DuckDB | Analytics, History, Register |

---

## 2.0 Universal Holon Identifier (UHI) Naming System

### 2.1 UHI Format Specification

```
UHI = {runtime}:{layer}:{domain}:{type}:{instance}

FQDN = UHI:{database_type}
```

### 2.2 UHI Component Definitions

#### Runtime Identifiers

| Code | Runtime | Description |
|------|---------|-------------|
| `ex` | Elixir/OTP | BEAM runtime holons |
| `fs` | F#/.NET | .NET runtime holons |
| `zig` | Zig | Native performance holons |
| `rs` | Rust | Systems programming holons |

#### Layer Codes (L0-L7 Fractal)

| Code | Layer | Description |
|------|-------|-------------|
| `l0` | Runtime | Core execution substrate |
| `l1` | Function | Individual functions |
| `l2` | Component | Grouped functions |
| `l3` | Holon | Autonomous agent |
| `l4` | Container | Isolated environment |
| `l5` | Node | Physical/virtual machine |
| `l6` | Cluster | Distributed group |
| `l7` | Federation | Global coordination |

#### Domain Codes (30+ Domains)

| Code | Domain | Description |
|------|--------|-------------|
| `kms` | Key Management | Cryptographic key storage |
| `prj` | Prajna | C3I command cockpit |
| `grd` | Guardian | Safety validation |
| `snt` | Sentinel | Health monitoring |
| `imm` | Immune | Digital immune system |
| `fnd` | Founder | Founder directive enforcement |
| `zen` | Zenoh | Mesh coordination |
| `brg` | Bridge | Cross-runtime bridge |
| `obs` | Observability | Telemetry and monitoring |
| `reg` | Register | Immutable audit trail |
| `alm` | Alarms | Alarm management |
| `acc` | Access | Access control |
| `dev` | Devices | Device management |
| `vid` | Video | Video processing |
| `ana` | Analytics | Data analytics |
| `cmp` | Compliance | Regulatory compliance |
| `sec` | Security | Security operations |
| `evo` | Evolution | Test evolution |
| `cor` | Cortex | AI cognitive |
| `pln` | Planning | Task planning |

#### Type Codes

| Code | Type | Description |
|------|------|-------------|
| `srv` | Service | Stateless service holon |
| `agt` | Agent | Autonomous agent holon |
| `wkr` | Worker | Task execution holon |
| `crd` | Coordinator | Orchestration holon |
| `mon` | Monitor | Observability holon |

#### Database Type Codes

| Code | File Extension | Engine | Purpose |
|------|----------------|--------|---------|
| `state` | `.sqlite` | SQLite | Real-time mutable state |
| `vectors` | `.sqlite` | SQLite | Embeddings for semantic search |
| `cache` | `.sqlite` | SQLite | Temporary cached data |
| `analytics` | `.duckdb` | DuckDB | Analytical queries |
| `history` | `.duckdb` | DuckDB | Immutable event log |
| `register` | `.duckdb` | DuckDB | Cryptographic audit trail |

### 2.3 UHI Examples

```
# Elixir KMS Service Main Instance - State Database
ex:l3:kms:srv:main:state
→ data/holons/ex/l3/kms/srv/main/state.sqlite

# F# Prajna Cockpit Agent - Analytics Database
fs:l4:prj:agt:cockpit:analytics
→ data/holons/fs/l4/prj/agt/cockpit/analytics.duckdb

# Elixir Guardian Agent Primary - History Database
ex:l3:grd:agt:primary:history
→ data/holons/ex/l3/grd/agt/primary/history.duckdb

# F# Bridge Service CEPAF - Register Database
fs:l4:brg:srv:cepaf:register
→ data/holons/fs/l4/brg/srv/cepaf/register.duckdb
```

### 2.4 Path Resolution Rules

```elixir
# Elixir path resolution
def resolve(fqdn) do
  [runtime, layer, domain, type, instance, db_type] = String.split(fqdn, ":")

  extension = case db_type do
    "state" -> "sqlite"
    "vectors" -> "sqlite"
    "cache" -> "sqlite"
    "analytics" -> "duckdb"
    "history" -> "duckdb"
    "register" -> "duckdb"
  end

  "data/holons/#{runtime}/#{layer}/#{domain}/#{type}/#{instance}/#{db_type}.#{extension}"
end
```

```fsharp
// F# path resolution
let resolve (fqdn: string) =
    let parts = fqdn.Split(':')
    let runtime, layer, domain, typ, instance, dbType =
        parts.[0], parts.[1], parts.[2], parts.[3], parts.[4], parts.[5]

    let extension =
        match dbType with
        | "state" | "vectors" | "cache" -> "sqlite"
        | "analytics" | "history" | "register" -> "duckdb"
        | _ -> failwith $"Unknown db type: {dbType}"

    $"data/holons/{runtime}/{layer}/{domain}/{typ}/{instance}/{dbType}.{extension}"
```

---

## 3.0 Access Patterns

### 3.1 Pattern 1: Direct Local Access

Each holon accesses its own databases directly via native libraries.

```elixir
# Elixir: Direct SQLite access via Exqlite
defmodule Indrajaal.Holon.Database.HolonDatabase do
  def query(holon_id, :state, sql, params) do
    with {:ok, conn} <- get_sqlite_pool(holon_id, :state),
         {:ok, result} <- Exqlite.query(conn, sql, params) do
      {:ok, result.rows}
    end
  end

  def query(holon_id, :analytics, sql, params) do
    with {:ok, conn} <- get_duckdb_pool(holon_id, :analytics),
         {:ok, result} <- Duckdbex.query(conn, sql, params) do
      {:ok, result}
    end
  end
end
```

```fsharp
// F#: Direct SQLite access via Microsoft.Data.Sqlite
let query (holonId: string) (dbType: HolonDbType) (sql: string) (params: obj list) =
    async {
        let! pool = getPool holonId dbType
        use! conn = pool.AcquireAsync()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- sql
        for i, p in params |> List.indexed do
            cmd.Parameters.AddWithValue($"@p{i}", p) |> ignore
        use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask
        return readAllRows reader
    }
```

### 3.2 Pattern 2: Cross-Holon Access via Zenoh

Cross-runtime communication uses Zenoh pub/sub messaging.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CROSS-HOLON REQUEST FLOW                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ELIXIR HOLON                          F# HOLON                          │
│  ┌─────────────────┐                   ┌─────────────────┐              │
│  │ ex:l3:kms:srv:a │                   │ fs:l4:prj:agt:b │              │
│  └────────┬────────┘                   └────────┬────────┘              │
│           │                                      │                       │
│           │ 1. Build Request                     │                       │
│           │ {request_id, sql, params, version}  │                       │
│           ▼                                      │                       │
│  ┌─────────────────────────┐                    │                       │
│  │ ZenohDatabaseBridge     │                    │                       │
│  └────────┬────────────────┘                    │                       │
│           │                                      │                       │
│           │ 2. Publish to Zenoh                  │                       │
│           │ Topic: indrajaal/db/ex/a/request/fs/b/state                 │
│           ▼                                      │                       │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                      ZENOH MESH                                      ││
│  └────────────────────────────────────────┬────────────────────────────┘│
│                                           │                              │
│                                           │ 3. Message Delivered         │
│                                           ▼                              │
│                              ┌─────────────────────────────┐            │
│                              │ ZenohCrossHolonBridge       │            │
│                              └────────────┬────────────────┘            │
│                                           │                              │
│                                           │ 4. Route to Database         │
│                                           ▼                              │
│                              ┌─────────────────────────────┐            │
│                              │ HolonDatabase               │            │
│                              │ - Execute Query             │            │
│                              │ - Return Result             │            │
│                              └────────────┬────────────────┘            │
│                                           │                              │
│                                           │ 5. Publish Response          │
│                                           │ Topic: indrajaal/db/ex/a/response/{request_id}
│                                           ▼                              │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                      ZENOH MESH                                      ││
│  └──────────────────────────┬──────────────────────────────────────────┘│
│                             │                                            │
│                             │ 6. Response Delivered                      │
│                             ▼                                            │
│  ┌─────────────────────────┐                                            │
│  │ ZenohDatabaseBridge     │                                            │
│  │ - Parse Response        │                                            │
│  │ - Reply to Caller       │                                            │
│  └────────┬────────────────┘                                            │
│           │                                                              │
│           │ 7. Return Result                                             │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ Caller Process  │                                                    │
│  └─────────────────┘                                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Pattern 3: Multi-Client Concurrent Access

Multiple clients can access the same holon database concurrently.

```elixir
# Concurrent access with OCC
defmodule Indrajaal.Holon.Database.ConcurrentAccess do
  def concurrent_update(holon_id, db_type, updates) do
    # Get current version vector
    {:ok, current_vv} = HolonDatabase.get_version_vector(holon_id)

    # Attempt updates concurrently
    results =
      updates
      |> Task.async_stream(fn {sql, params} ->
        HolonDatabase.execute_cas(holon_id, db_type, sql, params, current_vv)
      end, max_concurrency: 10, timeout: 5_000)
      |> Enum.to_list()

    # Handle conflicts with retry
    results
    |> Enum.filter(fn
      {:ok, {:conflict, _}} -> true
      _ -> false
    end)
    |> Enum.each(fn {:ok, {:conflict, new_vv}} ->
      # Retry with updated version
      retry_with_version(new_vv)
    end)

    {:ok, results}
  end
end
```

---

## 4.0 Concurrency Model

### 4.1 Optimistic Concurrency Control (OCC)

All write operations use OCC with version vectors to avoid locking.

```elixir
# Version Vector Implementation (Elixir)
defmodule Indrajaal.Holon.Database.VersionVector do
  @type t :: %{String.t() => non_neg_integer()}

  @doc "Increment version for a holon"
  def increment(vv, holon_id) do
    Map.update(vv, holon_id, 1, &(&1 + 1))
  end

  @doc "Merge two version vectors (component-wise max)"
  def merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  @doc "Check if vv1 >= vv2 (happens-before or concurrent)"
  def gte?(vv1, vv2) do
    Enum.all?(vv2, fn {k, v2} ->
      Map.get(vv1, k, 0) >= v2
    end)
  end

  @doc "Compare version vectors"
  def compare(vv1, vv2) do
    cond do
      vv1 == vv2 -> :eq
      gte?(vv1, vv2) -> :gt
      gte?(vv2, vv1) -> :lt
      true -> :concurrent
    end
  end
end
```

```fsharp
// Version Vector Implementation (F#)
module VersionVector =
    type T = Map<string, int64>

    let empty: T = Map.empty

    let increment (vv: T) (holonId: string) : T =
        let current = Map.tryFind holonId vv |> Option.defaultValue 0L
        Map.add holonId (current + 1L) vv

    let merge (vv1: T) (vv2: T) : T =
        Map.fold (fun acc k v2 ->
            let v1 = Map.tryFind k acc |> Option.defaultValue 0L
            Map.add k (max v1 v2) acc
        ) vv1 vv2

    let gte (vv1: T) (vv2: T) : bool =
        Map.forall (fun k v2 ->
            Map.tryFind k vv1 |> Option.defaultValue 0L >= v2
        ) vv2

    let compare (vv1: T) (vv2: T) =
        if vv1 = vv2 then 0
        elif gte vv1 vv2 then 1
        elif gte vv2 vv1 then -1
        else 2  // Concurrent
```

### 4.2 Compare-And-Swap (CAS) Operations

```elixir
# CAS operation with version check (Elixir)
def execute_cas(holon_id, db_type, sql, params, expected_version) do
  GenServer.call(via_tuple(holon_id), {:execute_cas, db_type, sql, params, expected_version})
end

# GenServer handler
def handle_call({:execute_cas, db_type, sql, params, expected_version}, _from, state) do
  if VersionVector.gte?(state.version_vector, expected_version) do
    case execute_write(state, db_type, sql, params) do
      {:ok, result} ->
        new_vv = VersionVector.increment(state.version_vector, state.holon_id)
        {:reply, {:ok, %{result | version: new_vv}}, %{state | version_vector: new_vv}}
      error ->
        {:reply, error, state}
    end
  else
    {:reply, {:conflict, state.version_vector}, state}
  end
end
```

### 4.3 Connection Pooling

```elixir
# Elixir Connection Pool
defmodule Indrajaal.Holon.Database.Pool do
  def child_spec(holon_id, db_type, opts) do
    pool_opts = [
      name: pool_name(holon_id, db_type),
      pool_size: Keyword.get(opts, :pool_size, 5),
      max_overflow: Keyword.get(opts, :max_overflow, 2)
    ]

    :poolboy.child_spec(
      pool_name(holon_id, db_type),
      pool_opts,
      [path: resolve_path(holon_id, db_type)]
    )
  end

  def with_connection(holon_id, db_type, fun) do
    :poolboy.transaction(pool_name(holon_id, db_type), fn conn ->
      fun.(conn)
    end, 5_000)
  end
end
```

---

## 5.0 Transaction Semantics

### 5.1 Local Transactions (ACID)

```elixir
# Elixir: Local transaction with SQLite
def transaction(holon_id, db_type, fun) do
  Pool.with_connection(holon_id, db_type, fn conn ->
    Exqlite.transaction(conn, fn tx_conn ->
      fun.(tx_conn)
    end)
  end)
end

# Usage
HolonDatabase.transaction("ex:l3:kms:srv:main", :state, fn conn ->
  Exqlite.execute(conn, "INSERT INTO keys (id, value) VALUES (?, ?)", [key_id, value])
  Exqlite.execute(conn, "INSERT INTO audit (key_id, action) VALUES (?, 'create')", [key_id])
  {:ok, key_id}
end)
```

### 5.2 Distributed Transactions (2PC)

```elixir
# Two-Phase Commit for cross-holon transactions
defmodule Indrajaal.Holon.Database.TwoPhaseCommit do
  @type tx_id :: String.t()
  @type participant :: String.t()

  @doc "Begin distributed transaction"
  def begin_transaction(participants) when is_list(participants) do
    tx_id = generate_tx_id()

    # Phase 1: Prepare all participants
    prepare_results =
      participants
      |> Enum.map(&prepare_participant(&1, tx_id))
      |> Enum.reduce({:ok, []}, &collect_prepare_result/2)

    case prepare_results do
      {:ok, prepared} ->
        {:ok, %{tx_id: tx_id, participants: prepared}}
      {:error, reason} ->
        # Abort all participants
        abort_all(participants, tx_id)
        {:error, reason}
    end
  end

  @doc "Commit distributed transaction"
  def commit(tx_id, participants) do
    # Phase 2: Commit all participants
    commit_results =
      participants
      |> Enum.map(&commit_participant(&1, tx_id))

    if Enum.all?(commit_results, &match?({:ok, _}, &1)) do
      {:ok, tx_id}
    else
      {:error, :partial_commit, commit_results}
    end
  end

  @doc "Rollback distributed transaction"
  def rollback(tx_id, participants) do
    Enum.each(participants, &rollback_participant(&1, tx_id))
    {:ok, :rolled_back}
  end

  defp prepare_participant(holon_id, tx_id) do
    ZenohDatabaseBridge.send_command(
      holon_id,
      {:prepare, tx_id}
    )
  end

  defp commit_participant(holon_id, tx_id) do
    ZenohDatabaseBridge.send_command(
      holon_id,
      {:commit, tx_id}
    )
  end

  defp rollback_participant(holon_id, tx_id) do
    ZenohDatabaseBridge.send_command(
      holon_id,
      {:rollback, tx_id}
    )
  end
end
```

---

## 6.0 STAMP Safety Constraints (SC-XHOLON-*)

### 6.1 Core Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-001 | Each holon MUST have isolated database files | CRITICAL | Path verification |
| SC-XHOLON-002 | Direct database access MUST use native high-performance libraries | CRITICAL | Library validation |
| SC-XHOLON-003 | Cross-holon access MUST only occur via Zenoh pub/sub | CRITICAL | Code review |
| SC-XHOLON-004 | All database paths MUST follow UHI naming convention | HIGH | Path regex |
| SC-XHOLON-005 | SQLite databases MUST use WAL mode | HIGH | PRAGMA check |

### 6.2 Concurrency Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-010 | All writes MUST use OCC with version vectors | CRITICAL | Code review |
| SC-XHOLON-011 | Version vectors MUST be monotonically increasing | CRITICAL | Property test |
| SC-XHOLON-012 | Conflicting writes MUST return conflict with current version | HIGH | Integration test |
| SC-XHOLON-013 | CAS operations MUST be atomic | CRITICAL | Transaction test |
| SC-XHOLON-014 | Connection pools MUST limit concurrent connections | HIGH | Pool config |

### 6.3 Performance Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-020 | SQLite read latency MUST be < 1ms | HIGH | Benchmark |
| SC-XHOLON-021 | DuckDB query latency MUST be < 10ms | HIGH | Benchmark |
| SC-XHOLON-022 | Cross-holon request latency MUST be < 50ms local | MEDIUM | Telemetry |
| SC-XHOLON-023 | Cross-holon request latency MUST be < 200ms remote | MEDIUM | Telemetry |
| SC-XHOLON-024 | Connection pool acquire MUST be < 100ms | HIGH | Timeout |
| SC-XHOLON-025 | Cross-holon request timeout MUST be < 5s | HIGH | Config |
| SC-XHOLON-026 | Failed requests MUST retry with exponential backoff | MEDIUM | Code review |

### 6.4 Security Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-030 | SQL injection MUST be prevented via parameterized queries | CRITICAL | Code review |
| SC-XHOLON-031 | Cross-holon requests MUST include source holon identity | HIGH | Message format |
| SC-XHOLON-032 | Database files MUST have restrictive permissions | HIGH | File perms |
| SC-XHOLON-033 | Sensitive data MUST be encrypted at rest | MEDIUM | Encryption |
| SC-XHOLON-034 | Internal system tables MUST NOT be exposed cross-holon | HIGH | Query filter |

### 6.5 Reliability Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-040 | Database corruption MUST be detected on startup | CRITICAL | Integrity check |
| SC-XHOLON-041 | Version vectors MUST be persisted atomically | CRITICAL | WAL verify |
| SC-XHOLON-042 | Transaction rollback MUST restore previous state | CRITICAL | Test |
| SC-XHOLON-043 | Zenoh disconnection MUST trigger auto-reconnect | HIGH | Integration |
| SC-XHOLON-044 | Request timeout MUST not leave orphaned transactions | CRITICAL | Cleanup |
| SC-XHOLON-045 | Distributed transaction timeout MUST trigger abort | HIGH | 2PC test |

### 6.6 Scalability Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-050 | System MUST support 100+ concurrent holons | HIGH | Load test |
| SC-XHOLON-051 | Each holon MUST support 10+ concurrent clients | HIGH | Load test |
| SC-XHOLON-052 | Cross-holon throughput MUST exceed 1000 req/s | MEDIUM | Benchmark |
| SC-XHOLON-053 | Database files MUST support growth to 10GB+ | MEDIUM | Schema design |
| SC-XHOLON-054 | Memory usage MUST be bounded per holon | HIGH | Monitoring |

---

## 7.0 Agent Operating Rules (AOR-XHOLON-*)

| ID | Rule |
|----|------|
| AOR-XHOLON-001 | ALWAYS use HolonDatabase abstraction for database access |
| AOR-XHOLON-002 | NEVER bypass Zenoh for cross-holon communication |
| AOR-XHOLON-003 | ALWAYS include version vector in write operations |
| AOR-XHOLON-004 | RETRY on conflict with fresh version vector |
| AOR-XHOLON-005 | CLOSE connections promptly after use |
| AOR-XHOLON-006 | LOG all database errors to telemetry |
| AOR-XHOLON-007 | VALIDATE UHI format before path resolution |
| AOR-XHOLON-008 | USE parameterized queries exclusively |
| AOR-XHOLON-009 | CHECK database health on holon startup |
| AOR-XHOLON-010 | BACKUP critical databases before schema changes |

---

## 8.0 FMEA Risk Analysis

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Database file corruption | Data loss | 9 | 2 | 8 | 144 | WAL mode, checksums, backups |
| Version vector desync | Lost updates | 8 | 3 | 6 | 144 | Periodic sync validation |
| Zenoh partition | Cross-holon unavailable | 7 | 4 | 5 | 140 | 2oo3 voting, auto-reconnect |
| Pool exhaustion | Requests timeout | 6 | 5 | 4 | 120 | Pool sizing, queuing |
| SQL injection | Data breach | 10 | 1 | 9 | 90 | Parameterized queries |
| Transaction deadlock | Requests hang | 7 | 2 | 6 | 84 | OCC (no locks), timeouts |
| Memory leak | OOM crash | 8 | 2 | 5 | 80 | Connection cleanup, limits |
| Disk full | Write failures | 8 | 2 | 4 | 64 | Monitoring, alerts |
| Schema mismatch | Query errors | 6 | 3 | 3 | 54 | Migration versioning |
| Network latency spike | Slow responses | 5 | 5 | 2 | 50 | Timeouts, circuit breakers |

---

## 9.0 9-Degree Interaction Matrix

### 9.1 Interaction Degrees

| Degree | Name | Description |
|--------|------|-------------|
| D1 | Cross-Runtime | Elixir ↔ F# holon communication |
| D2 | Database Types | SQLite/DuckDB type interoperability |
| D3 | Operations | Read/Write/CAS/Transaction operations |
| D4 | Concurrency | Multi-client concurrent access |
| D5 | Transactions | Local and distributed transaction scope |
| D6 | Failure Modes | Error handling and recovery |
| D7 | Performance | Latency and throughput under load |
| D8 | Security | Authentication and injection prevention |
| D9 | Recovery | State restoration after failures |

### 9.2 Full Interaction Test Matrix

| Test ID | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | Description |
|---------|----|----|----|----|----|----|----|----|----|--------------------|
| T-001 | ✓ |   |   |   |   |   |   |   |   | Basic Elixir→F# query |
| T-002 | ✓ |   |   |   |   |   |   |   |   | Basic F#→Elixir query |
| T-003 | ✓ | ✓ |   |   |   |   |   |   |   | Cross-runtime SQLite access |
| T-004 | ✓ | ✓ |   |   |   |   |   |   |   | Cross-runtime DuckDB access |
| T-005 | ✓ | ✓ | ✓ |   |   |   |   |   |   | Cross-runtime read operation |
| T-006 | ✓ | ✓ | ✓ |   |   |   |   |   |   | Cross-runtime write operation |
| T-007 | ✓ | ✓ | ✓ |   |   |   |   |   |   | Cross-runtime CAS operation |
| T-008 | ✓ | ✓ | ✓ | ✓ |   |   |   |   |   | Concurrent cross-runtime writes |
| T-009 | ✓ | ✓ | ✓ | ✓ |   |   |   |   |   | OCC conflict detection |
| T-010 | ✓ | ✓ | ✓ | ✓ | ✓ |   |   |   |   | Local transaction scope |
| T-011 | ✓ | ✓ | ✓ | ✓ | ✓ |   |   |   |   | Distributed 2PC transaction |
| T-012 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   |   |   | Timeout handling |
| T-013 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   |   |   | Connection failure recovery |
| T-014 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   |   | Latency under load |
| T-015 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   |   | Throughput benchmark |
| T-016 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   | SQL injection prevention |
| T-017 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |   | Holon isolation verification |
| T-018 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Full recovery after crash |
| T-019 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Version vector recovery |
| T-020 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Complete system integration |

---

## 10.0 Formal Verification Requirements

### 10.1 Agda Proofs Required

1. **Version Vector Monotonicity**: ∀ vv₁ vv₂, increment(vv₁) ≥ vv₁
2. **CAS Atomicity**: ∀ tx, atomic(tx) ⟹ (commit(tx) ∨ rollback(tx))
3. **OCC Correctness**: ∀ w₁ w₂, concurrent(w₁, w₂) ⟹ ¬(both_commit(w₁, w₂))
4. **UHI Uniqueness**: ∀ h₁ h₂, path(h₁) = path(h₂) ⟹ h₁ = h₂
5. **Transaction Isolation**: ∀ tx₁ tx₂, isolated(tx₁, tx₂) ⟹ serializable(tx₁, tx₂)

### 10.2 Quint Model Requirements

1. **State Machine**: Holon database lifecycle (init → ready → query → execute → close)
2. **Concurrency Model**: Version vector updates under concurrent access
3. **2PC Protocol**: Distributed transaction commit/abort semantics
4. **Failure Recovery**: State restoration after crash scenarios
5. **Zenoh Message Flow**: Request-response correlation verification

---

## 11.0 Implementation Checklist

### 11.1 Elixir Implementation

- [x] `Indrajaal.Holon.Database.HolonDatabase` GenServer
- [x] `Indrajaal.Holon.Database.ZenohDatabaseBridge` cross-holon bridge
- [x] `Indrajaal.Holon.DatabasePath` UHI path resolution
- [x] `Indrajaal.Holon.Database.ConcurrencyHandler` OCC with version vectors
- [x] Connection pool management (Exqlite + Duckdbex)
- [x] Transaction support (local)
- [ ] Distributed transaction (2PC) - enhance
- [x] Telemetry integration

### 11.2 F# Implementation

- [x] `Cepaf.Database.HolonDatabase` MailboxProcessor
- [x] `Cepaf.Database.ZenohCrossHolonBridge` request handler
- [x] `Cepaf.Holon.DatabasePath` UHI path resolution
- [x] `Cepaf.Database.HolonConcurrencyHandler` OCC with version vectors
- [x] Connection pool (Microsoft.Data.Sqlite + DuckDB.NET)
- [x] Transaction support (local)
- [ ] Distributed transaction (2PC) - enhance
- [x] Telemetry integration

### 11.3 Test Coverage

- [x] Unit tests: HolonDatabase (Elixir)
- [x] Unit tests: HolonDatabase (F#)
- [x] Integration tests: Cross-holon interop
- [x] 9-degree interaction matrix
- [ ] Property-based tests: Version vectors
- [ ] Performance benchmarks
- [ ] Chaos testing: Network partitions
- [ ] Security testing: SQL injection

---

## 12.0 Related Documents

- `docs/architecture/HOLON_DATABASE_NAMING_SYSTEM.md` - UHI naming specification
- `docs/formal_specs/cross_holon_database.agda` - Agda formal proofs
- `docs/formal_specs/cross_holon_database.qnt` - Quint state machine model
- `journal/2026-01/20260117-cross-holon-database-v2.md` - Development journal

---

**Document Control**
- Version: 2.0.0
- Author: Claude Opus 4.5
- Date: 2026-01-17
- STAMP: SC-XHOLON-001 to SC-XHOLON-054
- AOR: AOR-XHOLON-001 to AOR-XHOLON-010
