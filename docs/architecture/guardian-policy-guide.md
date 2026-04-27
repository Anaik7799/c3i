# Guardian Policy Configuration Guide

**Module**: `lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_tools.gleam`
**TypeScript**: `.pi/extensions/c3i-bridge.ts` (via `GUARDIAN_MODE` env var)
**STAMP**: SC-PI-002, SC-SAFETY-001, SC-SIL4-006

---

## Quick Start

The Guardian is **PERMISSIVE by default** for development. No tool calls are blocked.

```bash
# Development (default) — all tools allowed
export GUARDIAN_MODE=permissive

# Staging — log violations but don't block
export GUARDIAN_MODE=audit_only

# Production — full HITL enforcement
export GUARDIAN_MODE=enforce_all
```

---

## Guardian Modes (5 levels)

| Mode | Env Value | Blocks? | Logs? | Use Case |
|------|-----------|---------|-------|----------|
| **Permissive** | `permissive` | No | No | Development, CI, automated agents |
| **Audit Only** | `audit_only` | No | Yes (warnings) | Staging, testing with audit trail |
| **Enforce Non-L0** | `enforce_non_l0` | L1-L7 gated tools | Yes | Normal operations (operator trusted at L0) |
| **Enforce All** | `enforce_all` | All gated tools | Yes | Production safety-critical |
| **Lockdown** | `lockdown` | Everything except read-only | Yes | Emergency, incident response |

---

## How Gates Work

Every tool in the federated registry has a `FractalGate`:

```
NoGate            — Always allowed in any mode
GuardianRequired  — Requires approval in enforce modes
ConsensusRequired — Requires 2oo3 voting in enforce modes
```

### Gate Assignment by Tool Type

| Tool Category | Gate | Layer | Example Tools |
|---------------|------|-------|---------------|
| Read operations | NoGate | L3 | `read`, `grep`, `find`, `plan_status` |
| Write operations | NoGate | L3 | `write`, `edit`, `plan_add` |
| Shell execution | NoGate | L4 | `bash`, `plan_update` |
| System health | GuardianRequired | L4 | `system_health`, `system_immune` |
| Verification | GuardianRequired | L0 | `system_verification`, `sil6_checklist` |
| Auto-evolution | GuardianRequired | L7 | `auto_evolve` |
| Email dispatch | NoGate | L7 | `send_email` |
| Knowledge ingest | NoGate | L3 | `knowledge_search`, `knowledge_ingest` |

---

## Gleam API

### Creating a Policy

```gleam
import cepaf_gleam/bridge/pi_tools

// Development — fully permissive
let policy = pi_tools.default_guardian_policy()
// GuardianPolicy(mode: Permissive, auto_allow_layers: [], audit_all: False, emergency_override: False)

// Production — full enforcement
let policy = pi_tools.production_guardian_policy()
// GuardianPolicy(mode: EnforceAll, auto_allow_layers: [], audit_all: True, emergency_override: False)

// Staging — audit without blocking
let policy = pi_tools.staging_guardian_policy()
// GuardianPolicy(mode: AuditOnly, auto_allow_layers: [], audit_all: True, emergency_override: False)

// Operator — trusted for L0
let policy = pi_tools.operator_guardian_policy()
// GuardianPolicy(mode: EnforceNonL0, auto_allow_layers: [0], audit_all: True, emergency_override: False)
```

### Custom Policy

```gleam
let policy = pi_tools.GuardianPolicy(
  mode: pi_tools.AuditOnly,
  auto_allow_layers: [3, 5],  // L3 and L5 tools always allowed
  audit_all: True,
  emergency_override: False,
)
```

### Checking a Tool

```gleam
let tool = pi_tools.FederatedTool(
  name: "system_health",
  source: pi_tools.C3iTool,
  description: "Check system health",
  fractal_layer: 4,
  gate: pi_tools.GuardianRequired,
)

let decision = pi_tools.check_gate(policy, tool)
// In Permissive mode: Allowed(reason: "permissive_mode")
// In EnforceAll mode: Blocked(reason: "guardian_required_enforced")

// Check if execution should proceed
case pi_tools.is_allowed(decision) {
  True -> dispatch_tool(tool)
  False -> {
    let msg = pi_tools.gate_decision_to_string(decision)
    log_guardian_block(msg)
  }
}
```

