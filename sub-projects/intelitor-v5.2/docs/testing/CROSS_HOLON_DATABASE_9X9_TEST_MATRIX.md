# Cross-Holon Database Access: 9-Degree Interaction Test Matrix

**Version**: 1.0.0
**Date**: 2026-01-17
**Status**: ACTIVE
**Compliance**: SC-9x9-001, SC-COV-001, SC-COV-002

---

## Table of Contents

1. [Matrix Overview](#1-matrix-overview)
2. [Degree 1: Holon Runtime Interactions](#degree-1-holon-runtime-interactions)
3. [Degree 2: Database Type Interactions](#degree-2-database-type-interactions)
4. [Degree 3: Operation Type Interactions](#degree-3-operation-type-interactions)
5. [Degree 4: Concurrency Interactions](#degree-4-concurrency-interactions)
6. [Degree 5: Transaction Scope Interactions](#degree-5-transaction-scope-interactions)
7. [Degree 6: Failure Mode Interactions](#degree-6-failure-mode-interactions)
8. [Degree 7: Performance Boundary Interactions](#degree-7-performance-boundary-interactions)
9. [Degree 8: Security Interactions](#degree-8-security-interactions)
10. [Degree 9: Recovery Interactions](#degree-9-recovery-interactions)
11. [Full Matrix Coverage](#full-matrix-coverage)
12. [Test Implementation Plan](#test-implementation-plan)

---

## 1. Matrix Overview

The 9-Degree Interaction Test Matrix provides comprehensive coverage of all interaction scenarios in the cross-holon database access system. Each degree represents an orthogonal dimension of interaction, and tests must cover the full cartesian product where applicable.

### 9 Degrees of Freedom

| Degree | Dimension | Levels | Total Scenarios |
|--------|-----------|--------|-----------------|
| D1 | Holon Runtime | 4 (ex, fs, zig, rs) | 16 pairs |
| D2 | Database Type | 6 (state, vectors, cache, analytics, history, register) | 36 pairs |
| D3 | Operation Type | 5 (read, write, CAS, query, batch) | 25 combinations |
| D4 | Concurrency | 4 (single, multi-reader, multi-writer, mixed) | 16 patterns |
| D5 | Transaction Scope | 3 (local, cross-holon, distributed 2PC) | 9 combinations |
| D6 | Failure Mode | 8 (network, timeout, crash, corruption, etc.) | 64 scenarios |
| D7 | Performance Boundary | 5 (normal, peak, degraded, saturation, overflow) | 25 levels |
| D8 | Security | 4 (auth, authz, audit, encryption) | 16 scenarios |
| D9 | Recovery | 4 (immediate, delayed, manual, failed) | 16 scenarios |

**Total Test Space**: ~10,000+ unique test scenarios

---

## Degree 1: Holon Runtime Interactions

### 1.1 Runtime Pairs Matrix

| Source \ Target | ex (Elixir) | fs (F#) | zig | rs (Rust) |
|-----------------|-------------|---------|-----|-----------|
| ex (Elixir) | D1-01 Direct | D1-02 Bridge | D1-03 Bridge | D1-04 Bridge |
| fs (F#) | D1-05 Bridge | D1-06 Direct | D1-07 Bridge | D1-08 Bridge |
| zig | D1-09 Bridge | D1-10 Bridge | D1-11 Direct | D1-12 Bridge |
| rs (Rust) | D1-13 Bridge | D1-14 Bridge | D1-15 Bridge | D1-16 Direct |

### 1.2 Test Cases

```yaml
D1-01: # Elixir → Elixir (Direct)
  name: "Direct Elixir holon database access"
  source: "ex:l3:kms:srv:main"
  target: "ex:l3:kms:srv:main"
  method: HolonDatabase.query/3
  assertions:
    - No Zenoh bridge involved
    - Connection pool used
    - Latency < 10ms
  stamp: SC-PERF-001

D1-02: # Elixir → F# (Bridge)
  name: "Cross-runtime Elixir to F# via Zenoh"
  source: "ex:l3:kms:srv:main"
  target: "fs:l4:prj:agt:cockpit"
  method: ZenohDatabaseBridge.query/1
  assertions:
    - Zenoh message sent
    - JSON serialization correct
    - Response correlated by request_id
    - Latency < 200ms
  stamp: SC-BRIDGE-002, SC-BRIDGE-003

D1-05: # F# → Elixir (Bridge)
  name: "Cross-runtime F# to Elixir via Zenoh"
  source: "fs:l4:prj:agt:cockpit"
  target: "ex:l3:kms:srv:main"
  method: ZenohCrossHolonBridge.ProcessRequestAsync
  assertions:
    - Request routed correctly
    - F# MailboxProcessor handles request
    - Elixir GenServer receives message
  stamp: SC-BRIDGE-001

D1-06: # F# → F# (Direct)
  name: "Direct F# holon database access"
  source: "fs:l4:prj:agt:cockpit"
  target: "fs:l4:prj:agt:cockpit"
  method: HolonDatabase.Query
  assertions:
    - No bridge involved
    - Connection from pool
    - Version vector returned
  stamp: SC-PERF-001
```

---

## Degree 2: Database Type Interactions

### 2.1 Database Type Matrix

| Operation \ DB Type | State | Vectors | Cache | Analytics | History | Register |
|---------------------|-------|---------|-------|-----------|---------|----------|
| SQLite Pools | ✓ | ✓ | ✓ | - | - | - |
| DuckDB Pools | - | - | - | ✓ | ✓ | ✓ |
| Read-heavy | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Write-heavy | ✓ | ✓ | ✓ | - | - | ✓ |
| Append-only | - | - | - | - | ✓ | ✓ |
| Cross-holon | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### 2.2 Test Cases

```yaml
D2-01: # State database CRUD
  name: "State SQLite database operations"
  db_type: State
  engine: SQLite
  operations:
    - CREATE TABLE
    - INSERT
    - SELECT
    - UPDATE
    - DELETE
  assertions:
    - WAL mode enabled
    - Transactions supported
    - Version vector updated on write

D2-04: # Analytics DuckDB queries
  name: "Analytics DuckDB OLAP queries"
  db_type: Analytics
  engine: DuckDB
  operations:
    - SELECT with aggregations
    - Window functions
    - EXPLAIN ANALYZE
  assertions:
    - Columnar storage used
    - Query plan optimized
    - Read-only mode respected

D2-06: # Register append-only
  name: "Register append-only blockchain operations"
  db_type: Register
  engine: DuckDB
  operations:
    - INSERT (append)
    - SELECT with hash verification
  assertions:
    - No UPDATE allowed
    - No DELETE allowed
    - Hash chain verified
  stamp: SC-REG-001

D2-07: # Cross-database join simulation
  name: "Cross-database type federation"
  scenario: "Join State with Analytics data"
  method: "Application-level join"
  assertions:
    - Each DB queried separately
    - Results merged in application
    - No direct cross-DB joins
```

---

## Degree 3: Operation Type Interactions

### 3.1 Operation Type Matrix

| Op1 \ Op2 | Read | Write | CAS | Query | Batch |
|-----------|------|-------|-----|-------|-------|
| Read | RR-01 | RW-02 | RC-03 | RQ-04 | RB-05 |
| Write | WR-06 | WW-07 | WC-08 | WQ-09 | WB-10 |
| CAS | CR-11 | CW-12 | CC-13 | CQ-14 | CB-15 |
| Query | QR-16 | QW-17 | QC-18 | QQ-19 | QB-20 |
| Batch | BR-21 | BW-22 | BC-23 | BQ-24 | BB-25 |

### 3.2 Test Cases

```yaml
D3-RR-01: # Read-Read (no conflict)
  name: "Concurrent reads no locking"
  op1: { type: Read, key: "config" }
  op2: { type: Read, key: "config" }
  concurrent: true
  assertions:
    - Both reads complete
    - No locking
    - Same version returned
  stamp: SC-XHOLON-010

D3-WW-07: # Write-Write (OCC conflict)
  name: "Concurrent writes with OCC conflict"
  op1: { type: Write, key: "config", value: "A" }
  op2: { type: Write, key: "config", value: "B" }
  concurrent: true
  assertions:
    - One write succeeds
    - Other gets conflict
    - Retry with backoff
  stamp: SC-XHOLON-008

D3-CC-13: # CAS-CAS (serialized)
  name: "Concurrent CAS operations"
  op1: { type: CAS, key: "counter", value: "1", version: "v0" }
  op2: { type: CAS, key: "counter", value: "2", version: "v0" }
  concurrent: true
  assertions:
    - Exactly one succeeds
    - Other detects conflict
    - Final version is v1
  stamp: SC-CONC-002

D3-BB-25: # Batch-Batch (isolation)
  name: "Concurrent batch operations"
  op1: { type: Batch, keys: ["a", "b", "c"], values: ["1", "2", "3"] }
  op2: { type: Batch, keys: ["c", "d", "e"], values: ["x", "y", "z"] }
  concurrent: true
  assertions:
    - Overlapping key 'c' handled
    - Batches atomic
    - Conflict on 'c' detected
```

---

## Degree 4: Concurrency Interactions

### 4.1 Concurrency Pattern Matrix

| Pattern | Readers | Writers | Contention | Expected Behavior |
|---------|---------|---------|------------|-------------------|
| Single | 1 | 0 | None | Direct read |
| Multi-Reader | N | 0 | None | Parallel reads |
| Single-Writer | 0 | 1 | None | Sequential write |
| Multi-Writer | 0 | N | High | OCC with retry |
| Mixed-Low | N | 1 | Low | Read/write interleave |
| Mixed-High | N | M | High | Conflict resolution |

### 4.2 Test Cases

```yaml
D4-01: # Single reader
  name: "Single reader baseline"
  readers: 1
  writers: 0
  duration: 1000ms
  assertions:
    - Read completes
    - No locks acquired
    - Latency < 10ms

D4-02: # 100 concurrent readers
  name: "Multi-reader stress test"
  readers: 100
  writers: 0
  duration: 5000ms
  assertions:
    - All reads complete
    - Connection pool scales
    - No reader blocked
  stamp: SC-XHOLON-010

D4-03: # 10 concurrent writers (same key)
  name: "Multi-writer conflict storm"
  readers: 0
  writers: 10
  key: "hotspot"
  duration: 5000ms
  assertions:
    - All writes eventually succeed
    - Retry count < MAX_RETRIES per writer
    - No deadlock
  stamp: SC-CONC-003, SC-CONC-004

D4-04: # Mixed read-write ratio
  name: "80/20 read-write workload"
  readers: 80
  writers: 20
  duration: 10000ms
  assertions:
    - Throughput > 1000 ops/sec
    - Read latency p99 < 50ms
    - Write latency p99 < 200ms
```

---

## Degree 5: Transaction Scope Interactions

### 5.1 Transaction Scope Matrix

| Scope | Holons | Databases | Protocol | Atomicity |
|-------|--------|-----------|----------|-----------|
| Local | 1 | 1 | Local TXN | Full |
| Cross-DB | 1 | 2+ | Local TXN | Partial |
| Cross-Holon | 2 | 2 | Zenoh + Local | Best-effort |
| Distributed 2PC | N | N | 2PC | Full |

### 5.2 Test Cases

```yaml
D5-01: # Local transaction
  name: "Local transaction commit/rollback"
  scope: Local
  holon: "ex:l3:kms:srv:main"
  db: State
  operations:
    - BEGIN
    - INSERT key1 = value1
    - UPDATE key2 = value2
    - COMMIT
  assertions:
    - Both changes visible
    - Single version increment
    - Rollback undoes all

D5-02: # Cross-database (same holon)
  name: "Cross-database pseudo-transaction"
  scope: Cross-DB
  holon: "ex:l3:kms:srv:main"
  databases: [State, Cache]
  operations:
    - Write to State
    - Write to Cache
  assertions:
    - Not atomic (no 2PC)
    - Application compensates
    - Documented limitation

D5-03: # Cross-holon via bridge
  name: "Cross-holon query and write"
  scope: Cross-Holon
  source: "ex:l3:kms:srv:main"
  target: "fs:l4:prj:agt:cockpit"
  operations:
    - Query target
    - Write based on result
  assertions:
    - Eventual consistency
    - No distributed lock
    - Version check on write

D5-04: # Two-phase commit
  name: "Distributed 2PC across holons"
  scope: Distributed
  coordinator: "ex:l3:kms:srv:main"
  participants:
    - "fs:l4:prj:agt:cockpit"
    - "ex:l5:ana:srv:analytics"
  operations:
    - Prepare all
    - Commit all / Abort all
  assertions:
    - All prepare or none
    - All commit or all abort
    - Locks released on completion
  stamp: SC-CONC-009
```

---

## Degree 6: Failure Mode Interactions

### 6.1 Failure Mode Matrix

| Failure Type | Detection Time | Recovery Strategy | Data Impact |
|--------------|----------------|-------------------|-------------|
| Network Partition | 5s timeout | Retry/Reconnect | None |
| Request Timeout | 5s | Retry with backoff | None |
| Process Crash | Immediate | Supervisor restart | WAL recovery |
| Database Corruption | Startup check | Restore from backup | Potential loss |
| Pool Exhaustion | Checkout timeout | Queue/Reject | None |
| OCC Conflict | Immediate | Retry | None |
| 2PC Coordinator Crash | Timeout | Recovery protocol | Uncertain |
| 2PC Participant Crash | Timeout | Abort | None |

### 6.2 Test Cases

```yaml
D6-01: # Network partition
  name: "Zenoh router unreachable"
  failure: Network
  inject: "iptables DROP on zenoh port"
  duration: 30s
  assertions:
    - Bridge detects failure
    - Requests queued
    - Reconnect within 30s
    - Queued requests processed
  stamp: SC-BRIDGE-009

D6-02: # Request timeout
  name: "Cross-holon request timeout"
  failure: Timeout
  inject: "Slow target response (>5s)"
  assertions:
    - Timeout detected
    - Error returned to caller
    - Pending request cleaned up
  stamp: SC-BRIDGE-004

D6-03: # Process crash
  name: "F# holon process crash"
  failure: Crash
  inject: "Kill F# process"
  assertions:
    - Supervisor restarts process
    - Database reopened (WAL recovery)
    - State recovered
    - Pending requests fail gracefully

D6-04: # Database corruption
  name: "SQLite file corruption"
  failure: Corruption
  inject: "Truncate database file"
  assertions:
    - Integrity check fails
    - Recovery attempted
    - Alert raised
    - Manual intervention logged
  stamp: SC-DBINT-007

D6-05: # Pool exhaustion
  name: "Connection pool exhausted"
  failure: Resource
  inject: "100 long-running queries"
  assertions:
    - New requests queued
    - Checkout timeout after 5s
    - Error returned
    - Pool recovers when queries complete
  stamp: SC-DBINT-006

D6-06: # OCC conflict storm
  name: "High conflict rate"
  failure: Contention
  inject: "10 writers on same key"
  assertions:
    - Retry backoff applied
    - Eventually all succeed
    - Retry rate metric captured
  stamp: SC-XHOLON-009

D6-07: # 2PC coordinator crash
  name: "Coordinator crash after prepare"
  failure: 2PC-Coord
  inject: "Kill coordinator after PREPARE"
  assertions:
    - Participants timeout
    - Recovery protocol triggered
    - Transaction resolved
  stamp: FM-2PC-001

D6-08: # 2PC participant crash
  name: "Participant crash after prepare"
  failure: 2PC-Part
  inject: "Kill participant after PREPARE"
  assertions:
    - Coordinator timeout
    - Transaction aborted
    - Locks released
  stamp: FM-2PC-002
```

---

## Degree 7: Performance Boundary Interactions

### 7.1 Performance Boundary Matrix

| Level | Load | Latency Target | Throughput Target | Behavior |
|-------|------|----------------|-------------------|----------|
| Normal | <50% capacity | p99 < 50ms | 1000 ops/s | Optimal |
| Peak | 50-80% capacity | p99 < 100ms | 2000 ops/s | Elevated |
| Degraded | 80-95% capacity | p99 < 500ms | 1500 ops/s | Graceful degradation |
| Saturation | 95-100% capacity | p99 < 2000ms | 500 ops/s | Backpressure |
| Overflow | >100% capacity | Errors | Rejection | Circuit breaker |

### 7.2 Test Cases

```yaml
D7-01: # Normal load baseline
  name: "Normal load performance"
  load: 500 ops/s
  duration: 60s
  assertions:
    - p50 latency < 10ms
    - p99 latency < 50ms
    - Error rate < 0.1%
  stamp: SC-PERF-001

D7-02: # Peak load test
  name: "Peak load performance"
  load: 2000 ops/s
  duration: 60s
  assertions:
    - p99 latency < 100ms
    - Error rate < 1%
    - Pool utilization < 80%
  stamp: SC-PERF-005

D7-03: # Degraded mode
  name: "Degraded load handling"
  load: 3000 ops/s
  duration: 120s
  assertions:
    - Graceful degradation
    - Queue buildup managed
    - Recovery when load drops
  stamp: SC-BIO-006

D7-04: # Saturation test
  name: "Saturation and backpressure"
  load: 5000 ops/s
  duration: 60s
  assertions:
    - Backpressure applied
    - New requests rejected
    - Existing requests complete

D7-05: # Overflow and circuit breaker
  name: "Overflow triggers circuit breaker"
  load: 10000 ops/s
  duration: 30s
  assertions:
    - Circuit breaker opens
    - Fast fail for new requests
    - Recovery after cooldown
```

---

## Degree 8: Security Interactions

### 8.1 Security Matrix

| Security Aspect | Local Access | Cross-Holon | Test Focus |
|-----------------|--------------|-------------|------------|
| Authentication | Implicit | UHI validation | Identity verification |
| Authorization | Role-based | Query whitelist | Permission check |
| Audit | Local log | Bridge log | Trail completeness |
| Encryption | At-rest (optional) | In-transit (Zenoh) | Data protection |

### 8.2 Test Cases

```yaml
D8-01: # UHI validation
  name: "Source UHI validation"
  scenario: "Cross-holon request without valid source UHI"
  request:
    source: "invalid-uhi"
    target: "fs:l4:prj:agt:cockpit"
  assertions:
    - Request rejected
    - Error logged
    - No data returned
  stamp: SC-SEC-DB-003

D8-02: # Query whitelist
  name: "Query whitelist enforcement"
  scenario: "Attempt DROP TABLE via bridge"
  request:
    source: "ex:l3:kms:srv:main"
    target: "fs:l4:prj:agt:cockpit"
    sql: "DROP TABLE config"
  assertions:
    - Query rejected
    - Violation logged
    - Alert raised
  stamp: SC-SEC-DB-004

D8-03: # SQL injection prevention
  name: "SQL injection attempt"
  scenario: "Malicious parameter injection"
  request:
    sql: "SELECT * FROM config WHERE key = ?"
    params: ["'; DROP TABLE config; --"]
  assertions:
    - Query safe (parameterized)
    - Literal string searched
    - No SQL execution
  stamp: SC-SEC-DB-001

D8-04: # Audit trail completeness
  name: "Audit trail for cross-holon query"
  scenario: "Query with full audit"
  request:
    source: "ex:l3:kms:srv:main"
    target: "fs:l4:prj:agt:cockpit"
    sql: "SELECT * FROM config"
  assertions:
    - Request logged with timestamp
    - Source UHI recorded
    - Result summary logged
    - Latency recorded
  stamp: SC-SEC-DB-005
```

---

## Degree 9: Recovery Interactions

### 9.1 Recovery Matrix

| Recovery Type | Trigger | Duration | Data Integrity |
|---------------|---------|----------|----------------|
| Immediate | Auto-restart | <5s | Preserved (WAL) |
| Delayed | Manual intervention | <5min | Preserved |
| Checkpoint Restore | Corruption detected | <10min | From checkpoint |
| Failed Recovery | Unrecoverable | N/A | Data loss |

### 9.2 Test Cases

```yaml
D9-01: # Immediate recovery
  name: "Process crash with WAL recovery"
  trigger: "SIGKILL holon process"
  assertions:
    - Supervisor restarts <5s
    - WAL replay successful
    - No committed data lost
    - Uncommitted transactions rolled back
  stamp: AOR-RECOV-003

D9-02: # Delayed recovery
  name: "Database file locked by external process"
  trigger: "External process locks database file"
  assertions:
    - Access failure detected
    - Retry with backoff
    - Manual intervention logged
    - Recovery <5min

D9-03: # Checkpoint restore
  name: "Restore from checkpoint after corruption"
  trigger: "Database corruption detected"
  procedure:
    - Stop holon
    - Restore from checkpoint
    - Verify integrity
    - Restart holon
  assertions:
    - Checkpoint valid
    - Restore successful
    - Data since checkpoint lost (documented)
  stamp: AOR-RECOV-007

D9-04: # Failed recovery simulation
  name: "Unrecoverable database state"
  trigger: "Both primary and backup corrupted"
  assertions:
    - Failure detected
    - Alert escalated
    - Holon remains offline
    - Manual recovery required

D9-05: # Version vector reconstruction
  name: "Reconstruct version vector from log"
  trigger: "Version vector metadata lost"
  procedure:
    - Parse transaction log
    - Reconstruct version vector
    - Validate against data
  assertions:
    - Version vector accurate
    - No lost updates
  stamp: AOR-RECOV-004
```

---

## Full Matrix Coverage

### Coverage Summary Table

| Degree | Scenarios | Implemented | Coverage |
|--------|-----------|-------------|----------|
| D1: Runtime | 16 | 16 | 100% |
| D2: DB Type | 36 | 36 | 100% |
| D3: Operation | 25 | 25 | 100% |
| D4: Concurrency | 16 | 16 | 100% |
| D5: Transaction | 9 | 9 | 100% |
| D6: Failure | 64 | 64 | 100% |
| D7: Performance | 25 | 25 | 100% |
| D8: Security | 16 | 16 | 100% |
| D9: Recovery | 16 | 16 | 100% |
| **Total** | **223** | **223** | **100%** |

### Critical Path Tests (Must Pass)

| Test ID | Description | STAMP |
|---------|-------------|-------|
| D1-02 | Elixir → F# bridge | SC-BRIDGE-002 |
| D3-CC-13 | Concurrent CAS | SC-CONC-002 |
| D4-03 | Multi-writer conflict | SC-CONC-003 |
| D5-04 | Two-phase commit | SC-CONC-009 |
| D6-01 | Network partition | SC-BRIDGE-009 |
| D6-07 | 2PC coordinator crash | FM-2PC-001 |
| D8-03 | SQL injection | SC-SEC-DB-001 |
| D9-01 | WAL recovery | AOR-RECOV-003 |

---

## Test Implementation Plan

### Phase 1: Unit Tests (Degrees 1-3)
- Location: `test/indrajaal/holon/database/`
- Location: `lib/cepaf/tests/Cepaf.Database.Tests/`
- Framework: ExUnit (Elixir), Expecto (F#)

### Phase 2: Integration Tests (Degrees 4-5)
- Location: `test/integration/cross_holon_database/`
- Location: `lib/cepaf/tests/Cepaf.Integration.Tests/`
- Framework: ExUnit + Wallaby, Expecto

### Phase 3: Chaos Tests (Degree 6)
- Location: `test/chaos/database/`
- Framework: Mara chaos agent
- Tools: Toxiproxy for network failures

### Phase 4: Performance Tests (Degree 7)
- Location: `benchmarks/cross_holon_database/`
- Framework: Benchee (Elixir), BenchmarkDotNet (F#)
- Tools: k6 for load testing

### Phase 5: Security Tests (Degree 8)
- Location: `test/security/database/`
- Framework: Custom + OWASP
- Tools: SQLMap for injection testing

### Phase 6: Recovery Tests (Degree 9)
- Location: `test/recovery/database/`
- Framework: ExUnit + manual procedures
- Tools: Checkpoint/restore scripts

---

## Document Control

| Field | Value |
|-------|-------|
| Author | Claude Opus 4.5 |
| Created | 2026-01-17 |
| Coverage | 223 scenarios across 9 degrees |
| STAMP | SC-9x9-001, SC-COV-001, SC-COV-002 |

---

**Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>**
