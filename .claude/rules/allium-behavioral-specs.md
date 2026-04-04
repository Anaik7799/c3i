# Allium Behavioral Specification Protocol (SC-ALLIUM)

## Overview

**Allium v3** (2,215 lines, 26 sections, 24 implemented GRL rules + 35 planned) is the behavioral specification language for the C3I system. All domain logic, container lifecycle, OODA decisions, health orchestration, and rule engine behavior MUST have corresponding `.allium` specifications.

**Official skill**: `.agents/skills/allium/` (installed via `npx skills add juxt/allium`)
**Spec**: `specs/allium/ignition.allium` | **Template**: `specs/allium/TEMPLATE.allium` | **Checklist**: `specs/allium/CHECKLIST.md`

Allium captures **intent** (what the system SHOULD do) separately from **implementation** (what the code DOES). When they diverge, that divergence is information — not a bug to silently fix.

**Spec location**: `specs/allium/*.allium`
**Language reference**: https://github.com/juxt/allium/blob/main/references/language-reference.md

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ALLIUM-001 | Every Rust ignition module MUST have corresponding Allium entities/rules | HIGH |
| SC-ALLIUM-002 | Allium specs MUST use `-- allium: 3` header | CRITICAL |
| SC-ALLIUM-003 | Entity names MUST match Rust struct names (PascalCase) | HIGH |
| SC-ALLIUM-004 | Config values MUST match Rust `types.rs` constants | HIGH |
| SC-ALLIUM-005 | Transition graphs MUST match Rust enum state machines | CRITICAL |
| SC-ALLIUM-006 | Invariants MUST be pure (no `now`, no side effects) | CRITICAL |
| SC-ALLIUM-007 | Contracts MUST map to Rust trait boundaries | HIGH |
| SC-ALLIUM-008 | Open questions MUST be resolved before implementation | MEDIUM |

## File Structure

```
specs/allium/
  ignition.allium       -- 16-container genome, boot, OODA, rules, health, apoptosis
  (future) ui.allium    -- Lustre/Wisp/TUI behavioral spec
  (future) zenoh.allium -- Mesh telemetry behavioral spec
```

## Key Allium ↔ Rust Mappings

| Allium Construct | Rust Equivalent | Module |
|-----------------|-----------------|--------|
| `entity Container` | `struct ContainerRow` / `GenomeEntry` | types.rs |
| `entity BootSequence` | Boot flow in `launch.rs` | launch.rs |
| `entity OodaCycle` | `struct OodaCycle` | ooda_supervisor.rs |
| `entity GrlRule` | GRL string in `rule_engine.rs` | rule_engine.rs |
| `contract PodmanOperations` | Functions in `podman.rs` | podman.rs |
| `contract HealthOrchestra` | `check_consensus()` | health_orchestra.rs |
| `contract RuleEngine` | `evaluate_decision()` | rule_engine.rs |
| `contract LLMAdvisor` | `query_llm_advisor()` | openrouter.rs |
| `contract GuardianGate` | `validate_with_guardian()` | ooda_supervisor.rs |
| `surface OperatorDashboard` | `tui.rs` 12-tab dashboard | tui.rs |
| `surface AiAdvisorInterface` | OODA + rule + LLM integration | ooda_supervisor.rs |
| `surface ZenohMeshBus` | `zenoh_telemetry.rs` | zenoh_telemetry.rs |
| `invariant QuorumMaintained` | 2oo3 voting in health.rs | health.rs |
| `invariant OodaCycleSLA` | 100ms budget in ooda_supervisor.rs | ooda_supervisor.rs |

## Workflow

### When Adding New Features
1. Write the Allium spec FIRST (entities, rules, invariants)
2. Implement the Rust code
3. Run `weed` to detect divergence between spec and code
4. Resolve divergence (update spec or fix code)

### When Modifying Existing Features
1. Check `specs/allium/ignition.allium` for the relevant rule/entity
2. Update the spec if behavior changes
3. Implement the code change
4. Verify invariants still hold

### Allium Agents (if installed)
- `tend` — Grow specs from requirements
- `weed` — Detect spec ↔ code drift

## Allium Syntax Quick Reference

```allium
-- Entity with transitions
entity Order {
    status: pending | confirmed | shipped
    transitions status {
        pending -> confirmed
        confirmed -> shipped
        terminal: shipped
    }
}

-- Rule with preconditions and postconditions
rule ProcessOrder {
    when: order: Order.status transitions_to confirmed
    requires: exists order.payment
    ensures: order.shipped_at = now
    @guidance -- Implementation notes
}

-- Config block
config {
    timeout_ms: Integer = 5000
}

-- Contract
contract PaymentGateway {
    charge: (amount: Decimal) -> Boolean
    @invariant Idempotent -- Same charge ID = no-op
}

-- Invariant (must be pure)
invariant PositiveBalance {
    for a in Accounts: a.balance >= 0
}
```

## Integration with rust-rule-engine

GRL rules in `rule_engine.rs` correspond to Allium rules with salience:
- Allium `rule GrlEmergencyStop` → GRL `rule "Emergency Stop" salience 100`
- The Allium spec is the **source of truth** for rule behavior
- The GRL string literal is the **implementation**
- Drift between them should be caught by `weed`

## Integration with OpenRouter LLM

The `contract LLMAdvisor` in Allium defines the behavioral boundary:
- LLM is **advisory only** (never auto-executes P0 actions)
- Called only when rules return `escalate_to_llm`
- Response within `config.openrouter_timeout_secs`
- The `@guidance` annotation captures when/why to call LLM
