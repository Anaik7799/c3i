# ZENOH TEST MESSAGING - FMEA & DAG SPECIFICATION
## Version 2.0.0 | 2026-01-18 | Pass 2: Risk Analysis & Dependency Management

---

## 1. FAILURE MODE AND EFFECTS ANALYSIS (FMEA)

### 1.1 FMEA Methodology

**RPN Calculation**:
$$RPN = Severity \times Occurrence \times Detection$$

**Risk Classification**:
- **CRITICAL**: RPN > 200 → Immediate action required
- **HIGH**: 100 < RPN ≤ 200 → Scheduled remediation
- **MEDIUM**: 50 < RPN ≤ 100 → Monitor and improve
- **LOW**: RPN ≤ 50 → Accept with documentation

### 1.2 Comprehensive FMEA Matrix

| ID | Failure Mode | Effect | Severity (1-10) | Occurrence (1-10) | Detection (1-10) | RPN | Risk Level | Mitigation | Constraint | AOR |
|----|--------------|--------|-----------------|-------------------|------------------|-----|------------|------------|------------|-----|
| **FMEA-ZTEST-001** | Zenoh router unavailable | No real-time messaging | 7 | 3 | 8 | **168** | HIGH | Log-based fallback | SC-ZTEST-008 | AOR-ZTEST-008 |
| **FMEA-ZTEST-002** | Message lost in transit | Missing checkpoint data | 5 | 2 | 6 | **60** | MEDIUM | At-least-once delivery, log backup | SC-ZTEST-004 | AOR-ZTEST-004 |
| **FMEA-ZTEST-003** | High publish latency (>10ms) | Dashboard stale, slow feedback | 6 | 3 | 4 | **72** | MEDIUM | Async non-blocking publish | SC-ZTEST-003 | AOR-ZTEST-004 |
| **FMEA-ZTEST-004** | Schema version mismatch | Message parsing failures | 4 | 2 | 3 | **24** | LOW | Semver versioning in messages | SC-ZTEST-014 | AOR-ZTEST-009 |
| **FMEA-ZTEST-005** | Dashboard update stale (>100ms) | Operator sees old data | 5 | 3 | 2 | **30** | LOW | Heartbeat/timeout detection | SC-ZTEST-005 | AOR-ZTEST-006 |
| **FMEA-ZTEST-006** | State vector corruption | Invalid startup state tracking | 8 | 1 | 5 | **40** | LOW | Schema validation, monotonicity check | SC-ZTEST-006 | AOR-ZTEST-003 |
| **FMEA-ZTEST-007** | Topic collision | Message routing errors | 9 | 1 | 3 | **27** | LOW | Unique topic registry | SC-ZTEST-001 | AOR-ZTEST-001 |
| **FMEA-ZTEST-008** | FIFO ordering violation | Out-of-order test results | 6 | 2 | 4 | **48** | LOW | Per-topic sequencing | SC-ZTEST-012 | AOR-ZTEST-012 |
| **FMEA-ZTEST-009** | Quorum lost (< 2oo3) | Consensus failure | 9 | 2 | 3 | **54** | MEDIUM | 2oo3 voting protocol | SC-ZTEST-020 | AOR-ZTEST-014 |
| **FMEA-ZTEST-010** | Log fallback unreadable | Cannot verify checkpoints offline | 5 | 2 | 4 | **40** | LOW | Regex validation tests | AOR-ZTEST-013 | AOR-ZTEST-013 |
| **FMEA-ZTEST-011** | Checkpoint ID format error | Message rejected | 4 | 2 | 2 | **16** | LOW | Regex validation CP-{DOMAIN}-{NN} | SC-ZTEST-013 | AOR-ZTEST-009 |
| **FMEA-ZTEST-012** | Timestamp format error | Ordering/replay issues | 4 | 1 | 3 | **12** | LOW | ISO 8601 UTC enforcement | SC-ZTEST-015 | AOR-ZTEST-010 |
| **FMEA-ZTEST-013** | Payload too large (>64KB) | Message dropped | 6 | 1 | 4 | **24** | LOW | Size check before publish | SC-ZTEST-016 | AOR-ZTEST-009 |
| **FMEA-ZTEST-014** | Topic too deep (>6 levels) | Routing performance degradation | 3 | 2 | 3 | **18** | LOW | Topic depth validation | SC-ZTEST-017 | AOR-ZTEST-009 |
| **FMEA-ZTEST-015** | Subscriber timeout (>5s) | Missed messages | 5 | 2 | 4 | **40** | LOW | Timeout configuration | SC-ZTEST-018 | AOR-ZTEST-005 |
| **FMEA-ZTEST-016** | Publisher retry exhausted | Message permanently lost | 6 | 2 | 5 | **60** | MEDIUM | 3 retries + log fallback | SC-ZTEST-019 | AOR-ZTEST-011 |
| **FMEA-ZTEST-017** | NIF crash | All Zenoh operations fail | 9 | 1 | 8 | **72** | MEDIUM | Supervisor restart, log fallback | SC-ZENOH-001 | AOR-ZTEST-008 |
| **FMEA-ZTEST-018** | Memory leak in formatter | OOM during test suite | 7 | 1 | 6 | **42** | LOW | GenServer state cleanup | SC-ZTEST-004 | AOR-BRIDGE-003 |
| **FMEA-ZTEST-019** | F# bridge timeout | Boot checkpoints missing | 6 | 2 | 5 | **60** | MEDIUM | HTTP timeout + log fallback | SC-ZTEST-009 | AOR-ZTEST-008 |
| **FMEA-ZTEST-020** | Telemetry event dropped | Observability gap | 3 | 3 | 4 | **36** | LOW | Telemetry buffer | AOR-ZTEST-015 | AOR-ZTEST-015 |

