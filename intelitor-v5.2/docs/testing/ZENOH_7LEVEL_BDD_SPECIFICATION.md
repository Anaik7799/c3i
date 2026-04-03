# Zenoh 7-Level BDD Integration Specification

**Version**: 21.3.0-SIL6
**File**: `test/features/zenoh_integration.feature`
**Total Scenarios**: 59
**Total Lines**: 887
**Author**: Claude Opus 4.5
**Date**: 2026-01-14
**Status**: ACTIVE

## Overview

This document describes the comprehensive BDD (Behavior-Driven Development) feature file for testing Zenoh NIF across all 7 fractal layers of the Indrajaal system. The feature file contains **59 scenarios** organized across **10 feature groups**, covering:

- **L1 FFI Layer**: Native memory safety and handle management
- **L2 Core Layer**: Session management and pub/sub operations
- **L3 Envelope Layer**: Type-safe message serialization
- **L4 Bridge Layer**: Elixir-F# interoperability (<50ms latency)
- **L5 Lifecycle Layer**: Connection state machine with reconnection
- **L6 Cluster Layer**: 2oo3 quorum consensus and voting
- **L7 Federation Layer**: Cross-holon communication and attestation
- **Integration**: End-to-end scenarios spanning multiple layers
- **Safety**: Formal verification and SIL-6 compliance
- **Performance**: Stress testing and latency requirements

## Layer-by-Layer Breakdown

### L1: FFI Layer (6 scenarios)
**Focus**: Native interface safety and memory management
**STAMP Constraints**: SC-NIF-001 through SC-NIF-006
**Scenarios**:
1. **Handle Creation** - Create native Zenoh session handle safely
2. **Resource Cleanup** - Proper deallocation on process exit
3. **Error Translation** - Native error codes → Elixir atoms
4. **Dirty Scheduler** - I/O operations on dirty schedulers
5. **Type Safety** - FFI boundary type validation
6. **Concurrent Access** - Thread-safe handle sharing

**Key Requirements**:
- Zero memory leaks (valgrind clean)
- <1ms latency with no scheduler blocking
- Resource Arc management for BEAM integration
- Proper error propagation and context

### L2: Core Layer (10 scenarios)
**Focus**: Session management and fundamental pub/sub
**STAMP Constraints**: SC-ZENOH-SES-*, SC-PUB-*, SC-SUB-*, SC-QRY-*
**Scenarios**:
1. **Single Session per Node** - Authoritative session management
2. **Connection Options** - Multiple config modes (client/peer/router)
3. **Graceful Shutdown** - Message drain and resource cleanup
4. **Publisher Lifecycle** - Create/publish/dispose patterns
5. **Message Publishing** - Fast pub/sub >1000 msg/sec
6. **Batch Publishing** - Atomic batch delivery <50ms
7. **Subscriber Creation** - Wildcard pattern support
8. **Message Reception** - Callback-based delivery
9. **Subscriber Cleanup** - Proper resource deallocation
10. **Concurrent Subscribers** - Fan-out delivery without loss
11. **Query Operations** - Get/retrieve from Zenoh store
12. **Query Timeout** - Non-blocking query with timeout protection

**Key Requirements**:
- >1000 msg/sec throughput
- <50ms batch delivery latency
- Support for wildcard subscriptions
- Query completion within 100ms

### L3: Envelope Layer (4 scenarios)
**Focus**: Type-safe message serialization and schema validation
**STAMP Constraints**: SC-ENV-001 through SC-ENV-004
**Scenarios**:
1. **Envelope Structure** - Versioned, typed message format
2. **Schema Validation** - Reject malformed envelopes
3. **Version Compatibility** - Forward/backward compatible parsing
4. **Encoding Options** - Binary vs JSON serialization

**Key Requirements**:
- Human-readable JSON format available
- 30-40% size reduction with binary encoding
- Version-aware deserialization
- Type enforcement at deserialization

