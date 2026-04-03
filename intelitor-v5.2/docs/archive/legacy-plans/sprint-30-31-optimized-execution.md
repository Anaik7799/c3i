# Sprint 30-31 Token-Optimized Execution Plan

## Execution Principles

### Token Efficiency
- **Batch reads**: Read related files in single parallel call
- **Minimal context**: Only read files directly needed for current task
- **Reuse patterns**: Copy existing test patterns, don't reinvent
- **Concise output**: No verbose explanations, just code

### API Efficiency
- **Parallel agents**: Max 5 concurrent for independent tasks
- **Sequential chains**: Dependencies execute in order
- **Haiku workers**: Use `model: "haiku"` for simple tasks
- **Batch commits**: Group related changes

---

## Phase 1: Coverage Gap Analysis (5 min)

### Missing Test Files
| Source File | Test Status | Priority |
|-------------|-------------|----------|
| `bridge/holon_adapter.ex` | MISSING | P1 |
| `feature_flags.ex` | MISSING | P2 |
| `immune/antibody_supervisor.ex` | MISSING | P1 |
| `reed_solomon.ex` | MISSING | P1 |
| `bio/types.ex` | N/A (types only) | - |

### Execution Pattern
```bash
# Single command - no agent needed
grep -c "def " lib/indrajaal/cockpit/prajna/{bridge/holon_adapter,feature_flags,immune/antibody_supervisor,reed_solomon}.ex
```

---

## Phase 2: P1 Test Generation (Parallel)

### Task 2.1: HolonAdapter Tests
**Context**: `Read bridge/holon_adapter.ex` only
**Pattern**: Copy from `sentinel_bridge_test.exs`
**Output**: `test/indrajaal/cockpit/prajna/bridge/holon_adapter_test.exs`

### Task 2.2: AntibodySupervisor Tests
**Context**: `Read immune/antibody_supervisor.ex` + `immune/antibody_test.exs`
**Pattern**: Supervisor child spec tests
**Output**: `test/indrajaal/cockpit/prajna/immune/antibody_supervisor_test.exs`

### Task 2.3: ReedSolomon Tests
**Context**: `Read reed_solomon.ex` only
**Pattern**: Property tests for encode/decode
**Output**: `test/indrajaal/cockpit/prajna/reed_solomon_test.exs`

### Parallel Execution
```elixir
# Launch 3 agents simultaneously
Task(2.1, model: "haiku", run_in_background: true)
Task(2.2, model: "haiku", run_in_background: true)
Task(2.3, model: "haiku", run_in_background: true)
```

---

## Phase 3: Property Test Expansion

### Modules Needing Property Tests
| Module | Current Props | Target | Gap |
|--------|---------------|--------|-----|
| Config | 0 | 5 | +5 |
| DarkCockpit | 0 | 3 | +3 |
| TelemetryDisplay | 0 | 3 | +3 |
| Orchestrator | 0 | 4 | +4 |

### Generator Reuse Pattern
```elixir
# Use existing PrajnaGenerators - NO new generators
alias Indrajaal.Test.PrajnaGenerators, as: PG

property "config values within bounds" do
  forall config <- PG.config_gen() do
    Config.valid?(config)
  end
end
```

---

## Phase 4: Integration Tests

### Critical Paths (Sequential)
1. **Guardian → Prajna → Sentinel** flow
2. **ImmutableState → DuckDB → Verification** chain
3. **OODA cycle** end-to-end

### Test Pattern (Minimal)
```elixir
describe "integration" do
  @tag :integration
  test "guardian validates prajna command" do
    assert {:ok, _} = GuardianIntegration.submit_proposal(%{cmd: :test})
  end
end
```

---

## Phase 5: Quality Gates

### Single Command Verification
```bash
# All gates in one command
MIX_ENV=test mix do compile --warnings-as-errors, format --check-formatted, credo --strict, test test/indrajaal/cockpit/prajna/
```

### Expected Output
```
Compiled 773 files (0 warnings)
All files formatted
5 issues (readability only)
836 tests, 75 properties, 0 failures
```

---

## Execution Matrix

| Phase | Tasks | Agents | Model | Time |
|-------|-------|--------|-------|------|
| 1 | Gap Analysis | 1 | - | 2m |
| 2 | P1 Tests | 3 | haiku | 5m |
| 3 | Properties | 4 | haiku | 8m |
| 4 | Integration | 2 | sonnet | 5m |
| 5 | Quality | 1 | - | 3m |

**Total: ~23 min, ~15 API calls**

---

## Token Budget

| Operation | Est. Tokens |
|-----------|-------------|
| Context reads | 8K |
| Test generation | 12K |
| Verification | 3K |
| **Total** | **~23K** |

---

## Quick Reference Commands

```bash
# Run all Prajna tests
test test/indrajaal/cockpit/prajna/ --trace

# Run with coverage
test-cover test/indrajaal/cockpit/prajna/

# Check single module
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/MODULE_test.exs

# Property tests only
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ --only property
```

---

## STAMP Constraint Checklist

- [ ] SC-PRAJNA-001: Guardian pre-approval
- [ ] SC-PRAJNA-002: Founder validation
- [ ] SC-PRAJNA-003: Immutable Register
- [ ] SC-PRAJNA-004: Sentinel sync
- [ ] SC-PRAJNA-005: PROMETHEUS tokens
- [ ] SC-PRAJNA-006: Constitutional check
- [ ] SC-PRAJNA-007: Two-step commit
- [ ] SC-SIL4-001: Timeout ≤2s
- [ ] SC-SIL4-002: Circuit breaker
- [ ] SC-SIL4-003: Dual channel
- [ ] SC-SIL4-004: DC >99%
- [ ] SC-PROP-023: PC. prefix
- [ ] SC-PROP-024: SD. prefix

---

## Completion Criteria

```
✅ 100% source files have corresponding tests
✅ 75+ property tests
✅ 850+ unit tests
✅ 0 compilation warnings
✅ All STAMP constraints verified
✅ Quality gates pass
```
