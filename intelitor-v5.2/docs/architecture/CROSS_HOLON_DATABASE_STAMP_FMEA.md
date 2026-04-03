# Cross-Holon Database Access: STAMP/AOR/FMEA Analysis

**Version**: 1.0.0
**Date**: 2026-01-17
**Status**: ACTIVE
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [STAMP Constraints](#2-stamp-constraints)
3. [Agent Operating Rules (AOR)](#3-agent-operating-rules-aor)
4. [FMEA Analysis](#4-fmea-analysis)
5. [Control Flow Safety Analysis](#5-control-flow-safety-analysis)
6. [Mathematical Safety Properties](#6-mathematical-safety-properties)
7. [5-Order Effects Analysis](#7-5-order-effects-analysis)
8. [Mitigation Strategies](#8-mitigation-strategies)
9. [Verification Requirements](#9-verification-requirements)

---

## 1. Executive Summary

This document provides comprehensive safety analysis for the Cross-Holon Database Access system using:

- **STAMP (Systems-Theoretic Accident Model and Processes)**: 55 safety constraints
- **AOR (Agent Operating Rules)**: 40 operational rules
- **FMEA (Failure Mode and Effects Analysis)**: 48 failure modes analyzed

### Safety Criticality Classification

| Component | SIL Level | PFH Target | Justification |
|-----------|-----------|------------|---------------|
| Version Vector OCC | SIL-6 Biomorphic | < 10⁻⁸ | Prevents data corruption |
| Zenoh Bridge | SIL-3 | < 10⁻⁷ | Cross-holon isolation |
| Connection Pool | SIL-2 | < 10⁻⁶ | Resource management |
| Query Execution | SIL-2 | < 10⁻⁶ | Business logic integrity |
| Two-Phase Commit | SIL-6 Biomorphic | < 10⁻⁸ | Distributed consistency |

---

## 2. STAMP Constraints

### 2.1 Cross-Holon Isolation Constraints (SC-XHOLON-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XHOLON-001 | Holon databases MUST be physically isolated (separate files) | CRITICAL | File path check |
| SC-XHOLON-002 | Direct cross-holon database access is FORBIDDEN | CRITICAL | Code review |
| SC-XHOLON-003 | Cross-holon access ONLY via Zenoh bridge | CRITICAL | Protocol enforcement |
| SC-XHOLON-004 | Each holon MUST manage its own connection pools | HIGH | Pool isolation |
| SC-XHOLON-005 | Schema changes MUST NOT cascade across holons | CRITICAL | Migration isolation |
| SC-XHOLON-006 | Concurrent access MUST use OCC or explicit locking | CRITICAL | Concurrency tests |
| SC-XHOLON-007 | Version vectors MUST be monotonically increasing | CRITICAL | Property tests |
| SC-XHOLON-008 | OCC conflicts MUST be detected before commit | CRITICAL | Conflict detection |
| SC-XHOLON-009 | Retry backoff MUST be exponential with jitter | HIGH | Timing analysis |
| SC-XHOLON-010 | Lock-free reads MANDATORY for performance | HIGH | Read path analysis |

### 2.2 Zenoh Bridge Constraints (SC-BRIDGE-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-BRIDGE-001 | Message buffer MUST maintain FIFO ordering | CRITICAL | Queue tests |
| SC-BRIDGE-002 | Bridge latency budget: 50ms local, 200ms remote | HIGH | Latency tests |
| SC-BRIDGE-003 | Request-response correlation via request_id | HIGH | Message tests |
| SC-BRIDGE-004 | Request timeout < 5 seconds | HIGH | Timeout tests |
| SC-BRIDGE-005 | Bridge shutdown MUST drain pending requests | HIGH | Shutdown tests |
| SC-BRIDGE-006 | JSON serialization MUST be schema-versioned | HIGH | Schema tests |
| SC-BRIDGE-007 | Error responses MUST include error category | MEDIUM | Error format |
| SC-BRIDGE-008 | Bridge statistics MUST be available | MEDIUM | Metrics check |
| SC-BRIDGE-009 | Zenoh session reconnect on failure | HIGH | Reconnect tests |
| SC-BRIDGE-010 | Topic patterns MUST follow UHI convention | HIGH | Topic validation |

### 2.3 Database Integrity Constraints (SC-DBINT-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DBINT-001 | SQLite MUST use WAL mode for holons | CRITICAL | Connection check |
| SC-DBINT-002 | DuckDB MUST use read-write mode with transactions | CRITICAL | Connection check |
| SC-DBINT-003 | All writes MUST be within transactions | CRITICAL | Code analysis |
| SC-DBINT-004 | Transaction timeout < 30 seconds | HIGH | Timeout config |
| SC-DBINT-005 | Connection pool size >= 2, <= 20 | HIGH | Config validation |
| SC-DBINT-006 | Pool checkout timeout < 5 seconds | HIGH | Timing tests |
| SC-DBINT-007 | Database files MUST have integrity check on load | CRITICAL | Startup check |
| SC-DBINT-008 | Backup MUST be possible without service interruption | HIGH | Backup tests |
| SC-DBINT-009 | Schema migrations MUST be idempotent | CRITICAL | Migration tests |
| SC-DBINT-010 | Database path MUST follow UHI convention | HIGH | Path validation |

### 2.4 Concurrency Safety Constraints (SC-CONC-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-CONC-001 | Version vector merge MUST take max of each component | CRITICAL | Property tests |
| SC-CONC-002 | Compare-and-swap MUST be atomic | CRITICAL | Concurrency tests |
| SC-CONC-003 | Deadlock detection timeout < 10 seconds | CRITICAL | Deadlock tests |
| SC-CONC-004 | No starvation permitted in OCC retry | CRITICAL | Fairness tests |
| SC-CONC-005 | Max OCC retries = 3 before failure | HIGH | Retry tests |
| SC-CONC-006 | Exponential backoff base = 100ms | HIGH | Timing tests |
| SC-CONC-007 | Max backoff delay = 2000ms | HIGH | Timing tests |
| SC-CONC-008 | Lock expiry timeout = 5 seconds | HIGH | Lock tests |
| SC-CONC-009 | Two-phase commit MUST have prepare/commit/rollback | CRITICAL | 2PC tests |
| SC-CONC-010 | Pessimistic locks MUST be released on crash | CRITICAL | Crash tests |

### 2.5 Performance Constraints (SC-PERF-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-PERF-001 | Local query latency p99 < 10ms | HIGH | Latency tests |
| SC-PERF-002 | Local write latency p99 < 50ms | HIGH | Latency tests |
| SC-PERF-003 | Cross-holon query latency p99 < 200ms | HIGH | Latency tests |
| SC-PERF-004 | Cross-holon write latency p99 < 500ms | HIGH | Latency tests |
| SC-PERF-005 | Connection pool utilization < 80% sustained | MEDIUM | Pool metrics |
| SC-PERF-006 | Memory per connection < 10MB | MEDIUM | Memory tests |
| SC-PERF-007 | OCC retry rate < 5% in normal operation | MEDIUM | Retry metrics |
| SC-PERF-008 | Zenoh message size < 1MB | HIGH | Message tests |
| SC-PERF-009 | Query result set < 10,000 rows per page | HIGH | Result tests |
| SC-PERF-010 | Batch insert size < 1,000 rows per transaction | HIGH | Batch tests |

### 2.6 Security Constraints (SC-SEC-DB-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SEC-DB-001 | SQL injection prevention via parameterized queries | CRITICAL | Code analysis |
| SC-SEC-DB-002 | Database files MUST have 0600 permissions | CRITICAL | Permission check |
| SC-SEC-DB-003 | Cross-holon requests MUST include source UHI | CRITICAL | Auth check |
| SC-SEC-DB-004 | Query whitelisting for cross-holon access | HIGH | Whitelist check |
| SC-SEC-DB-005 | Audit log for all cross-holon queries | HIGH | Audit tests |

---

## 3. Agent Operating Rules (AOR)

### 3.1 Database Access Rules (AOR-DB-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-DB-001 | ALWAYS use connection pool, never direct connections | Code review |
| AOR-DB-002 | ALWAYS wrap writes in transactions | Static analysis |
| AOR-DB-003 | ALWAYS use parameterized queries | Linter |
| AOR-DB-004 | NEVER access another holon's database files directly | Path validation |
| AOR-DB-005 | ALWAYS release connections back to pool | Pool monitoring |
| AOR-DB-006 | ALWAYS set query timeout | Config check |
| AOR-DB-007 | LOG all database errors to telemetry | Log verification |
| AOR-DB-008 | CHECKPOINT state before risky migrations | Migration protocol |
| AOR-DB-009 | VERIFY schema compatibility before operations | Schema check |
| AOR-DB-010 | USE UHI paths for all database file references | Path validation |

### 3.2 Concurrency Rules (AOR-CONC-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CONC-001 | READ version vector before any update | Code pattern |
| AOR-CONC-002 | USE compare-and-swap for state mutations | Code review |
| AOR-CONC-003 | RETRY with exponential backoff on conflict | Retry logic |
| AOR-CONC-004 | RELEASE locks in finally/ensure blocks | Exception handling |
| AOR-CONC-005 | DETECT deadlocks via timeout | Timeout config |
| AOR-CONC-006 | LOG all conflict resolutions | Telemetry |
| AOR-CONC-007 | PREFER optimistic over pessimistic locking | Design review |
| AOR-CONC-008 | MONITOR retry rates for hotspot detection | Metrics |
| AOR-CONC-009 | USE two-phase commit for multi-holon transactions | Protocol |
| AOR-CONC-010 | ABORT stale transactions after timeout | Cleanup |

### 3.3 Bridge Rules (AOR-BRIDGE-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BRIDGE-001 | SERIALIZE all cross-holon requests to JSON | Serialization |
| AOR-BRIDGE-002 | INCLUDE request_id in every message | Message format |
| AOR-BRIDGE-003 | SET timeout for every cross-holon operation | Timeout config |
| AOR-BRIDGE-004 | HANDLE all error categories explicitly | Error handling |
| AOR-BRIDGE-005 | RECONNECT Zenoh session on connection loss | Reconnect logic |
| AOR-BRIDGE-006 | VALIDATE response schema before processing | Schema validation |
| AOR-BRIDGE-007 | LOG all bridge operations to telemetry | Telemetry |
| AOR-BRIDGE-008 | RATE LIMIT outgoing requests | Rate limiter |
| AOR-BRIDGE-009 | QUEUE requests during reconnection | Queue management |
| AOR-BRIDGE-010 | DRAIN queue gracefully on shutdown | Shutdown protocol |

### 3.4 Recovery Rules (AOR-RECOV-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-RECOV-001 | VERIFY database integrity on startup | Startup check |
| AOR-RECOV-002 | REPAIR corrupted indexes automatically | Auto-repair |
| AOR-RECOV-003 | ROLLBACK uncommitted transactions on crash recovery | WAL recovery |
| AOR-RECOV-004 | RECONSTRUCT version vectors from transaction log | Log replay |
| AOR-RECOV-005 | NOTIFY dependent systems on recovery completion | Notification |
| AOR-RECOV-006 | CHECKPOINT state periodically | Scheduled task |
| AOR-RECOV-007 | BACKUP before destructive operations | Backup protocol |
| AOR-RECOV-008 | TEST recovery procedures regularly | Recovery tests |
| AOR-RECOV-009 | MAINTAIN recovery time objective (RTO) < 5 minutes | RTO validation |
| AOR-RECOV-010 | MAINTAIN recovery point objective (RPO) < 1 minute | RPO validation |

---

## 4. FMEA Analysis

### 4.1 FMEA Severity Scale

| Level | Severity | Description | Effect |
|-------|----------|-------------|--------|
| 10 | Catastrophic | System failure with data loss | Complete outage |
| 9 | Critical | System failure, recoverable | Extended outage |
| 8 | Major | Feature failure | Partial outage |
| 7 | High | Degraded performance | User impact |
| 6 | Moderate | Noticeable issues | Minor user impact |
| 5 | Low | Minor issues | Minimal impact |
| 4 | Very Low | Cosmetic issues | No impact |
| 3 | Minimal | Detectable, no effect | None |
| 2 | Very Minimal | Rarely detectable | None |
| 1 | None | Undetectable | None |

### 4.2 Connection Pool Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-CP-001 | Pool exhaustion | Queries timeout | 8 | 4 | 3 | 96 | Dynamic pool sizing |
| FM-CP-002 | Connection leak | Gradual degradation | 7 | 3 | 5 | 105 | Connection tracking |
| FM-CP-003 | Stale connection | Query failure | 6 | 4 | 4 | 96 | Keep-alive pings |
| FM-CP-004 | Pool creation failure | Service won't start | 9 | 2 | 2 | 36 | Retry with backoff |
| FM-CP-005 | Checkout timeout | Request failure | 6 | 5 | 3 | 90 | Queue management |
| FM-CP-006 | Connection corruption | Data integrity risk | 9 | 1 | 6 | 54 | Connection validation |

### 4.3 Concurrency Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-CONC-001 | Lost update | Data inconsistency | 9 | 3 | 7 | 189 | OCC with version vectors |
| FM-CONC-002 | Dirty read | Incorrect data | 8 | 2 | 6 | 96 | Transaction isolation |
| FM-CONC-003 | Phantom read | Query inconsistency | 7 | 3 | 5 | 105 | Serializable isolation |
| FM-CONC-004 | Deadlock | System hang | 9 | 2 | 4 | 72 | Timeout detection |
| FM-CONC-005 | Starvation | Unfair access | 7 | 2 | 5 | 70 | Fair scheduling |
| FM-CONC-006 | Version vector overflow | Loss of ordering | 10 | 1 | 8 | 80 | 64-bit counters |
| FM-CONC-007 | CAS failure cascade | Repeated retries | 6 | 4 | 3 | 72 | Exponential backoff |
| FM-CONC-008 | Lock not released | Resource leak | 8 | 2 | 4 | 64 | Lock timeout |
| FM-CONC-009 | Split brain | Data divergence | 10 | 1 | 7 | 70 | Quorum consensus |
| FM-CONC-010 | Race condition | Undefined behavior | 9 | 2 | 6 | 108 | Atomic operations |

### 4.4 Zenoh Bridge Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-ZB-001 | Router unreachable | Cross-holon access fails | 8 | 3 | 2 | 48 | Reconnect logic |
| FM-ZB-002 | Message corruption | Invalid request/response | 8 | 1 | 4 | 32 | Checksum validation |
| FM-ZB-003 | Request timeout | Operation failure | 6 | 5 | 3 | 90 | Retry with backoff |
| FM-ZB-004 | Response mismatch | Wrong data returned | 9 | 1 | 5 | 45 | Request ID correlation |
| FM-ZB-005 | Topic routing error | Message lost | 8 | 2 | 6 | 96 | Topic validation |
| FM-ZB-006 | Serialization failure | Request rejected | 7 | 2 | 3 | 42 | Schema validation |
| FM-ZB-007 | Buffer overflow | Memory exhaustion | 8 | 1 | 4 | 32 | Buffer limits |
| FM-ZB-008 | Session leak | Resource exhaustion | 7 | 2 | 5 | 70 | Session management |
| FM-ZB-009 | Ordering violation | FIFO broken | 8 | 2 | 6 | 96 | Sequence numbers |
| FM-ZB-010 | Latency spike | Timeout cascade | 7 | 4 | 4 | 112 | Adaptive timeout |

### 4.5 Database Integrity Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-DI-001 | SQLite corruption | Data loss | 10 | 1 | 3 | 30 | WAL + integrity check |
| FM-DI-002 | DuckDB corruption | Analytics unavailable | 8 | 1 | 4 | 32 | Regular backups |
| FM-DI-003 | Index corruption | Query errors | 7 | 2 | 4 | 56 | Index rebuild |
| FM-DI-004 | Schema mismatch | Operation failure | 8 | 2 | 3 | 48 | Schema versioning |
| FM-DI-005 | Disk full | Write failure | 9 | 2 | 2 | 36 | Disk monitoring |
| FM-DI-006 | File lock conflict | Access denied | 7 | 3 | 3 | 63 | Lock management |
| FM-DI-007 | Transaction log overflow | Recovery impacted | 8 | 2 | 4 | 64 | Log rotation |
| FM-DI-008 | Checkpoint failure | Durability risk | 8 | 2 | 4 | 64 | Checkpoint retry |
| FM-DI-009 | Foreign key violation | Data integrity | 7 | 3 | 3 | 63 | Constraint enforcement |
| FM-DI-010 | Type mismatch | Query failure | 6 | 3 | 3 | 54 | Type validation |

### 4.6 Cross-Runtime Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-XR-001 | Elixir holon down | Bridge unavailable | 8 | 3 | 2 | 48 | Health monitoring |
| FM-XR-002 | F# holon down | Bridge unavailable | 8 | 3 | 2 | 48 | Health monitoring |
| FM-XR-003 | UHI resolution failure | Wrong target | 9 | 1 | 4 | 36 | UHI validation |
| FM-XR-004 | Protocol mismatch | Communication failure | 8 | 2 | 3 | 48 | Version negotiation |
| FM-XR-005 | Type conversion error | Data corruption | 8 | 2 | 5 | 80 | Type mappings |
| FM-XR-006 | Timezone handling error | Time inconsistency | 6 | 3 | 5 | 90 | UTC everywhere |
| FM-XR-007 | Encoding mismatch | Character corruption | 7 | 2 | 4 | 56 | UTF-8 enforcement |
| FM-XR-008 | Floating point precision | Numeric errors | 5 | 3 | 6 | 90 | Decimal types |
| FM-XR-009 | NULL handling difference | Logic errors | 6 | 3 | 5 | 90 | Explicit NULL handling |
| FM-XR-010 | Date format mismatch | Parse errors | 6 | 3 | 4 | 72 | ISO 8601 format |

### 4.7 Two-Phase Commit Failures

| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FM-2PC-001 | Coordinator crash after prepare | Uncertain state | 10 | 1 | 5 | 50 | Recovery protocol |
| FM-2PC-002 | Participant crash after prepare | Blocked resources | 9 | 1 | 4 | 36 | Timeout recovery |
| FM-2PC-003 | Network partition during commit | Split decision | 10 | 1 | 6 | 60 | Quorum-based decision |
| FM-2PC-004 | Prepare timeout | Transaction abort | 6 | 3 | 3 | 54 | Retry logic |
| FM-2PC-005 | Commit message lost | Inconsistent state | 9 | 1 | 6 | 54 | Idempotent commit |
| FM-2PC-006 | Rollback message lost | Resource leak | 7 | 2 | 5 | 70 | Cleanup protocol |

### 4.8 RPN Priority Matrix

| RPN Range | Priority | Action Required |
|-----------|----------|-----------------|
| 150-200 | Critical | Immediate fix required |
| 100-149 | High | Fix in current sprint |
| 50-99 | Medium | Plan for next sprint |
| 25-49 | Low | Monitor and track |
| 1-24 | Acceptable | Document only |

**Critical Failures (RPN ≥ 100):**
- FM-CONC-001: Lost update (RPN 189) - **MITIGATED by OCC**
- FM-ZB-010: Latency spike (RPN 112) - **MITIGATED by adaptive timeout**
- FM-CONC-010: Race condition (RPN 108) - **MITIGATED by atomic operations**
- FM-CP-002: Connection leak (RPN 105) - **MITIGATED by connection tracking**
- FM-CONC-003: Phantom read (RPN 105) - **MITIGATED by serializable isolation**

---

## 5. Control Flow Safety Analysis

### 5.1 Direct Database Access Flow (Same Runtime)

```
┌─────────────────────────────────────────────────────────────────────┐
│  DIRECT ACCESS CONTROL FLOW (Safe States Marked ✓)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Client Request                                                      │
│       │                                                              │
│       ▼                                                              │
│  ┌─────────────┐                                                    │
│  │ Input       │ ✓ Parameterized query validation                   │
│  │ Validation  │ ✓ SQL injection prevention                         │
│  └──────┬──────┘                                                    │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────┐                                                    │
│  │ Pool        │ ✓ Connection acquired within timeout               │
│  │ Checkout    │ ✓ Pool not exhausted                               │
│  └──────┬──────┘                                                    │
│         │                                                            │
│         ├──────────────────┐                                        │
│         │                  │                                        │
│         ▼                  ▼                                        │
│  ┌─────────────┐    ┌─────────────┐                                │
│  │ Read Path   │    │ Write Path  │                                │
│  │ (Lock-Free) │    │ (OCC/Lock)  │                                │
│  └──────┬──────┘    └──────┬──────┘                                │
│         │                  │                                        │
│         │                  ▼                                        │
│         │           ┌─────────────┐                                │
│         │           │ Version     │ ✓ Version read before write    │
│         │           │ Vector Get  │                                │
│         │           └──────┬──────┘                                │
│         │                  │                                        │
│         │                  ▼                                        │
│         │           ┌─────────────┐                                │
│         │           │ Transaction │ ✓ Atomic execution             │
│         │           │ Begin       │ ✓ Isolation level set          │
│         │           └──────┬──────┘                                │
│         │                  │                                        │
│         │                  ▼                                        │
│         │           ┌─────────────┐                                │
│         │           │ Execute     │ ✓ Query executed               │
│         │           │ Operation   │                                │
│         │           └──────┬──────┘                                │
│         │                  │                                        │
│         │                  ▼                                        │
│         │           ┌─────────────┐    ┌─────────────┐            │
│         │           │ Compare &   │───▶│ Conflict?   │            │
│         │           │ Swap        │    │ Retry/Fail  │            │
│         │           └──────┬──────┘    └─────────────┘            │
│         │                  │ No Conflict                           │
│         │                  ▼                                        │
│         │           ┌─────────────┐                                │
│         │           │ Transaction │ ✓ Durably committed           │
│         │           │ Commit      │ ✓ Version incremented         │
│         │           └──────┬──────┘                                │
│         │                  │                                        │
│         ▼                  ▼                                        │
│  ┌─────────────┐                                                    │
│  │ Pool        │ ✓ Connection returned                             │
│  │ Checkin     │                                                    │
│  └──────┬──────┘                                                    │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────┐                                                    │
│  │ Response    │ ✓ Result or error returned                        │
│  │ Return      │ ✓ Telemetry emitted                               │
│  └─────────────┘                                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cross-Holon Access Flow (Different Runtime)

```
┌─────────────────────────────────────────────────────────────────────┐
│  CROSS-HOLON ACCESS CONTROL FLOW (Zenoh Bridge)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────────────┐      ┌───────────────────────┐          │
│  │    Elixir Holon       │      │      F# Holon         │          │
│  │  (Source: ex:l3:kms)  │      │  (Target: fs:l4:prj)  │          │
│  └───────────┬───────────┘      └───────────┬───────────┘          │
│              │                              │                        │
│              ▼                              │                        │
│  ┌───────────────────────┐                 │                        │
│  │ 1. Build Request      │                 │                        │
│  │    - request_id       │                 │                        │
│  │    - source UHI       │                 │                        │
│  │    - target UHI       │                 │                        │
│  │    - operation        │                 │                        │
│  │    - SQL + params     │                 │                        │
│  │    - version (if CAS) │                 │                        │
│  └───────────┬───────────┘                 │                        │
│              │                              │                        │
│              ▼                              │                        │
│  ┌───────────────────────┐                 │                        │
│  │ 2. Serialize to JSON  │                 │                        │
│  │    ✓ Schema validated │                 │                        │
│  └───────────┬───────────┘                 │                        │
│              │                              │                        │
│              ▼                              │                        │
│  ┌───────────────────────┐                 │                        │
│  │ 3. Publish to Zenoh   │                 │                        │
│  │    Topic: indrajaal/  │                 │                        │
│  │    db/ex/kms/request/ │                 │                        │
│  │    fs/cockpit/state   │                 │                        │
│  └───────────┬───────────┘                 │                        │
│              │                              │                        │
│              │     ┌────────────────────┐  │                        │
│              └────▶│   ZENOH ROUTER     │──┘                        │
│                    │   (Message Bus)    │                            │
│                    └────────┬───────────┘                            │
│                             │                                        │
│                             ▼                                        │
│              ┌───────────────────────┐                              │
│              │ 4. F# Bridge Receives │                              │
│              │    ✓ Topic matched    │                              │
│              │    ✓ JSON parsed      │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│                          ▼                                          │
│              ┌───────────────────────┐                              │
│              │ 5. Route to Database  │                              │
│              │    ✓ Target found     │                              │
│              │    ✓ DB type valid    │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│                          ▼                                          │
│              ┌───────────────────────┐                              │
│              │ 6. Execute Operation  │                              │
│              │    ✓ Query/Execute/   │                              │
│              │      ExecuteCAS       │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│                          ▼                                          │
│              ┌───────────────────────┐                              │
│              │ 7. Build Response     │                              │
│              │    - request_id       │                              │
│              │    - success/error    │                              │
│              │    - result/rows      │                              │
│              │    - new_version      │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│                          ▼                                          │
│              ┌───────────────────────┐                              │
│              │ 8. Publish Response   │                              │
│              │    Topic: indrajaal/  │                              │
│              │    db/ex/kms/response │                              │
│              │    /{request_id}      │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│     ┌────────────────────┘                                          │
│     │                                                                │
│     ▼                                                                │
│  ┌───────────────────────┐                                          │
│  │ 9. Elixir Receives    │                                          │
│  │    ✓ Correlated by ID │                                          │
│  │    ✓ JSON parsed      │                                          │
│  └───────────┬───────────┘                                          │
│              │                                                       │
│              ▼                                                       │
│  ┌───────────────────────┐                                          │
│  │ 10. Return Result     │                                          │
│  │    ✓ {:ok, data}      │                                          │
│  │    ✓ {:error, reason} │                                          │
│  │    ✓ {:conflict, vv}  │                                          │
│  └───────────────────────┘                                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3 Two-Phase Commit Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  TWO-PHASE COMMIT CONTROL FLOW (Distributed Transaction)            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐              │
│  │ Coordinator │   │Participant A│   │Participant B│              │
│  │ (ex:l3:kms) │   │(fs:l4:prj)  │   │(fs:l5:ana)  │              │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘              │
│         │                 │                 │                       │
│         │   PHASE 1: PREPARE                │                       │
│         │─────────────────│─────────────────│                       │
│         │                 │                 │                       │
│         │  PREPARE(txn_id)│                 │                       │
│         │────────────────▶│                 │                       │
│         │                 │                 │                       │
│         │  PREPARE(txn_id)│                 │                       │
│         │─────────────────│────────────────▶│                       │
│         │                 │                 │                       │
│         │                 │  ┌───────────┐  │                       │
│         │                 │  │ Acquire   │  │                       │
│         │                 │  │ Locks     │  │                       │
│         │                 │  └─────┬─────┘  │                       │
│         │                 │        │        │                       │
│         │  PREPARED(ok)   │◀───────┘        │                       │
│         │◀────────────────│                 │                       │
│         │                 │                 │  ┌───────────┐        │
│         │                 │                 │  │ Acquire   │        │
│         │                 │                 │  │ Locks     │        │
│         │                 │                 │  └─────┬─────┘        │
│         │  PREPARED(ok)   │                 │        │              │
│         │◀────────────────│─────────────────│◀───────┘              │
│         │                 │                 │                       │
│         │   PHASE 2: COMMIT                 │                       │
│         │─────────────────│─────────────────│                       │
│         │                 │                 │                       │
│         │  COMMIT(txn_id) │                 │                       │
│         │────────────────▶│                 │                       │
│         │                 │                 │                       │
│         │  COMMIT(txn_id) │                 │                       │
│         │─────────────────│────────────────▶│                       │
│         │                 │                 │                       │
│         │                 │  ┌───────────┐  │                       │
│         │                 │  │ Apply &   │  │                       │
│         │                 │  │ Release   │  │                       │
│         │                 │  └─────┬─────┘  │                       │
│         │                 │        │        │                       │
│         │  COMMITTED      │◀───────┘        │                       │
│         │◀────────────────│                 │                       │
│         │                 │                 │  ┌───────────┐        │
│         │                 │                 │  │ Apply &   │        │
│         │                 │                 │  │ Release   │        │
│         │                 │                 │  └─────┬─────┘        │
│         │  COMMITTED      │                 │        │              │
│         │◀────────────────│─────────────────│◀───────┘              │
│         │                 │                 │                       │
│         ▼                 │                 │                       │
│  ┌─────────────┐         │                 │                       │
│  │ Transaction │         │                 │                       │
│  │ Complete    │         │                 │                       │
│  └─────────────┘         │                 │                       │
│                                                                      │
│  ROLLBACK PATH (if any PREPARE fails):                              │
│         │                 │                 │                       │
│         │  ROLLBACK       │                 │                       │
│         │────────────────▶│                 │                       │
│         │─────────────────│────────────────▶│                       │
│         │                 │                 │                       │
│         │  ROLLED_BACK    │  ROLLED_BACK    │                       │
│         │◀────────────────│◀────────────────│                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. Mathematical Safety Properties

### 6.1 Version Vector Properties

**Property 1: Monotonicity**
```
∀ vv, holon_id:
  increment(vv, holon_id)[holon_id] > vv[holon_id] ∨
  (holon_id ∉ keys(vv) ∧ increment(vv, holon_id)[holon_id] = 1)
```

**Property 2: Merge Commutativity**
```
∀ vv1, vv2:
  merge(vv1, vv2) = merge(vv2, vv1)
```

**Property 3: Merge Associativity**
```
∀ vv1, vv2, vv3:
  merge(merge(vv1, vv2), vv3) = merge(vv1, merge(vv2, vv3))
```

**Property 4: Happens-Before Transitivity**
```
∀ vv1, vv2, vv3:
  happensBefore(vv1, vv2) ∧ happensBefore(vv2, vv3) ⟹ happensBefore(vv1, vv3)
```

**Property 5: Concurrent Detection**
```
∀ vv1, vv2:
  concurrent(vv1, vv2) ⟺ ¬happensBefore(vv1, vv2) ∧ ¬happensBefore(vv2, vv1)
```

### 6.2 OCC Correctness Properties

**Property 6: Serializability**
```
∀ transactions T1, T2:
  (commit(T1) ∧ commit(T2) ∧ conflict(T1, T2)) ⟹
  (happensBefore(T1.write_version, T2.read_version) ∨
   happensBefore(T2.write_version, T1.read_version))
```

**Property 7: No Lost Updates**
```
∀ write operations W1, W2 on same key K:
  commit(W1) ∧ commit(W2) ⟹
  W1.version ≠ W2.version
```

**Property 8: Retry Fairness**
```
∀ transaction T with retry count N:
  N ≤ MAX_RETRIES ∧
  delay(N) = min(BASE_DELAY × 2^N + jitter, MAX_DELAY)
```

### 6.3 Two-Phase Commit Properties

**Property 9: Atomicity**
```
∀ distributed transaction T:
  (∀ participant P: commit(T, P)) ∨ (∀ participant P: abort(T, P))
```

**Property 10: Consistency**
```
∀ distributed transaction T:
  pre(T) satisfies invariants ⟹ post(T) satisfies invariants
```

**Property 11: Isolation**
```
∀ transactions T1, T2:
  execute_concurrent(T1, T2) produces same result as
  execute_serial(T1, T2) or execute_serial(T2, T1)
```

**Property 12: Durability**
```
∀ committed transaction T:
  crash(system) ∧ recover(system) ⟹ effects(T) preserved
```

---

## 7. 5-Order Effects Analysis

### 7.1 Direct Query Operation

| Order | Effect | Time Scale | Verification |
|-------|--------|------------|--------------|
| 1st | Query parsed, execution plan created | Immediate | Plan captured |
| 2nd | Connection acquired, query executed | Milliseconds | Execution time |
| 3rd | Result set assembled, memory allocated | Milliseconds | Memory usage |
| 4th | Telemetry emitted, metrics updated | Milliseconds | Telemetry event |
| 5th | Cache potentially invalidated, stats updated | Seconds | Cache state |

### 7.2 Direct Write Operation (OCC)

| Order | Effect | Time Scale | Verification |
|-------|--------|------------|--------------|
| 1st | Version vector read, lock acquired | Immediate | Lock held |
| 2nd | Transaction started, operation executed | Milliseconds | Transaction active |
| 3rd | CAS performed, conflict detected/resolved | Milliseconds | CAS result |
| 4th | Transaction committed, version incremented | Milliseconds | New version |
| 5th | Indexes updated, triggers fired, replication | Seconds | Index state |

### 7.3 Cross-Holon Query

| Order | Effect | Time Scale | Verification |
|-------|--------|------------|--------------|
| 1st | Request serialized, published to Zenoh | Immediate | Message sent |
| 2nd | Message routed, received by target bridge | Milliseconds | Message delivered |
| 3rd | Query executed on target database | Milliseconds | Query result |
| 4th | Response serialized, returned via Zenoh | Milliseconds | Response sent |
| 5th | Source receives, telemetry updated, cache | Seconds | Response received |

### 7.4 Two-Phase Commit

| Order | Effect | Time Scale | Verification |
|-------|--------|------------|--------------|
| 1st | Prepare messages sent to all participants | Immediate | Messages sent |
| 2nd | Participants acquire locks, vote | Milliseconds-Seconds | Votes received |
| 3rd | Coordinator decides commit/abort | Milliseconds | Decision made |
| 4th | Commit/abort messages sent, applied | Milliseconds-Seconds | Applied |
| 5th | Locks released, logs updated, metrics | Seconds | Cleanup complete |

---

## 8. Mitigation Strategies

### 8.1 Connection Pool Mitigations

| Risk | Mitigation | Implementation |
|------|------------|----------------|
| Pool exhaustion | Dynamic pool sizing based on load | `adjust_pool_size/2` |
| Connection leak | Tracking with automatic cleanup | `check_connections/0` |
| Stale connection | Keep-alive pings every 30s | `ping_connections/0` |

### 8.2 Concurrency Mitigations

| Risk | Mitigation | Implementation |
|------|------------|----------------|
| Lost update | OCC with version vectors | `compareAndSwap/5` |
| Deadlock | Timeout-based detection | 10s timeout |
| Starvation | Fair retry with jitter | Exponential backoff |

### 8.3 Bridge Mitigations

| Risk | Mitigation | Implementation |
|------|------------|----------------|
| Router unreachable | Reconnect with backoff | Auto-reconnect |
| Message loss | Request ID correlation | Unique request IDs |
| Latency spike | Adaptive timeout | Dynamic timeout |

### 8.4 Integrity Mitigations

| Risk | Mitigation | Implementation |
|------|------------|----------------|
| File corruption | WAL mode + integrity check | SQLite PRAGMA |
| Disk full | Space monitoring | Alert at 80% |
| Schema mismatch | Version negotiation | Schema versioning |

---

## 9. Verification Requirements

### 9.1 Unit Tests Required

| Category | Test Count | Priority |
|----------|------------|----------|
| Version Vector Operations | 15 | P0 |
| Connection Pool | 12 | P0 |
| OCC Concurrency | 20 | P0 |
| Zenoh Bridge | 18 | P0 |
| Two-Phase Commit | 15 | P1 |

### 9.2 Property Tests Required

| Property | Generator | Shrinking |
|----------|-----------|-----------|
| Version vector monotonicity | Random increments | Minimal counter |
| Merge commutativity | Random version vectors | Minimal keys |
| CAS correctness | Concurrent operations | Minimal conflicts |
| FIFO ordering | Message sequences | Minimal queue |

### 9.3 Integration Tests Required

| Scenario | Components | Duration |
|----------|------------|----------|
| Direct access roundtrip | Pool + DB | 10ms |
| Cross-holon query | Bridge + Zenoh + DB | 200ms |
| OCC conflict resolution | Multiple writers | 500ms |
| Two-phase commit success | Coordinator + Participants | 1000ms |
| Two-phase commit rollback | Coordinator + Participants | 1000ms |

### 9.4 Chaos Tests Required

| Failure Injection | Expected Behavior |
|-------------------|-------------------|
| Kill Zenoh router | Reconnect within 30s |
| Exhaust connection pool | Queue requests, timeout |
| Inject network latency | Adaptive timeout |
| Force OCC conflict | Retry with backoff |
| Coordinator crash | Recovery protocol |

---

## Document Control

| Field | Value |
|-------|-------|
| Author | Claude Opus 4.5 |
| Created | 2026-01-17 |
| STAMP | SC-XHOLON-*, SC-BRIDGE-*, SC-DBINT-*, SC-CONC-*, SC-PERF-*, SC-SEC-DB-* |
| AOR | AOR-DB-*, AOR-CONC-*, AOR-BRIDGE-*, AOR-RECOV-* |
| FMEA | FM-CP-*, FM-CONC-*, FM-ZB-*, FM-DI-*, FM-XR-*, FM-2PC-* |

---

**Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>**
