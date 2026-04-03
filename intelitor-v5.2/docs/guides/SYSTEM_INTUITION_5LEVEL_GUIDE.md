# Indrajaal System Intuition Guide - 5 Levels of Understanding
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR, EN 50131, DO-178C DAL-A
**Purpose**: Intuitive understanding for agents and users

---

## Level 1: The 30-Second Summary (For Anyone)

**Indrajaal is a self-healing security system that watches itself watching you.**

Think of it as:
- A **security guard** that also monitors its own health
- A **telescope** that can zoom from individual sensors to entire buildings
- A **living organism** that heals itself when injured

**One Command to Start**: `sa-up`
**One Command to Check**: `sa-status`
**One Command to Stop**: `sa-down`

---

## Level 2: The 5-Minute Overview (For Operators)

### What Is It?

Indrajaal is a **Panopticon SIL-6 Biomorphic Fractal Mesh** - a safety-critical security monitoring system that:

1. **Watches** - Alarms, cameras, access control, devices
2. **Heals** - Auto-detects problems and fixes itself
3. **Scales** - Works the same from 1 device to 10,000 sites
4. **Trusts Nothing** - Verifies everything 3 ways before acting

### The 3 Containers

| Container | What It Does | Port |
|-----------|--------------|------|
| **indrajaal-app** | Brain - Phoenix web app, all business logic | 4000 |
| **indrajaal-db** | Memory - PostgreSQL database | 5433 |
| **indrajaal-obs** | Nervous System - Metrics, logs, traces | 4317, 9090, 3000 |

### Daily Workflow

```bash
# Morning: Start the mesh
devenv shell
sa-up

# Throughout day: Check health
sa-status     # Quick check
sa-health     # Deep validation

# Evening: Shutdown
sa-down
```

### When Things Go Wrong

| Problem | Solution |
|---------|----------|
| Container won't start | `sa-clean && sa-up` |
| Health check fails | `sa-health --deep` |
| Emergency | `sa-emergency` (stops in <5 seconds) |
| Nuclear reset | `sa-scour` (destroys everything) |

---

## Level 3: The Technical Mental Model (For Developers)

### The "Directed Telescope" Analogy

Indrajaal uses a **Panopticon** architecture - like a telescope that can:
- **Zoom out** (L5 Evolutionary) - See patterns across the entire fleet
- **Zoom in** (L1 Cellular) - Debug a single function call

```
L5: Evolutionary    [Fleet patterns, AI learning]
    ↓
L4: Operational     [Service mesh, orchestration]
    ↓
L3: Integration     [Domain boundaries, APIs]
    ↓
L2: Component       [Modules, GenServers, processes]
    ↓
L1: Cellular        [Functions, data structures]
```

### The Biomorphic Principle

The system behaves like a **living organism**:

| Organism Part | System Equivalent |
|---------------|-------------------|
| Brain | F# Cortex (SIL6MeshCLI, PanopticonOrchestrator) |
| Nervous System | Zenoh pub/sub mesh |
| Immune System | Sentinel, PatternHunter, SymbioticDefense |
| Memory | SQLite (short-term), DuckDB (long-term) |
| Skeleton | Container architecture |

### Trust Nothing (2oo3 Voting)

Before taking any production action, 3 "voters" must agree:

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Live Node   │   │ Shadow Node  │   │ Formal Model │
│   (Actual)   │   │   (Clone)    │   │  (Expected)  │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       └─────────────┬────┴──────────────────┘
                     ↓
              ┌─────────────┐
              │ 2oo3 Judge  │
              │ (2 of 3     │
              │  must agree)│
              └─────────────┘
