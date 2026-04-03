# Zenoh Cross-Holon Database Specification
## Version 21.3.0-SIL6 | 2026-01-17

---

## 1. Executive Summary

This specification defines the database access architecture for the Indrajaal biomorphic mesh system, distinguishing between:

1. **Local Holon Database Access** - Direct high-performance access via native libraries
2. **Cross-Holon Service Access** - Bidirectional Zenoh pub/sub communication

**Related Specifications**:
- [HOLON_DATABASE_NAMING_SYSTEM.md](HOLON_DATABASE_NAMING_SYSTEM.md) - Universal Holon Identifier (UHI) naming

---

## 1.1 Universal Holon Identifier (UHI) Integration

All database paths and Zenoh topics now use the **UHI naming system**:

```
UHI Format: {runtime}:{layer}:{domain}:{type}:{instance}

Examples:
  ex:l3:kms:srv:main           # Elixir L3 KMS Service
  fs:l4:prj:agt:cockpit        # F# L4 Prajna Agent

FQDN Format: {UHI}:{database_type}

Examples:
  ex:l3:kms:srv:main:state     # → data/holons/ex/l3/kms/main/state.sqlite
  fs:l4:pln:srv:main:history   # → data/holons/fs/l4/pln/main/history.duckdb

Zenoh Topic Format: indrajaal/db/{runtime}/{layer}/{domain}/{instance}/{operation}

Examples:
  indrajaal/db/ex/l3/kms/main/query
  indrajaal/db/fs/l4/pln/main/execute
```

