# Cross-Holon Database Access Specification

**Version**: 1.0.0 | **Date**: 2026-01-17 | **Status**: ACTIVE
**STAMP**: SC-XHOLON-001 to SC-XHOLON-050
**Compliance**: IEC 61508 SIL-6, SC-HOLON-*, SC-DBNAME-*

---

## 1.0 Executive Summary

This specification defines the architecture for bidirectional database access between Elixir and F# holons in the Indrajaal biomorphic mesh. The design ensures:

1. **Direct Access**: Each holon accesses its own SQLite/DuckDB via native high-performance libraries
2. **Cross-Holon Access**: Elixir ↔ F# access via Zenoh pub/sub with full transaction semantics
3. **Concurrency**: Lock-free concurrent access with optimistic concurrency control
4. **Scalability**: Horizontal scaling via Zenoh mesh topology
5. **Safety**: STAMP-verified, FMEA-analyzed, formally proven (Agda/Quint)

---

## 2.0 Universal Holon Identifier (UHI) Database Naming

### 2.1 UHI Format

```
{runtime}:{layer}:{domain}:{type}:{instance}:{database}

Examples:
  ex:l3:kms:srv:main:state       → Elixir KMS SQLite state
  ex:l3:kms:srv:main:analytics   → Elixir KMS DuckDB analytics
  fs:l4:ctx:srv:cortex:vectors   → F# Cortex SQLite vectors
  fs:l4:ctx:srv:cortex:history   → F# Cortex DuckDB history
```

### 2.2 Runtime Identifiers

| Runtime | Code | Native Libraries |
|---------|------|------------------|
| Elixir | `ex` | Exqlite (SQLite), Duckdbex (DuckDB) |
| F# | `fs` | Microsoft.Data.Sqlite, DuckDB.NET |
| Zig | `zig` | sqlite3, duckdb-zig |
| Rust | `rs` | rusqlite, duckdb-rs |

### 2.3 Database Type Extensions

| Type | Extension | Engine | Purpose |
|------|-----------|--------|---------|
| state | .sqlite | SQLite WAL | OLTP real-time state |
| analytics | .duckdb | DuckDB | OLAP columnar analytics |
| history | .duckdb | DuckDB | Append-only evolution |
| vectors | .sqlite | SQLite | Vector embeddings |
| register | .duckdb | DuckDB | Immutable blockchain |
| cache | .sqlite | SQLite | Temporary cache |

### 2.4 Directory Structure

```
data/holons/
├── ex/                                    # Elixir Runtime
│   ├── l3/                                # L3 - Holon Layer
│   │   ├── kms/                           # Knowledge Management
│   │   │   └── main/
│   │   │       ├── state.sqlite           # ex:l3:kms:srv:main:state
│   │   │       ├── analytics.duckdb       # ex:l3:kms:srv:main:analytics
│   │   │       ├── history.duckdb         # ex:l3:kms:srv:main:history
│   │   │       └── vectors.sqlite         # ex:l3:kms:srv:main:vectors
│   │   ├── prj/                           # Prajna C3I
│   │   │   └── prajna/
│   │   │       ├── state.sqlite           # ex:l3:prj:srv:prajna:state
│   │   │       └── register.duckdb        # ex:l3:prj:srv:prajna:register
│   │   ├── grd/                           # Guardian
│   │   │   └── main/
│   │   │       └── state.sqlite           # ex:l3:grd:srv:main:state
│   │   └── snt/                           # Sentinel
│   │       └── main/
│   │           └── state.sqlite           # ex:l3:snt:srv:main:state
│   └── l5/                                # L5 - Node Layer
│       └── fnd/                           # Founder
│           └── founder/
│               ├── state.sqlite           # ex:l5:fnd:reg:founder:state
│               └── history.duckdb         # ex:l5:fnd:reg:founder:history
│
└── fs/                                    # F# Runtime
    └── l4/                                # L4 - Container Layer
        ├── ctx/                           # Cortex (AI)
        │   └── cortex/
        │       ├── state.sqlite           # fs:l4:ctx:srv:cortex:state
        │       ├── vectors.sqlite         # fs:l4:ctx:srv:cortex:vectors
        │       └── history.duckdb         # fs:l4:ctx:srv:cortex:history
        ├── pln/                           # Planning
        │   └── main/
        │       └── state.sqlite           # fs:l4:pln:srv:main:state
        └── obs/                           # Observability
            └── main/
                └── analytics.duckdb       # fs:l4:obs:srv:main:analytics
```

