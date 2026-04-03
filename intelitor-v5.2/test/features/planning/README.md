# Planning System BDD Test Suite

## Overview

This test suite implements comprehensive BDD testing across 9 fractal layers PLUS
5 cross-cutting concern feature files, covering all aspects of the Planning System
from unit-level access control to constitutional compliance verification.

## Cross-Cutting Concern Features (NEW)

In addition to the 9-layer fractal coverage, we now have 5 comprehensive feature
files that test system-wide concerns:

| Feature File | Scenarios | Focus |
|--------------|-----------|-------|
| `access_control_enforcement.feature` | 30+ | SC-TODO-001 enforcement across all actors |
| `planning_cli_operations.feature` | 40+ | F# CLI operations (add, update, list, delete) |
| `orchestration_coordination.feature` | 35+ | Multi-service coordination (Cortex, Prajna, Smriti, Chaya) |
| `safety_kernel_validation.feature` | 35+ | Pre/runtime/post-execution safety checks |
| `circuit_breaker.feature` | 40+ | Violation handling and resilience |
| **TOTAL** | **180+** | **Comprehensive system-level coverage** |

## 9-Layer Fractal BDD Coverage

## Layer Summary

| Layer | Name | File | Scenarios | Focus |
|-------|------|------|-----------|-------|
| L1 | Unit | `l1_unit/access_control.feature` | 45 | Access control enforcement |
| L2 | Integration | `l2_integration/parser_integration.feature` | 55 | Parser + Repository |
| L3 | Component | `l3_component/cli_interface.feature` | 70 | CLI commands |
| L4 | API | `l4_api/rest_graphql.feature` | 60 | REST + GraphQL |
| L5 | System | `l5_system/e2e_workflows.feature` | 65 | End-to-end workflows |
| L6 | Agent | `l6_agent/autonomous_operations.feature` | 55 | Autonomous AI ops |
| L7 | Joint | `l7_joint/human_agent_collaboration.feature` | 60 | Human-AI collaboration |
| L8 | Fractal | `l8_fractal/layer_propagation.feature` | 70 | L0-L9 propagation |
| L9 | Constitutional | `l9_constitutional/stamp_compliance.feature` | 75 | STAMP/Ψ compliance |
| **TOTAL** | | | **555** | |

## STAMP Constraint Coverage

| Constraint Range | Coverage | Layer |
|-----------------|----------|-------|
| SC-TODO-001 to SC-TODO-008 | 100% | L1, L9 |
| SC-PLAN-001 to SC-PLAN-015 | 100% | L2, L3 |
| SC-PLAN-020 to SC-PLAN-030 | 100% | L4 |
| SC-PLAN-040 to SC-PLAN-050 | 100% | L5 |
| SC-CHAYA-001 to SC-CHAYA-010 | 100% | L6 |
| SC-OODA-001 to SC-OODA-005 | 100% | L6 |
| SC-PLAN-060 to SC-PLAN-075 | 100% | L7 |
| SC-FRAC-001 to SC-FRAC-020 | 100% | L8 |
| SC-CONST-001 to SC-CONST-020 | 100% | L9 |

## Running Tests

### Run All Planning BDD Tests
```bash
# Using Cucumber
mix cucumber --tags @planning

# Run specific layer
mix cucumber test/features/planning/l1_unit/

# Run with specific tag
mix cucumber --tags @sc_todo_001
```

### Run by Priority
```bash
# Critical tests only (safety-related)
mix cucumber --tags @critical

# Security tests
mix cucumber --tags @security

# Agent tests
mix cucumber --tags @autonomous
```

## Test Categories

### By Actor Type
- `@human` - Human operator tests
- `@agent` - AI agent tests
- `@joint` - Human-agent collaboration tests

### By Severity
- `@critical` - Safety-critical tests
- `@high` - High priority
- `@medium` - Medium priority

### By Feature
- `@access_control` - Access control enforcement
- `@cli` - CLI interface tests
- `@api` - API interface tests
- `@workflow` - Workflow tests
- `@ooda` - OODA cycle tests
- `@fractal` - Fractal architecture tests
- `@constitutional` - Constitutional compliance

## Architecture

