# PROJECT TODOLIST - FAME v2.0-BIO + INDRAJAAL EVOLUTION

**Status**: ACTIVE | **Phase**: FAME Implementation + Indrajaal Migration
**Date**: 2025-12-28 | **Framework**: SOPv5.11 + STAMP + TDG + 5-Level Hierarchy

---

## AGENT ARCHITECTURE (5 Agents + 1 Supervisor)

```
                    ┌─────────────────────────────────────┐
                    │   L5-SUPERVISOR: Executive Agent    │
                    │   THINKING: Strategic orchestration │
                    │   DOING: Coordinates all L4 agents  │
                    └─────────────────┬───────────────────┘
                                      │
        ┌─────────────┬───────────────┼───────────────┬─────────────┐
        │             │               │               │             │
   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │L4-FAME  │   │L4-MIGR  │   │L4-QUAL  │   │L4-CEPAF │   │L4-OBS   │
   │Agent    │   │Agent    │   │Agent    │   │Agent    │   │Agent    │
   │Schema   │   │Naming   │   │Compile  │   │F#/Podman│   │Telemetry│
   └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

| Agent | Domain | THINKING | DOING |
|-------|--------|----------|-------|
| **L5-SUPERVISOR** | Strategic | Prioritizing P0 critical path | Orchestrating 5 domain agents |
| **L4-FAME** | Metadata | Planning 12-block schema | Creating `lib/indrajaal/fame/` |
| **L4-MIGR** | Migration | Analyzing indrajaal → indrajaal | Renaming directories/files |
| **L4-QUAL** | Quality | Fixing compilation errors | Running tests, eliminating warnings |
| **L4-CEPAF** | Infrastructure | Planning F# integration | Building podman containers |
| **L4-OBS** | Observability | Designing fractal logging | Implementing telemetry |

---

## L5.0 STRATEGIC LAYER (Supervisor)

### 1.0.0.0.0 - FAME v2.0-BIO Master Goal [L5-SUPERVISOR]
**Status**: pending | **Priority**: P0 | **Agent**: L5-SUPERVISOR
**THINKING**: Orchestrating 10-week implementation plan across 5 domain agents
**DOING**: Monitoring progress, resolving cross-agent dependencies

---

## L4.0 TACTICAL LAYER (5 Agents)

### 2.0.0.0.0 - FAME Schema & Tooling [L4-FAME Agent]
**Status**: pending | **Priority**: P0 | **Agent**: L4-FAME
**THINKING**: Designing 12-block metadata schema for 8,375+ artifacts
**DOING**: Creating `lib/indrajaal/fame/` module structure

### 3.0.0.0.0 - Indrajaal Migration [L4-MIGR Agent]
**Status**: in_progress | **Priority**: P1 | **Agent**: L4-MIGR
**THINKING**: Planning directory rename `indrajaal_web` → `indrajaal_web`
**DOING**: Updating 230+ file references

### 4.0.0.0.0 - Quality Assurance [L4-QUAL Agent]
**Status**: pending | **Priority**: P0 | **Agent**: L4-QUAL
**THINKING**: Analyzing 11 compilation errors, 486 warnings
**DOING**: Fixing critical errors, running tests

### 5.0.0.0.0 - CEPAF Infrastructure [L4-CEPAF Agent]
**Status**: pending | **Priority**: P2 | **Agent**: L4-CEPAF
**THINKING**: Planning F# module enrichment with FAME metadata
**DOING**: Building OBS standalone container

### 6.0.0.0.0 - Observability [L4-OBS Agent]
**Status**: pending | **Priority**: P2 | **Agent**: L4-OBS
**THINKING**: Designing 5-level fractal logging
**DOING**: Implementing Zenoh-style key expressions

---

## L3.0 OPERATIONAL LAYER (Tasks)

### 2.1.0.0.0 - Create FAME Core Schema [L4-FAME]
**Status**: pending | **Priority**: P0 | **Parent**: 2.0.0.0.0
**THINKING**: Defining type specifications for all 12 blocks
**DOING**: Writing `lib/indrajaal/fame/schema.ex`

### 2.2.0.0.0 - Create FAME Validator [L4-FAME]
**Status**: pending | **Priority**: P0 | **Parent**: 2.0.0.0.0
**THINKING**: Planning validation rules for FAME metadata
**DOING**: Writing `lib/indrajaal/fame/validator.ex`

### 2.3.0.0.0 - Create Mix Tasks [L4-FAME]
**Status**: pending | **Priority**: P0 | **Parent**: 2.0.0.0.0
**THINKING**: Designing CLI interface for FAME operations
**DOING**: Writing `lib/mix/tasks/fame.*.ex`

### 3.1.0.0.0 - Rename lib/indrajaal_web [L4-MIGR]
**Status**: pending | **Priority**: P1 | **Parent**: 3.0.0.0.0
**THINKING**: Planning atomic rename with rollback capability
**DOING**: `mv lib/indrajaal_web lib/indrajaal_web`

### 3.2.0.0.0 - Rename test/indrajaal_web [L4-MIGR]
**Status**: pending | **Priority**: P1 | **Parent**: 3.0.0.0.0
**THINKING**: Planning test directory migration
**DOING**: `mv test/indrajaal_web test/indrajaal_web`

### 3.3.0.0.0 - Update Asset Config [L4-MIGR]
**Status**: pending | **Priority**: P2 | **Parent**: 3.0.0.0.0
**THINKING**: Analyzing esbuild/tailwind configuration
**DOING**: Updating `config/config.exs`

### 4.1.0.0.0 - Fix Compilation Errors [L4-QUAL]
**Status**: completed | **Priority**: P0 | **Parent**: 4.0.0.0.0
**THINKING**: Analyzing membrane.ex undefined functions
**DOING**: Adding missing function implementations

### 4.2.0.0.0 - Eliminate Warnings [L4-QUAL]
**Status**: pending | **Priority**: P3 | **Parent**: 4.0.0.0.0
**THINKING**: Categorizing 486 warnings by severity
**DOING**: Systematic warning elimination

### 4.3.0.0.0 - Run Test Suite [L4-QUAL]
**Status**: pending | **Priority**: P2 | **Parent**: 4.0.0.0.0
**THINKING**: Planning test execution strategy
**DOING**: `MIX_ENV=test mix test`

### 5.1.0.0.0 - Create OBS Verifier [L4-CEPAF]
**Status**: pending | **Priority**: P2 | **Parent**: 5.0.0.0.0
**THINKING**: Designing F# ObsVerifier module
**DOING**: Writing `lib/cepaf/src/Cepaf/Observability/ObsVerifier.fs`

### 5.2.0.0.0 - Update podman-compose-obs [L4-CEPAF]
**Status**: pending | **Priority**: P3 | **Parent**: 5.0.0.0.0
**THINKING**: Planning OBS standalone container configuration
**DOING**: Creating `podman-compose-obs-standalone.yml`

### 6.1.0.0.0 - Implement Fractal Logging [L4-OBS]
**Status**: pending | **Priority**: P2 | **Parent**: 6.0.0.0.0
**THINKING**: Designing L1-L5 logging hierarchy
**DOING**: Updating `lib/indrajaal/observability/fractal/`

---

## L2.0 IMPLEMENTATION LAYER (Subtasks)

### 2.1.1.0.0 - Define @meta block type
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.0.0.0

### 2.1.2.0.0 - Define @impact block type
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.0.0.0

### 2.1.3.0.0 - Define @boundaries block type
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.0.0.0

### 2.1.4.0.0 - Define @metabolism block type (Bio-Fractal)
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.0.0.0

### 2.1.5.0.0 - Define @invariants block type (Bio-Fractal)
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.0.0.0

### 4.1.1.0.0 - Fix membrane.ex undefined functions
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.0.0.0
**DONE**: Added check_immune_status/1, validate_schema/1, check_metabolism/1, extract_dna/1

### 4.1.2.0.0 - Fix GeneticPayload alias
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.0.0.0
**DONE**: Updated alias to use Types.GeneticPayload

---

## L1.0 ATOMIC LAYER (Actions)

### 2.1.1.1.0 - Write @type fame_meta
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.1.0.0

### 2.1.1.2.0 - Write artifact_id validator
**Status**: pending | **Priority**: P0 | **Parent**: 2.1.1.0.0

### 4.1.1.1.0 - Add check_immune_status/1
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.1.0.0

### 4.1.1.2.0 - Add validate_schema/1
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.1.0.0

### 4.1.1.3.0 - Add check_metabolism/1
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.1.0.0

### 4.1.1.4.0 - Add extract_dna/1
**Status**: completed | **Priority**: P0 | **Parent**: 4.1.1.0.0

---

## SESSION TASK MAPPING

| Session ID | Mapped To | Status |
|------------|-----------|--------|
| SESSION.202512281057.4855 | 4.1.0.0.0 | in_progress |
| SESSION.202512281057.1857 | 4.1.1.0.0 | completed |
| SESSION.202512281057.2057 | 5.1.0.0.0 | pending |
| SESSION.202512281057.9156 | 5.1.0.0.0 | pending |
| SESSION.202512281057.3263 | 5.1.0.0.0 | pending |
| SESSION.202512281057.7288 | 5.2.0.0.0 | pending |
| SESSION.202512281057.9541 | ARCHIVED | superseded |
| SESSION.202512281057.0906 | ARCHIVED | superseded |
| SESSION.202512281057.4732 | ARCHIVED | superseded |
| SESSION.202512281057.8728 | ARCHIVED | superseded |
| SESSION.202512281057.8626 | 4.2.0.0.0 | pending |

---

## FAME v2.0-BIO BLOCK REFERENCE

| # | Block | L-Level | Agent |
|---|-------|---------|-------|
| 1 | @meta | L3 | L4-FAME |
| 2 | @impact | L3 | L4-FAME |
| 3 | @boundaries | L3 | L4-FAME |
| 4 | @knowledge | L3 | L4-FAME |
| 5 | @evolution | L3 | L4-FAME |
| 6 | @formal | L2 | L4-FAME |
| 7 | @agent_context | L2 | L4-FAME |
| 8 | @metabolism | L3 | L4-FAME |
| 9 | @invariants | L3 | L4-FAME |
| 10 | @stigmergy | L2 | L4-FAME |
| 11 | @contracts | L3 | L4-QUAL |
| 12 | @observability | L3 | L4-OBS |

---

## QUICK COMMANDS

```bash
# Status
elixir scripts/planning/todolist_manager.exs --status

# Update task
elixir scripts/planning/todolist_manager.exs --update 4.1.0.0.0 completed

# Add task
elixir scripts/planning/todolist_manager.exs --add --parent 2.1.0.0.0 "Define @contracts block"

# Find tasks
elixir scripts/planning/todolist_manager.exs --find "FAME"

# Working set
elixir scripts/planning/todolist_manager.exs --working-set

# Validate
elixir scripts/planning/todolist_manager.exs --validate-hierarchical
```

---

*Updated: 2025-12-28T12:30:00+01:00 | Agent Architecture: 5+1 | Levels: L1-L5*
