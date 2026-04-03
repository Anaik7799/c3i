# FUNCTIONAL INVARIANT RULE (SC-FUNC-000)

## SUPREME OPERATIONAL MANDATE

**THE SYSTEM MUST ALWAYS BE IN A FUNCTIONAL STATE.**

This is a FUNDAMENTAL RULE applicable across:
- ALL System artifacts
- ALL fractal evolutionary dimensions
- ALL operational dimensions
- ALL monitoring dimensions
- ALL SIL-6 control layers

## Constitutional Alignment

This rule derives from and enforces:
- **Ψ₀ (Existence)**: System survives ALL operations
- **Ω₀ (Founder's Directive)**: Holon exists for symbiotic survival

## STAMP Constraints (Functional Invariant)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-FUNC-001 | System MUST compile at all times | INFINITE | Pre-commit hook |
| SC-FUNC-002 | Core services MUST be operational | CRITICAL | Health monitoring |
| SC-FUNC-003 | Rollback path MUST exist for every change | CRITICAL | Git checkpoint |
| SC-FUNC-004 | State MUST be recoverable from SQLite/DuckDB | CRITICAL | Holon sovereignty |
| SC-FUNC-005 | Container stack MUST auto-heal | HIGH | Supervisor restart |
| SC-FUNC-006 | Quality gates MUST pass before merge | CRITICAL | CI/CD enforcement |
| SC-FUNC-007 | Zenoh mesh MUST maintain connectivity | HIGH | Health heartbeat |
| SC-FUNC-008 | Digital Twin MUST reflect actual state | HIGH | Sync every 30s |

## AOR Rules (Functional Invariant)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-FUNC-001 | VERIFY compilation before ANY code commit | BLOCK commit |
| AOR-FUNC-002 | CHECKPOINT git state before risky operations | Require --force |
| AOR-FUNC-003 | TEST locally before pushing to remote | BLOCK push |
| AOR-FUNC-004 | MONITOR container health continuously | Alert + auto-restart |
| AOR-FUNC-005 | ROLLBACK immediately on functional degradation | Auto-rollback |
| AOR-FUNC-006 | LOG all state mutations to Immutable Register | Audit trail |
| AOR-FUNC-007 | SYNC Digital Twin within 30s of any change | State verification |
| AOR-FUNC-008 | HALT operations if functional invariant violated | Jidoka principle |

## Operational Modes

### 1. Evolution Mode (Code Changes)
```
PRE-CONDITION:  System is functional
OPERATION:      Make code change
POST-CONDITION: System MUST remain functional
FAILURE:        Auto-rollback to last functional state
```

### 2. Deployment Mode (Container Operations)
```
PRE-CONDITION:  Container stack is operational
OPERATION:      Deploy new version
POST-CONDITION: All containers MUST be healthy
FAILURE:        Rollback to previous image
```

### 3. Monitoring Mode (Homeostasis)
```
CONTINUOUS:     Health checks every 10s
THRESHOLD:      Degradation > 10% triggers alert
ACTION:         Auto-healing or operator notification
ESCALATION:     5-level RCA for persistent failures
```

## OODA Loop Integration

```
OBSERVE → Is system functional?
  │         └─ NO → IMMEDIATE HALT + RCA
  ▼
ORIENT  → What is the delta from last functional state?
  │         └─ Analyze 1st-5th order effects
  ▼
DECIDE  → Can we maintain functionality during change?
  │         └─ NO → Defer change, plan safer approach
  ▼
ACT     → Execute with rollback capability
  │         └─ VERIFY functional state after
  ▼
FEEDBACK ← Update Digital Twin, telemetry, KPIs
```

## SIL-6 Control Measures

| Control | Description | Implementation |
|---------|-------------|----------------|
| Redundancy | N+1 for all critical services | Container replicas |
| Verification | Formal proofs for critical paths | Quint/Agda specs |
| Monitoring | Real-time observability | Zenoh + OTEL |
| Recovery | Automatic failover | Supervisor trees |
| Audit | Immutable log of all actions | Blockchain register |

## Jidoka (Autonomation) Protocol

When functional invariant is violated:

1. **STOP**: Immediately halt current operation
2. **SIGNAL**: Alert via Zenoh control plane
3. **ANALYZE**: 5-level RCA (5-Why methodology)
4. **FIX**: Root cause resolution with global view
5. **VERIFY**: Confirm functional state restored
6. **PREVENT**: Update constraints to prevent recurrence

## Digital Twin State Tracking

```elixir
%DigitalTwin{
  containers: %{
    "indrajaal-db-prod" => %{status: :healthy, ports: [5433], uptime: "15h"},
    "indrajaal-obs-prod" => %{status: :unhealthy, ports: [4317, 9090], uptime: "1h"},
    "indrajaal-ex-app-1" => %{status: :created, ports: [4000], uptime: nil}
  },
  compilation: %{
    status: :passing,
    errors: 0,
    warnings: 15,
    last_build: ~U[2026-01-05 12:10:00Z]
  },
  zenoh_mesh: %{
    connected: true,
    nodes: 3,
    latency_ms: 5
  },
  holon_state: %{
    sqlite_path: "data/holons/",
    duckdb_path: "data/holons/",
    integrity: :verified
  }
}
```

## Fractal Cluster Default Mode

The system MUST start, run, and stop ONLY in Fractal Cluster mode:

```yaml
fractal_cluster:
  mode: DEFAULT
  containers:
    - indrajaal-db-prod    # Database layer
    - indrajaal-obs-prod   # Observability layer
    - indrajaal-ex-app-1   # Application layer
  mesh:
    zenoh: enabled
    telemetry: verbose
    control_plane: active
  health:
    check_interval: 10s
    auto_heal: true
    escalation: 5-level-rca
```

## Enforcement

This rule is:
- **IMMUTABLE**: Cannot be disabled or bypassed
- **UNIVERSAL**: Applies to all agents, operators, and automated systems
- **VERIFIED**: Checked before and after every operation
- **LOGGED**: All violations recorded in Immutable Register

## Related Documents

- CLAUDE.md §1.0 Fundamental Axioms
- GEMINI.md §91.0 PROMETHEUS Verification
- docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md
- docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md