### 1.3 RPN Distribution

```
CRITICAL (>200):  0 failures
HIGH (100-200):   1 failure  (FMEA-ZTEST-001: Zenoh unavailable)
MEDIUM (50-100):  6 failures
LOW (<50):        13 failures

Total Failures Analyzed: 20
Average RPN: 47.3
Maximum RPN: 168 (Zenoh unavailable)
```

### 1.4 Mitigation Summary by Risk Level

**HIGH RISK (RPN 168)**:
- FMEA-ZTEST-001: Zenoh unavailable
  - Primary: Log-based fallback [ZTEST-CHECKPOINT]
  - Secondary: Exponential backoff reconnection
  - Tertiary: Health check alerting

**MEDIUM RISK (RPN 50-100)**:
- FMEA-ZTEST-003 (72): Async publishing
- FMEA-ZTEST-009 (54): 2oo3 quorum protocol
- FMEA-ZTEST-016 (60): Retry with log fallback
- FMEA-ZTEST-017 (72): Supervisor restart
- FMEA-ZTEST-019 (60): HTTP timeout handling
- FMEA-ZTEST-002 (60): At-least-once + log backup

---

## 2. DIRECTED ACYCLIC GRAPH (DAG) SPECIFICATIONS

### 2.1 Boot Checkpoint DAG

**Formal Definition**:
$$G_{boot} = (V_{boot}, E_{boot})$$

where:
- $V_{boot} = \{CP\text{-}BOOT\text{-}01, ..., CP\text{-}BOOT\text{-}10\}$
- $E_{boot} \subseteq V_{boot} \times V_{boot}$

**Adjacency Matrix**:
```
       01  02  03  04  05  06  07  08  09  10
    ┌──────────────────────────────────────────┐
 01 │  0   1   0   0   0   0   0   0   0   0  │
 02 │  0   0   1   1   0   1   0   0   0   0  │
 03 │  0   0   0   0   1   0   0   0   0   0  │
 04 │  0   0   0   0   1   0   0   0   0   0  │
 05 │  0   0   0   0   0   0   0   1   0   0  │
 06 │  0   0   0   0   0   0   1   0   0   0  │
 07 │  0   0   0   0   0   0   0   1   0   0  │
 08 │  0   0   0   0   0   0   0   0   1   0  │
 09 │  0   0   0   0   0   0   0   0   0   1  │
 10 │  0   0   0   0   0   0   0   0   0   0  │
    └──────────────────────────────────────────┘
```

