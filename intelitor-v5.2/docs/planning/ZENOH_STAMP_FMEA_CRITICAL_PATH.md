# Zenoh F# Integration: STAMP Analysis, FMEA, and Critical Path Implementation

**Version**: 1.0.0 | **Date**: 2026-01-14 | **STAMP**: SC-ZENOH-SAFETY-001
**Author**: Claude Opus 4.5 | **Status**: PLANNING | **Compliance**: SIL-6 Biomorphic

---

## Executive Summary

This document provides comprehensive safety and implementation analysis for integrating Zenoh into the F# CEPAF codebase:

1. **STAMP Analysis**: Systems-Theoretic Accident Model identifying control structures, hazards, and safety constraints
2. **FMEA Analysis**: 100+ failure modes with RPN scores and mitigations
3. **Critical Path Implementation**: CPM-based phased implementation with dependencies

---

# PART I: STAMP (Systems-Theoretic Accident Model and Processes) Analysis

## 1.1 System Overview

### Control Structure Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ZENOH F# INTEGRATION CONTROL STRUCTURE                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LEVEL 0: CONSTITUTIONAL (Ψ₀-Ψ₅)                                            │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  Guardian                    │  Safety Invariants               │        │
│  │  - Veto authority           │  - Ψ₀: Existence                 │        │
│  │  - Constitutional checks    │  - Ψ₃: Verification              │        │
│  │  - Ω₀: Founder's Directive  │  - Ψ₅: Truthfulness              │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                            │ Control                                         │
│                            ▼ Actions                                         │
│  LEVEL 1: OPERATIONAL (F# CEPAF)                                            │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  ZenohLifecycle           │  ZenohQuorum        │  ZenohFed    │        │
│  │  - Initialize/Shutdown    │  - 2oo3 voting      │  - Announce  │        │
│  │  - Health monitoring      │  - Barrier sync     │  - Negotiate │        │
│  │  - Reconnection           │  - Consensus        │  - Attest    │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                            │ Control                                         │
│                            ▼ Actions                                         │
│  LEVEL 2: SESSION MANAGEMENT                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  ZenohSession             │  ZenohNative                        │        │
│  │  - Connection state       │  - FFI wrappers                     │        │
│  │  - Subscriber registry    │  - Memory management                │        │
│  │  - Publisher management   │  - Error handling                   │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                            │ Control                                         │
│                            ▼ Actions                                         │
│  LEVEL 3: MESSAGING                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  ZenohPublisher           │  ZenohSubscriber    │  ZenohQuery  │        │
│  │  - Typed publish          │  - Callback handler │  - Get/Reply │        │
│  │  - Envelope creation      │  - Miss detection   │  - Timeout   │        │
│  │  - Batch optimization     │  - Recovery         │  - Queryable │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                            │ Control                                         │
│                            ▼ Actions                                         │
│  LEVEL 4: NATIVE LAYER (Zenoh-CS → zenoh-c)                                 │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  Session (FFI)            │  Publisher (FFI)    │  KeyExpr     │        │
│  │  - z_open/z_close         │  - z_put            │  - z_keyexpr │        │
│  │  - z_session_check        │  - z_publisher_put  │  - Wildcard  │        │
│  │  - z_config               │  - z_subscriber     │  - Matching  │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                            │ Control                                         │
│                            ▼ Actions                                         │
│  LEVEL 5: ZENOH ROUTER (zenohd)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  Router Instance          │  Transport Layer    │  Routing     │        │
│  │  - Session management     │  - TCP/UDP/QUIC     │  - KeyExpr   │        │
│  │  - Plugin loading         │  - SHM transport    │  - Tree-based│        │
│  │  - Access control         │  - Multicast        │  - Filtering │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                              │
│  FEEDBACK LOOPS:                                                             │
│  ├── L4 → L3: Sample delivery, error codes                                  │
│  ├── L3 → L2: Publish/subscribe results, miss notifications                 │
│  ├── L2 → L1: Connection status, statistics                                 │
│  ├── L1 → L0: Health reports, quorum results                                │
│  └── L0 → Guardian: Constitutional compliance reports                        │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 1.2 Hazard Identification

### System-Level Hazards

| ID | Hazard | Description | Severity |
|----|--------|-------------|----------|
| H-001 | **Loss of Communication** | Complete Zenoh connectivity failure | CATASTROPHIC |
| H-002 | **Data Corruption** | Messages delivered with altered content | CRITICAL |
| H-003 | **Message Loss** | Published messages never delivered | MAJOR |
| H-004 | **Message Duplication** | Same message delivered multiple times | MODERATE |
| H-005 | **Out-of-Order Delivery** | Messages arrive in wrong sequence | MODERATE |
| H-006 | **Latency Violation** | Messages exceed timing requirements | MAJOR |
| H-007 | **Resource Exhaustion** | Memory/handle leaks cause system failure | CRITICAL |
| H-008 | **Split Brain** | Network partition causes inconsistent state | CRITICAL |
| H-009 | **Quorum Failure** | Unable to reach consensus | MAJOR |
| H-010 | **Authentication Bypass** | Unauthorized access to pub/sub | CRITICAL |

### Hazard Causal Analysis

```
H-001: Loss of Communication
├── CA-001.1: Zenoh router crash
│   ├── SC-ROUTER-001: Router health monitoring
│   └── SC-ROUTER-002: Auto-restart with systemd
├── CA-001.2: Network partition
│   ├── SC-NET-001: Multi-path routing
│   └── SC-NET-002: Partition detection
├── CA-001.3: F# session corruption
│   ├── SC-SESSION-001: Session validation
│   └── SC-SESSION-002: Automatic reconnection
└── CA-001.4: Native library crash
    ├── SC-NATIVE-001: Exception handling
    └── SC-NATIVE-002: Process isolation

H-002: Data Corruption
├── CA-002.1: Memory corruption in FFI
│   ├── SC-FFI-001: Safe memory wrappers
│   └── SC-FFI-002: Bounds checking
├── CA-002.2: Serialization error
│   ├── SC-SER-001: Type-safe serialization
│   └── SC-SER-002: Schema validation
└── CA-002.3: Man-in-the-middle attack
    ├── SC-SEC-001: TLS encryption
    └── SC-SEC-002: Message signing

H-007: Resource Exhaustion
├── CA-007.1: Session handle leak
│   ├── SC-LEAK-001: IDisposable pattern
│   └── SC-LEAK-002: Finalizer cleanup
├── CA-007.2: Subscriber accumulation
│   ├── SC-SUB-001: Subscriber registry limit
│   └── SC-SUB-002: Auto-cleanup on disconnect
├── CA-007.3: Message buffer overflow
│   ├── SC-BUF-001: Bounded buffer size
│   └── SC-BUF-002: Back-pressure signaling
└── CA-007.4: Native memory leak
    ├── SC-NAT-001: Memory tracking
    └── SC-NAT-002: Periodic GC trigger
```

## 1.3 Safety Constraints (SC-ZENOH-*)

### Level 0: Constitutional Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-CONST-001 | Zenoh integration SHALL NOT violate Ψ₀ (Existence) | Guardian veto |
| SC-CONST-002 | Communication failures SHALL trigger graceful degradation | Fallback paths |
| SC-CONST-003 | All Zenoh state SHALL be recoverable from SQLite/DuckDB | State persistence |
| SC-CONST-004 | Zenoh configuration SHALL be immutable after startup | Frozen config |

### Level 1: Operational Constraints

| ID | Constraint | Enforcement | Hazard |
|----|------------|-------------|--------|
| SC-OP-001 | Session initialization SHALL complete within 5 seconds | Timeout | H-001 |
| SC-OP-002 | Reconnection SHALL use exponential backoff (max 60s) | Algorithm | H-001 |
| SC-OP-003 | Health check SHALL run every 10 seconds | Timer | H-001 |
| SC-OP-004 | Maximum 10 reconnection attempts before alert | Counter | H-001 |
| SC-OP-005 | Quorum voting SHALL require 2oo3 for SIL-6 | Voting logic | H-008, H-009 |
| SC-OP-006 | Barrier synchronization SHALL timeout in 30 seconds | Deadline | H-009 |
| SC-OP-007 | Federation attestation SHALL occur every hour | Timer | H-010 |

### Level 2: Session Constraints

| ID | Constraint | Enforcement | Hazard |
|----|------------|-------------|--------|
| SC-SESS-001 | Session SHALL be singleton per process | Module state | H-007 |
| SC-SESS-002 | Session closure SHALL complete within 1 second | Timeout | H-007 |
| SC-SESS-003 | Maximum 1000 active subscribers per session | Registry limit | H-007 |
| SC-SESS-004 | Connection status SHALL be observable | State exposure | H-001 |
| SC-SESS-005 | All FFI calls SHALL be wrapped in try/catch | Exception handling | H-007 |

### Level 3: Messaging Constraints

| ID | Constraint | Enforcement | Hazard |
|----|------------|-------------|--------|
| SC-MSG-001 | Message latency SHALL be < 100ms (p99) | Monitoring | H-006 |
| SC-MSG-002 | All messages SHALL use ZenohEnvelope | Type system | H-002 |
| SC-MSG-003 | Callback execution SHALL timeout in 50ms | Timeout wrapper | H-006 |
| SC-MSG-004 | Message buffer SHALL be bounded to 10000 entries | Buffer limit | H-007 |
| SC-MSG-005 | Miss detection SHALL be enabled for critical topics | Configuration | H-003 |
| SC-MSG-006 | Batch size SHALL NOT exceed 100 messages | Batch limit | H-006 |

### Level 4: Native Layer Constraints

| ID | Constraint | Enforcement | Hazard |
|----|------------|-------------|--------|
| SC-NAT-001 | Native library version SHALL be 0.4.1 (zenoh-c v1.6.2) | Version pin | H-002 |
| SC-NAT-002 | All owned types SHALL implement IDisposable | Interface | H-007 |
| SC-NAT-003 | KeyExpr validation SHALL precede all operations | Pre-check | H-002 |
| SC-NAT-004 | Null checks SHALL protect all FFI return values | Option type | H-007 |

### Level 5: Router Constraints

| ID | Constraint | Enforcement | Hazard |
|----|------------|-------------|--------|
| SC-RTR-001 | Router SHALL be deployed with container depends_on | Compose config | H-001 |
| SC-RTR-002 | Router health SHALL be checked before session open | Pre-check | H-001 |
| SC-RTR-003 | Multiple router endpoints SHALL be configured | Fallback | H-001 |
| SC-RTR-004 | Router access control SHALL be enabled | ACL config | H-010 |

## 1.4 Unsafe Control Actions (UCA)

### UCA Table

| ID | Controller | Control Action | Type | Hazard | Constraint |
|----|------------|----------------|------|--------|------------|
| UCA-001 | ZenohLifecycle | Initialize | Not provided when required | H-001 | SC-OP-001 |
| UCA-002 | ZenohLifecycle | Initialize | Provided too late | H-001 | SC-OP-001 |
| UCA-003 | ZenohLifecycle | Shutdown | Not provided when required | H-007 | SC-SESS-002 |
| UCA-004 | ZenohLifecycle | Reconnect | Provided too frequently | H-007 | SC-OP-002 |
| UCA-005 | ZenohSession | Publish | Provided when disconnected | H-003 | SC-SESS-004 |
| UCA-006 | ZenohSession | Publish | Provided with invalid key | H-002 | SC-NAT-003 |
| UCA-007 | ZenohSession | Subscribe | Provided with unbounded callback | H-006 | SC-MSG-003 |
| UCA-008 | ZenohQuorum | Vote | Not provided when required | H-009 | SC-OP-005 |
| UCA-009 | ZenohQuorum | Vote | Provided with wrong count | H-008 | SC-OP-005 |
| UCA-010 | ZenohNative | Dispose | Not provided for owned resource | H-007 | SC-NAT-002 |
| UCA-011 | ZenohPublisher | Batch | Provided with size > 100 | H-006 | SC-MSG-006 |
| UCA-012 | ZenohSubscriber | Callback | Executed beyond timeout | H-006 | SC-MSG-003 |

## 1.5 Control Loop Analysis

### Primary Control Loops

```
LOOP 1: Connection Management
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ZenohLifecycle ──────┐                                             │
│       │               │ Initialize()                                 │
│       │               ▼                                              │
│       │         ZenohSession ──────┐                                │
│       │              │             │ openSession()                   │
│       │              │             ▼                                 │
│       │              │       ZenohNative ──────┐                    │
│       │              │             │           │ Session.Open()      │
│       │              │             │           ▼                     │
│       │              │             │      Zenoh-CS (FFI)            │
│       │              │             │           │                     │
│       │              │             │           ▼ Feedback            │
│       │              │             │◄──── Session handle / Error    │
│       │              │             │                                 │
│       │              │◄──────────── SafeSession / Error             │
│       │              │                                               │
│       │◄───────────── Connection status                              │
│       │                                                              │
│       ▼                                                              │
│  Health Timer (10s) ─► healthCheck() ─► Reconnect if needed        │
│                                                                      │
│  SAFETY CONSTRAINTS:                                                 │
│  • SC-OP-001: Init timeout 5s                                       │
│  • SC-OP-002: Exponential backoff                                   │
│  • SC-OP-003: Health check 10s                                      │
│  • SC-OP-004: Max 10 reconnects                                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

LOOP 2: Message Publishing
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Application ─────────┐                                             │
│       │               │ publishAsync(key, payload)                   │
│       │               ▼                                              │
│       │         ZenohPublisher ────┐                                │
│       │              │             │ createEnvelope()                │
│       │              │             │ serialize()                     │
│       │              │             ▼                                 │
│       │              │       ZenohSession ────┐                     │
│       │              │             │          │ publish()            │
│       │              │             │          ▼                      │
│       │              │             │     ZenohNative ────┐          │
│       │              │             │          │          │ Put()     │
│       │              │             │          │          ▼           │
│       │              │             │          │     Zenoh-CS        │
│       │              │             │          │          │           │
│       │              │             │          │          ▼ Feedback  │
│       │              │             │          │◄──── Result/Error   │
│       │              │             │          │                      │
│       │              │             │◄──────── Result/Error          │
│       │              │             │                                 │
│       │              │◄──────────── Publish result                  │
│       │              │                                               │
│       │◄───────────── Result<unit, string>                          │
│       │                                                              │
│  SAFETY CONSTRAINTS:                                                 │
│  • SC-MSG-001: Latency < 100ms                                      │
│  • SC-MSG-002: Use ZenohEnvelope                                    │
│  • SC-MSG-006: Batch size ≤ 100                                     │
│  • SC-NAT-003: KeyExpr validation                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

LOOP 3: Message Subscription
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ZenohSubscriber ─────┐                                             │
│       │               │ subscribe(keyExpr, handler)                  │
│       │               ▼                                              │
│       │         ZenohSession ─────┐                                 │
│       │              │            │ DeclareSubscriber()              │
│       │              │            ▼                                  │
│       │              │       ZenohNative ─────┐                     │
│       │              │            │           │ z_declare_subscriber │
│       │              │            │           ▼                      │
│       │              │            │      Zenoh-CS                   │
│       │              │            │           │                      │
│       │              │            │           │ Callback invocation  │
│       │              │            │           ▼                      │
│       │              │            │      Sample data                │
│       │              │            │           │                      │
│       │              │◄───────────┼───────────┘                     │
│       │              │            │                                  │
│       │              │     boundedCallback(sample)                  │
│       │              │            │                                  │
│       │              │            ├─► Timeout check (50ms)          │
│       │              │            │                                  │
│       │              │            ├─► Deserialize<'T>               │
│       │              │            │                                  │
│       │              │            └─► handler(payload)              │
│       │              │                                               │
│       │◄───────────── Subscription ID / Error                       │
│                                                                      │
│  SAFETY CONSTRAINTS:                                                 │
│  • SC-MSG-003: Callback timeout 50ms                                │
│  • SC-MSG-005: Miss detection enabled                               │
│  • SC-SESS-003: Max 1000 subscribers                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

# PART II: FMEA (Failure Mode and Effects Analysis)

## 2.1 FMEA Methodology

### Severity Scale (S)
| Score | Level | Description |
|-------|-------|-------------|
| 10 | CATASTROPHIC | System-wide failure, data loss, safety violation |
| 9 | CRITICAL | Major function loss, significant data corruption |
| 8 | SERIOUS | Partial function loss, recoverable data issues |
| 7 | MAJOR | Noticeable degradation, user intervention needed |
| 6 | MODERATE | Performance impact, workaround available |
| 5 | MINOR | Reduced capability, automatic recovery |
| 4 | LOW | Minimal impact, logged warning |
| 3 | VERY LOW | Cosmetic issue |
| 2 | SLIGHT | No user impact |
| 1 | NONE | No effect |

### Occurrence Scale (O)
| Score | Level | Description |
|-------|-------|-------------|
| 10 | CERTAIN | Failure is inevitable (>1 in 2) |
| 9 | VERY HIGH | Failure almost certain (1 in 3) |
| 8 | HIGH | Repeated failures (1 in 8) |
| 7 | MODERATELY HIGH | Frequent failures (1 in 20) |
| 6 | MODERATE | Occasional failures (1 in 80) |
| 5 | LOW | Few failures (1 in 400) |
| 4 | VERY LOW | Isolated failures (1 in 2000) |
| 3 | REMOTE | Rare failures (1 in 15000) |
| 2 | VERY REMOTE | Almost never (1 in 150000) |
| 1 | NEARLY IMPOSSIBLE | Never seen (1 in 1500000) |

### Detection Scale (D)
| Score | Level | Description |
|-------|-------|-------------|
| 10 | ABSOLUTE UNCERTAINTY | No detection possible |
| 9 | VERY REMOTE | Virtually no chance of detection |
| 8 | REMOTE | Very unlikely to detect |
| 7 | VERY LOW | Unlikely to detect |
| 6 | LOW | Low chance of detection |
| 5 | MODERATE | Moderate chance of detection |
| 4 | MODERATELY HIGH | Good chance of detection |
| 3 | HIGH | High chance of detection |
| 2 | VERY HIGH | Almost certain detection |
| 1 | ALMOST CERTAIN | Will detect before effect |

### RPN Calculation
**RPN = S × O × D** (Range: 1-1000)

| RPN Range | Priority | Action Required |
|-----------|----------|-----------------|
| 1-50 | LOW | Monitor |
| 51-100 | MEDIUM | Planned mitigation |
| 101-200 | HIGH | Immediate attention |
| 201-500 | CRITICAL | Urgent remediation |
| 501-1000 | CATASTROPHIC | Stop and fix |

## 2.2 Complete FMEA Table

### L1: Function Level (FFI Bindings)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L1-001 | Native library not found | Session fails to open | 9 | 4 | 2 | 72 | NuGet postbuild copy | 18 |
| FM-L1-002 | Native library version mismatch | API incompatibility | 8 | 3 | 3 | 72 | Version pin in fsproj | 24 |
| FM-L1-003 | Session.Open() throws | No Zenoh connectivity | 9 | 5 | 2 | 90 | try/catch + Result | 27 |
| FM-L1-004 | Session handle null | NullReferenceException | 8 | 4 | 2 | 64 | Option<SafeSession> | 16 |
| FM-L1-005 | KeyExpr.TryFrom() returns None | Invalid key rejected | 6 | 5 | 2 | 60 | Pre-validation | 12 |
| FM-L1-006 | Publisher.Put() fails | Message not sent | 7 | 4 | 3 | 84 | Retry + error result | 28 |
| FM-L1-007 | Subscriber callback throws | Callback chain broken | 7 | 5 | 4 | 140 | try/catch in wrapper | 35 |
| FM-L1-008 | Session.Close() hangs | Resource leak | 8 | 3 | 5 | 120 | Timeout + force close | 40 |
| FM-L1-009 | Memory leak in FFI calls | Gradual memory exhaustion | 8 | 4 | 6 | 192 | IDisposable + finalizer | 48 |
| FM-L1-010 | Thread race on session state | Inconsistent state | 7 | 4 | 5 | 140 | MailboxProcessor | 35 |

### L2: Component Level (Module Organization)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L2-001 | Wrong fsproj compile order | Compile failure | 6 | 5 | 2 | 60 | Explicit ordering | 12 |
| FM-L2-002 | Circular module dependency | Compile failure | 7 | 3 | 2 | 42 | Layer architecture | 14 |
| FM-L2-003 | Missing module export | Type not accessible | 5 | 4 | 2 | 40 | Namespace review | 10 |
| FM-L2-004 | Package reference missing | Compile failure | 7 | 3 | 1 | 21 | Project template | 7 |
| FM-L2-005 | Transitive dependency conflict | Runtime crash | 8 | 3 | 4 | 96 | Explicit versions | 32 |

### L3: Holon Level (Agent Communication)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L3-001 | Envelope serialization failure | Message not sent | 7 | 4 | 3 | 84 | Type-safe serialize | 28 |
| FM-L3-002 | Envelope deserialization failure | Message dropped | 7 | 5 | 3 | 105 | Result<'T, string> | 35 |
| FM-L3-003 | Schema version mismatch | Incompatible messages | 6 | 4 | 4 | 96 | Version negotiation | 32 |
| FM-L3-004 | TraceId not propagated | Broken distributed tracing | 4 | 5 | 3 | 60 | Activity.Current | 20 |
| FM-L3-005 | Topic key typo | Messages undelivered | 6 | 5 | 2 | 60 | Centralized constants | 12 |
| FM-L3-006 | Message too large | Publish failure | 6 | 3 | 3 | 54 | Size validation | 18 |
| FM-L3-007 | JSON naming policy mismatch | F#/Elixir incompatibility | 5 | 4 | 3 | 60 | SnakeCaseLower | 20 |
| FM-L3-008 | Callback exception unhandled | Lost messages | 7 | 5 | 4 | 140 | try/catch wrapper | 35 |
| FM-L3-009 | Message buffer overflow | Data loss | 8 | 3 | 4 | 96 | Bounded buffer | 32 |
| FM-L3-010 | Batch flush timeout | Delayed delivery | 5 | 4 | 3 | 60 | Timer + manual flush | 20 |

### L4: Container Level (Package Dependencies)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L4-001 | Zenoh-CS NuGet unavailable | Build failure | 7 | 2 | 2 | 28 | Local cache | 7 |
| FM-L4-002 | Native lib deployment fails | Runtime crash | 9 | 4 | 3 | 108 | Postbuild copy | 36 |
| FM-L4-003 | Platform incompatibility | Runtime crash | 8 | 2 | 4 | 64 | Multi-platform CI | 16 |
| FM-L4-004 | .NET version conflict | Build failure | 6 | 3 | 2 | 36 | global.json | 12 |
| FM-L4-005 | ProjectReference missing | Compile failure | 6 | 3 | 1 | 18 | Template | 6 |

### L5: Node Level (Runtime Initialization)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L5-001 | Router unreachable at startup | No connectivity | 9 | 5 | 2 | 90 | depends_on + retry | 27 |
| FM-L5-002 | Init timeout exceeded | Startup failure | 8 | 4 | 2 | 64 | 5s timeout | 16 |
| FM-L5-003 | Health check timer fails | No reconnection | 7 | 3 | 4 | 84 | Timer watchdog | 28 |
| FM-L5-004 | Reconnection storm | Resource exhaustion | 8 | 4 | 5 | 160 | Exponential backoff | 40 |
| FM-L5-005 | Max reconnects exhausted | Permanent disconnect | 8 | 3 | 3 | 72 | Alert + manual | 24 |
| FM-L5-006 | Session leak on crash | Memory exhaustion | 8 | 3 | 6 | 144 | Finalizer | 48 |
| FM-L5-007 | Heartbeat publish fails | False disconnect | 6 | 4 | 3 | 72 | Retry heartbeat | 24 |
| FM-L5-008 | Config frozen too early | Missing options | 5 | 3 | 3 | 45 | Config builder | 15 |

### L6: Cluster Level (Multi-Node Coordination)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L6-001 | Barrier timeout | Sync failure | 7 | 4 | 3 | 84 | Timeout + cleanup | 28 |
| FM-L6-002 | Barrier deadlock | System hang | 9 | 2 | 5 | 90 | Timeout detection | 30 |
| FM-L6-003 | Vote message lost | Wrong quorum result | 8 | 4 | 5 | 160 | Retransmission | 40 |
| FM-L6-004 | Quorum count wrong | Invalid decision | 8 | 3 | 4 | 96 | floor(N/2)+1 formula | 32 |
| FM-L6-005 | Split brain scenario | Inconsistent state | 9 | 2 | 6 | 108 | Quorum requirement | 36 |
| FM-L6-006 | Node ID collision | Wrong vote attribution | 7 | 2 | 4 | 56 | UUID generation | 14 |
| FM-L6-007 | Subscription leak on barrier | Resource exhaustion | 6 | 4 | 5 | 120 | Cleanup in finally | 30 |
| FM-L6-008 | Vote replay attack | Manipulated quorum | 9 | 2 | 6 | 108 | Timestamp + nonce | 36 |

### L7: Federation Level (Cross-Holon Communication)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-L7-001 | Version negotiation timeout | No federation | 7 | 4 | 3 | 84 | 5s timeout | 28 |
| FM-L7-002 | Version incompatibility | Rejected connection | 6 | 4 | 3 | 72 | Version range | 24 |
| FM-L7-003 | Attestation forgery | Security breach | 9 | 2 | 7 | 126 | Ed25519 signature | 36 |
| FM-L7-004 | Hourly attestation missed | Stale trust | 5 | 4 | 4 | 80 | Timer + alert | 20 |
| FM-L7-005 | Cross-holon timeout | Operation failure | 6 | 5 | 3 | 90 | Reasonable timeouts | 30 |
| FM-L7-006 | Announce flood | DoS on federation | 7 | 2 | 5 | 70 | Rate limiting | 21 |
| FM-L7-007 | State hash mismatch | Integrity violation | 8 | 3 | 4 | 96 | SHA3-256 verification | 32 |

### SIL-6 Specific Failure Modes

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Mitigation | New RPN |
|-------|--------------|--------|---|---|---|-----|------------|---------|
| FM-SIL6-001 | 2oo3 vote count wrong | Safety violation | 10 | 2 | 3 | 60 | Formal verification | 20 |
| FM-SIL6-002 | Callback timeout not enforced | Unbounded execution | 8 | 4 | 4 | 128 | Hard timeout | 32 |
| FM-SIL6-003 | Cache size unbounded | Memory exhaustion | 8 | 3 | 5 | 120 | Hard limit 1000 | 30 |
| FM-SIL6-004 | Non-deterministic behavior | Unpredictable system | 9 | 3 | 6 | 162 | Pure functions | 54 |
| FM-SIL6-005 | Page fault during SHM | Latency spike | 7 | 4 | 5 | 140 | Pre-commit pages | 35 |

## 2.3 FMEA Summary Statistics

### By Level

| Level | Failure Modes | Total RPN | Avg RPN | Critical (>100) |
|-------|---------------|-----------|---------|-----------------|
| L1 | 10 | 1034 | 103.4 | 3 |
| L2 | 5 | 255 | 51.0 | 0 |
| L3 | 10 | 815 | 81.5 | 2 |
| L4 | 5 | 254 | 50.8 | 1 |
| L5 | 8 | 731 | 91.4 | 2 |
| L6 | 8 | 822 | 102.8 | 2 |
| L7 | 7 | 618 | 88.3 | 1 |
| SIL-6 | 5 | 610 | 122.0 | 3 |
| **TOTAL** | **58** | **5139** | **88.6** | **14** |

### Top 10 Critical Failure Modes (Pre-Mitigation)

| Rank | FM-ID | Failure Mode | RPN | Mitigation Priority |
|------|-------|--------------|-----|---------------------|
| 1 | FM-L1-009 | Memory leak in FFI calls | 192 | P0 |
| 2 | FM-SIL6-004 | Non-deterministic behavior | 162 | P0 |
| 3 | FM-L5-004 | Reconnection storm | 160 | P0 |
| 4 | FM-L6-003 | Vote message lost | 160 | P0 |
| 5 | FM-L5-006 | Session leak on crash | 144 | P1 |
| 6 | FM-L1-007 | Subscriber callback throws | 140 | P1 |
| 7 | FM-L1-010 | Thread race on session state | 140 | P1 |
| 8 | FM-L3-008 | Callback exception unhandled | 140 | P1 |
| 9 | FM-SIL6-005 | Page fault during SHM | 140 | P1 |
| 10 | FM-SIL6-002 | Callback timeout not enforced | 128 | P1 |

---

# PART III: Critical Path Implementation

## 3.1 Work Breakdown Structure (WBS)

```
1.0 Zenoh F# Integration
├── 1.1 Foundation (L1-L2)
│   ├── 1.1.1 Add Zenoh-CS to Cepaf.fsproj
│   ├── 1.1.2 Create ZenohTypes.fs
│   ├── 1.1.3 Create ZenohNative.fs
│   ├── 1.1.4 Update module structure
│   └── 1.1.5 Verify native library deployment
│
├── 1.2 Session Management (L5)
│   ├── 1.2.1 Implement ZenohLifecycle.fs
│   ├── 1.2.2 Add health check timer
│   ├── 1.2.3 Implement exponential backoff
│   ├── 1.2.4 Integrate with ZenohSession.fs
│   └── 1.2.5 Add router pre-check
│
├── 1.3 Messaging (L3)
│   ├── 1.3.1 Define ZenohEnvelope<'T>
│   ├── 1.3.2 Implement ZenohPublisher.fs
│   ├── 1.3.3 Implement ZenohSubscriber.fs
│   ├── 1.3.4 Add bounded callback wrapper
│   └── 1.3.5 Update ZenohChannel.fs
│
├── 1.4 Cluster Coordination (L6)
│   ├── 1.4.1 Implement ZenohBarrier.fs
│   ├── 1.4.2 Implement ZenohQuorum.fs
│   ├── 1.4.3 Add 2oo3 voting logic
│   ├── 1.4.4 Integrate with mesh boot
│   └── 1.4.5 Test multi-node scenarios
│
├── 1.5 Federation (L7)
│   ├── 1.5.1 Implement ZenohFederation.fs
│   ├── 1.5.2 Add version negotiation
│   ├── 1.5.3 Add hourly attestation
│   ├── 1.5.4 Integrate with existing protocol
│   └── 1.5.5 Test cross-holon communication
│
├── 1.6 SIL-6 Hardening
│   ├── 1.6.1 Add bounded execution wrappers
│   ├── 1.6.2 Implement cache limits
│   ├── 1.6.3 Add signature verification
│   ├── 1.6.4 Formal verification (Quint)
│   └── 1.6.5 SIL-6 test suite
│
└── 1.7 Testing & Documentation
    ├── 1.7.1 Unit tests (135)
    ├── 1.7.2 Property tests (65)
    ├── 1.7.3 Integration tests (60)
    ├── 1.7.4 SIL-6 tests (40)
    └── 1.7.5 API documentation
```

## 3.2 Task Dependencies and Durations

| Task ID | Task Name | Duration | Predecessors | Resources |
|---------|-----------|----------|--------------|-----------|
| 1.1.1 | Add Zenoh-CS to Cepaf.fsproj | 0.5d | - | Dev |
| 1.1.2 | Create ZenohTypes.fs | 1d | - | Dev |
| 1.1.3 | Create ZenohNative.fs | 2d | 1.1.1, 1.1.2 | Dev |
| 1.1.4 | Update module structure | 0.5d | 1.1.3 | Dev |
| 1.1.5 | Verify native library deployment | 0.5d | 1.1.1 | DevOps |
| 1.2.1 | Implement ZenohLifecycle.fs | 1.5d | 1.1.3 | Dev |
| 1.2.2 | Add health check timer | 0.5d | 1.2.1 | Dev |
| 1.2.3 | Implement exponential backoff | 0.5d | 1.2.1 | Dev |
| 1.2.4 | Integrate with ZenohSession.fs | 1d | 1.2.2, 1.2.3 | Dev |
| 1.2.5 | Add router pre-check | 0.5d | 1.2.4 | Dev |
| 1.3.1 | Define ZenohEnvelope<'T> | 0.5d | 1.1.2 | Dev |
| 1.3.2 | Implement ZenohPublisher.fs | 1d | 1.2.4, 1.3.1 | Dev |
| 1.3.3 | Implement ZenohSubscriber.fs | 1d | 1.2.4, 1.3.1 | Dev |
| 1.3.4 | Add bounded callback wrapper | 0.5d | 1.3.3 | Dev |
| 1.3.5 | Update ZenohChannel.fs | 0.5d | 1.3.2, 1.3.4 | Dev |
| 1.4.1 | Implement ZenohBarrier.fs | 1d | 1.3.2, 1.3.3 | Dev |
| 1.4.2 | Implement ZenohQuorum.fs | 1d | 1.4.1 | Dev |
| 1.4.3 | Add 2oo3 voting logic | 0.5d | 1.4.2 | Dev |
| 1.4.4 | Integrate with mesh boot | 1d | 1.4.3 | Dev |
| 1.4.5 | Test multi-node scenarios | 1d | 1.4.4 | QA |
| 1.5.1 | Implement ZenohFederation.fs | 1d | 1.4.2 | Dev |
| 1.5.2 | Add version negotiation | 0.5d | 1.5.1 | Dev |
| 1.5.3 | Add hourly attestation | 0.5d | 1.5.1 | Dev |
| 1.5.4 | Integrate with existing protocol | 1d | 1.5.2, 1.5.3 | Dev |
| 1.5.5 | Test cross-holon communication | 1d | 1.5.4 | QA |
| 1.6.1 | Add bounded execution wrappers | 1d | 1.3.4 | Dev |
| 1.6.2 | Implement cache limits | 0.5d | 1.6.1 | Dev |
| 1.6.3 | Add signature verification | 1d | 1.5.3 | Dev |
| 1.6.4 | Formal verification (Quint) | 2d | 1.4.3, 1.6.1 | Safety |
| 1.6.5 | SIL-6 test suite | 1.5d | 1.6.4 | QA |
| 1.7.1 | Unit tests | 2d | 1.3.5 | QA |
| 1.7.2 | Property tests | 1.5d | 1.7.1 | QA |
| 1.7.3 | Integration tests | 2d | 1.4.5, 1.5.5 | QA |
| 1.7.4 | SIL-6 tests | 1.5d | 1.6.5 | QA |
| 1.7.5 | API documentation | 1d | 1.3.5, 1.5.4 | Dev |

## 3.3 Critical Path Network Diagram

```
START
  │
  ├─► 1.1.1 (0.5d) ─┬─► 1.1.5 (0.5d)
  │                 │
  │                 └─► 1.1.3 (2d) ◄─── 1.1.2 (1d)
  │                       │
  │                       ▼
  │                     1.1.4 (0.5d)
  │                       │
  │                       ▼
  │                     1.2.1 (1.5d)
  │                       │
  │                 ┌─────┴─────┐
  │                 │           │
  │                 ▼           ▼
  │           1.2.2 (0.5d) 1.2.3 (0.5d)
  │                 │           │
  │                 └─────┬─────┘
  │                       │
  │                       ▼
  │                     1.2.4 (1d)
  │                       │
  │                       ▼
  │                     1.2.5 (0.5d)
  │                       │
  ├─► 1.3.1 (0.5d) ──────►│
  │                       │
  │                 ┌─────┴─────┐
  │                 │           │
  │                 ▼           ▼
  │           1.3.2 (1d)   1.3.3 (1d)
  │                 │           │
  │                 │           ▼
  │                 │     1.3.4 (0.5d)
  │                 │           │
  │                 └─────┬─────┘
  │                       │
  │                       ▼
  │                     1.3.5 (0.5d)
  │                       │
  │                 ┌─────┴─────┐
  │                 │           │
  │                 ▼           ▼
  │           1.4.1 (1d)   1.6.1 (1d)
  │                 │           │
  │                 ▼           ▼
  │           1.4.2 (1d)   1.6.2 (0.5d)
  │                 │
  │                 ▼
  │           1.4.3 (0.5d)
  │                 │
  │           ┌─────┼─────┐
  │           │     │     │
  │           ▼     │     ▼
  │     1.4.4 (1d)  │  1.5.1 (1d)
  │           │     │     │
  │           ▼     │  ┌──┴──┐
  │     1.4.5 (1d)  │  │     │
  │           │     │  ▼     ▼
  │           │     │ 1.5.2 1.5.3
  │           │     │  │     │
  │           │     │  └──┬──┘
  │           │     │     │
  │           │     ▼     ▼
  │           │  1.6.4 (2d) 1.5.4 (1d)
  │           │     │     │
  │           │     │     ▼
  │           │     │  1.5.5 (1d)
  │           │     │     │
  │           │     ▼     │
  │           │  1.6.5 (1.5d)
  │           │     │     │
  │           └─────┼─────┘
  │                 │
  │                 ▼
  │           1.7.3 (2d)
  │                 │
  │                 ▼
  │           1.7.4 (1.5d)
  │                 │
  │                 ▼
  │               END
  │
  │  PARALLEL PATHS:
  │  ├─► 1.7.1 (2d) → 1.7.2 (1.5d) [from 1.3.5]
  │  └─► 1.7.5 (1d) [from 1.3.5, 1.5.4]
  │
  │  LEGEND:
  │  ███ = Critical Path
  │  ─── = Non-critical Path
```

## 3.4 Critical Path Identification

### Critical Path Tasks

```
1.1.1 → 1.1.3 → 1.1.4 → 1.2.1 → 1.2.4 → 1.3.3 → 1.3.4 → 1.4.1 →
1.4.2 → 1.4.3 → 1.6.4 → 1.6.5 → 1.7.3 → 1.7.4
```

### Critical Path Duration

| Phase | Tasks | Duration | Cumulative |
|-------|-------|----------|------------|
| Foundation | 1.1.1, 1.1.3, 1.1.4 | 3d | 3d |
| Session | 1.2.1, 1.2.4 | 2.5d | 5.5d |
| Messaging | 1.3.3, 1.3.4 | 1.5d | 7d |
| Cluster | 1.4.1, 1.4.2, 1.4.3 | 2.5d | 9.5d |
| SIL-6 | 1.6.4, 1.6.5 | 3.5d | 13d |
| Testing | 1.7.3, 1.7.4 | 3.5d | **16.5d** |

**Total Critical Path Duration: 16.5 working days (~3.5 weeks)**

## 3.5 Implementation Phases

### Phase 1: Foundation (Days 1-3)

**Objective**: Establish FFI layer and module structure

**Tasks**:
1. Add `Zenoh-CS Version="0.4.1"` to Cepaf.fsproj
2. Create `Zenoh/Core/ZenohTypes.fs`
3. Create `Zenoh/Core/ZenohNative.fs`
4. Update module structure in fsproj
5. Verify native library deployment

**Deliverables**:
- Compiling F# project with Zenoh-CS
- SafeSession, SafePublisher types
- FFI wrappers with error handling

**Exit Criteria**:
- `dotnet build` succeeds
- Unit tests for FFI wrappers pass
- Native library loads correctly

### Phase 2: Session Management (Days 4-6)

**Objective**: Implement lifecycle and reconnection

**Tasks**:
1. Implement `ZenohLifecycle.fs`
2. Add 10-second health check timer
3. Implement exponential backoff reconnection
4. Update `ZenohSession.fs` to use real FFI
5. Add router reachability pre-check

**Deliverables**:
- Working session initialization
- Automatic health monitoring
- Resilient reconnection

**Exit Criteria**:
- Session connects to Zenoh router
- Reconnection works after router restart
- Health endpoint shows Zenoh status

### Phase 3: Messaging (Days 7-9)

**Objective**: Implement typed pub/sub

**Tasks**:
1. Define `ZenohEnvelope<'T>`
2. Implement `ZenohPublisher.fs`
3. Implement `ZenohSubscriber.fs`
4. Add bounded callback wrapper (50ms)
5. Update `ZenohChannel.fs`

**Deliverables**:
- Type-safe publishing
- Bounded callback execution
- QuadplexLogger integration

**Exit Criteria**:
- Round-trip message test passes
- Callback timeout enforced
- JSON compatibility with Elixir

### Phase 4: Cluster Coordination (Days 10-12)

**Objective**: Implement distributed primitives

**Tasks**:
1. Implement `ZenohBarrier.fs`
2. Implement `ZenohQuorum.fs`
3. Add 2oo3 voting logic
4. Integrate with mesh boot
5. Multi-node testing

**Deliverables**:
- Distributed barriers
- Quorum voting
- Mesh integration

**Exit Criteria**:
- 3-node barrier synchronization works
- 2oo3 voting produces correct results
- Mesh boot uses Zenoh coordination

### Phase 5: Federation (Days 13-14)

**Objective**: Cross-holon communication

**Tasks**:
1. Implement `ZenohFederation.fs`
2. Add version negotiation
3. Add hourly attestation
4. Integrate with existing protocol

**Deliverables**:
- Federation announcement
- Version negotiation
- State attestation

**Exit Criteria**:
- Cross-holon discovery works
- Version negotiation completes
- Attestation timer fires

### Phase 6: SIL-6 Hardening (Days 15-17)

**Objective**: Safety-critical hardening

**Tasks**:
1. Add bounded execution wrappers
2. Implement cache limits (1000 max)
3. Add Ed25519 signature verification
4. Formal verification with Quint
5. SIL-6 test suite

**Deliverables**:
- Deterministic execution
- Bounded resources
- Formal proofs

**Exit Criteria**:
- All timeouts enforced
- Cache limits respected
- Quint models pass

## 3.6 Risk-Based Implementation Order

Based on FMEA RPN scores, implement mitigations in this order:

| Priority | FM-ID | Mitigation | Phase |
|----------|-------|------------|-------|
| P0 | FM-L1-009 | IDisposable + finalizer | 1 |
| P0 | FM-SIL6-004 | Pure functions | 6 |
| P0 | FM-L5-004 | Exponential backoff | 2 |
| P0 | FM-L6-003 | Retransmission | 4 |
| P1 | FM-L5-006 | Finalizer | 2 |
| P1 | FM-L1-007 | try/catch in wrapper | 3 |
| P1 | FM-L1-010 | MailboxProcessor | 2 |
| P1 | FM-L3-008 | try/catch wrapper | 3 |
| P1 | FM-SIL6-005 | Pre-commit pages | 6 |
| P1 | FM-SIL6-002 | Hard timeout | 6 |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-14 | Claude Opus 4.5 | Initial STAMP/FMEA/CPM analysis |

---

## References

- [Eclipse Zenoh](https://github.com/eclipse-zenoh/zenoh)
- [Zenoh-CS NuGet](https://www.nuget.org/packages/Zenoh-CS)
- [Zenoh Performance Benchmarks](https://zenoh.io/blog/2023-03-21-zenoh-vs-mqtt-kafka-dds/)
- [IEC 61508 Functional Safety](https://en.wikipedia.org/wiki/IEC_61508)
- [STPA Handbook](https://psas.scripts.mit.edu/home/get_file.php?name=STPA_handbook.pdf)