---

## 3.0 Access Architecture

### 3.1 Three Access Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CROSS-HOLON DATABASE ACCESS ARCHITECTURE                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PATTERN 1: DIRECT ACCESS (Same Runtime)                                    │
│  ═══════════════════════════════════════                                    │
│                                                                              │
│  ┌──────────────┐         ┌──────────────┐                                  │
│  │ Elixir Holon │ ──────► │ SQLite/DuckDB│  (Exqlite/Duckdbex)              │
│  └──────────────┘         └──────────────┘                                  │
│                                                                              │
│  ┌──────────────┐         ┌──────────────┐                                  │
│  │  F# Holon    │ ──────► │ SQLite/DuckDB│  (Microsoft.Data.Sqlite/DuckDB.NET)
│  └──────────────┘         └──────────────┘                                  │
│                                                                              │
│  PATTERN 2: CROSS-HOLON ACCESS (Different Runtime)                          │
│  ════════════════════════════════════════════════                           │
│                                                                              │
│  ┌──────────────┐    ┌───────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ Elixir Holon │───►│ Zenoh │───►│  F# Bridge   │───►│ SQLite/DuckDB│     │
│  │   Client     │◄───│ Mesh  │◄───│   Service    │◄───│  (F# Holon)  │     │
│  └──────────────┘    └───────┘    └──────────────┘    └──────────────┘     │
│                                                                              │
│  ┌──────────────┐    ┌───────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  F# Holon    │───►│ Zenoh │───►│Elixir Bridge │───►│ SQLite/DuckDB│     │
│  │   Client     │◄───│ Mesh  │◄───│   Service    │◄───│(Elixir Holon)│     │
│  └──────────────┘    └───────┘    └──────────────┘    └──────────────┘     │
│                                                                              │
│  PATTERN 3: MULTI-CLIENT CONCURRENT ACCESS                                  │
│  ═══════════════════════════════════════════                                │
│                                                                              │
│  ┌────────┐                                                                 │
│  │Client 1│──┐                                                              │
│  └────────┘  │     ┌───────────────┐    ┌─────────────────┐                │
│  ┌────────┐  │     │               │    │ Concurrency     │                │
│  │Client 2│──┼────►│  Zenoh Mesh   │───►│ Handler         │───► DB         │
│  └────────┘  │     │               │    │ (OCC + Locking) │                │
│  ┌────────┐  │     └───────────────┘    └─────────────────┘                │
│  │Client N│──┘                                                              │
│  └────────┘                                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Zenoh Topic Structure

```
indrajaal/db/{source_runtime}/{source_holon}/request/{target_runtime}/{target_holon}/{db_type}
indrajaal/db/{source_runtime}/{source_holon}/response/{request_id}

Examples:
  indrajaal/db/ex/kms/request/fs/cortex/vectors    # Elixir KMS → F# Cortex vectors
  indrajaal/db/fs/cortex/request/ex/kms/analytics  # F# Cortex → Elixir KMS analytics
  indrajaal/db/ex/kms/response/req-12345           # Response to request
```

### 3.3 Message Protocol

```json
{
  "version": "1.0",
  "request_id": "req-uuid-12345",
  "source_holon": "ex:l3:kms:srv:main",
  "target_holon": "fs:l4:ctx:srv:cortex",
  "target_db": "vectors",
  "operation": {
    "type": "query|execute|transaction",
    "sql": "SELECT * FROM embeddings WHERE model = ?",
    "params": ["text-embedding-3-small"],
    "isolation": "serializable",
    "timeout_ms": 5000
  },
  "transaction": {
    "id": "txn-uuid-67890",
    "action": "begin|commit|rollback|savepoint|release"
  },
  "timestamp": "2026-01-17T12:00:00.000Z",
  "correlation_id": "corr-uuid-11111"
}
```

---

## 4.0 Elixir Direct Database Access

### 4.1 Architecture

```elixir
┌─────────────────────────────────────────────────────────────┐
│                    ELIXIR HOLON DATABASE STACK               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Application Layer                                           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  HolonDatabase (GenServer)                          │    │
│  │  - Manages connections to SQLite + DuckDB           │    │
│  │  - Provides unified API                             │    │
│  │  - Handles concurrency                              │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                           │                      │
│           ▼                           ▼                      │
│  ┌─────────────────┐        ┌─────────────────┐             │
│  │ SQLitePool      │        │ DuckDBPool      │             │
│  │ (Exqlite)       │        │ (Duckdbex)      │             │
│  │ - WAL mode      │        │ - Columnar      │             │
│  │ - Connection    │        │ - OLAP queries  │             │
│  │   pooling       │        │ - Append-only   │             │
│  └─────────────────┘        └─────────────────┘             │
│           │                           │                      │
│           ▼                           ▼                      │
│  ┌─────────────────┐        ┌─────────────────┐             │
│  │ state.sqlite    │        │ analytics.duckdb│             │
│  │ vectors.sqlite  │        │ history.duckdb  │             │
│  │ cache.sqlite    │        │ register.duckdb │             │
│  └─────────────────┘        └─────────────────┘             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Concurrency Model

```elixir
# Elixir Concurrency Handler
defmodule Indrajaal.Holon.Database.ConcurrencyHandler do
  @moduledoc """
  Optimistic Concurrency Control (OCC) with version vectors.

  CONSTRAINTS:
    - SC-XHOLON-010: Lock-free reads
    - SC-XHOLON-011: Version vector conflict detection
    - SC-XHOLON-012: Automatic retry with exponential backoff
  """

  @type version_vector :: %{node_id => non_neg_integer()}
  @type conflict_resolution :: :last_write_wins | :merge | :reject

  # OCC Protocol:
  # 1. Read with version vector
  # 2. Modify locally
  # 3. Compare-and-swap on write
  # 4. Retry on conflict
end
```

### 4.3 Transaction Semantics

| Isolation Level | SQLite | DuckDB | Use Case |
|-----------------|--------|--------|----------|
| READ_UNCOMMITTED | Yes | N/A | Fast dirty reads |
| READ_COMMITTED | Yes | Yes | Default for analytics |
| REPEATABLE_READ | Yes | Yes | Consistent snapshots |
| SERIALIZABLE | Yes | Yes | Critical mutations |

---

## 5.0 F# Direct Database Access

### 5.1 Architecture

```fsharp
┌─────────────────────────────────────────────────────────────┐
│                    F# HOLON DATABASE STACK                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Application Layer                                           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  HolonDatabase (MailboxProcessor)                   │    │
│  │  - Actor-based message processing                   │    │
│  │  - Async/await patterns                             │    │
│  │  - Connection multiplexing                          │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                           │                      │
│           ▼                           ▼                      │
│  ┌─────────────────┐        ┌─────────────────┐             │
│  │ SqlitePool      │        │ DuckDBPool      │             │
│  │ (Microsoft.Data │        │ (DuckDB.NET)    │             │
│  │  .Sqlite)       │        │ - High perf     │             │
│  │ - Pooled conns  │        │ - Columnar ops  │             │
│  └─────────────────┘        └─────────────────┘             │
│           │                           │                      │
│           ▼                           ▼                      │
│  ┌─────────────────┐        ┌─────────────────┐             │
│  │ state.sqlite    │        │ analytics.duckdb│             │
│  │ vectors.sqlite  │        │ history.duckdb  │             │
│  └─────────────────┘        └─────────────────┘             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Concurrency Model

```fsharp
/// F# Concurrency Handler using Software Transactional Memory (STM)
module Cepaf.Holon.Database.ConcurrencyHandler

open System.Threading

/// Version vector for OCC
type VersionVector = Map<string, uint64>

/// Conflict resolution strategy
type ConflictResolution =
    | LastWriteWins
    | Merge of (obj -> obj -> obj)
    | Reject

/// Transaction context
type TransactionContext = {
    TxnId: string
    StartVersion: VersionVector
    Isolation: IsolationLevel
    Timeout: TimeSpan
    Savepoints: string list
}

/// Compare-and-swap with retry
let casWithRetry (maxRetries: int) (operation: unit -> Async<Result<'T, string>>) =
    let rec loop attempt =
        async {
            match! operation() with
            | Ok result -> return Ok result
            | Error "CONFLICT" when attempt < maxRetries ->
                do! Async.Sleep(int (Math.Pow(2.0, float attempt) * 100.0))
                return! loop (attempt + 1)
            | Error msg -> return Error msg
        }
    loop 0
```

---

## 6.0 Zenoh Cross-Holon Bridge

### 6.1 Bridge Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ZENOH CROSS-HOLON BRIDGE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────┐                    ┌──────────────────────┐       │
│  │   ELIXIR HOLON       │                    │      F# HOLON        │       │
│  │                      │                    │                      │       │
│  │ ┌──────────────────┐ │                    │ ┌──────────────────┐ │       │
│  │ │ ZenohDBClient    │ │                    │ │ ZenohDBClient    │ │       │
│  │ │ - Request/Reply  │ │                    │ │ - Request/Reply  │ │       │
│  │ │ - Transaction mgr│ │                    │ │ - Transaction mgr│ │       │
│  │ └────────┬─────────┘ │                    │ └────────┬─────────┘ │       │
│  │          │           │                    │          │           │       │
│  │ ┌────────▼─────────┐ │                    │ ┌────────▼─────────┐ │       │
│  │ │ ZenohDBServer    │ │                    │ │ ZenohDBServer    │ │       │
│  │ │ - Listen for req │ │                    │ │ - Listen for req │ │       │
│  │ │ - Execute local  │ │                    │ │ - Execute local  │ │       │
│  │ └────────┬─────────┘ │                    │ └────────┬─────────┘ │       │
│  │          │           │                    │          │           │       │
│  │ ┌────────▼─────────┐ │                    │ ┌────────▼─────────┐ │       │
│  │ │ HolonDatabase    │ │                    │ │ HolonDatabase    │ │       │
│  │ │ (Direct Access)  │ │                    │ │ (Direct Access)  │ │       │
│  │ └──────────────────┘ │                    │ └──────────────────┘ │       │
│  └──────────┬───────────┘                    └──────────┬───────────┘       │
│             │                                           │                    │
│             │         ┌───────────────────┐             │                    │
│             └────────►│   ZENOH ROUTER    │◄────────────┘                    │
│                       │   (7447/7448/7449)│                                  │
│                       │   2oo3 Redundancy │                                  │
│                       └───────────────────┘                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Transaction Protocol (Two-Phase Commit)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TWO-PHASE COMMIT OVER ZENOH                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Coordinator (Elixir)              Participant (F#)                         │
│       │                                  │                                   │
│       │────── PREPARE (txn_id) ─────────►│                                   │
│       │                                  │ ◄─ Lock resources                 │
│       │◄───── VOTE (ready/abort) ────────│                                   │
│       │                                  │                                   │
│       │ [If all ready]                   │                                   │
│       │────── COMMIT (txn_id) ──────────►│                                   │
│       │                                  │ ◄─ Apply changes                  │
│       │◄───── ACK ───────────────────────│                                   │
│       │                                  │                                   │
│       │ [If any abort]                   │                                   │
│       │────── ROLLBACK (txn_id) ────────►│                                   │
│       │                                  │ ◄─ Release locks                  │
│       │◄───── ACK ───────────────────────│                                   │
│       │                                  │                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7.0 STAMP Constraints

### 7.1 Core Constraints (SC-XHOLON-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-001 | Each holon MUST have isolated database files | CRITICAL | Directory structure |
| SC-XHOLON-002 | Direct access MUST use native high-perf libraries | CRITICAL | Library check |
| SC-XHOLON-003 | Cross-holon access MUST use Zenoh bridge | CRITICAL | Protocol verification |
| SC-XHOLON-004 | All operations MUST have timeout < 5s | HIGH | Telemetry |
| SC-XHOLON-005 | Transaction isolation MUST be configurable | HIGH | API verification |
| SC-XHOLON-006 | Concurrent access MUST use OCC or locking | CRITICAL | Race condition test |
| SC-XHOLON-007 | Version vectors MUST be monotonically increasing | CRITICAL | Formal proof |
| SC-XHOLON-008 | Cross-holon transactions MUST use 2PC | CRITICAL | Protocol verification |
| SC-XHOLON-009 | All failures MUST trigger automatic retry | HIGH | Chaos testing |
| SC-XHOLON-010 | Read operations MUST be lock-free | HIGH | Performance test |

### 7.2 Performance Constraints

| ID | Constraint | Severity | Target |
|----|------------|----------|--------|
| SC-XHOLON-020 | Local SQLite read latency | HIGH | < 1ms |
| SC-XHOLON-021 | Local DuckDB query latency | HIGH | < 10ms |
| SC-XHOLON-022 | Cross-holon request latency | HIGH | < 50ms |
| SC-XHOLON-023 | Transaction commit latency | HIGH | < 100ms |
| SC-XHOLON-024 | Concurrent throughput | HIGH | > 10k ops/sec |
| SC-XHOLON-025 | Connection pool utilization | MEDIUM | > 80% |

### 7.3 Safety Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-030 | No data loss on crash | CRITICAL | WAL verification |
| SC-XHOLON-031 | ACID compliance mandatory | CRITICAL | Transaction tests |
| SC-XHOLON-032 | No deadlocks permitted | CRITICAL | Formal proof |
| SC-XHOLON-033 | No starvation permitted | CRITICAL | Fairness proof |
| SC-XHOLON-034 | Rollback always possible | CRITICAL | Recovery test |
| SC-XHOLON-035 | Audit trail immutable | CRITICAL | Append-only verification |

---

## 8.0 Agent Operating Rules (AOR)

### 8.1 Database Access Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-XHOLON-001 | ALWAYS use connection pooling | Code review |
| AOR-XHOLON-002 | NEVER access other holon's DB directly | Architecture enforcement |
| AOR-XHOLON-003 | ALWAYS set query timeout | API design |
| AOR-XHOLON-004 | ALWAYS use parameterized queries | Code analysis |
| AOR-XHOLON-005 | ALWAYS close transactions explicitly | Linter rule |
| AOR-XHOLON-006 | NEVER hold locks across Zenoh calls | Protocol design |
| AOR-XHOLON-007 | ALWAYS log database operations | Telemetry wrapper |
| AOR-XHOLON-008 | ALWAYS validate input before query | Input validation |

### 8.2 Concurrency Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-XHOLON-010 | PREFER optimistic concurrency | Design pattern |
| AOR-XHOLON-011 | RETRY on conflict with backoff | Error handler |
| AOR-XHOLON-012 | LIMIT retry attempts to 3 | Configuration |
| AOR-XHOLON-013 | USE version vectors for CAS | Protocol |
| AOR-XHOLON-014 | RELEASE locks in finally block | Code pattern |

### 8.3 Cross-Holon Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-XHOLON-020 | VERIFY target holon exists | Discovery check |
| AOR-XHOLON-021 | HANDLE timeout gracefully | Error handling |
| AOR-XHOLON-022 | CIRCUIT BREAK on repeated failures | Circuit breaker |
| AOR-XHOLON-023 | LOG all cross-holon operations | Telemetry |
| AOR-XHOLON-024 | COMPRESS large payloads | Protocol |

---

## 9.0 FMEA Analysis

### 9.1 Failure Mode Matrix

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Database corruption | Data loss | 10 | 1 | 3 | 30 | WAL + checksums |
| Connection exhaustion | Service unavailable | 8 | 3 | 5 | 120 | Connection pooling |
| Deadlock | Transaction hang | 9 | 2 | 4 | 72 | Timeout + detection |
| Network partition | Cross-holon failure | 7 | 4 | 6 | 168 | Retry + circuit breaker |
| Version conflict | Write failure | 5 | 6 | 2 | 60 | OCC retry |
| Query timeout | Operation failure | 6 | 5 | 3 | 90 | Timeout handling |
| Memory exhaustion | Process crash | 9 | 2 | 4 | 72 | Memory limits |
| Disk full | Write failure | 8 | 2 | 3 | 48 | Monitoring + alerts |
| Schema mismatch | Query failure | 7 | 3 | 5 | 105 | Migration versioning |
| Zenoh router failure | Bridge unavailable | 8 | 2 | 4 | 64 | 2oo3 redundancy |

### 9.2 Critical Path Analysis

```
Risk Priority Number (RPN) Thresholds:
  RPN < 50:   LOW RISK    - Monitor
  RPN 50-100: MEDIUM RISK - Mitigate
  RPN > 100:  HIGH RISK   - Immediate action required

High Risk Items (RPN > 100):
  1. Network partition (168) → Circuit breaker + retry
  2. Connection exhaustion (120) → Pool sizing + monitoring
  3. Schema mismatch (105) → Version control + migration
```

---

## 10.0 Mathematical Specification

### 10.1 Agda Specification

```agda
-- Cross-Holon Database Access Formal Specification
module CrossHolonDB where

open import Data.Nat
open import Data.Bool
open import Data.Maybe
open import Relation.Binary.PropositionalEquality

-- Holon identifier
record HolonId : Set where
  field
    runtime : Runtime
    layer : Layer
    domain : Domain
    holonType : HolonType
    instance : String

-- Database operation
data DBOperation : Set where
  Read : Query → DBOperation
  Write : Statement → DBOperation
  Transaction : List DBOperation → DBOperation

-- Version vector
VersionVector : Set
VersionVector = HolonId → ℕ

-- Happens-before relation
_≺_ : VersionVector → VersionVector → Bool
v1 ≺ v2 = all (λ h → v1 h ≤ v2 h) holons

-- Safety property: No lost updates
noLostUpdates : ∀ (op1 op2 : DBOperation) (v1 v2 : VersionVector) →
  concurrent op1 op2 → conflict op1 op2 →
  (applied op1 → v1 ≺ result) × (applied op2 → v2 ≺ result)

-- Liveness property: Every operation eventually completes
progress : ∀ (op : DBOperation) → ◇ (completed op)

-- Deadlock freedom
deadlockFree : ∀ (t1 t2 : Transaction) →
  ¬ (waiting t1 t2 × waiting t2 t1)
```

### 10.2 Quint Specification

```quint
// Cross-Holon Database State Machine
module CrossHolonDB {

  type HolonId = str
  type DbType = str
  type TxnId = str
  type Version = int

  type Operation =
    | Query(sql: str, params: List[str])
    | Execute(sql: str, params: List[str])
    | BeginTxn(isolation: str)
    | Commit
    | Rollback

  type Request = {
    id: str,
    source: HolonId,
    target: HolonId,
    targetDb: DbType,
    operation: Operation,
    timestamp: int
  }

  type Response = {
    requestId: str,
    success: bool,
    result: Option[str],
    error: Option[str]
  }

  // State
  var databases: HolonId -> DbType -> Map[str, str]
  var transactions: TxnId -> {state: str, locks: Set[str]}
  var versionVectors: HolonId -> Map[str, int]
  var pendingRequests: Set[Request]

  // Invariants
  invariant noDeadlock =
    forall t1, t2 in transactions.keys():
      not (waiting(t1, t2) and waiting(t2, t1))

  invariant versionMonotonic =
    forall h in versionVectors.keys():
      forall k in versionVectors[h].keys():
        old(versionVectors[h][k]) <= versionVectors[h][k]

  invariant transactionIsolation =
    forall t in transactions.keys():
      transactions[t].state == "active" implies
        not exists other in transactions.keys():
          other != t and conflicting(t, other)

  // Actions
  action beginTransaction(source: HolonId, target: HolonId, db: DbType, isolation: str): bool = {
    val txnId = freshTxnId()
    transactions' = transactions.set(txnId, {state: "active", locks: Set()})
    true
  }

  action commitTransaction(txnId: TxnId): bool = {
    require(transactions[txnId].state == "active")
    transactions' = transactions.set(txnId, {...transactions[txnId], state: "committed"})
    // Release all locks
    true
  }

  action executeQuery(req: Request): Response = {
    require(req.source in databases.keys())
    require(req.target in databases.keys())

    val result = databases[req.target][req.targetDb].query(req.operation)
    {requestId: req.id, success: true, result: Some(result), error: None}
  }
}
```

### 10.3 Graph-Based Verification

```
Control Flow Graph (CFG) Coverage Requirements:

┌─────────────────────────────────────────────────────────────┐
│                    DATABASE OPERATION CFG                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [Start] ──► [Validate Input] ──► [Acquire Connection]      │
│                    │                      │                  │
│                    ▼                      ▼                  │
│              [Error: Invalid]    [Connection Pool]           │
│                    │                      │                  │
│                    │             ┌────────┼────────┐         │
│                    │             ▼        ▼        ▼         │
│                    │         [Retry]  [Execute] [Timeout]    │
│                    │             │        │        │         │
│                    │             └────────┼────────┘         │
│                    │                      ▼                  │
│                    │              [Process Result]           │
│                    │                      │                  │
│                    │             ┌────────┼────────┐         │
│                    │             ▼        ▼        ▼         │
│                    │         [Success] [Error] [Conflict]    │
│                    │             │        │        │         │
│                    └─────────────┴────────┴────────┘         │
│                                   │                          │
│                                   ▼                          │
│                              [Release Conn]                  │
│                                   │                          │
│                                   ▼                          │
│                               [End]                          │
│                                                              │
│  Coverage Requirements:                                      │
│  - 100% Node Coverage (all 12 nodes)                        │
│  - 100% Edge Coverage (all 15 edges)                        │
│  - 100% Path Coverage (all 8 paths)                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 11.0 Test Approach

### 11.1 Test Pyramid

```
                    ┌─────────┐
                    │ E2E     │  5%   (Cross-system flows)
                   ┌┴─────────┴┐
                   │Integration│ 20%  (Holon interaction)
                  ┌┴───────────┴┐
                  │  Component  │ 30%  (DB access, Zenoh)
                 ┌┴─────────────┴┐
                 │     Unit      │ 45%  (Functions, modules)
                 └───────────────┘
```

### 11.2 Test Categories

| Category | Count | Coverage Target |
|----------|-------|-----------------|
| Elixir SQLite Direct Access | 50 | 100% |
| Elixir DuckDB Direct Access | 50 | 100% |
| F# SQLite Direct Access | 50 | 100% |
| F# DuckDB Direct Access | 50 | 100% |
| Cross-Holon Bridge | 100 | 100% |
| Concurrency Tests | 75 | 100% |
| Transaction Tests | 75 | 100% |
| Performance Tests | 50 | All SLAs |
| Chaos Tests | 25 | Recovery |
| **Total** | **525** | **100%** |

### 11.3 9-Degree Interaction Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    9-DEGREE INTERACTION MATRIX                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Degree 1: Single Operation                                                  │
│  ─────────────────────────────                                              │
│  [Elixir] → [SQLite Read]                                                   │
│  [F#] → [DuckDB Query]                                                      │
│                                                                              │
│  Degree 2: Same-Holon Transaction                                           │
│  ────────────────────────────────                                           │
│  [Elixir] → [Begin] → [Read] → [Write] → [Commit]                          │
│                                                                              │
│  Degree 3: Cross-Holon Single Query                                         │
│  ─────────────────────────────────                                          │
│  [Elixir] → [Zenoh] → [F#] → [SQLite Read] → [Response]                    │
│                                                                              │
│  Degree 4: Cross-Holon Transaction                                          │
│  ────────────────────────────────                                           │
│  [Elixir] → [Begin TXN] → [Zenoh] → [F# Prepare] → [Commit]                │
│                                                                              │
│  Degree 5: Multi-Client Concurrent                                          │
│  ────────────────────────────────                                           │
│  [Client1] ─┬─► [Same DB] ←─┬─ [Client2]                                    │
│             └─► [OCC] ◄─────┘                                               │
│                                                                              │
│  Degree 6: Multi-Holon Chain                                                │
│  ───────────────────────────                                                │
│  [Elixir KMS] → [F# Cortex] → [Elixir Prajna] → [F# Planning]              │
│                                                                              │
│  Degree 7: Distributed Transaction                                          │
│  ─────────────────────────────────                                          │
│  [Coordinator] → [Prepare All] → [Vote] → [Commit All]                     │
│       ├──► [Elixir Holon 1]                                                 │
│       ├──► [F# Holon 2]                                                     │
│       └──► [Elixir Holon 3]                                                 │
│                                                                              │
│  Degree 8: Failure Recovery                                                 │
│  ──────────────────────────                                                 │
│  [Normal Op] → [Inject Failure] → [Detect] → [Recover] → [Verify]          │
│                                                                              │
│  Degree 9: Full Mesh Chaos                                                  │
│  ────────────────────────────                                               │
│  [All Holons] × [All DBs] × [All Operations] × [Random Failures]           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12.0 Implementation Roadmap

### 12.1 Phase 1: Direct Access (Week 1)

- [ ] Implement Elixir HolonDatabase module
- [ ] Implement F# HolonDatabase module
- [ ] Unit tests for both runtimes
- [ ] Performance benchmarks

### 12.2 Phase 2: Zenoh Bridge (Week 2)

- [ ] Implement Elixir ZenohDBClient/Server
- [ ] Implement F# ZenohDBClient/Server
- [ ] Protocol tests
- [ ] Integration tests

### 12.3 Phase 3: Concurrency (Week 3)

- [ ] Implement OCC handlers
- [ ] Version vector management
- [ ] Conflict resolution
- [ ] Concurrency tests

### 12.4 Phase 4: Transactions (Week 4)

- [ ] Two-phase commit protocol
- [ ] Savepoint support
- [ ] Rollback handling
- [ ] Transaction tests

### 12.5 Phase 5: Verification (Week 5)

- [ ] Agda proofs
- [ ] Quint model checking
- [ ] Graph coverage verification
- [ ] Chaos testing

---

## 13.0 Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Author | Claude Opus 4.5 |
| Date | 2026-01-17 |
| STAMP | SC-XHOLON-001 to SC-XHOLON-050 |
| Status | ACTIVE |

---

**Next Steps**:
1. Review and approve specification
2. Implement core modules
3. Execute test plan
4. Deploy to staging
5. Production rollout