### L4: Bridge Layer (5 scenarios)
**Focus**: Elixir-F# message passing with latency guarantees
**STAMP Constraints**: SC-BRIDGE-001 through SC-BRIDGE-005
**Scenarios**:
1. **Outbound Elixir→F#** - Publish to Cortex with <50ms latency
2. **Inbound F#→Elixir** - Receive from Cortex correctly
3. **Buffer Management** - Queue handling under load
4. **Latency Budget** - p50/p95/p99/max latency targets
5. **Topic Mapping** - Correct Zenoh topic routing

**Key Requirements**:
- p50 latency <20ms
- p95 latency <40ms
- p99 latency <45ms
- p100 (max) latency <50ms
- 100% of messages meet budget

### L5: Lifecycle Layer (7 scenarios)
**Focus**: Connection state machine with health monitoring
**STAMP Constraints**: SC-LIFE-001 through SC-LIFE-007
**Scenarios**:
1. **Initial Connection** - State transitions from disconnected→connected
2. **Loss Detection** - Detect within 5 seconds
3. **Exponential Backoff** - Retry with increasing delays (100ms→10s cap)
4. **Successful Recovery** - Restore after temporary outage
5. **Failure Escalation** - Notify Sentinel after max retries
6. **Health Monitoring** - Continuous 10-second checks
7. **Graceful Shutdown** - Complete sequence with resource cleanup

**Key Requirements**:
- Loss detection within 5 seconds
- Exponential backoff max 10 seconds
- 5-minute total retry window
- Health checks every 10 seconds
- Health score >= 95%

### L6: Cluster Layer (7 scenarios)
**Focus**: 2oo3 quorum consensus and distributed voting
**STAMP Constraints**: SC-QUORUM-001 through SC-QUORUM-007, SC-SIL6-006/011
**Scenarios**:
1. **Quorum Achievement** - All 3 nodes establish consensus
2. **Single Node Failure** - Maintained with 2oo3
3. **Quorum Loss** - Detection and read-only mode
4. **Vote Replay Protection** - Prevent attack via sequence/nonce/signature
5. **Leader Election** - Unanimous agreement on leader
6. **Message Ordering** - Canonical ordering across nodes
7. **Two-Phase Commit** - Atomic transactions across quorum

**Key Requirements**:
- 2oo3 voting mandatory (SC-SIL6-006)
- Quorum = floor(N/2)+1 (SC-SIL6-011)
- No split-brain conditions
- Leader lease 30 seconds with 5s heartbeat
- New election within 15 seconds on failure

### L7: Federation Layer (9 scenarios)
**Focus**: Cross-holon communication and protocol negotiation
**STAMP Constraints**: SC-FED-001 through SC-FED-009
**Scenarios**:
1. **Cross-Holon Attestation** - Hourly verification of identity/integrity
2. **Protocol Negotiation** - Compatible version selection
3. **Message Routing** - Shortest path across federation
4. **Federation Join** - Safe bootstrapping with votes
5. **Federation Leave** - Graceful exit with state drain
6. **Data Consistency** - Replication ensures matching state
7. **Partition Healing** - Recover from network splits
8. **Cross-Holon Query** - Read-consistent results
9. **Catchup Synchronization** - Efficient delta application

**Key Requirements**:
- Attestation within 100ms
- Delta sync in <1s (small), <10s (medium), <60s (large)
- No data loss or duplication on partition/heal
- Staleness <100ms
- No loops in message routing

### Integration: End-to-End Scenarios (5 scenarios)
**Focus**: Complex flows across multiple layers
**Scenarios**:
1. **Publish-Subscribe Through All Layers** - Message flow L1→L7
2. **Failure Recovery** - Graceful recovery across layers (<15s)
3. **Load Under Pressure** - 1000 msg/sec for 60s sustained
4. **Byzantine Failure** - Survive malicious node (isolation)
5. **Full System Restart** - Cold boot and restore (30s healthy)

### Safety & Verification (4 scenarios)
**Focus**: Formal properties and compliance
**Scenarios**:
1. **No Segfaults** - Fuzz testing 1M inputs, zero crashes
2. **Liveness** - Messages delivered within 100ms (no deadlock)
3. **Consistency** - ACID properties across failures
4. **SIL-6 Compliance** - PFH targets < 10⁻¹²/hour