```
test/features/planning/
├── # Cross-Cutting Concern Features (System-Wide)
├── access_control_enforcement.feature      # SC-TODO-001 enforcement
├── planning_cli_operations.feature         # F# CLI operations
├── orchestration_coordination.feature      # Multi-service coordination
├── safety_kernel_validation.feature        # Pre/runtime/post execution safety
├── circuit_breaker.feature                 # Violation handling & resilience
│
├── # 9-Layer Fractal Coverage
├── l1_unit/
│   └── access_control.feature      # SC-TODO-001 to SC-TODO-008
├── l2_integration/
│   └── parser_integration.feature  # Markdown + SQLite
├── l3_component/
│   └── cli_interface.feature       # sa-plan, chaya commands
├── l4_api/
│   └── rest_graphql.feature        # REST + GraphQL APIs
├── l5_system/
│   └── e2e_workflows.feature       # Sprint, lifecycle workflows
├── l6_agent/
│   └── autonomous_operations.feature # OODA, autonomous execution
├── l7_joint/
│   └── human_agent_collaboration.feature # Hybrid workflows
├── l8_fractal/
│   └── layer_propagation.feature   # L0-L9 propagation
├── l9_constitutional/
│   └── stamp_compliance.feature    # Ψ₀-Ψ₅, STAMP, Ω₀
└── README.md                       # This file
```

## Constitutional Invariants Tested

| Invariant | Description | Scenarios |
|-----------|-------------|-----------|
| Ψ₀ | Existence - System survives all operations | 3 |
| Ψ₁ | Regeneration - State recoverable from SQLite/DuckDB | 3 |
| Ψ₂ | History - Complete evolution recorded | 3 |
| Ψ₃ | Verification - All state verifiable | 3 |
| Ψ₄ | Human Alignment - Founder primacy | 3 |
| Ψ₅ | Truthfulness - No deceptive operations | 3 |
| Ω₀ | Founder's Directive | 5 |

## Related Documents

- [Planning System Specification](../../../docs/planning/PLANNING_SYSTEM_SPECIFICATION.md)
- [Fractal Extension](../../../docs/planning/PLANNING_SYSTEM_FRACTAL_EXTENSION.md)
- [Access Control Rules](../../../.claude/rules/todolist-access-control.md)
- [Agda Proofs](../../../docs/formal_specs/agda/TodolistAccessControl.agda)
- [Quint Models](../../../docs/formal_specs/quint/todolist_access_control.qnt)

## Compliance

- **IEC 61508 SIL-6**: Safety constraint coverage (SC-SIL6-001 to SC-SIL6-020)
- **ISO 27001**: Security constraint coverage
- **GDPR**: Data handling compliance
- **DO-178C DAL-A**: Critical system verification

---

## Detailed Feature File Descriptions

### 1. access_control_enforcement.feature

**Purpose**: Test SC-TODO-001 enforcement across all actor types

