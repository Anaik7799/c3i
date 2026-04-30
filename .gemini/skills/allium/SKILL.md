---
name: allium
description: You are working with **Allium v3** behavioral specifications for the C3I SIL-6 Biomorphic Mesh.
---

# Allium Behavioral Specification Skill

**Official skill installed at**: `.agents/skills/allium/` (via `npx skills add juxt/allium`)
**Project spec**: `specs/allium/ignition.allium` (1,923 lines, 26 sections)
**Template**: `specs/allium/TEMPLATE.allium` (316 lines, 26-section standard)
**Checklist**: `specs/allium/CHECKLIST.md` (144 lines, per-construct verification)
**User Guide**: `docs/allium-user-guide.md` (full workflow + 33 math structures) AND `docs/user_guides/PROMPT_COMMANDS_USER_GUIDE.md` (for user journeys and scenarios).
**Journal**: `docs/journal/20260404-allium-comprehensive-system-spec.md` (13-section entry)

## Usage
```
/allium              — Examine project, offer distillation or spec building
/allium:tend <req>   — Grow specs from requirements (delegates to Tend agent)
/allium:weed <path>  — Detect spec ↔ code drift (delegates to Weed agent)
/allium:distill      — Extract specs from existing code
/allium:propagate    — Generate tests from specifications
/allium:elicit       — Structured conversation to build spec from scratch
```

## When to Invoke
- When working with `.allium` files in `specs/allium/`
- When adding new features that need behavioral specification
- When detecting drift between spec and implementation
- When generating tests from behavioral contracts

## Skill Instructions

You are working with **Allium v3** behavioral specifications for the C3I SIL-6 Biomorphic Mesh.

### Project Allium Files
- `specs/allium/ignition.allium` — Main spec (1,189 lines): 16-container genome, 7-tier boot, OODA supervisor, rule engine (rust-rule-engine v1.20.1), OpenRouter LLM advisor, FMEA failure modes, UI dashboard, testing collateral, formal verification (Agda/Quint/TLA+)
- `specs/allium/ha_seamless_upgrade.allium` — HA Active/Standby Leader Election, Graceful Drain, Deadlock freedom
- `specs/allium/openclaw_advanced.allium` — Isolated Cortex Sessions, Semantic Vector Memory, Subagent Routing
- `specs/allium/openclaw_perception_acp.allium` — Continuous Voice Streams, Shared A2UI CRDT Hologram, Agent Control Protocol (ACP) Boundaries

### Allium v3 Syntax Quick Reference

```allium
-- allium: 3
-- Entity with state machine
entity Container {
    status: running | stopped | failed
    transitions status {
        stopped -> running
        running -> stopped
        running -> failed
        failed -> stopped
        terminal: -- none
    }
}

-- Rule with trigger, preconditions, postconditions
rule RestartFailed {
    when: c: Container.status transitions_to failed
    requires: c.criticality = p0_critical
    ensures: c.status = running
    @guidance -- Operator hint: check logs first
}

-- Config block
config {
    timeout_ms: Integer = 5000
    max_retries: Integer = 3
}

-- Contract (module boundary)
contract HealthCheck {
    check: (container: String) -> Boolean
    @invariant Deterministic -- Same input → same output
}

-- Invariant (must be pure: no now, no side effects)
invariant AlwaysPositive {
    for a in Accounts: a.balance >= 0
}

-- Surface (actor-facing boundary)
surface Dashboard {
    facing viewer: Operator
    context boot: BootSequence
    exposes: boot.phase, boot.progress
    provides: EmergencyStop(reason: String)
    contracts: demands HealthCheck
    @guarantee IdempotentOperations
}
```

### Naming Conventions
- **PascalCase**: entities, variants, rules, actors, surfaces, contracts, invariants
- **snake_case**: fields, config parameters, derived values, enum literals

### Key Allium ↔ C3I Mappings
| Allium | Rust | Gleam |
|--------|------|-------|
| entity Container | `types.rs::GenomeEntry` | `ui/domain.gleam::Page` |
| rule OodaDecide | `ooda_supervisor.rs::decide()` | n/a (Rust-only) |
| contract RuleEngine | `rule_engine.rs::evaluate_decision()` | n/a |
| contract LLMAdvisor | `openrouter.rs::query_llm_advisor()` | n/a |
| surface OperatorDashboard | `tui.rs` (12-tab Ratatui) | `ui/tui/split_screen.gleam` |
| invariant QuorumMaintained | `health.rs::check_quorum()` | `verification/probes.gleam::verify_2oo3()` |

### Tend Agent Workflow
When user says `/allium:tend <requirement>`:
1. Read `specs/allium/ignition.allium`
2. Identify which entities/rules/contracts are affected
3. Write or modify the Allium spec to capture the new behavior
4. Validate: every rule has `when`, `requires`, `ensures`
5. Check: new entities have transition graphs if stateful
6. Verify: contracts referenced by surfaces exist

### Weed Agent Workflow
When user says `/allium:weed <path>`:
1. Read the Allium spec for the domain
2. Read the Rust/Gleam source files at `<path>`
3. Compare: entities vs structs, rules vs functions, invariants vs assertions
4. Report: ALIGNED (spec matches code), DRIFTED (minor differences), DIVERGED (significant mismatch)
5. For each divergence: "Is the code wrong, or is the spec aspirational?"

### Formal Verification Integration
The spec includes proof obligations for:
- **Agda**: Type-level proofs (totality, monotonicity, exhaustiveness)
- **Quint**: State machine bounded model checking
- **TLA+**: Temporal logic for distributed consensus and liveness
