# Zenoh 7-Level BDD Quick Start Guide

**File**: `test/features/zenoh_integration.feature`
**Scenarios**: 59 total
**Layers Covered**: L1-L7 + Integration + Safety
**Tags**: @zenoh_integration, @sil6, @safety-critical, @performance

## Quick Commands

### Run All Zenoh BDD Tests
```bash
cd /home/an/dev/ver/intelitor-v5.2
devenv shell
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature
```

### Run by Layer
```bash
# L1 FFI Layer (6 scenarios) - 5 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l1_ffi

# L2 Core Layer (10 scenarios) - 10 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l2_core

# L3 Envelope Layer (4 scenarios) - 5 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l3_envelope

# L4 Bridge Layer (5 scenarios) - 10 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l4_bridge

# L5 Lifecycle Layer (7 scenarios) - 15 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l5_lifecycle

# L6 Cluster Layer (7 scenarios) - 20 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l6_cluster

# L7 Federation Layer (9 scenarios) - 25 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l7_federation

# Integration E2E (5 scenarios) - 20 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @integration

# Safety & Verification (4 scenarios) - 30 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @safety
```

### Run Critical Path Only
```bash
# SIL-6 critical scenarios only (~15 scenarios) - 15 min
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @sil6
```

### Run Priority Subsets
```bash
# Memory safety critical (FFI + Safety)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @memory_safety

# Consensus critical (Quorum + Federation)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @quorum --tags @federation

# Performance critical (Latency, throughput)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @performance

# Resilience (Failure recovery, health)
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @resilience
```

## Feature Structure Overview

```
test/features/zenoh_integration.feature
├── L1: FFI Layer (6 scenarios)
│   ├── Handle creation and disposal
│   ├── Memory safety verification
│   ├── Error code handling
│   ├── Dirty scheduler compliance
│   ├── Type safety at FFI boundary
│   └── Concurrent handle safety
│
├── L2: Core Layer (10 scenarios)
│   ├── Session management
│   ├── Publisher lifecycle
│   ├── Message publishing & batching
│   ├── Subscriber creation & cleanup
│   ├── Multiple concurrent subscribers
│   ├── Query operations
│   └── Query with timeout
│
├── L3: Envelope Layer (4 scenarios)
│   ├── Envelope structure with versioning
│   ├── Schema validation
│   ├── Version compatibility
│   └── Binary vs JSON encoding
│
├── L4: Bridge Layer (5 scenarios)
│   ├── Elixir→F# message passing
│   ├── F#→Elixir message passing
│   ├── Buffer management under load
│   ├── Latency budget compliance (<50ms)
│   └── Zenoh topic mapping
│
├── L5: Lifecycle Layer (7 scenarios)
│   ├── Initial connection
│   ├── Loss detection
│   ├── Exponential backoff reconnection
│   ├── Successful recovery
│   ├── Failure escalation
│   ├── Health monitoring
│   └── Graceful shutdown
│
├── L6: Cluster Layer (7 scenarios)
│   ├── Quorum achievement (2oo3)
│   ├── Single node failure
│   ├── Quorum loss (2+ nodes down)
│   ├── Vote replay protection
│   ├── Leader election
│   ├── Message ordering in quorum
│   └── Two-phase commit
│
├── L7: Federation Layer (9 scenarios)
│   ├── Cross-holon attestation
│   ├── Protocol negotiation
│   ├── Message routing in federation
│   ├── Federation join handshake
│   ├── Federation member leave
│   ├── Data consistency replication
│   ├── Partition and heal recovery
│   ├── Cross-holon query consistency
│   └── Resource synchronization on catchup
│
├── Integration: End-to-End (5 scenarios)
│   ├── Publish-subscribe through all layers
│   ├── Failure recovery across layers
│   ├── Load under pressure (1000 msg/sec)
│   ├── Byzantine failure handling
│   └── Full system restart
│
└── Safety & Verification (4 scenarios)
    ├── No segfaults (fuzz 1M inputs)
    ├── Liveness property (message delivery)
    ├── ACID consistency
    └── SIL-6 compliance
```

## Scenario Count by Category

| Category | Scenarios | Est. Time |
|----------|-----------|-----------|
| L1 FFI | 6 | 5 min |
| L2 Core | 10 | 10 min |
| L3 Envelope | 4 | 5 min |
| L4 Bridge | 5 | 10 min |
| L5 Lifecycle | 7 | 15 min |
| L6 Cluster | 7 | 20 min |
| L7 Federation | 9 | 25 min |
| Integration | 5 | 20 min |
| Safety | 4 | 30 min |
| **TOTAL** | **59** | **140 min** |