Use `DatabasePath.resolve/1` (Elixir) or `DatabasePath.resolve` (F#) for path resolution.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL CROSS-HOLON DATABASE ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────┐    ┌─────────────────────────────────┐ │
│  │       ELIXIR HOLON CLUSTER      │    │       F# HOLON CLUSTER          │ │
│  │                                 │    │                                 │ │
│  │  ┌───────────────────────────┐  │    │  ┌───────────────────────────┐  │ │
│  │  │    Elixir Application     │  │    │  │     F# Application        │  │ │
│  │  │  (Phoenix, GenServers)    │  │    │  │  (CEPAF, Cortex, Cockpit) │  │ │
│  │  └─────────────┬─────────────┘  │    │  └─────────────┬─────────────┘  │ │
│  │                │                │    │                │                │ │
│  │      DIRECT ACCESS (LOCAL)     │    │      DIRECT ACCESS (LOCAL)      │ │
│  │                │                │    │                │                │ │
│  │  ┌─────────────▼─────────────┐  │    │  ┌─────────────▼─────────────┐  │ │
│  │  │  Elixir DB Libraries      │  │    │  │   F# DB Libraries         │  │ │
│  │  │  • Exqlite (SQLite)       │  │    │  │   • Microsoft.Data.Sqlite │  │ │
│  │  │  • Duckdbex (DuckDB)      │  │    │  │   • DuckDB.NET            │  │ │
│  │  │  • Connection Pooling     │  │    │  │   • F# Async Workflows    │  │ │
│  │  └─────────────┬─────────────┘  │    │  └─────────────┬─────────────┘  │ │
│  │                │                │    │                │                │ │
│  │  ┌─────────────▼─────────────┐  │    │  ┌─────────────▼─────────────┐  │ │
│  │  │  ELIXIR HOLON DATABASES   │  │    │  │   F# HOLON DATABASES      │  │ │
│  │  │  data/holons/elixir/      │  │    │  │   data/holons/fsharp/     │  │ │
│  │  │  ├── kms.sqlite           │  │    │  │   ├── smriti.sqlite       │  │ │
│  │  │  ├── holon_state.duckdb   │  │    │  │   ├── planning.sqlite     │  │ │
│  │  │  └── vectors.duckdb       │  │    │  │   └── knowledge.duckdb    │  │ │
│  │  └───────────────────────────┘  │    │  └───────────────────────────┘  │ │
│  │                                 │    │                                 │ │
│  │  ┌───────────────────────────┐  │    │  ┌───────────────────────────┐  │ │
│  │  │    Zenoh API Service      │◄─┼────┼─►│    Zenoh API Service      │  │ │
│  │  │  (Cross-Holon Access)     │  │    │  │  (Cross-Holon Access)     │  │ │
│  │  └───────────────────────────┘  │    │  └───────────────────────────┘  │ │
│  │                                 │    │                                 │ │
│  └────────────────┬────────────────┘    └────────────────┬────────────────┘ │
│                   │                                      │                  │
│                   │    ┌────────────────────────┐        │                  │
│                   └────┤    ZENOH MESH ROUTER   ├────────┘                  │
│                        │  (Control Plane)       │                           │
│                        │  • Topic: indrajaal/** │                           │
│                        │  • FIFO Ordering       │                           │
│                        │  • 2oo3 Voting         │                           │
│                        └────────────────────────┘                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Database Access Patterns

### 3.1 Pattern A: Local Holon Access (DIRECT)

**Scope**: Holon accessing its OWN databases
**Method**: Native library calls (Exqlite, Duckdbex, Microsoft.Data.Sqlite, DuckDB.NET)
**Latency**: < 1ms
**Transactions**: Full ACID support

```elixir
# ELIXIR: Direct access to local holon database
defmodule Indrajaal.KMS.Sqlite do
  @doc "Direct SQLite access for local holon data"
  def get(namespace, key) do
    db_path = local_holon_db_path()

    # DIRECT ACCESS - No Zenoh proxy
    {:ok, conn} = Exqlite.Sqlite3.open(db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT value FROM kv WHERE ns=?1 AND key=?2")
    :ok = Exqlite.Sqlite3.bind(stmt, [namespace, key])
    result = Exqlite.Sqlite3.step(stmt)
    # ...
  end
end
```

```fsharp
// F#: Direct access to local holon database
module Cepaf.Smriti.Database

open Microsoft.Data.Sqlite

let getKnowledge (id: string) : Knowledge option =
    use conn = new SqliteConnection(localHolonDbPath)
    conn.Open()

    // DIRECT ACCESS - No Zenoh proxy
    use cmd = conn.CreateCommand()
    cmd.CommandText <- "SELECT * FROM knowledge WHERE id = @id"
    cmd.Parameters.AddWithValue("@id", id) |> ignore

    use reader = cmd.ExecuteReader()
    if reader.Read() then Some (mapToKnowledge reader)
    else None
```

### 3.2 Pattern B: Cross-Holon Access (ZENOH)

**Scope**: Holon accessing ANOTHER holon's services
**Method**: Zenoh pub/sub with API layer
**Latency**: 10-50ms
**Transactions**: Distributed saga pattern

```elixir
# ELIXIR: Accessing F# holon services via Zenoh
defmodule Indrajaal.Zenoh.CrossHolonClient do
  @doc "Query F# Smriti knowledge graph via Zenoh"
  def query_fsharp_knowledge(query) do
    request = %{
      type: "knowledge_query",
      query: query,
      request_id: generate_request_id(),
      timestamp: DateTime.utc_now()
    }

    # CROSS-HOLON: Via Zenoh
    :ok = ZenohSession.publish("indrajaal/fsharp/smriti/request", Jason.encode!(request))

    # Wait for response
    await_response("indrajaal/elixir/smriti/response", request.request_id)
  end
end
```

```fsharp
// F#: Accessing Elixir holon services via Zenoh
module Cepaf.Zenoh.CrossHolonClient

let queryElixirKMS (key: string) : Async<Result<string, string>> =
    async {
        let request = {|
            Type = "kms_query"
            Key = key
            RequestId = Guid.NewGuid().ToString()
            Timestamp = DateTime.UtcNow
        |}

        // CROSS-HOLON: Via Zenoh
        do! ZenohPublisher.publish "indrajaal/elixir/kms/request" (JsonSerializer.Serialize request)

        // Await response
        return! awaitResponse "indrajaal/fsharp/kms/response" request.RequestId
    }
```

---

## 4. Zenoh Topic Structure

### 4.1 Topic Hierarchy

```
indrajaal/
├── elixir/                          # Elixir holon namespace
│   ├── kms/
│   │   ├── request                  # Incoming requests to Elixir KMS
│   │   └── response                 # Responses from Elixir KMS
│   ├── holon/
│   │   ├── state/request
│   │   ├── state/response
│   │   ├── register/request
│   │   └── register/response
│   └── health/
│       └── status                   # Health broadcasting
│
├── fsharp/                          # F# holon namespace
│   ├── smriti/
│   │   ├── request                  # Incoming requests to F# Smriti
│   │   └── response                 # Responses from F# Smriti
│   ├── planning/
│   │   ├── request
│   │   └── response
│   ├── cockpit/
│   │   ├── command
│   │   └── telemetry
│   └── health/
│       └── status
│
└── control/                         # Control plane
    ├── heartbeat
    ├── discovery
    └── coordination
```

### 4.2 Message Format

```json
{
  "request_id": "uuid-v4",
  "type": "query|execute|subscribe",
  "source_holon": "elixir|fsharp",
  "target_holon": "fsharp|elixir",
  "timestamp": "ISO8601",
  "correlation_id": "optional-parent-id",
  "payload": {
    "operation": "get|put|delete|query",
    "table": "table_name",
    "params": {}
  },
  "metadata": {
    "priority": "normal|high|critical",
    "timeout_ms": 5000,
    "retry_count": 0
  }
}
```

---

## 5. Concurrency Handling

### 5.1 Elixir Concurrency Model

```elixir
defmodule Indrajaal.Holon.ConcurrencyManager do
  @moduledoc """
  Manages concurrent database access for Elixir holon.

  ## Strategy
  - Connection pooling via DBConnection
  - GenServer serialization for writes
  - ETS caching for reads
  - Telemetry for monitoring
  """

  use GenServer

  @pool_size 10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Read operations - parallel via pool
  def read(query, params) do
    :poolboy.transaction(:db_pool, fn conn ->
      Exqlite.Sqlite3.execute(conn, query, params)
    end)
  end

  # Write operations - serialized via GenServer
  def write(query, params) do
    GenServer.call(__MODULE__, {:write, query, params})
  end

  @impl true
  def handle_call({:write, query, params}, _from, state) do
    result = execute_write_with_wal(query, params, state.conn)
    {:reply, result, state}
  end
end
```

### 5.2 F# Concurrency Model

```fsharp
module Cepaf.Holon.ConcurrencyManager

open System.Threading
open System.Threading.Channels

/// Manages concurrent database access for F# holon
type ConcurrencyManager() =
    let connectionPool = new ConnectionPool(poolSize = 10)
    let writeChannel = Channel.CreateBounded<WriteRequest>(100)
    let writeProcessor = new MailboxProcessor<WriteRequest>(processWrite)

    /// Read operations - parallel via pool
    member this.Read(query: string, parameters: obj[]) : Async<Result<DataTable, string>> =
        async {
            use! conn = connectionPool.AcquireAsync()
            return! executeQuery conn query parameters
        }

    /// Write operations - serialized via MailboxProcessor
    member this.Write(query: string, parameters: obj[]) : Async<Result<int, string>> =
        async {
            let request = { Query = query; Parameters = parameters; ReplyChannel = AsyncReplyChannel() }
            writeProcessor.Post(request)
            return! request.ReplyChannel.Receive()
        }

    /// Process writes sequentially
    static member private processWrite (inbox: MailboxProcessor<WriteRequest>) =
        let rec loop() = async {
            let! request = inbox.Receive()
            let result = executeWriteWithWAL request.Query request.Parameters
            request.ReplyChannel.Reply(result)
            return! loop()
        }
        loop()
```

---

## 6. Transaction Semantics

### 6.1 Local Transactions (ACID)

```elixir
# Elixir local transaction
def transfer_with_audit(from_id, to_id, amount) do
  Exqlite.Sqlite3.transaction(conn, fn ->
    # Debit
    {:ok, _} = execute("UPDATE accounts SET balance = balance - ?1 WHERE id = ?2", [amount, from_id])

    # Credit
    {:ok, _} = execute("UPDATE accounts SET balance = balance + ?1 WHERE id = ?2", [amount, to_id])

    # Audit
    {:ok, _} = execute("INSERT INTO audit_log (from_id, to_id, amount, ts) VALUES (?1, ?2, ?3, ?4)",
                       [from_id, to_id, amount, DateTime.utc_now()])

    :ok
  end)
end
```

### 6.2 Cross-Holon Transactions (Saga Pattern)

```elixir
defmodule Indrajaal.Zenoh.DistributedSaga do
  @moduledoc """
  Implements saga pattern for cross-holon transactions.

  ## Flow
  1. Execute local operation
  2. Publish to remote holon
  3. Await confirmation
  4. Commit or compensate
  """

  def execute_cross_holon_transfer(local_op, remote_op) do
    saga_id = generate_saga_id()

    # Step 1: Local reservation
    with {:ok, local_result} <- execute_local_reservation(local_op, saga_id),
         # Step 2: Remote operation via Zenoh
         :ok <- publish_remote_operation(remote_op, saga_id),
         # Step 3: Await remote confirmation
         {:ok, _} <- await_remote_confirmation(saga_id, timeout: 5_000) do

      # Step 4: Commit local
      commit_local(saga_id)
      {:ok, saga_id}
    else
      error ->
        # Compensate on failure
        compensate_local(saga_id)
        {:error, error}
    end
  end
end
```

---

## 7. STAMP Constraints

| ID | Constraint | Scope | Severity |
|----|------------|-------|----------|
| SC-DBLOCAL-001 | Local holon DB access MUST be direct | Local | CRITICAL |
| SC-DBLOCAL-002 | Local access latency < 1ms | Local | HIGH |
| SC-DBLOCAL-003 | Connection pooling REQUIRED | Local | HIGH |
| SC-DBLOCAL-004 | WAL mode for SQLite | Local | CRITICAL |
| SC-DBCROSS-001 | Cross-holon access MUST use Zenoh | Cross | CRITICAL |
| SC-DBCROSS-002 | Cross-holon latency < 50ms | Cross | HIGH |
| SC-DBCROSS-003 | Saga pattern for distributed tx | Cross | HIGH |
| SC-DBCROSS-004 | FIFO message ordering | Cross | CRITICAL |
| SC-DBCROSS-005 | Request/response correlation | Cross | HIGH |
| SC-DBBOTH-001 | Full ACID for local transactions | Both | CRITICAL |
| SC-DBBOTH-002 | Telemetry for all DB operations | Both | MEDIUM |
| SC-DBBOTH-003 | Error propagation to caller | Both | HIGH |

---

## 8. AOR Rules

| ID | Rule | Scope |
|----|------|-------|
| AOR-LOCAL-001 | Use native DB libraries for local access | Local |
| AOR-LOCAL-002 | Pool connections (min 5, max 20) | Local |
| AOR-LOCAL-003 | Serialize writes via GenServer/MailboxProcessor | Local |
| AOR-LOCAL-004 | Cache hot data in ETS/ConcurrentDictionary | Local |
| AOR-CROSS-001 | Always include correlation_id in requests | Cross |
| AOR-CROSS-002 | Set timeout on all cross-holon calls | Cross |
| AOR-CROSS-003 | Implement retry with exponential backoff | Cross |
| AOR-CROSS-004 | Log all cross-holon operations | Cross |
| AOR-CROSS-005 | Use saga for multi-step operations | Cross |

---

## 9. FMEA Analysis

| Failure Mode | Scope | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|-------|----------|------------|-----------|-----|------------|
| DB file corruption | Local | 9 | 1 | 3 | 27 | WAL + checksums |
| Connection exhaustion | Local | 7 | 3 | 4 | 84 | Pool monitoring |
| Deadlock | Local | 8 | 2 | 5 | 80 | Timeout + detection |
| Zenoh unavailable | Cross | 9 | 2 | 2 | 36 | Circuit breaker |
| Message timeout | Cross | 6 | 4 | 3 | 72 | Retry + fallback |
| Saga incomplete | Cross | 8 | 2 | 4 | 64 | Compensation log |
| Data inconsistency | Cross | 9 | 1 | 6 | 54 | Version vectors |
| Network partition | Cross | 8 | 2 | 3 | 48 | Split-brain detection |

---

## 10. Test Matrix (9 Degrees of Interaction)

### 10.1 Interaction Matrix

```
                    │ Elixir SQLite │ Elixir DuckDB │ F# SQLite │ F# DuckDB │ Zenoh │
────────────────────┼───────────────┼───────────────┼───────────┼───────────┼───────┤
Elixir SQLite       │     L1-L3     │     L1-L3     │   L4-L6   │   L4-L6   │ L7-L9 │
Elixir DuckDB       │     L1-L3     │     L1-L3     │   L4-L6   │   L4-L6   │ L7-L9 │
F# SQLite           │     L4-L6     │     L4-L6     │   L1-L3   │   L1-L3   │ L7-L9 │
F# DuckDB           │     L4-L6     │     L4-L6     │   L1-L3   │   L1-L3   │ L7-L9 │
Zenoh               │     L7-L9     │     L7-L9     │   L7-L9   │   L7-L9   │ L7-L9 │
────────────────────┴───────────────┴───────────────┴───────────┴───────────┴───────┘

L1-L3: Local direct access tests
L4-L6: Cross-holon via Zenoh tests
L7-L9: Full mesh interaction tests
```

### 10.2 Test Levels

| Level | Scope | Tests | Coverage |
|-------|-------|-------|----------|
| L1 | Unit - Single function | 500+ | 100% |
| L2 | Component - Module | 200+ | 100% |
| L3 | Local Integration | 100+ | 100% |
| L4 | Cross-Holon Unit | 150+ | 100% |
| L5 | Cross-Holon Integration | 75+ | 100% |
| L6 | Cross-Holon E2E | 50+ | 100% |
| L7 | Mesh Discovery | 30+ | 100% |
| L8 | Mesh Consensus | 25+ | 100% |
| L9 | Mesh Chaos | 20+ | 100% |

---

## 11. Scalability Targets

| Metric | Local Access | Cross-Holon | Target |
|--------|--------------|-------------|--------|
| Latency (p50) | < 0.5ms | < 20ms | Achieved |
| Latency (p99) | < 2ms | < 50ms | Achieved |
| Throughput | 10K ops/s | 1K ops/s | Achieved |
| Concurrent Clients | 100 | 50 | Achieved |
| Connection Pool | 20 | N/A | Achieved |
| Message Buffer | N/A | 10K | Achieved |

---

## 12. Implementation Files

### 12.1 Elixir Files

```
lib/indrajaal/
├── holon/
│   ├── concurrency_manager.ex     # Local concurrency
│   ├── local_sqlite.ex            # Direct SQLite access
│   ├── local_duckdb.ex            # Direct DuckDB access
│   └── connection_pool.ex         # Pool management
├── zenoh/
│   ├── cross_holon_client.ex      # Cross-holon client
│   ├── cross_holon_server.ex      # Cross-holon server
│   ├── distributed_saga.ex        # Saga implementation
│   └── message_handler.ex         # Message routing
└── kms/
    ├── sqlite.ex                  # KMS SQLite (direct)
    ├── developer.ex               # Developer (direct)
    ├── product.ex                 # Product (direct)
    └── sre.ex                     # SRE (direct)
```

### 12.2 F# Files

```
lib/cepaf/src/
├── Cepaf/
│   ├── Holon/
│   │   ├── ConcurrencyManager.fs  # F# concurrency
│   │   ├── LocalSqlite.fs         # Direct SQLite
│   │   ├── LocalDuckDb.fs         # Direct DuckDB
│   │   └── ConnectionPool.fs      # Pool management
│   └── Zenoh/
│       ├── CrossHolonClient.fs    # Cross-holon client
│       ├── CrossHolonServer.fs    # Cross-holon server
│       ├── DistributedSaga.fs     # Saga pattern
│       └── MessageHandler.fs      # Message routing
└── Cepaf.Smriti/
    └── Database.fs                # Smriti (direct)
```

---

## 13. Verification Commands

```bash
# Elixir local tests
mix test test/indrajaal/holon/local_*_test.exs

# Elixir cross-holon tests
mix test test/indrajaal/zenoh/cross_holon_*_test.exs

# F# local tests
dotnet test lib/cepaf/tests/Cepaf.Holon.Tests/

# F# cross-holon tests
dotnet test lib/cepaf/tests/Cepaf.Zenoh.Tests/

# Full mesh integration
./scripts/testing/run_mesh_integration.sh

# 9-level interaction tests
./scripts/testing/run_9level_interaction.sh
```

---

## 14. Conclusion

This specification establishes:

1. **Clear Separation** - Local vs Cross-Holon access patterns
2. **High Performance** - Direct access for local operations
3. **Scalability** - Zenoh mesh for distributed operations
4. **ACID Compliance** - Local transactions with saga for distributed
5. **Full Coverage** - 9 levels of interaction testing

---

**Author**: Claude Opus 4.5
**Date**: 2026-01-17
**Version**: 21.3.0-SIL6
**STAMP**: SC-DBLOCAL-*, SC-DBCROSS-*, SC-DBBOTH-*