### Per-Layer Auto-Allow

```gleam
// Allow ALL tools at layers 3 and 5, enforce everything else
let policy = pi_tools.GuardianPolicy(
  mode: pi_tools.EnforceAll,
  auto_allow_layers: [3, 5],
  audit_all: True,
  emergency_override: False,
)

// A GuardianRequired tool at L3 → Allowed (layer override)
// A GuardianRequired tool at L4 → Blocked (no layer override)
```

### Emergency Override

```gleam
// Temporarily allow ALL operations (for incident response)
let policy = pi_tools.GuardianPolicy(
  ..policy,
  emergency_override: True,  // MUST be time-limited!
)

// ALL tools pass regardless of gate or mode
pi_tools.check_gate(policy, any_tool)
// → Allowed(reason: "emergency_override_active")
```

---

## TypeScript API (Pi Extensions)

Set `GUARDIAN_MODE` environment variable:

```bash
# In .env or shell
export GUARDIAN_MODE=permissive  # or: audit_only, enforce_non_l0, enforce_all, lockdown
```

The `.pi/extensions/c3i-bridge.ts` Guardian gate reads this on every tool call:

```typescript
// Reads GUARDIAN_MODE env var, defaults to "permissive"
const guardianMode = process.env.GUARDIAN_MODE || "permissive";
```

### Changing at Runtime

```bash
# From Pi agent:
! export GUARDIAN_MODE=audit_only

# Or via sa-plan-daemon:
sa-plan-daemon set-pref -k guardian_mode -v audit_only -C security
```

---

## Decision Matrix

| Mode | NoGate Tool | GuardianRequired Tool | ConsensusRequired Tool |
|------|-------------|----------------------|----------------------|
| Permissive | ALLOW | ALLOW | ALLOW |
| AuditOnly | ALLOW | ALLOW + LOG | ALLOW + LOG |
| EnforceNonL0 | ALLOW | ALLOW (L0) / BLOCK (L1+) | BLOCK |
| EnforceAll | ALLOW | BLOCK | BLOCK |
| Lockdown | ALLOW (L≤3) / BLOCK (L≥4) | BLOCK | BLOCK |

---

## Migration from Old Behavior

### Before (v22.10.0)
- Guardian was hardcoded to either always-allow (stub) or always-deny
- No configurable modes
- No audit trail for allowed operations
- No per-layer overrides

### After (v22.10.1)
- 5 configurable modes via `GuardianMode` type
- `GUARDIAN_MODE` env var for TypeScript side
- Per-layer auto-allow via `auto_allow_layers`
- Emergency override for incident response
- Audit-only mode for staging
- `GateDecision` type with reason string for logging

### To upgrade existing code:

```gleam
// OLD: Direct gate check
case tool.gate {
  GuardianRequired -> block()
  _ -> allow()
}

// NEW: Policy-based check
let policy = pi_tools.default_guardian_policy()  // or from config
let decision = pi_tools.check_gate(policy, tool)
case pi_tools.is_allowed(decision) {
  True -> allow()
  False -> block()
}
```

---

## STAMP Alignment

| Constraint | How Satisfied |
|------------|--------------|
| SC-PI-002 | GuardianRequired gate on L0 tools |
| SC-SAFETY-001 | EnforceAll mode for production |
| SC-SIL4-006 | ConsensusRequired gate for 2oo3 voting |
| SC-DMS-001 | Emergency override for dead-man's switch |
| SC-TRUTH-001 | GateDecision includes reason string |
| SC-LOG-001 | AuditOnly mode logs all decisions |

---

**Version**: v22.10.1-PI-SYMBIOSIS | **Date**: 2026-04-20
