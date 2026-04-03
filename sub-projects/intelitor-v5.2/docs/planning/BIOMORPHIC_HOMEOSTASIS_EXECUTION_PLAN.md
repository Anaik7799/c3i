# Biomorphic Homeostasis Execution Plan
## Version 21.3.0 - SIL-6 Controls | Fractal Cluster Mode

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL HOMEOSTASIS
     ╭╯ ╰─╯ ╰╮       EXECUTION PLAN
    ●╯       ╰●       2026-01-05 | v21.3.0
```

## Executive Summary

This execution plan establishes the Biomorphic Homeostasis Protocol - ensuring the Indrajaal system maintains functional stability at all times while evolving. The plan follows the FUNCTIONAL INVARIANT RULE (SC-FUNC-000) and implements SIL-6 controls across all fractal layers.

---

## FUNDAMENTAL RULE: FUNCTIONAL INVARIANT

**THE SYSTEM MUST ALWAYS BE IN A FUNCTIONAL STATE.**

This is IMMUTABLE, UNIVERSAL, and VERIFIED before/after every operation.

---

## Current System State (OBSERVE Phase)

| Component | Status | Health | Notes |
|-----------|--------|--------|-------|
| **indrajaal-db-prod** | UP | ✅ Healthy | Port 5433, PostgreSQL 17 |
| **indrajaal-obs-prod** | UP | ⚠️ Unhealthy | Port 4317/9090, needs attention |
| **indrajaal-ex-app-1** | DOWN | ❌ Failed | Missing /bin/bash in image |
| **Elixir Compilation** | PASS | ✅ | 0 errors, ~15 warnings |
| **Test Compilation** | NEEDS FIX | ⚠️ | PropCheck pattern issues |
| **F# CEPAF** | UNKNOWN | ⚠️ | Build verification needed |
| **Zenoh Mesh** | INACTIVE | ⚠️ | Needs app container |

---

## 5-Level Execution Plan

### Level 1: FOUNDATION STABILIZATION (P0-CRITICAL)
**Timeline: Immediate | Parallelism: HIGH**

```
┌─────────────────────────────────────────────────────────────────┐
│  L1: FOUNDATION STABILIZATION                                   │
├─────────────────────────────────────────────────────────────────┤
│  [████████░░] 80% Complete                                      │
│                                                                  │
│  ✅ L1.1: Functional Invariant Rule established                 │
│  ✅ L1.2: Compilation passing (0 errors)                        │
│  🔄 L1.3: Fix test PropCheck patterns (in progress)             │
│  ⬜ L1.4: Fix container image (bash missing)                    │
│  ⬜ L1.5: Verify all quality gates                               │
└─────────────────────────────────────────────────────────────────┘
```

#### STAMP Constraints (L1)

| ID | Constraint | Severity | Status |
|----|------------|----------|--------|
| SC-L1-001 | Compilation 0 errors | CRITICAL | ✅ |
| SC-L1-002 | Test files compile | CRITICAL | 🔄 |
| SC-L1-003 | Container images valid | HIGH | ❌ |
| SC-L1-004 | Quality gates pass | CRITICAL | ⬜ |

#### AOR Rules (L1)

| ID | Rule | Action |
|----|------|--------|
| AOR-L1-001 | Verify compilation before any commit | Pre-commit hook |
| AOR-L1-002 | Fix errors immediately (Jidoka) | Auto-halt on failure |
| AOR-L1-003 | Maintain rollback capability | Git checkpoint |

#### Tasks (L1)

```elixir
# L1.3: Fix remaining PropCheck patterns
# Pattern types to fix:
#   - PC.xxx(generator() do  → PC.xxx(generator()) do
#   - PC.xxx()) do           → PC.xxx() do
#   - check all x <- gen) do → check all x <- gen do

# L1.4: Fix container image
# Options:
#   1. Rebuild image with bash
#   2. Use sh instead of bash in entrypoint
#   3. Run Phoenix directly via mix phx.server