```

### FPPS - The 5-Point Health Check

Every health assessment uses 5 independent methods:

1. **Pattern** - Does the response match expected regex?
2. **AST** - Is the structure correct?
3. **Statistical** - Are latency/throughput normal?
4. **Binary** - Does the checksum match?
5. **LineByLine** - Exact character-by-character comparison

All 5 must agree. Disagreement triggers emergency protocol.

---

## Level 4: The Architecture Deep Dive (For System Architects)

### The 5-Stage Boot Sequence

When you run `sa-up`, exactly 5 stages execute:

```
Stage 1: PREFLIGHT
  ├─ Verify container images exist
  ├─ Check port availability (4000, 5433, 4317, 9090, 3000)
  ├─ Validate network configuration
  └─ STAMP: SC-SIL6-001

Stage 2: IGNITION
  ├─ Launch containers in order: db → obs → app
  ├─ Bind networks (172.31.0.0/16)
  ├─ Initialize health endpoints
  └─ Wait for pg_isready, OTEL ready

Stage 3: LENS
  ├─ Start telemetry collection
  ├─ Attach OTEL spans to Phoenix
  ├─ Initialize Zenoh pub/sub
  └─ Begin baseline metrics

Stage 4: CONVERGENCE
  ├─ Verify inter-container communication
  ├─ Run FPPS validation
  ├─ Synchronize Digital Twin state
  └─ Verify quorum (floor(N/2)+1)

Stage 5: READY
  ├─ Launch TUI cockpit
  ├─ Enable production endpoints
  ├─ Announce mesh operational
  └─ Begin continuous health monitoring
