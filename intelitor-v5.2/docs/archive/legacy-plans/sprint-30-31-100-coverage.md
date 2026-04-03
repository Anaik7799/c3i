# Sprint 30-31: 100% Prajna Test Coverage Plan

**Version**: 1.0.0 | **Created**: 2026-01-02 | **Status**: ACTIVE
**Optimization**: Token-efficient, API-efficient execution

## Current State

| Metric | Value |
|--------|-------|
| Modules | 33 |
| Test Files | 35 |
| With PropCheck | 28 |
| Without PropCheck | 7 |
| Current Tests | ~907 |
| Current Properties | ~110 |

## Gap Analysis

### P0: Missing PropCheck (7 files)
```
ai_copilot_test.exs
neuro/spine_test.exs
bio/simplex_test.exs
supervisor_test.exs
domain_test.exs
smart_metrics_test.exs
config_sil_profiles_test.exs
```

### P1: Thin Tests (<100 lines)
```
neuro/spine_test.exs (44 lines)
bio/simplex_test.exs (58 lines)
```

### P2: Medium Tests (100-250 lines) - Need Property Expansion
```
bridge/holon_adapter_test.exs (123 lines)
immune/antibody_supervisor_test.exs (161 lines)
reed_solomon_test.exs (207 lines)
messaging_test.exs (231 lines)
circuit_breaker_test.exs (235 lines)
```

## Execution Strategy

### Token Efficiency Rules
1. **Batch reads**: Read max 3 files per tool call
2. **Parallel agents**: Use 5 haiku workers per phase
3. **Template reuse**: Generate tests from pattern templates
4. **Incremental verify**: Test after each 5-file batch

### API Efficiency Rules
1. **Agent budget**: Max 15 concurrent agents
2. **Model selection**: Haiku for generation, Sonnet for review
3. **Context limit**: Compact at 70% usage
4. **Batch commits**: Stage 10 files, commit once

## Phase 1: PropCheck Addition (P0)

**Goal**: Add property tests to 7 files missing PropCheck
**Agents**: 3 haiku workers (parallel)
**Est. Tokens**: 15K per file

### Tasks
| ID | File | Properties to Add | Priority |
|----|------|-------------------|----------|
| 1.1 | ai_copilot_test.exs | 5 (recommendations, analysis) | HIGH |
| 1.2 | supervisor_test.exs | 4 (child management) | HIGH |
| 1.3 | smart_metrics_test.exs | 5 (metrics aggregation) | HIGH |
| 1.4 | domain_test.exs | 4 (domain state) | MEDIUM |
| 1.5 | config_sil_profiles_test.exs | 3 (profile validation) | MEDIUM |
| 1.6 | neuro/spine_test.exs | 3 (spine routing) | LOW |
| 1.7 | bio/simplex_test.exs | 3 (simplex comms) | LOW |

### Template (Copy-Paste Efficiency)
```elixir
# Add after existing imports:
use PropCheck
alias PropCheck.BasicTypes, as: PC

# Add property section:
describe "property tests" do
  property "PROPERTY_NAME" do
    forall INPUT <- PC.GENERATOR() do
      ASSERTION
    end
  end
end
```

## Phase 2: Thin Test Expansion (P1)

**Goal**: Expand 2 thin test files to 150+ lines each
**Agents**: 2 haiku workers
**Est. Tokens**: 20K per file

### Tasks
| ID | File | Tests to Add | Properties |
|----|------|--------------|------------|
| 2.1 | neuro/spine_test.exs | 8 unit + 3 prop | routing, failover |
| 2.2 | bio/simplex_test.exs | 8 unit + 3 prop | channels, sync |

## Phase 3: Medium Test Enhancement (P2)

**Goal**: Add 3-5 property tests to each medium file
**Agents**: 5 haiku workers (parallel)
**Est. Tokens**: 10K per file

### Tasks
| ID | File | Properties to Add |
|----|------|-------------------|
| 3.1 | holon_adapter_test.exs | 3 (adaptation) |
| 3.2 | antibody_supervisor_test.exs | 3 (lifecycle) |
| 3.3 | reed_solomon_test.exs | 3 (encoding) |
| 3.4 | messaging_test.exs | 4 (delivery) |
| 3.5 | circuit_breaker_test.exs | 4 (state machine) |

## Phase 4: Integration Test Audit

**Goal**: Verify critical path coverage
**Agents**: 1 sonnet reviewer
**Est. Tokens**: 5K

### Critical Paths to Verify
1. Guardian → Orchestrator → Command flow
2. Sentinel → SmartMetrics → Advisory flow
3. ImmutableState → DuckDB → Chain flow
4. Config → Profile → Validation flow

## Phase 5: Quality Gate

**Goal**: Pass all gates before merge
**Agents**: 1 sonnet verifier

### Gates
```bash
# G1: Compilation
mix compile --warnings-as-errors

# G2: Format
mix format --check-formatted

# G3: Credo
mix credo --strict

# G4: Tests
mix test test/indrajaal/cockpit/prajna/ --cover

# G5: Coverage
# Target: >95% line coverage
```

## Execution Commands

### Quick Start (Single Command)
```bash
# Run all Prajna tests with coverage
SKIP_ZENOH_NIF=0 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ --cover
```

### Per-Phase Verification
```bash
# Phase 1 verify
mix test test/indrajaal/cockpit/prajna/ai_copilot_test.exs \
         test/indrajaal/cockpit/prajna/supervisor_test.exs \
         test/indrajaal/cockpit/prajna/smart_metrics_test.exs

# Phase 2 verify
mix test test/indrajaal/cockpit/prajna/neuro/ \
         test/indrajaal/cockpit/prajna/bio/simplex_test.exs

# Phase 3 verify
mix test test/indrajaal/cockpit/prajna/bridge/ \
         test/indrajaal/cockpit/prajna/immune/
```

## Agent Deployment Pattern

```
Session Start
├── Deploy Context Monitor (haiku, background)
├── Phase 1: PropCheck Addition
│   ├── Worker 1 (haiku): ai_copilot, supervisor
│   ├── Worker 2 (haiku): smart_metrics, domain
│   └── Worker 3 (haiku): config_sil, spine, simplex
├── Verify Phase 1 (sonnet)
├── Phase 2: Thin Expansion
│   ├── Worker 1 (haiku): spine_test.exs
│   └── Worker 2 (haiku): simplex_test.exs
├── Verify Phase 2 (sonnet)
├── Phase 3: Medium Enhancement
│   ├── Worker 1-5 (haiku): One file each
├── Verify Phase 3 (sonnet)
├── Phase 4: Integration Audit (sonnet)
└── Phase 5: Quality Gate (sonnet)
```

## Success Criteria

| Metric | Target | Current |
|--------|--------|---------|
| Test Files with PropCheck | 35/35 (100%) | 28/35 (80%) |
| Total Properties | 150+ | ~110 |
| Total Tests | 1000+ | ~907 |
| Line Coverage | >95% | TBD |
| Quality Gates | 5/5 | TBD |

## STAMP Compliance

- SC-TDG-001: All tests use PropCheck + ExUnitProperties
- SC-COV-001: 100% static coverage
- SC-COV-002: 100% runtime coverage
- SC-PRAJNA-*: All Prajna constraints verified

## Rollback Plan

If tests fail after changes:
```bash
git stash
mix test test/indrajaal/cockpit/prajna/
git stash pop  # Only if tests pass without changes
```