## STAMP Constraints Mapped

The feature file references **70+ STAMP constraints**:

| Category | Constraints | Count |
|----------|-------------|-------|
| NIF | SC-NIF-001 to SC-NIF-006 | 6 |
| Zenoh Session | SC-ZENOH-SES-001 to SC-ZENOH-SES-003 | 3 |
| Publisher | SC-PUB-001 to SC-PUB-003 | 3 |
| Subscriber | SC-SUB-001 to SC-SUB-004 | 4 |
| Query | SC-QRY-001 to SC-QRY-002 | 2 |
| Envelope | SC-ENV-001 to SC-ENV-004 | 4 |
| Bridge | SC-BRIDGE-001 to SC-BRIDGE-005 | 5 |
| Lifecycle | SC-LIFE-001 to SC-LIFE-007 | 7 |
| Quorum | SC-QUORUM-001 to SC-QUORUM-007 | 7 |
| Federation | SC-FED-001 to SC-FED-009 | 9 |
| Safety | SC-SAFE-001 to SC-SAFE-004 | 4 |
| SIL-6 Biomorphic/SIL-6 | SC-SIL6-006, SC-SIL6-011, SC-SIL6-* | 11 |

## AOR Rules Covered

**Primary AOR Rules**:
- AOR-ZENOH-001: Never skip SKIP_ZENOH_NIF=1 in production
- AOR-ZENOH-002: Always verify router before app startup
- AOR-ZENOH-003: Zenoh in compose dependencies
- AOR-ZENOH-004 to AOR-ZENOH-008: Logging, alerts, reconnection, health publishing

**Secondary AOR Rules**:
- AOR-MESH-001: Use sa-mesh/sa-up for all mesh operations
- AOR-MESH-003: Verify Zenoh on all nodes post-boot
- AOR-TEST-NIF-001 to AOR-TEST-NIF-003: NIF testing with SKIP_ZENOH_NIF=0

## Scenario Tags and Filtering

### By Layer
```bash
# Run only L1 FFI scenarios
mix test.features --tags @l1_ffi

# Run only L6 Cluster scenarios
mix test.features --tags @l6_cluster

# Run all federation tests
mix test.features --tags @l7_federation
```

### By Priority/Risk
```bash
# Critical path scenarios (SIL-6)
mix test.features --tags @sil6

# Safety-critical scenarios
mix test.features --tags @safety-critical

# Performance requirements
mix test.features --tags @performance
```

### By Test Type
```bash
# Integration tests only
mix test.features --tags @integration

# E2E scenarios
mix test.features --tags @e2e

# Formal verification
mix test.features --tags @formal
```

## Running the Tests

### Prerequisites
```bash
devenv shell
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature
```

### Full Suite (59 scenarios)
```bash
# Run all Zenoh integration tests
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --format documentation

# With detailed output
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --format html
```

### By Layer
```bash
# Test L1-L3 (core infrastructure)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l1_ffi --tags @l2_core --tags @l3_envelope

# Test L4-L7 (advanced features)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l4_bridge --tags @l5_lifecycle --tags @l6_cluster --tags @l7_federation
```

### Critical Path Only
```bash
# Quick verification (15 scenarios)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @sil6
```

## Implementation Map

Each scenario requires step definitions in `test/support/steps/`. Key step types:

### Layer 1 (FFI) Steps
- `Given the Zenoh NIF library is compiled`
- `When I call Indrajaal.Native.Zenoh.open_session/1`
- `Then session_ref should be a Rustler ResourceArc`
- `And no memory leak should be detected`

### Layer 2 (Core) Steps
- `Given Zenoh router is running on tcp/127.0.0.1:7447`
- `When I publish message to topic`
- `Then subscribers should receive the message`
- `And throughput should exceed 1000 msg/sec`