## Prerequisites

```bash
# 1. Ensure Zenoh NIF is compiled
SKIP_ZENOH_NIF=0 mix compile

# 2. Start Zenoh router (if needed for tests)
# Either via: sa-up, or standalone zenoh-router

# 3. Ensure test database is ready
mix ecto.create
mix ecto.migrate

# 4. Run tests
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature
```

## Environment Variables

```bash
# CRITICAL: Enable Zenoh NIF for all tests
SKIP_ZENOH_NIF=0

# Optional: Disable Lineage NIF (can remain 1)
SKIP_LINEAGE_NIF=1

# Optional: Verbose output
EXUNIT_VERBOSE=true

# Optional: Specific tag filtering
TAGS="@l6_cluster"
```

## Test Execution Examples

### Example 1: Quick Smoke Test (5 min)
```bash
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature \
  --tags @l1_ffi --tags @memory_safety
```

### Example 2: Core Infrastructure (25 min)
```bash
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature \
  --tags @l1_ffi --tags @l2_core --tags @l3_envelope
```

### Example 3: Cluster & Federation (45 min)
```bash
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature \
  --tags @l6_cluster --tags @l7_federation
```

### Example 4: Critical Path (15 min)
```bash
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature \
  --tags @sil6
```

### Example 5: Full Suite (2.5 hours)
```bash
SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature
```

## Key Scenarios to Know

### Must Pass (SIL-6 Critical)
- **L1-FFI-001**: Handle creation - foundational safety
- **L2-Core-002**: Message publishing - core functionality
- **L4-Bridge-004**: Latency budget - performance requirement
- **L5-Lifecycle-002**: Loss detection - resilience
- **L6-Cluster-002**: Single node failure - quorum maintained
- **L7-Federation-001**: Cross-holon attestation - trust establishment

### Performance Critical
- **L2-PUB-002**: >1000 msg/sec throughput
- **L3-ENV-004**: Binary encoding 30-40% smaller
- **L4-BRIDGE-004**: p50<20ms, p99<45ms, p100<50ms
- **L5-LIFE-002**: Loss detection <5 seconds
- **L6-QUORUM-005**: Leader election <15 seconds
- **L7-FED-009**: Delta sync <10 seconds (medium)

### Safety Critical
- **L1-NIF-006**: No thread safety issues with concurrent access
- **L6-QUORUM-002**: No split-brain scenarios
- **L6-QUORUM-004**: Vote replay protection prevents Byzantine attacks
- **L7-FED-007**: Partition healing with consistent state
- **Safety-003**: ACID properties maintained across failures
- **Safety-004**: SIL-6 compliance (PFH < 10⁻¹²/hour)

## Documentation References

- **Full Specification**: `docs/testing/ZENOH_7LEVEL_BDD_SPECIFICATION.md`
- **Zenoh Requirements**: `.claude/rules/zenoh-telemetry-mandatory.md`
- **Mesh Operations**: `.claude/rules/fsharp-sil6-mesh.md`
- **STAMP Constraints**: `CLAUDE.md` §SC-ZENOH-*
- **AOR Rules**: `CLAUDE.md` §AOR-ZENOH-*

## Troubleshooting

### "NIF not loaded" Error
```bash
# Ensure SKIP_ZENOH_NIF=0
SKIP_ZENOH_NIF=0 mix compile
SKIP_ZENOH_NIF=0 mix test.features
```

### "Zenoh router not found" Error
```bash
# Start router before tests
sa-up
# OR
zenoh-router
```

### "Test timeout" on slow systems
```bash
# Increase timeout
MIX_ENV=test EXUNIT_TIMEOUT=30000 mix test.features
```

### "Memory leak detected"
```bash
# Run with valgrind (L1 tests)
valgrind --leak-check=full mix test.features --tags @memory_safety
```

## Next Steps

1. **Run Smoke Test**: `SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature --tags @l1_ffi`
2. **Implement Step Definitions**: Create steps in `test/support/steps/`
3. **Add Scenario-Specific Logic**: Each scenario needs Given/When/Then implementations
4. **Run Full Suite**: `SKIP_ZENOH_NIF=0 mix test.features test/features/zenoh_integration.feature`
5. **Generate Report**: `--format html` for documentation

## Integration with CI/CD

```yaml
# In .github/workflows/test.yml
- name: Run Zenoh BDD Tests
  run: |
    export SKIP_ZENOH_NIF=0
    mix test.features test/features/zenoh_integration.feature
  timeout-minutes: 150
```

---

**Last Updated**: 2026-01-14
**Status**: READY FOR STEP DEFINITION IMPLEMENTATION
