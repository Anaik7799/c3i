# Allium Specification Checklist

**Use this checklist to verify an `.allium` file is comprehensive.**
Template: `specs/allium/TEMPLATE.allium`

## 21-Section Completeness Check

| # | Section | Required | Check |
|---|---------|----------|-------|
| 1 | **External Entities** | YES | All external systems referenced |
| 2 | **Enumerations** | YES | All domain value sets defined |
| 3 | **Value Types** | YES | Immutable embedded data structures |
| 4 | **Config** | YES | All thresholds, timeouts, limits parameterized |
| 5 | **Entities** | YES | All domain objects with identity |
| 6 | **Contracts** | YES | All module boundary APIs |
| 7 | **Actors** | YES | All parties at system boundaries |
| 8 | **Rules** | YES | All event-driven behavior (when/requires/ensures) |
| 9 | **Invariants** | YES | All always-true properties (pure, no side effects) |
| 10 | **Surfaces** | YES | All actor-facing boundaries (exposes/provides) |
| 11 | **Defaults** | if needed | Unconditional entity instances |
| 12 | **Deferred Specs** | if needed | Logic defined in other modules |
| 13 | **Open Questions** | RECOMMENDED | Unresolved design decisions |
| 14 | **Formal Verification** | RECOMMENDED | Agda, Quint, TLA+ proof obligations |
| 15 | **STAMP Constraints** | YES (C3I) | Cross-reference SC-* to rules/invariants |
| 16 | **AOR Rules** | YES (C3I) | Cross-reference AOR-* to rules/contracts |
| 17 | **FMEA** | RECOMMENDED | Failure modes with RPN scoring |
| 18 | **UI Specification** | if applicable | Tabs, palette, controls, dark cockpit |
| 19 | **Testing Specification** | RECOMMENDED | Coverage gates, BDD levels, math gates |
| 20 | **Mathematical Structures** | RECOMMENDED | All algorithms, formulas, metrics |
| 21 | **Knowledge Map** | RECOMMENDED | Journal, doc, source code references |

## Per-Entity Checklist

For every `entity` declaration, verify:

- [ ] **Fields**: All persistent data fields declared with types
- [ ] **Relationships**: Links to other entities via `with backref`
- [ ] **Projections**: Filtered views of relationships (where clause)
- [ ] **Derived values**: Computed properties (boolean or expression)
- [ ] **Transition graph**: If entity has lifecycle states
- [ ] **Entity invariant**: If there are per-instance constraints
- [ ] **STAMP mapping**: Which SC-* constraint this entity serves
- [ ] **Code mapping**: Which Rust/Gleam/F# struct this maps to

## Per-Rule Checklist

For every `rule` declaration, verify:

- [ ] **when**: Trigger defined (state transition, temporal, creation, action)
- [ ] **let**: Local bindings for complex expressions
- [ ] **requires**: All preconditions stated
- [ ] **ensures**: All postconditions stated (state change, creation, event)
- [ ] **@guidance**: Implementation notes for developers
- [ ] **STAMP mapping**: Which SC-* or AOR-* this rule enforces
- [ ] **Code mapping**: Which function in which file implements this
- [ ] **GRL rule**: If rule maps to a GRL salience-based rule

## Per-Contract Checklist

For every `contract` declaration, verify:

- [ ] **Methods**: All public API methods with typed signatures
- [ ] **@invariant**: Machine-checkable or prose invariants
- [ ] **@guidance**: Implementation guidance
- [ ] **Surface reference**: At least one surface demands or fulfils it
- [ ] **Code mapping**: Which Rust module/trait implements this

## Per-Invariant Checklist

- [ ] **Pure**: No `now`, no side effects, no mutations
- [ ] **Universal**: Uses `for` over entity collections
- [ ] **Testable**: Can be verified as assertion in tests
- [ ] **STAMP mapping**: Which SC-* this invariant proves

## Per-Surface Checklist

- [ ] **facing**: Actor declared
- [ ] **context**: Entity binding with optional predicate
- [ ] **exposes**: Visible data fields listed
- [ ] **provides**: Triggerable actions with guards
- [ ] **contracts**: demands/fulfils references
- [ ] **timeout**: Temporal triggers if applicable
- [ ] **@guarantee**: Surface-level properties

## Quality Gates

| Gate | Threshold | Check |
|------|-----------|-------|
| Every entity has ≥1 rule that creates it | 100% | `Entity.created(...)` in some ensures |
| Every enum value appears in ≥1 rule | 100% | No dead enum variants |
| Every transition edge has a witnessing rule | 100% | Rule triggers state change |
| Every contract method has ≥1 surface reference | 100% | No unused contracts |
| Every config param used in ≥1 rule/invariant | 100% | No dead config |
| Every invariant is pure | 100% | No `now`, `.add()`, `.remove()`, `.created()` |
| Open questions have owner + target date | Recommended | Prevents stale questions |

## C3I-Specific Additions

| Item | Required | Check |
|------|----------|-------|
| 16-container genome complete | YES | All 16 in entity Genome |
| All 8 fractal layers (L0-L7) covered | YES | Every layer has ≥1 entity/rule |
| OODA cycle (Observe/Orient/Decide/Act) rules | YES | 4+ rules with phase budgets |
| FPPS consensus (3/5 or 2/3) invariant | YES | Quorum voting specified |
| Rule engine GRL rules listed | YES | 24 implemented + 35 planned (salience annotated) |
| LLM escalation path defined | YES | Rule for uncertain decisions |
| Mathematical structures enumerated | RECOMMENDED | All 33 with formulas |
| Source code cross-references | RECOMMENDED | Rust + Gleam + F# file paths |
| Journal cross-references | RECOMMENDED | Relevant journal entries linked |

## Extended Sections Checklist (§22-§25)

| # | Section | Required | Check |
|---|---------|----------|-------|
| 22 | **UI Testing Specification** | YES (C3I) | Rust 7-layer pyramid, Gleam C1-C8, regression approaches, tab coverage matrix |
| 23 | **Implementation Notes** | RECOMMENDED | Key algorithms with caching/perf notes, known bugs |
| 24 | **Design Principles & Patterns** | YES | Rule-first/LLM-escalation, fail-safe, defense-in-depth, railway error handling, checkpoint-before-change, publish-on-transition, hysteresis wrapping, adaptive parallelism, fractal separation |
| 25 | **Anti-Patterns** | YES | Dead code modules, hardcoded DAG, stubbed guardian, in-memory checkpoints, single-drift handling, unstructured LLM response |
| 26 | **Journal Template** | RECOMMENDED | 13-section mandatory template per SC-JOURNAL |

## Anti-Pattern Checklist

For each module, verify NONE of these anti-patterns apply:

- [ ] No dead code modules (every .rs file called by at least one other)
- [ ] No hardcoded topology (use config-driven genome)
- [ ] No re-parsing on every call (cache expensive computations)
- [ ] No stubbed safety gates (Guardian must fail-closed, not always-true)
- [ ] No in-memory-only checkpoints (persist to SQLite)
- [ ] No single-item handling when multiple possible (sort by priority)
- [ ] No unstructured external responses (parse LLM output as JSON)
- [ ] No point-in-time-only health (track trends via hysteresis)

## Validation Commands

```bash
# If allium-cli installed:
allium validate specs/allium/ignition.allium

# Via Claude Code skill:
/allium:weed native/ignition_daemon/src/  # Check Rust drift
/allium:weed lib/cepaf_gleam/src/         # Check Gleam drift
/allium:propagate                          # Generate tests from spec
```