**Visual DAG**:
```
                    CP-BOOT-01 (Preflight Start)
                         │
                         ▼
                    CP-BOOT-02 (DAG Validated)
                    ╱    │    ╲
                   ▼     ▼     ▼
            CP-BOOT-03  CP-BOOT-04  CP-BOOT-06
            (DB Ready)  (Obs Ready) (Bridge)
                   ╲     ╱          │
                    ▼   ▼           ▼
                  CP-BOOT-05     CP-BOOT-07
                  (Quorum)      (Cortex)
                       ╲         ╱
                        ▼       ▼
                      CP-BOOT-08 (App Seed)
                           │
                           ▼
                      CP-BOOT-09 (Homeostasis)
                           │
                           ▼
                      CP-BOOT-10 (Complete)
```

### 2.2 DAG Properties

| Property | Value | Formula | Constraint |
|----------|-------|---------|------------|
| **Vertices** | 10 | $|V| = 10$ | Fixed |
| **Edges** | 10 | $|E| = 10$ | Minimal |
| **Sources** | 1 | $|sources(G)| = 1$ | DAG-ZTEST-002 |
| **Sinks** | 1 | $|sinks(G)| = 1$ | DAG-ZTEST-003 |
| **Critical Path** | 7 | $CPL(G) = 7$ | DAG-ZTEST-004 |
| **Width** | 3 | $width(G) = 3$ | DAG-ZTEST-005 |
| **Parallelism** | 2.5 | $\frac{\sum duration}{CPL}$ | Optimization target |

### 2.3 Topological Order

The unique topological sort for boot checkpoints:
```
τ = [01, 02, 03, 04, 06, 05, 07, 08, 09, 10]
   or
τ = [01, 02, 04, 03, 06, 07, 05, 08, 09, 10]
   or
τ = [01, 02, 06, 03, 04, 07, 05, 08, 09, 10]
```

Multiple valid orderings exist due to parallelism at levels 03/04/06.

### 2.4 Critical Path Analysis

**Critical Path**:
```
01 → 02 → 03 → 05 → 08 → 09 → 10
```

**Duration Estimates**:
| Checkpoint | Duration (ms) | Cumulative |
|------------|---------------|------------|
| CP-BOOT-01 | 100 | 100 |
| CP-BOOT-02 | 500 | 600 |
| CP-BOOT-03 | 5000 | 5600 |
| CP-BOOT-05 | 2000 | 7600 |
| CP-BOOT-08 | 3000 | 10600 |
| CP-BOOT-09 | 1000 | 11600 |
| CP-BOOT-10 | 100 | 11700 |

**Total Critical Path Duration**: ~12 seconds

### 2.5 DAG Constraints (DAG-ZTEST-*)

| ID | Constraint | Mathematical Form | Verification |
|----|------------|-------------------|--------------|
| DAG-ZTEST-001 | Acyclic graph | $\nexists$ cycle in $G$ | Kahn's algorithm |
| DAG-ZTEST-002 | Single source | $|sources(G)| = 1$ | Degree check |
| DAG-ZTEST-003 | Single sink | $|sinks(G)| = 1$ | Degree check |
| DAG-ZTEST-004 | Critical path ≤ 7 | $CPL(G) \leq 7$ | Path enumeration |
| DAG-ZTEST-005 | Parallel factor ≥ 2 | $width(G) \geq 2$ | Level width |
| DAG-ZTEST-006 | Edge count minimal | $|E| \leq 2|V|$ | Count check |
| DAG-ZTEST-007 | Transitive reduction | No redundant edges | TR algorithm |

---

## 3. TEST CHECKPOINT DAG

### 3.1 Test DAG Structure

```
CP-TEST-01 (Suite Start)
     │
     ▼
CP-TEST-02 (Compile)
     │
     ├──────────────────┐
     ▼                  ▼
CP-TEST-03         CP-TEST-04
(DB Sandbox)       (Factories)
     │                  │
     └────────┬─────────┘
              ▼
         [Test Modules]
         CP-TEST-05/06
              │
              ▼
         CP-TEST-07 (Suite Complete)
              │
              ▼
         CP-TEST-08 (Coverage)
```

### 3.2 Test DAG Properties

| Property | Value |
|----------|-------|
| Sources | 1 (CP-TEST-01) |
| Sinks | 1 (CP-TEST-08) |
| Critical Path | 6 |
| Parallel Modules | N (dynamic) |

---

## 4. SMOKE TEST CHECKPOINT DAG