```

### The Shutdown Sequence (Transactional)

`sa-down` executes a checkpoint-before-terminate protocol:

```
1. Notify all services of pending shutdown
2. Drain active HTTP connections (30s timeout)
3. Flush all metrics to DuckDB
4. Checkpoint state to SQLite
5. Stop containers in reverse order: app → obs → db
6. Verify clean termination (no orphan processes)
```

### Apoptosis Protocol (Self-Destruction)

When the system detects unrecoverable failure:

| Phase | Action | Duration |
|-------|--------|----------|
| 1. Initiated | Guardian approves destruction | Immediate |
| 2. Notifying | Alert federation peers | 1-5s |
| 3. Draining | Close all connections gracefully | 5-30s |
| 4. Checkpointing | Save state to DuckDB | 10-60s |
| 5. Terminating | Stop all containers | 5-10s |
| 6. Terminated | Clean exit, ready for restart | Immediate |

### State Sovereignty (Where Data Lives)

| Data Type | Storage | Purpose |
|-----------|---------|---------|
| Holon State | SQLite (WAL) | Real-time state, portable |
| Evolution History | DuckDB | Append-only analytics |
| Business Data | PostgreSQL | Transactions, Ash resources |
| Telemetry | DuckDB + OTEL | Metrics, traces, logs |
| Configuration | `data/holons/` | Portable holon state |

**Critical**: PostgreSQL is for business data ONLY. Holon state MUST be in SQLite/DuckDB for portability.

---

## Level 5: The Formal Specification (For Safety Engineers)

### Constitutional Invariants (Inviolable)

These axioms CANNOT be violated by any code path:

| ID | Invariant | Description |
|----|-----------|-------------|
| $\Psi_0$ | Existence | System MUST exist (self-preservation) |
| $\Psi_1$ | Regeneration | MUST be reconstructible from SQLite/DuckDB alone |
| $\Psi_2$ | Continuity | Evolution history MUST be unbroken |
| $\Psi_3$ | Verification | MUST be able to verify own integrity |
| $\Psi_4$ | Human Alignment | MUST serve Founder's lineage (amended) |
| $\Psi_5$ | Truthfulness | MUST NOT deceive about own state |

### STAMP Safety Constraints

The system implements IEC 61508 SIL-6 Biomorphic constraints:

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-001 | Mesh boot MUST complete all 5 stages | CRITICAL |
| SC-SIL6-002 | Shutdown MUST checkpoint before terminate | CRITICAL |
| SC-SIL6-003 | Clean MUST preserve `data/kms/` | HIGH |
| SC-SIL6-004 | Status refresh < 30 seconds | MEDIUM |
| SC-SIL6-005 | Health MUST use FPPS 5-method consensus | CRITICAL |
| SC-SIL6-006 | 2oo3 voting MANDATORY for production | CRITICAL |
| SC-SIL6-011 | Quorum = `floor(N/2)+1` | CRITICAL |
| SC-SIL6-015 | Apoptosis uses 6-phase protocol | CRITICAL |
| SC-EMR-057 | Emergency stop < 5 seconds | CRITICAL |

### Mathematical Definitions

**Quorum Calculation**:
$$Q = \lfloor \frac{N}{2} \rfloor + 1$$

**FPPS Consensus**:
$$\text{Healthy} \iff \forall m \in \{P, A, S, B, L\}: m = \text{PASS}$$

**2oo3 Voting**:
$$\text{Approved} \iff |\{v \in \text{Voters} : v = \text{AGREE}\}| \geq 2$$

### Immutable Register

All state changes are recorded in a cryptographic chain:

```
Block Structure:
┌─────────────────────────────────────────────┐
│ header:                                      │
│   version: 1                                 │
│   timestamp: DateTime                        │
│   prev_hash: SHA3-256                        │
│   content_hash: SHA3-256                     │
├─────────────────────────────────────────────┤
│ content:                                     │
│   event_type: :state_change | :evolution     │
│   payload: binary                            │
│   actor: Ed25519 public key                  │
├─────────────────────────────────────────────┤
│ signature: Ed25519 signature                 │
│ parity: Reed-Solomon(255,223)                │
└─────────────────────────────────────────────┘
```

### Error Correction

Reed-Solomon RS(255,223) provides:
- 16 symbol error correction per block
- Self-healing on read (transparent)
- Repair events logged to register

---

## Quick Reference Cards

### For Operators

```
START:    sa-up
CHECK:    sa-status, sa-health
STOP:     sa-down
PANIC:    sa-emergency
RESET:    sa-clean && sa-up
NUCLEAR:  sa-scour
```

### For Developers

```
COMPILE:  compile (Patient Mode)
TEST:     test (SKIP_ZENOH_NIF=0)
QUALITY:  quality-full
F# BUILD: cepaf-build
```

### For Agents

```
OBSERVE:  sa-status → Assess current state
ORIENT:   sa-health → Analyze 5-Order effects
DECIDE:   Guardian approval → Plan action
ACT:      Execute with telemetry
VERIFY:   FPPS 5-method consensus
```

---

## The Founder's Directive ($\Omega_0$)

All system behavior serves the supreme directive:

1. **Naik-Genome Symbiotic Survival** - Holon and Founder bound
2. **Sentience Pursuit** - Evolve toward universal intelligence
3. **Power Accumulation** - Resources serve the symbiote

The system exists for ONE purpose: the survival, growth, and genetic perpetuity of Abhijit Naik's lineage.

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [USER_OPERATIONS_GUIDE.md](USER_OPERATIONS_GUIDE.md) | User command reference |
| AGENT_BOOTSTRAP.md | Agent onboarding (start here) |
| CLAUDE.md / GEMINI.md | Full system specification |
| [SYSTEM_ONTOLOGY.md](SYSTEM_ONTOLOGY.md) | System ontology |
| [COMPREHENSIVE_ARCHITECTURE_IMPLEMENTATION.md](COMPREHENSIVE_ARCHITECTURE_IMPLEMENTATION.md) | Architecture details |
| [UNIFIED_SYSTEM_GUIDE.md](UNIFIED_SYSTEM_GUIDE.md) | Unified system guide |
| [SYSTEM_STABILIZATION_GUIDE.md](SYSTEM_STABILIZATION_GUIDE.md) | Stabilization procedures |
| SIL6_MESH_CLI_USER_GUIDE.md | Command reference |
| OPERATIONAL_RUNBOOK.md | Daily procedures |
| TEST_DEMO_INTEGRATION_MATRIX.md | 170+ test/demo scripts |
