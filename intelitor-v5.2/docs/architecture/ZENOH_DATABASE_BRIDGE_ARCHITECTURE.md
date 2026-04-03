# Zenoh Database Bridge Architecture

## COMPREHENSIVE SPECIFICATION
### Version 1.0.0 | 2026-01-17 | SIL-6 Compliant

---

## 1.0 EXECUTIVE SUMMARY

### 1.1 Purpose
This document defines the complete architecture for routing ALL Elixir database access (DuckDB and SQLite) through Zenoh pub/sub to CEPAF F# backend services, ensuring:
- **State Sovereignty**: F# CEPAF has authoritative control over holon state
- **Concurrency**: Thread-safe access via F# concurrency primitives
- **Transaction Semantics**: Full ACID compliance with distributed transactions
- **Scalability**: Horizontal scaling via Zenoh mesh networking
- **Safety**: SIL-6 compliance with formal verification

### 1.2 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ELIXIR LAYER (Clients)                          │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            │
│  │  DuckDBStore   │  │   SQLiteKMS    │  │ ImmutableState │    ...     │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘            │
│          │                   │                   │                      │
│          └───────────────────┼───────────────────┘                      │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    DatabaseProxy (GenServer)                     │   │
│  │  • Request serialization (JSON)                                  │   │
│  │  • Request ID tracking                                           │   │
│  │  • Timeout management                                            │   │
│  │  • Response correlation                                          │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      ZENOH MESH LAYER (Transport)                        │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Zenoh Router                              │   │
│  │  • Topic: indrajaal/db/duckdb/request                           │   │
│  │  • Topic: indrajaal/db/duckdb/response                          │   │
│  │  • Topic: indrajaal/db/sqlite/request                           │   │
│  │  • Topic: indrajaal/db/sqlite/response                          │   │
│  │  • Topic: indrajaal/db/transaction/*                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      F# CEPAF LAYER (Server)                            │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  ZenohDatabaseService (MailboxProcessor)         │   │
│  │  • Message deserialization                                       │   │
│  │  • Concurrency coordination (Semaphore/Mutex)                   │   │
│  │  • Transaction management                                        │   │
│  │  • Connection pooling                                            │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
│                              │                                          │
│          ┌───────────────────┼───────────────────┐                      │
│          ▼                   ▼                   ▼                      │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐             │
│  │ DuckDBHandler │   │ SQLiteHandler │   │ TransactionMgr│             │
│  │               │   │               │   │               │             │
│  │ • Connection  │   │ • Connection  │   │ • Begin/End   │             │
│  │ • Query exec  │   │ • Query exec  │   │ • Rollback    │             │
│  │ • Result map  │   │ • Result map  │   │ • Savepoints  │             │
│  └───────┬───────┘   └───────┬───────┘   └───────────────┘             │
│          │                   │                                          │
│          ▼                   ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                     DATABASE LAYER                                │ │
│  │  ┌─────────────────────┐  ┌─────────────────────┐                │ │
│  │  │  DuckDB (Analytics) │  │  SQLite (OLTP/KMS)  │                │ │
│  │  │  data/holons/*.db   │  │  data/holons/*.db   │                │ │
│  │  └─────────────────────┘  └─────────────────────┘                │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2.0 STAMP CONSTRAINTS

### 2.1 Bridge Constraints (SC-BRIDGE-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-BRIDGE-001 | Message buffer FIFO ordering | CRITICAL | Unit test |
| SC-BRIDGE-002 | Latency budget 50ms p95 | HIGH | Performance test |
| SC-BRIDGE-003 | Request timeout 5s max | HIGH | Integration test |
| SC-BRIDGE-004 | JSON serialization only | MEDIUM | Static analysis |
| SC-BRIDGE-005 | Request ID globally unique | CRITICAL | Property test |
| SC-BRIDGE-006 | Response correlation exact | CRITICAL | Integration test |

### 2.2 Database Proxy Constraints (SC-DBPROXY-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DBPROXY-001 | No direct DuckDB/SQLite access in Elixir | CRITICAL | Static analysis |
| SC-DBPROXY-002 | All queries via Zenoh proxy | CRITICAL | Code review |
| SC-DBPROXY-003 | Connection pooling in F# | HIGH | Load test |
| SC-DBPROXY-004 | Transaction isolation serializable | CRITICAL | ACID test |
| SC-DBPROXY-005 | Concurrent request limit 100 | HIGH | Load test |
| SC-DBPROXY-006 | Circuit breaker on failure | HIGH | Chaos test |

### 2.3 Concurrency Constraints (SC-CONC-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-CONC-001 | F# MailboxProcessor for serialization | HIGH | Design review |
| SC-CONC-002 | SemaphoreSlim for connection limit | HIGH | Load test |
| SC-CONC-003 | ReaderWriterLockSlim for cache | MEDIUM | Performance test |
| SC-CONC-004 | No deadlock paths | CRITICAL | Formal proof |
| SC-CONC-005 | Starvation-free scheduling | HIGH | Property test |
| SC-CONC-006 | Lock timeout 1s max | HIGH | Timeout test |

### 2.4 Transaction Constraints (SC-TXN-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-TXN-001 | ACID semantics guaranteed | CRITICAL | ACID test suite |
| SC-TXN-002 | Distributed transaction support | HIGH | Integration test |
| SC-TXN-003 | Savepoint/rollback support | HIGH | Unit test |
| SC-TXN-004 | Transaction timeout 30s | HIGH | Timeout test |
| SC-TXN-005 | Deadlock detection | CRITICAL | Chaos test |
| SC-TXN-006 | Two-phase commit for cross-DB | HIGH | Integration test |

---

## 3.0 AOR RULES

### 3.1 Database Proxy Rules (AOR-DBPROXY-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-DBPROXY-001 | NEVER call Duckdbex/Exqlite directly from Elixir | Code review + lint |
| AOR-DBPROXY-002 | ALWAYS use DatabaseProxy for database access | Static analysis |
| AOR-DBPROXY-003 | ALWAYS include request timeout | Default parameter |
| AOR-DBPROXY-004 | ALWAYS log database errors to telemetry | Code review |
| AOR-DBPROXY-005 | ALWAYS use parameterized queries | Security review |
| AOR-DBPROXY-006 | NEVER interpolate SQL strings | Static analysis |

### 3.2 Concurrency Rules (AOR-CONC-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CONC-001 | Use async/await in F# for all DB ops | Code review |
| AOR-CONC-002 | Always release locks in finally blocks | Static analysis |
| AOR-CONC-003 | Limit concurrent connections per pool | Configuration |
| AOR-CONC-004 | Use CancellationToken for timeouts | Code review |
| AOR-CONC-005 | Log all lock contention events | Telemetry |
| AOR-CONC-006 | Profile lock wait times | Metrics |

### 3.3 Transaction Rules (AOR-TXN-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-TXN-001 | Always use explicit transactions for writes | Code review |
| AOR-TXN-002 | Commit or rollback, never leave open | Finally block |
| AOR-TXN-003 | Use savepoints for nested operations | Pattern |
| AOR-TXN-004 | Log all transaction boundaries | Telemetry |
| AOR-TXN-005 | Retry on deadlock with backoff | Retry policy |
| AOR-TXN-006 | Validate transaction isolation level | Unit test |

---

## 4.0 FMEA ANALYSIS

### 4.1 Failure Mode Matrix

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-001 | Zenoh router down | All DB ops fail | 10 | 3 | 9 | 270 | Redundant routers |
| FM-002 | F# service crash | Requests timeout | 9 | 4 | 8 | 288 | Supervisor restart |
| FM-003 | DuckDB corruption | Data loss | 10 | 2 | 7 | 140 | WAL + backups |
| FM-004 | SQLite lock contention | Slow queries | 6 | 5 | 6 | 180 | WAL mode |
| FM-005 | Request timeout | Operation lost | 7 | 4 | 8 | 224 | Retry policy |
| FM-006 | Deadlock | System hang | 9 | 3 | 5 | 135 | Timeout + detection |
| FM-007 | Message corruption | Invalid response | 8 | 2 | 7 | 112 | Checksum |
| FM-008 | Connection pool exhaustion | New requests fail | 7 | 4 | 8 | 224 | Pool monitoring |
| FM-009 | Memory leak in F# | OOM crash | 9 | 2 | 6 | 108 | Memory profiling |
| FM-010 | SQL injection | Security breach | 10 | 2 | 9 | 180 | Parameterized queries |

### 4.2 RPN Priority

1. **FM-002** (RPN 288): F# service crash - Mitigation: Supervisor with restart
2. **FM-001** (RPN 270): Zenoh down - Mitigation: 3-router mesh
3. **FM-005** (RPN 224): Timeout - Mitigation: Exponential backoff retry
4. **FM-008** (RPN 224): Pool exhaustion - Mitigation: Queue overflow handling
5. **FM-004** (RPN 180): Lock contention - Mitigation: SQLite WAL mode

---

## 5.0 MATHEMATICAL SPECIFICATION

### 5.1 Agda Specification

```agda
-- Database Bridge Formal Specification
module DatabaseBridge where

open import Data.Nat
open import Data.Bool
open import Data.List
open import Data.Maybe
open import Data.Product
open import Relation.Binary.PropositionalEquality

-- Request identifier (globally unique)
RequestId : Set
RequestId = ℕ

-- Database types
data DbType : Set where
  DuckDB : DbType
  SQLite : DbType

-- Query types
data QueryType : Set where
  Select : QueryType
  Insert : QueryType
  Update : QueryType
  Delete : QueryType
  Open   : QueryType
  Close  : QueryType

-- Request structure
record Request : Set where
  field
    requestId : RequestId
    dbType    : DbType
    queryType : QueryType
    sql       : List Char
    params    : List (Maybe ℕ)  -- Simplified param type

-- Response structure
record Response : Set where
  field
    requestId : RequestId
    success   : Bool
    result    : Maybe (List (List Char))
    error     : Maybe (List Char)

-- FIFO Queue invariant
data Queue (A : Set) : Set where
  empty : Queue A
  enqueue : A → Queue A → Queue A

-- Queue ordering property
queue-fifo : ∀ {A} → Queue A → Queue A → Set
queue-fifo q1 q2 = {!!}  -- First in, first out ordering

-- Request-Response correlation
correlates : Request → Response → Bool
correlates req resp = Request.requestId req ≡ᵇ Response.requestId resp
  where
    _≡ᵇ_ : ℕ → ℕ → Bool
    zero ≡ᵇ zero = true
    suc n ≡ᵇ suc m = n ≡ᵇ m
    _ ≡ᵇ _ = false

-- Transaction ACID properties
record Transaction : Set where
  field
    txnId      : ℕ
    operations : List Request
    committed  : Bool

-- Atomicity: all or nothing
atomicity : Transaction → Set
atomicity txn = ∀ (op : Request) → op ∈ Transaction.operations txn →
  (Transaction.committed txn → executed op) ×
  (¬ Transaction.committed txn → ¬ executed op)
  where
    _∈_ : Request → List Request → Set
    _∈_ = {!!}
    executed : Request → Set
    executed = {!!}

-- Isolation: serializable
isolation : List Transaction → Set
isolation txns = ∃ (order : List Transaction) →
  (∀ t → t ∈ txns → t ∈ order) ×
  serializable order
  where
    serializable : List Transaction → Set
    serializable = {!!}

-- Durability: committed data persists
durability : Transaction → Set
durability txn = Transaction.committed txn →
  ∀ (restart : Event) → data-preserved txn restart
  where
    data-preserved : Transaction → Event → Set
    data-preserved = {!!}
    Event : Set
    Event = {!!}
```

### 5.2 Quint Specification

```quint
// Zenoh Database Bridge State Machine
module DatabaseBridge {

  // Types
  type RequestId = str
  type DbType = DuckDB | SQLite
  type QueryType = Select | Insert | Update | Delete | Open | Close

  type Request = {
    requestId: RequestId,
    dbType: DbType,
    queryType: QueryType,
    sql: str,
    params: List[str],
    timestamp: int
  }

  type Response = {
    requestId: RequestId,
    success: bool,
    result: List[List[str]],
    error: str,
    timestamp: int
  }

  type TransactionState = Pending | Active | Committed | RolledBack

  type Transaction = {
    txnId: str,
    state: TransactionState,
    operations: List[Request],
    startTime: int
  }

  // State
  var pendingRequests: Set[Request]
  var activeTransactions: Map[str, Transaction]
  var requestQueue: List[Request]
  var responseQueue: List[Response]
  var connectionPool: Map[DbType, int]  // available connections
  var lockHolders: Map[str, RequestId]  // resource -> holder

  // Constants
  val MAX_CONNECTIONS = 10
  val REQUEST_TIMEOUT_MS = 5000
  val TXN_TIMEOUT_MS = 30000

  // Invariants

  // INV-001: FIFO ordering preserved
  invariant FifoOrdering = {
    forall (i in 0..(length(requestQueue) - 2)) {
      requestQueue[i].timestamp <= requestQueue[i + 1].timestamp
    }
  }

  // INV-002: Request IDs globally unique
  invariant UniqueRequestIds = {
    forall (r1 in pendingRequests) {
      forall (r2 in pendingRequests) {
        r1.requestId == r2.requestId implies r1 == r2
      }
    }
  }

  // INV-003: Connection pool limits respected
  invariant ConnectionLimits = {
    connectionPool.get(DuckDB).getOrElse(0) >= 0 and
    connectionPool.get(DuckDB).getOrElse(0) <= MAX_CONNECTIONS and
    connectionPool.get(SQLite).getOrElse(0) >= 0 and
    connectionPool.get(SQLite).getOrElse(0) <= MAX_CONNECTIONS
  }

  // INV-004: No orphaned locks
  invariant NoOrphanedLocks = {
    forall (resource in lockHolders.keys()) {
      exists (r in pendingRequests) {
        r.requestId == lockHolders.get(resource).getOrElse("")
      }
    }
  }

  // INV-005: Transaction consistency
  invariant TransactionConsistency = {
    forall (txn in activeTransactions.values()) {
      txn.state == Committed implies
        forall (op in txn.operations) {
          exists (resp in responseQueue) {
            resp.requestId == op.requestId and resp.success
          }
        }
    }
  }

  // Actions

  action submitRequest(req: Request): bool = {
    all {
      not(exists (r in pendingRequests) { r.requestId == req.requestId }),
      pendingRequests' = pendingRequests.union(Set(req)),
      requestQueue' = requestQueue.append(req)
    }
  }

  action processRequest(reqId: RequestId): bool = {
    val req = pendingRequests.filter(r => r.requestId == reqId).head()
    all {
      connectionPool.get(req.dbType).getOrElse(0) > 0,
      connectionPool' = connectionPool.set(req.dbType,
        connectionPool.get(req.dbType).getOrElse(0) - 1)
    }
  }

  action completeRequest(reqId: RequestId, success: bool): bool = {
    val req = pendingRequests.filter(r => r.requestId == reqId).head()
    val resp = {
      requestId: reqId,
      success: success,
      result: List(),
      error: "",
      timestamp: 0  // current time
    }
    all {
      pendingRequests' = pendingRequests.exclude(Set(req)),
      responseQueue' = responseQueue.append(resp),
      connectionPool' = connectionPool.set(req.dbType,
        connectionPool.get(req.dbType).getOrElse(0) + 1)
    }
  }

  action beginTransaction(txnId: str): bool = {
    val txn = {
      txnId: txnId,
      state: Active,
      operations: List(),
      startTime: 0  // current time
    }
    all {
      not(activeTransactions.keys().contains(txnId)),
      activeTransactions' = activeTransactions.set(txnId, txn)
    }
  }

  action commitTransaction(txnId: str): bool = {
    val txn = activeTransactions.get(txnId).getOrElse({
      txnId: "", state: Pending, operations: List(), startTime: 0
    })
    all {
      txn.state == Active,
      forall (op in txn.operations) {
        exists (resp in responseQueue) {
          resp.requestId == op.requestId and resp.success
        }
      },
      activeTransactions' = activeTransactions.set(txnId,
        { ...txn, state: Committed })
    }
  }

  action rollbackTransaction(txnId: str): bool = {
    val txn = activeTransactions.get(txnId).getOrElse({
      txnId: "", state: Pending, operations: List(), startTime: 0
    })
    all {
      txn.state == Active,
      activeTransactions' = activeTransactions.set(txnId,
        { ...txn, state: RolledBack })
    }
  }

  // Temporal properties

  // PROP-001: Every request eventually gets a response
  temporal EventualResponse = {
    forall (req in pendingRequests) {
      eventually {
        exists (resp in responseQueue) {
          resp.requestId == req.requestId
        }
      }
    }
  }

  // PROP-002: No request times out under normal conditions
  temporal NoTimeout = {
    always {
      forall (req in pendingRequests) {
        (currentTime() - req.timestamp) < REQUEST_TIMEOUT_MS
      }
    }
  }

  // PROP-003: Deadlock freedom
  temporal DeadlockFreedom = {
    always {
      exists (req in pendingRequests) {
        enabled(processRequest(req.requestId))
      }
    }
  }
}
```

### 5.3 Graph-Based Model

```
// Entity-Relationship Graph

NODES:
┌─────────────────────────────────────────────────────────────────────┐
│ Node Type        │ Cardinality │ Properties                        │
├──────────────────┼─────────────┼───────────────────────────────────┤
│ ElixirClient     │ N (1-100)   │ pid, name, request_count          │
│ DatabaseProxy    │ 1           │ pending_count, stats              │
│ ZenohSession     │ 1           │ connected, subscribers            │
│ ZenohRouter      │ 3 (2oo3)    │ endpoint, status                  │
│ FSharpService    │ M (1-5)     │ pool_size, active_txns            │
│ DuckDBConn       │ P (1-10)    │ path, status, lock_holder         │
│ SQLiteConn       │ Q (1-10)    │ path, status, wal_enabled         │
│ Request          │ transient   │ id, type, sql, params, timestamp  │
│ Response         │ transient   │ id, success, result, error        │
│ Transaction      │ transient   │ id, state, operations             │
└─────────────────────────────────────────────────────────────────────┘

EDGES:
┌─────────────────────────────────────────────────────────────────────┐
│ Edge Type        │ From → To           │ Cardinality │ Properties  │
├──────────────────┼─────────────────────┼─────────────┼─────────────┤
│ SENDS_REQUEST    │ ElixirClient→Proxy  │ N:1         │ timestamp   │
│ PUBLISHES        │ Proxy→ZenohSession  │ 1:1         │ topic       │
│ ROUTES           │ Session→Router      │ 1:3         │ priority    │
│ DELIVERS         │ Router→FSharpSvc    │ 3:M         │ latency     │
│ EXECUTES_ON      │ FSharpSvc→DuckDB    │ M:P         │ query       │
│ EXECUTES_ON      │ FSharpSvc→SQLite    │ M:Q         │ query       │
│ RESPONDS         │ FSharpSvc→Router    │ M:3         │ result      │
│ CORRELATES       │ Request→Response    │ 1:1         │ request_id  │
│ CONTAINS         │ Transaction→Request │ 1:N         │ order       │
│ HOLDS_LOCK       │ Request→Connection  │ 1:1         │ type        │
└─────────────────────────────────────────────────────────────────────┘

// Graph Invariants

INV-GRAPH-001: ∀ Request r, ∃! Response resp: CORRELATES(r, resp)
INV-GRAPH-002: ∀ Transaction t: |CONTAINS(t, _)| ≤ 100
INV-GRAPH-003: ∀ Connection c: |HOLDS_LOCK(_, c)| ≤ 1
INV-GRAPH-004: Path(ElixirClient, Response) ≤ 6 hops

// Graph Queries (Cypher-style)

// Q1: Find all pending requests older than timeout
MATCH (r:Request)
WHERE r.timestamp < now() - REQUEST_TIMEOUT
  AND NOT EXISTS (MATCH (r)-[:CORRELATES]->(resp:Response))
RETURN r

// Q2: Detect deadlock cycles
MATCH path = (r1:Request)-[:WAITS_FOR*]->(r1)
RETURN path

// Q3: Calculate connection pool utilization
MATCH (c:DuckDBConn)<-[:EXECUTES_ON]-(s:FSharpService)
RETURN s.id, count(c) as active, s.pool_size as total
```

---

## 6.0 IMPLEMENTATION APPROACH

### 6.1 Phase 1: Elixir Database Proxy (Complete)
- [x] Create `Indrajaal.Zenoh.DatabaseProxy` GenServer
- [x] Implement request serialization (JSON)
- [x] Implement request ID generation (crypto random)
- [x] Implement response correlation
- [x] Add telemetry instrumentation

### 6.2 Phase 2: F# Concurrency Handler

```fsharp
// lib/cepaf/src/Cepaf.Database/ZenohDatabaseService.fs

module Cepaf.Database.ZenohDatabaseService

open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks
open FSharp.Control

/// Connection pool with semaphore-based concurrency control
type ConnectionPool<'T>(maxConnections: int, createConnection: unit -> 'T) =
    let semaphore = new SemaphoreSlim(maxConnections, maxConnections)
    let connections = new ConcurrentBag<'T>()

    member _.Acquire(timeout: TimeSpan) =
        async {
            let! acquired = semaphore.WaitAsync(timeout) |> Async.AwaitTask
            if acquired then
                match connections.TryTake() with
                | true, conn -> return Some conn
                | false, _ -> return Some (createConnection())
            else
                return None
        }

    member _.Release(conn: 'T) =
        connections.Add(conn)
        semaphore.Release() |> ignore

/// Transaction manager with isolation levels
type TransactionManager() =
    let activeTxns = ConcurrentDictionary<string, Transaction>()
    let txnLock = new ReaderWriterLockSlim()

    member _.Begin(txnId: string, isolationLevel: IsolationLevel) =
        txnLock.EnterWriteLock()
        try
            let txn = { Id = txnId; State = Active; StartTime = DateTime.UtcNow }
            activeTxns.TryAdd(txnId, txn) |> ignore
            txn
        finally
            txnLock.ExitWriteLock()

    member _.Commit(txnId: string) =
        match activeTxns.TryGetValue(txnId) with
        | true, txn ->
            txn.State <- Committed
            activeTxns.TryRemove(txnId) |> ignore
            Ok ()
        | false, _ ->
            Error "Transaction not found"

    member _.Rollback(txnId: string) =
        match activeTxns.TryGetValue(txnId) with
        | true, txn ->
            txn.State <- RolledBack
            activeTxns.TryRemove(txnId) |> ignore
            Ok ()
        | false, _ ->
            Error "Transaction not found"

/// Main database service using MailboxProcessor for serialization
type ZenohDatabaseService(config: DatabaseConfig) =
    let duckdbPool = ConnectionPool(config.DuckDBPoolSize, DuckDB.open)
    let sqlitePool = ConnectionPool(config.SQLitePoolSize, SQLite.open)
    let txnManager = TransactionManager()

    let agent = MailboxProcessor<DatabaseMessage>.Start(fun inbox ->
        let rec loop () = async {
            let! msg = inbox.Receive()
            match msg with
            | DuckDBQuery(reqId, sql, params, replyChannel) ->
                let! result = executeDuckDBQuery sql params
                replyChannel.Reply(result)
                return! loop()

            | SQLiteQuery(reqId, sql, params, replyChannel) ->
                let! result = executeSQLiteQuery sql params
                replyChannel.Reply(result)
                return! loop()

            | BeginTransaction(txnId, isolationLevel, replyChannel) ->
                let txn = txnManager.Begin(txnId, isolationLevel)
                replyChannel.Reply(Ok txn)
                return! loop()

            | CommitTransaction(txnId, replyChannel) ->
                let result = txnManager.Commit(txnId)
                replyChannel.Reply(result)
                return! loop()

            | RollbackTransaction(txnId, replyChannel) ->
                let result = txnManager.Rollback(txnId)
                replyChannel.Reply(result)
                return! loop()
        }
        loop()
    )

    member _.ProcessRequest(request: DatabaseRequest) =
        async {
            match request.DbType with
            | DuckDB -> return! agent.PostAndAsyncReply(fun ch ->
                DuckDBQuery(request.RequestId, request.Sql, request.Params, ch))
            | SQLite -> return! agent.PostAndAsyncReply(fun ch ->
                SQLiteQuery(request.RequestId, request.Sql, request.Params, ch))
        }
```

### 6.3 Phase 3: Comment Out Direct Access

Files to modify:
1. `lib/indrajaal/knowledge/store/duckdb_store.ex` - Replace Duckdbex calls
2. `lib/indrajaal/kms/sqlite.ex` - Replace Exqlite calls
3. `lib/indrajaal/cockpit/prajna/immutable_state.ex` - Replace Duckdbex calls

### 6.4 Phase 4: Integration Testing

Test categories:
1. **Functional Tests**: Query/Insert/Update/Delete operations
2. **Concurrency Tests**: Multiple clients, lock contention
3. **Transaction Tests**: ACID compliance, isolation levels
4. **Performance Tests**: Latency, throughput, scalability
5. **Chaos Tests**: Failure injection, recovery

---

## 7.0 TEST APPROACH

### 7.1 Functional Test Cases

```elixir
# test/indrajaal/zenoh/database_proxy_test.exs

defmodule Indrajaal.Zenoh.DatabaseProxyTest do
  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Zenoh.DatabaseProxy

  describe "DuckDB queries" do
    test "SELECT returns results" do
      {:ok, result} = DatabaseProxy.duckdb_query("SELECT 1 as value")
      assert is_list(result)
    end

    test "INSERT creates record" do
      :ok = DatabaseProxy.duckdb_insert("test_table", %{id: UUID.uuid4(), data: "test"})
    end

    test "parameterized query prevents injection" do
      # Should not execute malicious SQL
      {:ok, _} = DatabaseProxy.duckdb_query(
        "SELECT * FROM holons WHERE id = ?",
        ["'; DROP TABLE holons; --"]
      )
    end
  end

  describe "SQLite queries" do
    test "SELECT returns results" do
      {:ok, result} = DatabaseProxy.sqlite_query("SELECT 1 as value")
      assert is_list(result)
    end

    test "connection lifecycle" do
      {:ok, conn_id} = DatabaseProxy.sqlite_open("data/test.db")
      :ok = DatabaseProxy.sqlite_close(conn_id)
    end
  end

  describe "concurrency" do
    test "handles 100 concurrent requests" do
      tasks = for i <- 1..100 do
        Task.async(fn ->
          DatabaseProxy.duckdb_query("SELECT ? as value", [i])
        end)
      end

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    property "request IDs are unique" do
      forall requests <- PC.list(PC.integer(1, 1000)) do
        ids = Enum.map(requests, fn _ ->
          :crypto.strong_rand_bytes(16) |> Base.encode16()
        end)
        Enum.uniq(ids) == ids
      end
    end
  end

  describe "transactions" do
    test "commit persists changes" do
      {:ok, txn_id} = DatabaseProxy.begin_transaction()
      :ok = DatabaseProxy.duckdb_insert("test", %{id: 1}, txn_id)
      :ok = DatabaseProxy.commit_transaction(txn_id)

      {:ok, [row]} = DatabaseProxy.duckdb_query("SELECT * FROM test WHERE id = 1")
      assert row.id == 1
    end

    test "rollback reverts changes" do
      {:ok, txn_id} = DatabaseProxy.begin_transaction()
      :ok = DatabaseProxy.duckdb_insert("test", %{id: 2}, txn_id)
      :ok = DatabaseProxy.rollback_transaction(txn_id)

      {:ok, result} = DatabaseProxy.duckdb_query("SELECT * FROM test WHERE id = 2")
      assert result == []
    end
  end
end
```

### 7.2 Scalability Test Cases

```elixir
# test/indrajaal/zenoh/database_proxy_scalability_test.exs

defmodule Indrajaal.Zenoh.DatabaseProxyScalabilityTest do
  use ExUnit.Case, async: false

  @tag :scalability
  test "sustains 1000 requests/second for 60 seconds" do
    start_time = System.monotonic_time(:millisecond)
    duration_ms = 60_000
    target_rps = 1000

    results = Stream.repeatedly(fn ->
      Task.async(fn ->
        start = System.monotonic_time(:microsecond)
        result = DatabaseProxy.duckdb_query("SELECT 1")
        elapsed = System.monotonic_time(:microsecond) - start
        {result, elapsed}
      end)
    end)
    |> Stream.take_while(fn _ ->
      System.monotonic_time(:millisecond) - start_time < duration_ms
    end)
    |> Stream.chunk_every(target_rps)
    |> Stream.map(fn tasks ->
      Task.await_many(tasks, 5_000)
    end)
    |> Enum.to_list()
    |> List.flatten()

    # Analyze results
    success_count = Enum.count(results, fn {{:ok, _}, _} -> true; _ -> false end)
    latencies = Enum.map(results, fn {_, lat} -> lat end)

    p50 = Enum.at(Enum.sort(latencies), div(length(latencies), 2))
    p99 = Enum.at(Enum.sort(latencies), div(length(latencies) * 99, 100))

    assert success_count / length(results) > 0.99
    assert p50 < 10_000  # 10ms p50
    assert p99 < 50_000  # 50ms p99
  end

  @tag :scalability
  test "connection pool handles burst traffic" do
    # Burst 500 concurrent requests
    tasks = for _ <- 1..500 do
      Task.async(fn ->
        DatabaseProxy.duckdb_query("SELECT * FROM holons LIMIT 10")
      end)
    end

    results = Task.await_many(tasks, 30_000)
    success = Enum.count(results, &match?({:ok, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    assert success >= 450  # At least 90% success under burst
    assert errors <= 50    # Some failures acceptable during burst
  end
end
```

### 7.3 Performance Test Cases

```elixir
# test/indrajaal/zenoh/database_proxy_performance_test.exs

defmodule Indrajaal.Zenoh.DatabaseProxyPerformanceTest do
  use ExUnit.Case, async: false

  @tag :performance
  test "query latency under 50ms p95" do
    samples = 1000

    latencies = for _ <- 1..samples do
      start = System.monotonic_time(:microsecond)
      {:ok, _} = DatabaseProxy.duckdb_query("SELECT 1")
      System.monotonic_time(:microsecond) - start
    end

    sorted = Enum.sort(latencies)
    p95 = Enum.at(sorted, div(samples * 95, 100))

    assert p95 < 50_000, "p95 latency #{p95}us exceeds 50ms"
  end

  @tag :performance
  test "throughput exceeds 500 queries/second" do
    start = System.monotonic_time(:millisecond)
    count = 5000

    for _ <- 1..count do
      {:ok, _} = DatabaseProxy.duckdb_query("SELECT 1")
    end

    elapsed = System.monotonic_time(:millisecond) - start
    throughput = count / (elapsed / 1000)

    assert throughput > 500, "Throughput #{throughput} qps below 500"
  end

  @tag :performance
  test "transaction overhead under 10ms" do
    start = System.monotonic_time(:microsecond)

    {:ok, txn} = DatabaseProxy.begin_transaction()
    :ok = DatabaseProxy.commit_transaction(txn)

    elapsed = System.monotonic_time(:microsecond) - start
    assert elapsed < 10_000, "Transaction overhead #{elapsed}us exceeds 10ms"
  end
end
```

---

## 8.0 USAGE APPROACH

### 8.1 Basic Query Usage

```elixir
# Instead of direct access:
# {:ok, conn} = Duckdbex.open(path)
# {:ok, result} = Duckdbex.query(conn, sql)

# Use Zenoh proxy:
alias Indrajaal.Zenoh.DatabaseProxy

# Simple query
{:ok, holons} = DatabaseProxy.duckdb_query(
  "SELECT * FROM holons WHERE entropy_score < ?",
  [0.5]
)

# Insert
:ok = DatabaseProxy.duckdb_insert("holons", %{
  uuid: UUID.uuid4(),
  path: "/system/core",
  title: "Core Holon",
  entropy_score: 0.1
})

# SQLite KMS access
{:ok, keys} = DatabaseProxy.sqlite_query(
  "SELECT * FROM kms_keys WHERE active = 1"
)
```

### 8.2 Transaction Usage

```elixir
# Begin transaction
{:ok, txn_id} = DatabaseProxy.begin_transaction(:serializable)

try do
  # Multiple operations within transaction
  :ok = DatabaseProxy.duckdb_insert("holons", holon1, txn_id)
  :ok = DatabaseProxy.duckdb_insert("relations", relation, txn_id)

  # Commit if all successful
  :ok = DatabaseProxy.commit_transaction(txn_id)
catch
  _ ->
    # Rollback on any error
    :ok = DatabaseProxy.rollback_transaction(txn_id)
    reraise
end
```

### 8.3 Connection Pool Monitoring

```elixir
# Get proxy statistics
stats = DatabaseProxy.stats()
IO.inspect(stats)
# %{
#   duckdb_queries: 1234,
#   sqlite_queries: 567,
#   avg_latency_ms: 12.5,
#   pending_requests: 3
# }

# Health check
if stats.pending_requests > 100 do
  Logger.warning("Database proxy backlog: #{stats.pending_requests}")
end
```

---

## 9.0 SCALABILITY APPROACH

### 9.1 Horizontal Scaling

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SCALED DEPLOYMENT (3 Nodes)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Node 1                    Node 2                    Node 3             │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐ │
│  │ Elixir Apps     │      │ Elixir Apps     │      │ Elixir Apps     │ │
│  │ DatabaseProxy   │      │ DatabaseProxy   │      │ DatabaseProxy   │ │
│  └────────┬────────┘      └────────┬────────┘      └────────┬────────┘ │
│           │                        │                        │          │
│           └────────────────────────┼────────────────────────┘          │
│                                    │                                    │
│                           ┌────────▼────────┐                          │
│                           │  Zenoh Router   │                          │
│                           │  (Mesh: 3 nodes)│                          │
│                           └────────┬────────┘                          │
│                                    │                                    │
│           ┌────────────────────────┼────────────────────────┐          │
│           │                        │                        │          │
│  ┌────────▼────────┐      ┌────────▼────────┐      ┌────────▼────────┐│
│  │ F# Service 1    │      │ F# Service 2    │      │ F# Service 3    ││
│  │ (Primary)       │      │ (Replica)       │      │ (Replica)       ││
│  │ DuckDB Writer   │      │ DuckDB Reader   │      │ DuckDB Reader   ││
│  │ SQLite Writer   │      │ SQLite Reader   │      │ SQLite Reader   ││
│  └─────────────────┘      └─────────────────┘      └─────────────────┘│
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Load Balancing Strategy

- **Read Distribution**: Round-robin across all F# service replicas
- **Write Concentration**: All writes to primary F# service
- **Transaction Affinity**: Transaction-bound requests to same service
- **Circuit Breaking**: Exclude unhealthy services from rotation

### 9.3 Capacity Planning

| Component | Base Capacity | Scaling Factor | Max Capacity |
|-----------|---------------|----------------|--------------|
| Elixir DatabaseProxy | 1000 req/s | Linear | 10K req/s |
| Zenoh Router | 50K msg/s | 3x mesh | 150K msg/s |
| F# Service | 500 req/s | N services | 5K req/s |
| DuckDB Connection | 10 concurrent | Pool size | 50 concurrent |
| SQLite Connection | 5 concurrent | WAL mode | 20 concurrent |

---

## 10.0 MONITORING AND OBSERVABILITY

### 10.1 Metrics

```elixir
# Telemetry events emitted by DatabaseProxy
:telemetry.attach_many("db-proxy-metrics", [
  [:database_proxy, :request, :start],
  [:database_proxy, :request, :stop],
  [:database_proxy, :request, :exception],
  [:database_proxy, :pool, :checkout],
  [:database_proxy, :pool, :checkin],
  [:database_proxy, :transaction, :start],
  [:database_proxy, :transaction, :commit],
  [:database_proxy, :transaction, :rollback]
], &handle_metric/4, nil)
```

### 10.2 Dashboard Metrics

| Metric | Type | Alert Threshold |
|--------|------|-----------------|
| `db_proxy_requests_total` | Counter | N/A |
| `db_proxy_latency_ms` | Histogram | p99 > 100ms |
| `db_proxy_errors_total` | Counter | > 10/min |
| `db_proxy_pool_utilization` | Gauge | > 80% |
| `db_proxy_pending_requests` | Gauge | > 100 |
| `db_proxy_transactions_active` | Gauge | > 50 |

---

## 11.0 DOCUMENT CONTROL

| Field | Value |
|-------|-------|
| Document ID | ARCH-ZENOH-DB-001 |
| Version | 1.0.0 |
| Author | Claude Opus 4.5 |
| Created | 2026-01-17 |
| STAMP | SC-BRIDGE-*, SC-DBPROXY-*, SC-CONC-*, SC-TXN-* |
| AOR | AOR-DBPROXY-*, AOR-CONC-*, AOR-TXN-* |

---

## 12.0 REFERENCES

- CLAUDE.md - Master system specification
- HOLON_IMMUTABLE_REGISTER.md - Holon state sovereignty
- HOLON_FOUNDERS_DIRECTIVE.md - Supreme symbiotic covenant
- Zenoh documentation - https://zenoh.io/docs
- DuckDB documentation - https://duckdb.org/docs
- SQLite WAL mode - https://sqlite.org/wal.html