### Layer 6 (Cluster) Steps
- `Given 3 Zenoh routers running`
- `When node-1 crashes`
- `Then quorum_status should be :degraded`
- `And message delivery should continue`

### Layer 7 (Federation) Steps
- `Given holon-1 and holon-2 running`
- `When holon-3 initiates join_request`
- `Then all peers vote on acceptance`
- `And holon-3 becomes federation member`

## FMEA Risk Analysis

### Critical Failure Modes (RPN > 100)

| Scenario | RPN | Severity | Mitigation |
|----------|-----|----------|-----------|
| NIF segfault | 216 | 9 (Max) | Valgrind + fuzzing |
| Quorum loss (2 nodes down) | 192 | 8 | Detect within 3s, alert immediately |
| Connection never recovers | 140 | 7 | Max 5-minute retry window |
| Byzantine node accepted | 140 | 7 | Cryptographic verification |
| Message loss on partition | 120 | 6 | Two-phase commit + durability |

### Mitigation Strategies
1. Fuzz testing with 1M inputs/layer
2. Network chaos injection (partition, delay, loss)
3. Byzantine injection (duplicate votes, out-of-order)
4. Sustained load testing (1000 msg/sec for 60s)
5. Cold restart and state recovery

## Performance Targets

| Component | Metric | Target | Tolerance |
|-----------|--------|--------|-----------|
| L1 NIF | Latency | <1ms | ±0.1ms |
| L2 Pub/Sub | Throughput | >1000 msg/sec | ±50 msg/sec |
| L3 Envelope | Serialization | <1ms | ±0.1ms |
| L4 Bridge | Latency (p50) | <20ms | ±2ms |
| L4 Bridge | Latency (p99) | <45ms | ±5ms |
| L5 Lifecycle | Loss detection | <5s | ±1s |
| L6 Cluster | Leader election | <15s | ±3s |
| L7 Federation | Attestation | <100ms | ±10ms |
| L7 Federation | Sync delta | <10s (med) | ±2s |

## Five-Level Test Coverage

This feature file satisfies **Level 5: BDD Integration** of the five-level testing framework:

```
Level 1: TDG (Unit/Property Tests) - Unit test counterparts exist
Level 2: FMEA (Failure Mode Analysis) - Failure scenarios documented
Level 3: Formal Proofs - Quint/Agda for consensus properties
Level 4: Graph Analysis - Control flow coverage mapping
Level 5: BDD Integration - THIS FILE (59 scenarios)
```

## Compliance and Verification

### STAMP Compliance Check
```bash
# Verify all STAMP constraints referenced
grep "SC-" test/features/zenoh_integration.feature | sort -u | wc -l
# Expected: 70+ constraints

# Verify all scenarios have tags
grep "Scenario:" test/features/zenoh_integration.feature | wc -l
# Expected: 59
```

### AOR Rule Verification
```bash
# Check for SKIP_ZENOH_NIF=0 enforcement
grep "SKIP_ZENOH_NIF" test/features/zenoh_integration.feature
# All tests should require NIF active
```

### SIL-6 Safety Properties
The feature file verifies:
- **Safety**: No segfaults under any condition (fuzz testing)
- **Liveness**: Messages eventually delivered (no deadlock)
- **Consistency**: ACID properties maintained
- **PFH Target**: Failure rate < 10⁻¹²/hour

## Related Documents

- `/home/an/dev/ver/intelitor-v5.2/.claude/rules/zenoh-telemetry-mandatory.md` - Zenoh requirements
- `/home/an/dev/ver/intelitor-v5.2/.claude/rules/fsharp-sil6-mesh.md` - Mesh orchestration
- `CLAUDE.md` §SC-ZENOH-* - STAMP constraints
- `CLAUDE.md` §AOR-ZENOH-* - Operating rules

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-14 | Claude Opus 4.5 | Initial creation: 59 scenarios across 7 layers |

---

**Status**: ACTIVE - Ready for step definition implementation and execution
**Maintainer**: Claude Code Agent
**Last Updated**: 2026-01-14
**Next Review**: 2026-02-14