# L1.5: Run quality gates
mix format --check-formatted && mix credo --strict
```

---

### Level 2: SERVICE RESTORATION (P1-HIGH)
**Timeline: After L1 | Parallelism: MEDIUM**

```
┌─────────────────────────────────────────────────────────────────┐
│  L2: SERVICE RESTORATION                                        │
├─────────────────────────────────────────────────────────────────┤
│  [░░░░░░░░░░] 0% Complete                                       │
│                                                                  │
│  ⬜ L2.1: Start Phoenix server (dev mode)                       │
│  ⬜ L2.2: Fix observability container health                    │
│  ⬜ L2.3: Verify database connectivity                          │
│  ⬜ L2.4: Build and verify F# CEPAF                             │
│  ⬜ L2.5: Establish Zenoh mesh connectivity                     │
└─────────────────────────────────────────────────────────────────┘
```

#### STAMP Constraints (L2)

| ID | Constraint | Severity | Status |
|----|------------|----------|--------|
| SC-L2-001 | Phoenix responds on :4000 | HIGH | ⬜ |
| SC-L2-002 | DB accepts connections | HIGH | ✅ |
| SC-L2-003 | F# builds successfully | MEDIUM | ⬜ |
| SC-L2-004 | Zenoh mesh connected | MEDIUM | ⬜ |

#### Tasks (L2)

```bash
# L2.1: Start Phoenix
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_dev" \
mix phx.server

# L2.2: Fix obs container
podman logs indrajaal-obs-prod
podman restart indrajaal-obs-prod

# L2.4: Build F#
.devenv/profile/bin/dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
```

---

### Level 3: DOMAIN VERIFICATION (P2-MEDIUM)
**Timeline: After L2 | Parallelism: HIGH**

```
┌─────────────────────────────────────────────────────────────────┐
│  L3: DOMAIN VERIFICATION                                        │
├─────────────────────────────────────────────────────────────────┤
│  [░░░░░░░░░░] 0% Complete                                       │
│                                                                  │
│  ⬜ L3.1: Run test suite (core domains)                         │
│  ⬜ L3.2: Verify Prajna cockpit endpoints                       │
│  ⬜ L3.3: Verify all 30+ domain handlers                        │
│  ⬜ L3.4: Run property tests (PropCheck + StreamData)           │
│  ⬜ L3.5: Verify holon state sovereignty                        │
└─────────────────────────────────────────────────────────────────┘
```

#### STAMP Constraints (L3)

| ID | Constraint | Severity | Status |
|----|------------|----------|--------|
| SC-L3-001 | Test suite 0 failures | CRITICAL | ⬜ |
| SC-L3-002 | All domains respond | HIGH | ⬜ |
| SC-L3-003 | Holon state in SQLite/DuckDB | CRITICAL | ⬜ |

---

### Level 4: OBSERVABILITY & TELEMETRY (P2-MEDIUM)
**Timeline: After L3 | Parallelism: MEDIUM**

```
┌─────────────────────────────────────────────────────────────────┐
│  L4: OBSERVABILITY & TELEMETRY                                  │
├─────────────────────────────────────────────────────────────────┤
│  [░░░░░░░░░░] 0% Complete                                       │
│                                                                  │
│  ⬜ L4.1: Configure Zenoh Control Plane                         │
│  ⬜ L4.2: Setup fractal logging (verbose mode)                  │
│  ⬜ L4.3: Establish Digital Twin state tracking                 │
│  ⬜ L4.4: Configure OTEL traces                                 │
│  ⬜ L4.5: Setup KPI dashboard (10s refresh)                     │
└─────────────────────────────────────────────────────────────────┘
```

#### Telemetry Topics (Zenoh)

```
indrajaal/
├── control/
│   ├── commands      # Control plane commands
│   └── health        # Health heartbeats
├── kpi/
│   ├── compilation   # Compilation metrics
│   ├── containers    # Container health
│   ├── domains       # Domain status
│   └── tests         # Test results
├── mesh/
│   ├── nodes         # Mesh node status
│   └── topology      # Network topology
└── digital_twin/
    ├── state         # Current system state
    └── delta         # State changes
```

---

### Level 5: HOMEOSTASIS & EVOLUTION (P3-LOW)
**Timeline: Continuous | Parallelism: LOW**

```
┌─────────────────────────────────────────────────────────────────┐
│  L5: HOMEOSTASIS & EVOLUTION                                    │
├─────────────────────────────────────────────────────────────────┤
│  [░░░░░░░░░░] 0% Complete                                       │
│                                                                  │
│  ⬜ L5.1: Establish OODA monitoring loop (30s)                  │
│  ⬜ L5.2: Configure auto-healing supervisors                    │
│  ⬜ L5.3: Setup 5-level RCA for failures                        │
│  ⬜ L5.4: Create documentation & journal                        │
│  ⬜ L5.5: Update KMS with procedures                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## OODA Loop Configuration