**Scenarios** (30+):
- Human access (allowed/denied)
- AI Agent access (always blocked for direct file access)
- System access (F# runtime allowed)
- Unknown entity access (blocked)
- Edge cases (symlinks, hard links, process injection)
- Audit trail verification
- Access Control Matrix immutability

**Tags**: `@planning`, `@access_control`, `@security`, `@critical`

**STAMP Coverage**: SC-TODO-001 to SC-TODO-008

### 2. planning_cli_operations.feature

**Purpose**: Test F# Planning CLI operations comprehensively

**Scenarios** (40+):
- Add task (simple, with priority, validation, hierarchy, metadata, concurrency)
- Update task (status, priority, multiple fields, validation, immutability)
- List tasks (all, by status, by priority, by assignee, JSON/table format, pagination)
- Delete task (with confirmation, archive, recovery)
- Priority management (reorder, bulk update, statistics, auto-escalate)
- Error handling (database locked, network failure, Unicode, special chars)

**Tags**: `@planning`, `@cli`, `@operations`, `@functional`

**STAMP Coverage**: SC-PLAN-001 to SC-PLAN-003

### 3. orchestration_coordination.feature

**Purpose**: Test multi-service coordination across Planning System ecosystem

**Scenarios** (35+):
- **Cortex integration** (event reception, complexity analysis, recommendations, failure recovery, telemetry)
- **Prajna integration** (dashboard, real-time updates via Zenoh, Guardian routing, AI Copilot, Sentinel monitoring)
- **SMRITI integration** (knowledge graph persistence, context provision, pattern learning, federation sync, recovery)
- **Chaya integration** (Digital Twin mirroring, OODA cycle, autonomous management, mesh distribution, sync)
- **Multi-service coordination** (full-stack lifecycle, event propagation, failure cascades, consensus, unified telemetry)
- **Safety and compliance** (Guardian approval, circuit breaker, audit trail)
- **Performance and scalability** (latency budgets, throughput, federation scaling)
- **Error handling and recovery** (database connection loss, Zenoh mesh partition)

**Tags**: `@planning`, `@orchestration`, `@coordination`, `@integration`

**STAMP Coverage**: SC-OODA-001, SC-BRIDGE-005, SC-CORTEX-*, SC-PRAJNA-*, SC-SMRITI-*, SC-CHAYA-*

### 4. safety_kernel_validation.feature

**Purpose**: Test Safety Kernel validation across all execution phases

**Scenarios** (35+):
- **Pre-execution validation** (constitutional check, STAMP constraints, Guardian validation, capability check, resource availability, conflict detection)
- **Runtime monitoring** (health monitoring, functional invariant verification, anomaly detection, constraint violation detection, telemetry collection, Guardian sync, self-correction)
- **Post-execution verification** (state verification, rollback on failure, audit trail completeness, constitutional compliance, performance metrics, AI feedback)
- **Emergency stop** (critical violation handling, rollback to safe state, component isolation, Guardian override)
- **Recovery and resilience** (self-healing, checkpoint creation, progressive degradation)
- **Compliance and audit** (GDPR, SIL-6, Immutable Register logging)

**Tags**: `@planning`, `@safety`, `@kernel`, `@critical`

**STAMP Coverage**: SC-FUNC-001 to SC-FUNC-008, Ψ₀-Ψ₅, Ω₀

### 5. circuit_breaker.feature

**Purpose**: Test Circuit Breaker violation handling and system resilience

**Scenarios** (40+):
- **Single violation** (low severity, medium severity, high severity double count, violation counter decay)
- **Multiple violations** (threshold breach, burst detection, different types accumulate, cascade detection)
- **Circuit breaker activation** (immediate opening, operation blocking, queueing, critical operations with Guardian approval, telemetry publishing)
- **Circuit breaker reset** (timer-based to HALF_OPEN, successful test requests close circuit, failed test request reopens, manual reset with Guardian approval, violation counter decay)
- **State transitions** (CLOSED→OPEN, OPEN→HALF_OPEN, HALF_OPEN→CLOSED, HALF_OPEN→OPEN, invalid transitions rejected)
- **Integration with safety systems** (Guardian coordination, Sentinel data feeding, Prajna dashboard display, Chaya Digital Twin reflection)
- **Performance and resilience** (minimal overhead, component failure handling, state persistence across restarts)
- **Error handling and edge cases** (counter overflow, rapid state changes, time window expiration)

**Tags**: `@planning`, `@circuit_breaker`, `@resilience`, `@critical`

**STAMP Coverage**: SC-EMR-057, SC-EMR-060, SC-FUNC-003, SC-TODO-001

---

## Running Cross-Cutting Concern Tests

```bash
# Run all cross-cutting concern tests
mix cucumber test/features/planning/access_control_enforcement.feature
mix cucumber test/features/planning/planning_cli_operations.feature
mix cucumber test/features/planning/orchestration_coordination.feature
mix cucumber test/features/planning/safety_kernel_validation.feature
mix cucumber test/features/planning/circuit_breaker.feature

# Or run by tag
mix cucumber --tags @access_control
mix cucumber --tags @cli
mix cucumber --tags @orchestration
mix cucumber --tags @safety
mix cucumber --tags @circuit_breaker

# Run all critical tests
mix cucumber --tags @critical

# Run smoke tests only
mix cucumber --tags @smoke
```

## Test Metrics

| Metric | Count |
|--------|-------|
| Total Feature Files | 14 (5 cross-cutting + 9 layers) |
| Total Scenarios | 735+ (180 cross-cutting + 555 layers) |
| STAMP Constraints Covered | 150+ |
| Constitutional Invariants Tested | 6 (Ψ₀-Ψ₅) |
| Founder's Directive Tests | 5 (Ω₀ sub-directives) |
| Actor Types Tested | 4 (Human, AI Agent, System, Unknown) |
| Service Integrations Tested | 4 (Cortex, Prajna, SMRITI, Chaya) |
| Safety Phases Tested | 3 (Pre-execution, Runtime, Post-execution) |

---

*Generated: 2026-01-16*
*Updated: 2026-01-16 (Added 5 cross-cutting concern features)*
*Version: 21.3.0-SIL6*
*STAMP: SC-BDD-001 to SC-BDD-012*
*Total Coverage: 735+ scenarios across 14 feature files*