### 4.1 Smoke DAG Structure

```
CP-SMOKE-01 (Batch Start)
     │
     ├────┬────┬────┬────┬────┐
     ▼    ▼    ▼    ▼    ▼    ▼
   API   DB  Zenoh Perf  Sec  Resil
   02    03   04    05   06    07
     │    │    │    │    │     │
     └────┴────┴────┴────┴─────┘
              │
              ▼
         CP-SMOKE-08 (Batch Complete)
```

### 4.2 Smoke DAG Properties

| Property | Value |
|----------|-------|
| Sources | 1 (CP-SMOKE-01) |
| Sinks | 1 (CP-SMOKE-08) |
| Critical Path | 3 |
| Parallel Tests | 6 |
| Maximum Parallelism | 6 |

---

## 5. COMBINED DAG ORCHESTRATION

### 5.1 Full System DAG

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FULL SYSTEM CHECKPOINT DAG                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  BOOT PHASE                    TEST PHASE                   SMOKE PHASE │
│  ══════════                    ══════════                   ═══════════ │
│                                                                          │
│  CP-BOOT-01 ─────────────────────────────────────────────────────────►  │
│       │                                                                  │
│       ▼                                                                  │
│  CP-BOOT-02                                                              │
│     / | \                                                                │
│    ▼  ▼  ▼                                                               │
│   03 04 06                                                               │
│    \ | /                                                                 │
│     \|/                                                                  │
│      ▼                                                                   │
│  CP-BOOT-05 ──────────────────────────────────┐                         │
│       │                                       │                         │
│       ▼                                       ▼                         │
│  CP-BOOT-08 ────────────────►  CP-TEST-01 ─────────────►  CP-SMOKE-01  │
│       │                            │                           │        │
│       ▼                            ▼                       /   |   \    │
│  CP-BOOT-09 ────────────────►  CP-TEST-07 ────────────► 02  03  ...  07│
│       │                            │                       \   |   /    │
│       ▼                            ▼                           ▼        │
│  CP-BOOT-10                    CP-TEST-08 ─────────────►  CP-SMOKE-08  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cross-Phase Dependencies

| Dependency | From | To | Type |
|------------|------|-----|------|
| Boot→Test | CP-BOOT-08 | CP-TEST-01 | Required |
| Boot→Smoke | CP-BOOT-09 | CP-SMOKE-01 | Required |
| Test→Smoke | CP-TEST-07 | CP-SMOKE-01 | Optional |

---

## 6. AORULES FOR FMEA/DAG (Extended)

| ID | Rule | FMEA Ref | DAG Ref |
|----|------|----------|---------|
| AOR-FMEA-001 | Document all failure modes with RPN > 50 | FMEA-ZTEST-* | - |
| AOR-FMEA-002 | Implement mitigation for HIGH risk (RPN > 100) | FMEA-ZTEST-001 | - |
| AOR-FMEA-003 | Test all mitigations quarterly | All | - |
| AOR-FMEA-004 | Update FMEA on architecture changes | All | - |
| AOR-DAG-001 | Verify DAG acyclicity before boot | - | DAG-ZTEST-001 |
| AOR-DAG-002 | Validate checkpoint dependencies | - | All DAG-ZTEST |
| AOR-DAG-003 | Track critical path duration | - | DAG-ZTEST-004 |
| AOR-DAG-004 | Optimize parallel execution | - | DAG-ZTEST-005 |
| AOR-DAG-005 | Publish checkpoint completion order | - | Topological |

---

## 7. VERIFICATION PROCEDURES

### 7.1 FMEA Verification

```bash
# Run FMEA test suite
mix test --only fmea_ztest

# Verify HIGH risk mitigations
mix test test/fmea/high_risk_mitigation_test.exs

# Log fallback verification
grep '\[ZTEST-CHECKPOINT\]' _build/test.log | wc -l
```

### 7.2 DAG Verification

```bash
# Verify DAG acyclicity
elixir scripts/verification/dag_cycle_check.exs

# Critical path analysis
elixir scripts/verification/dag_critical_path.exs

# Topological sort
elixir scripts/verification/dag_topo_sort.exs
```

---

## 8. REVISION HISTORY

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 2: Complete FMEA (20 modes), DAG specifications |