```
┌─────────────────────────────────────────────────────────────────┐
│                    30-SECOND OODA CYCLE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVE ─────────▶ ORIENT ─────────▶ DECIDE ─────────▶ ACT    │
│     │                  │                 │               │      │
│  [5s]              [10s]             [10s]           [5s]      │
│  ● Container       ● Analyze          ● Plan           ● Execute│
│    health           delta              fix              action  │
│  ● Compilation     ● 5-order          ● Select         ● Log   │
│    status           effects            strategy         result │
│  ● Test results    ● RCA if           ● Verify         ● Emit  │
│  ● Domain health     needed            deps             telemetry│
│     │                                                    │      │
│     └─────────────── FEEDBACK ◀──────────────────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Jidoka (5-Level RCA) Protocol

When a failure occurs:

| Level | Question | Example |
|-------|----------|---------|
| 1st Why | What happened? | Container exited with code 127 |
| 2nd Why | Why did that happen? | /bin/bash not found |
| 3rd Why | Why is that missing? | Container image built without bash |
| 4th Why | Why was it built that way? | NixOS minimal base image |
| 5th Why | What's the root cause? | Entrypoint script uses bash, not sh |

**Resolution**: Change entrypoint to use `/bin/sh` or rebuild image with bash.

---

## Digital Twin Data Structure

```elixir
%DigitalTwin{
  timestamp: ~U[2026-01-05 14:50:00Z],
  version: "21.1.0",

  containers: %{
    "indrajaal-db-prod" => %{
      status: :running,
      health: :healthy,
      ports: [5433],
      uptime: "2h",
      metrics: %{cpu: 5, mem: 256_mb}
    },
    "indrajaal-obs-prod" => %{
      status: :running,
      health: :unhealthy,
      ports: [4317, 9090, 3000],
      uptime: "2h",
      error: "health check failing"
    },
    "indrajaal-ex-app-1" => %{
      status: :exited,
      health: :failed,
      ports: [4000, 4001],
      exit_code: 127,
      error: "/bin/bash: No such file or directory"
    }
  },

  compilation: %{
    elixir: %{status: :passing, errors: 0, warnings: 15},
    tests: %{status: :partial, pattern_errors: 3},
    fsharp: %{status: :unknown, last_build: nil}
  },

  mesh: %{
    zenoh: %{connected: false, nodes: 0},
    control_plane: %{active: false}
  },

  domains: %{
    total: 30,
    verified: 0,
    handlers_loaded: false
  },

  holon_state: %{
    sqlite_path: "data/holons/",
    duckdb_path: "data/holons/",
    integrity: :pending_verification
  }
}
```

---

## SIL-6 Control Measures

| Control | Description | Implementation |
|---------|-------------|----------------|
| **Redundancy** | N+2 for critical services | Multiple container replicas |
| **Verification** | Formal proofs | Quint temporal logic models |
| **Monitoring** | Real-time observability | Zenoh + OTEL + Prometheus |
| **Recovery** | Automatic failover | Supervisor trees + restart policies |
| **Audit** | Immutable log | Blockchain-style register |
| **Isolation** | Fault containment | Process isolation, circuit breakers |

---

## Execution Commands

### Manual Execution

```bash
# Phase 1: Foundation
cd /home/an/dev/ver/intelitor-v5.2
devenv shell

# Check compilation
compile

# Fix any test issues
SKIP_ZENOH_NIF=0 MIX_ENV=test mix compile

# Run quality gates
quality

# Phase 2: Services
# Start Phoenix directly (bypassing container)
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_dev" \
mix phx.server

# Phase 3: Verification
test
test-cover

# Phase 4: Observability
sa-status
sa-logs
```

### Automated Execution

```bash
# Full startup sequence
./scripts/startup/biomorphic_startup.exs --verbose --level all

# With telemetry
./scripts/startup/biomorphic_startup.exs --verbose --telemetry zenoh
```

---

## Success Criteria

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| Compilation | 0 errors | `mix compile` exit code |
| Test Suite | >95% pass | `mix test` results |
| Quality Gate | 0 credo issues | `mix credo --strict` |
| Container Health | 3/3 healthy | `podman ps` status |
| Response Time | <50ms | Telemetry p99 |
| Zenoh Mesh | All nodes connected | Health heartbeat |
| Holon Integrity | SHA-256 verified | SQLite checksum |

---

## Related Documents

- `.claude/rules/functional-invariant.md` - Fundamental operational rule
- `docs/planning/BIOMORPHIC_OPERATIONAL_STABILITY_PLAN_5LEVEL.md` - Original plan
- `CLAUDE.md` - System specification
- `GEMINI.md` - Cybernetic architect guidance
- `journal/2026-01/` - Session journals
