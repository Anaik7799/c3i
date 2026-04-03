---
description: Code evolution — autonomous mutation with Guardian safety, shadow testing, OODA cycles via MCP
allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__zenoh_pub, mcp__sentinel-zenoh__zenoh_sub, mcp__sentinel-zenoh__test_fsharp_start, mcp__sentinel-zenoh__test_fsharp_status, mcp__sentinel-zenoh__test_fsharp_results, mcp__sentinel-zenoh__checkpoint_op, Read, Grep, Glob, Bash(mix:*), Bash(git:*)
argument-hint: [propose|execute|shadow|rollback|status] [change-description]
---

# Code Evolution Engine (SC-GDE-001, SC-OODA-001, SC-BIO-EXT-001 to SC-BIO-EXT-009)

Autonomous code evolution with Guardian validation, shadow testing, and biomorphic OODA cycles.

## Mathematical Foundation

**Evolution Algebra** $\mathcal{E}$:
$$\text{Evolve}: S_t \times \Delta \to S_{t+1}$$
where $\Delta$ = mutation, $S_t$ = system state at time $t$

**Safety Predicate** (must hold $\forall t$):
$$\text{Safe}(\Delta) \iff \text{Compiles}(S_t \oplus \Delta) \wedge \text{Tests}(S_t \oplus \Delta) \wedge \text{Guardian}(\Delta) = \text{approve}$$

**OODA Cycle** (SC-OODA-001: < 30ms):
$$\text{OODA}(\Delta) = \text{Act}(\text{Decide}(\text{Orient}(\text{Observe}(S_t, \Delta))))$$

**Fitness Function** $F: \Delta \to [0, 1]$:
$$F(\Delta) = w_c \cdot \text{Compile} + w_t \cdot \text{TestPass} + w_q \cdot \text{Quality} + w_s \cdot \text{Safety}$$
where $w_c = 0.3, w_t = 0.3, w_q = 0.2, w_s = 0.2$

**Shadow Testing Theorem**:
$$\text{Promote}(\Delta) \iff F(\Delta) \geq 0.8 \wedge \text{Shadow}(\Delta, S_t) = \text{pass}$$

## Usage
```
/evolution propose "refactor sentinel health scoring"  # Propose with safety analysis
/evolution execute "add circuit breaker to FFI"        # Execute with full safety pipeline
/evolution shadow                                       # Run shadow test on staged changes
/evolution rollback                                     # Rollback last evolution
/evolution status                                       # Evolution pipeline status
```

## Commands

### Propose Mutation (SC-GDE-001: Guardian validation required)
1. Parse proposal: $ARGUMENTS
2. **OBSERVE**: Check current state
   - `sentinel(action: "health")` — baseline health
   - `zenoh_query(action: "metrics")` — current performance
3. **ORIENT**: Analyze impact
   - Grep for affected modules and callers
   - Calculate 4-layer impact score (SC-CHG-002)
4. **DECIDE**: Guardian gate
   - Check $\Psi_{0-5}$ (constitutional invariants)
   - If impact > 20: require architecture review
   - If impact > 30: require Guardian explicit approval
5. **ACT**: Generate evolution plan
   - Create git checkpoint: `git stash` or branch
   - List files to modify, functions to change
   - Estimate fitness score $F(\Delta)$

### Execute Mutation (Full Safety Pipeline)
1. Create checkpoint: `checkpoint_op(action: "quick")`
2. Apply code changes (Write/Edit tools)
3. Compile: `NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" mix compile --warnings-as-errors --jobs 16`
4. Test: `SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" MIX_ENV=test mix test` (affected tests)
5. F# regression: `test_fsharp_start(levels: [1,2])` if F# files changed
6. Quality: `mix format --check-formatted && mix credo --strict`
7. Verify health: `sentinel(action: "health")` — must not degrade
8. Calculate fitness: $F(\Delta)$
9. If $F(\Delta) < 0.8$: **AUTO-ROLLBACK**
10. Publish result: `zenoh_pub(key: "indrajaal/evolution/result", payload: "{fitness}")`

### Shadow Testing (SC-GDE-002: Mandatory)
1. Create shadow branch: `git checkout -b shadow-{timestamp}`
2. Apply changes in isolation
3. Run full test suite against shadow
4. Compare metrics: shadow vs. production baseline
5. If shadow fails: `git checkout -` (no impact on main)
6. Report: shadow fitness vs. threshold

### Rollback (SC-FUNC-003: Rollback path MUST exist)
1. Identify last checkpoint: `git log --oneline -5`
2. Revert: `git revert HEAD --no-edit`
3. Verify: `mix compile`
4. Health check: `sentinel(action: "health")`
5. Publish: `zenoh_pub(key: "indrajaal/evolution/rollback", payload: "{reason}")`

## SIL-6 Evolution Safety

| Phase | Gate | Constraint |
|-------|------|-----------|
| Pre-mutation | Guardian validate | SC-CONST-001 |
| Mutation | Atomic change (compile gate) | SC-FUNC-001 |
| Post-mutation | Shadow test + health | SC-GDE-002 |
| Promotion | Fitness $\geq 0.8$ | SC-OODA-002 |
| Rollback | Auto within 30s on failure | SC-EMR-060 |
| Audit | Immutable register record | SC-REG-001 |

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-GDE-001 | Guardian validation required for evolution |
| SC-GDE-002 | Shadow testing mandatory |
| SC-OODA-001 | OODA cycle < 30ms |
| SC-FUNC-001 | System MUST compile at all times |
| SC-FUNC-003 | Rollback path MUST exist |
| SC-REG-001 | All mutations via immutable register |
| SC-BIO-EXT-003 | Regenerative healing from SQLite/DuckDB |
