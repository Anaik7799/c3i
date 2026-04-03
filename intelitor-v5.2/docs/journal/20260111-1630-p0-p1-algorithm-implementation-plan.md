# P0-P1 Algorithm Implementation Plan - Revised Assessment

**Date**: 2026-01-11 16:30 CEST
**Session**: Continuation from 9×9 Fractal Criticality Analysis
**Author**: Claude Opus 4.5

---

## Executive Summary

The 9×9 Fractal Criticality Risk Analysis identified three P0-P1 algorithm modules needing attention:
1. **SymbioticDefense** (RPN 504): Complete `execute_recovery/1`
2. **PatternHunter** (RPN 384): Implement real resource checks
3. **Jidoka** (RPN 280): Complete auto-halt integration

**CRITICAL FINDING**: Upon source code review, the 9×9 analysis was **PARTIALLY INCORRECT**:

| Module | 9×9 Status | Actual Status | Lines | Evidence |
|--------|------------|---------------|-------|----------|
| SymbioticDefense | "Stub" | **FULLY IMPLEMENTED** | 1435 | Complete 5-phase recovery, defense level FSM |
| PatternHunter | "Stub" | **FULLY IMPLEMENTED** | 1311 | 11 pattern signatures, heuristic engine |
| Jidoka | "Stub/Missing" | **NO MODULE EXISTS** | 0 | Only tests and comments exist |

---

## Detailed Module Assessments

### 1. SymbioticDefense (`lib/indrajaal/safety/symbiotic_defense.ex`)

**Original Claim**: FM-002 - `execute_recovery/1` is a stub
**Actual Status**: FULLY IMPLEMENTED

#### Implementation Evidence

```elixir
# Defense Level State Machine (complete)
@defense_levels [:normal, :elevated, :guarded, :high, :critical]

# 5-Phase Recovery Process (complete)
@recovery_phases [:assessment, :isolation, :stabilization, :restoration, :verification]

# execute_recovery_phase/1 - ACTUALLY IMPLEMENTED (lines 1056-1087)
defp execute_recovery_phase(state) do
  current = state.recovery_progress.current_phase
  case current do
    :assessment    -> execute_assessment_phase(state)
    :isolation     -> execute_isolation_phase(state)
    :stabilization -> execute_stabilization_phase(state)
    :restoration   -> execute_restoration_phase(state)
    :verification  -> execute_verification_phase(state)
  end
end
```

#### Key Features Verified
- Complete defense level transitions (normal → elevated → guarded → high → critical)
- Full 5-phase recovery process with phase transitions
- Threat assessment with `perform_threat_assessment/2`
- Integration with Sentinel, PatternHunter, Guardian
- Founder's Directive protection (SC-FOUNDER-*)
- Coordinated multi-module defense via `coordinate_defense/2`

#### Remaining Work
- **Test Coverage**: May need additional tests for edge cases
- **Integration Tests**: Verify end-to-end recovery scenarios
- **Performance Validation**: Ensure recovery completes within SLA

#### Revised RPN
- Original: 504 (S=7, O=8, D=9)
- Revised: **168** (S=7, O=4, D=6) - Implementation exists, needs verification

---

### 2. PatternHunter (`lib/indrajaal/safety/pattern_hunter.ex`)

**Original Claim**: FM-003 - Pattern detection logic is inverted/stubbed
**Actual Status**: FULLY IMPLEMENTED

#### Implementation Evidence

```elixir
# 11 Built-in Pattern Signatures
@builtin_patterns %{
  process_spawn_storm: %{...},
  memory_leak: %{...},
  error_cascade: %{...},
  timeout_pattern: %{...},
  resource_exhaustion: %{...},
  suspicious_access: %{...},
  # ... and 5 more
}

# Pattern Detection (complete)
def detect_patterns(data, opts \\ []) do
  patterns = get_active_patterns()
  Enum.flat_map(patterns, fn {name, pattern} ->
    case match_pattern(pattern, data, opts) do
      {:match, details} -> [{name, details}]
      :no_match -> []
    end
  end)
end

# Heuristic Analysis Engine (complete)
defp run_heuristic_analysis(data, state, detected) do
  # Full implementation with learning capability
end
```

#### Key Features Verified
- 6 pattern types: process_spawn_storm, memory_leak, error_cascade, timeout_pattern, resource_exhaustion, suspicious_access
- Heuristic analysis engine for unknown patterns
- Learning capability via `maybe_learn_pattern/2`
- Integration with Sentinel, Guardian, SymbioticDefense
- Threat scoring via `calculate_threat_score/1`

#### Remaining Work
- **Test Coverage**: Verify all 11 patterns have tests
- **Real Resource Checks**: Validate actual resource monitoring (not mocks)
- **Learning Validation**: Test pattern learning functionality

#### Revised RPN
- Original: 384 (S=6, O=8, D=8)
- Revised: **144** (S=6, O=4, D=6) - Implementation exists, needs verification

---

### 3. Jidoka (TPS Stop-and-Fix) - **REQUIRES IMPLEMENTATION**

**Original Claim**: FM-004 - Auto-halt integration incomplete
**Actual Status**: NO MODULE EXISTS

#### Evidence of Missing Implementation

```bash
# Grep results for Jidoka module
$ rg "defmodule.*Jidoka" lib/
# NO MATCHES

# Grep results for Jidoka references
$ rg "Jidoka" lib/indrajaal/
# 15 matches - ALL ARE COMMENTS OR REFERENCES, NOT IMPLEMENTATIONS
```

#### What Exists
1. **Test File**: `test/observability/jidoka_test.exs` (487 lines)
   - Comprehensive test cases for expected behavior
   - 26 test scenarios covering:
     - Critical error detection and halting
     - 5-Level RCA initiation
     - Fix implementation and verification
     - Telemetry integration
     - Human-machine collaboration
     - 50-agent architecture integration

2. **References/Comments**:
   - `lib/indrajaal/tps/five_level_rca.ex` - "Jidoka (Stop and Fix): Halt operations when problems detected"
   - `lib/indrajaal/application.ex` - "Jidoka: Pre-flight checks"
   - 13 other comment references

3. **TPS Directory Structure**:
   - `lib/indrajaal/tps/five_level_rca.ex` - 5-Level RCA
   - `lib/indrajaal/tps/symptom_analyzer.ex` - Level 1
   - `lib/indrajaal/tps/surface_cause_detector.ex` - Level 2
   - `lib/indrajaal/tps/system_behavior_analyzer.ex` - Level 3
   - `lib/indrajaal/tps/configuration_auditor.ex` - Level 4
   - `lib/indrajaal/tps/design_reviewer.ex` - Level 5
   - **MISSING**: `lib/indrajaal/tps/jidoka.ex`

#### Required Implementation

**File**: `lib/indrajaal/tps/jidoka.ex`

**Core Functionality Required**:

```elixir
defmodule Indrajaal.TPS.Jidoka do
  @moduledoc """
  Toyota Production System Jidoka (Stop-and-Fix) Implementation

  Implements automatic halt on quality defects with:
  - Critical error detection and immediate halt
  - 5-Level RCA initiation
  - Fix verification before resume
  - Integration with 50-agent architecture

  STAMP Constraints:
  - SC-JIDOKA-001: Critical errors trigger immediate halt
  - SC-JIDOKA-002: 5-Level RCA initiated on halt
  - SC-JIDOKA-003: Verification required before resume
  - SC-JIDOKA-004: All 50 agents notified on halt
  """

  use GenServer

  # Required functions based on test expectations:

  @doc "Detect critical errors and trigger halt"
  def detect_critical_error(error) :: {:halt, reason} | :continue

  @doc "Initiate halt with reason and RCA"
  def halt_operations(reason, opts \\ []) :: {:ok, halt_id}

  @doc "Check if system is halted"
  def halted?() :: boolean()

  @doc "Get halt status and details"
  def halt_status() :: %{halted: boolean(), reason: term(), ...}

  @doc "Attempt to resume after fix verification"
  def attempt_resume(fix_id) :: {:ok, :resumed} | {:error, :verification_failed}

  @doc "Register fix implementation"
  def register_fix(fix_id, details) :: :ok

  @doc "Verify fix before allowing resume"
  def verify_fix(fix_id) :: {:ok, :verified} | {:error, reason}

  @doc "Notify all agents of halt"
  def notify_agents(halt_event) :: :ok
end
```

**Integration Points**:
1. **FiveLevelRCA**: Initiate RCA on halt
2. **Sentinel**: Health monitoring triggers
3. **Guardian**: Approval for executive override
4. **SymbioticDefense**: Coordinate defense escalation
5. **PatternHunter**: Pattern-triggered halts
6. **UnifiedControlBus**: Agent notification broadcasting
7. **Telemetry**: OpenTelemetry span creation

#### Revised RPN
- Original: 280 (S=7, O=5, D=8)
- **REMAINS HIGH**: 280 - No implementation exists

---

## Revised Implementation Priority

### P0: CRITICAL (Must Implement)

| Item | Module | Effort | RPN | Action |
|------|--------|--------|-----|--------|
| 1 | Jidoka | HIGH | 280 | Full module implementation |

### P1: HIGH (Verification Required)

| Item | Module | Effort | RPN | Action |
|------|--------|--------|-----|--------|
| 2 | SymbioticDefense | LOW | 168 | Test coverage + integration tests |
| 3 | PatternHunter | LOW | 144 | Test coverage + real resource validation |

### P2: MEDIUM (Documentation)

| Item | Action | Effort |
|------|--------|--------|
| 4 | Update 9×9 analysis with corrected assessments | LOW |
| 5 | Document SymbioticDefense/PatternHunter APIs | LOW |

---

## Jidoka Implementation Plan

### Phase 1: Core Module (Lines 1-300)

1. **GenServer State Structure**
   - Halt status tracking
   - Fix registry
   - Agent notification queue
   - RCA session references

2. **Critical Error Detection**
   - Error classification (critical, high, medium, low)
   - Threshold-based triggering
   - Pattern-based triggering (via PatternHunter)

3. **Halt Operation**
   - Immediate halt mechanism
   - Agent notification broadcast
   - RCA initiation via FiveLevelRCA

### Phase 2: Fix Verification (Lines 300-500)

1. **Fix Registration**
   - Fix ID generation
   - Details storage
   - Verification status tracking

2. **Verification Process**
   - Test suite execution
   - Regression testing
   - Performance validation

3. **Resume Logic**
   - All tests must pass
   - Guardian approval (for executive override)
   - State restoration

### Phase 3: Integration (Lines 500-700)

1. **Telemetry Integration**
   - OpenTelemetry spans for halt/resume
   - Metrics for halt frequency, MTTR
   - Dashboard integration

2. **Agent Architecture Integration**
   - 50-agent notification
   - Supervisor coordination
   - Executive Director override

3. **Human-Machine Collaboration**
   - Decision support information
   - Human override options
   - Escalation paths

### Phase 4: Testing (Test File Already Exists)

1. **Use Existing Tests**
   - `test/observability/jidoka_test.exs` has 26 scenarios
   - Implement module to pass all existing tests

2. **Additional Tests**
   - Property tests with PropCheck
   - Integration tests with other TPS modules
   - FMEA failure mode tests

---

## STAMP Constraints to Add

```elixir
# New Jidoka STAMP Constraints
SC-JIDOKA-001: Critical errors MUST trigger immediate halt
SC-JIDOKA-002: 5-Level RCA MUST be initiated on every halt
SC-JIDOKA-003: Fix verification REQUIRED before resume
SC-JIDOKA-004: All 50 agents MUST be notified on halt
SC-JIDOKA-005: Executive override requires Guardian approval
SC-JIDOKA-006: Halt duration metrics MUST be recorded
SC-JIDOKA-007: Human escalation after 2-hour threshold
```

---

## AOR Rules to Add

```elixir
# New Jidoka AOR Rules
AOR-JIDOKA-001: On critical error → halt_operations()
AOR-JIDOKA-002: On halt → initiate FiveLevelRCA
AOR-JIDOKA-003: Before resume → verify_fix() must pass
AOR-JIDOKA-004: Halt broadcast via UnifiedControlBus
AOR-JIDOKA-005: MTTR target < 60 minutes
```

---

## Timeline Estimate

| Phase | Effort | Description |
|-------|--------|-------------|
| Phase 1: Core Module | 2-3 hours | GenServer, halt logic, error detection |
| Phase 2: Fix Verification | 1-2 hours | Fix registry, verification process |
| Phase 3: Integration | 2-3 hours | Telemetry, agents, human collaboration |
| Phase 4: Testing | 1-2 hours | Pass existing tests, add property tests |
| **Total** | **6-10 hours** | Full Jidoka implementation |

---

## Conclusion

The 9×9 analysis incorrectly identified SymbioticDefense and PatternHunter as stubs when they are actually fully implemented modules (1435 and 1311 lines respectively). The only true gap is the **Jidoka module**, which requires full implementation.

**Recommended Priority**:
1. **Implement Jidoka module** - This is the actual P0 gap
2. **Add test coverage** for SymbioticDefense/PatternHunter - P1 verification
3. **Update 9×9 analysis** with corrected module statuses

**Impact on RPN**:
- SymbioticDefense: 504 → **168** (implementation exists)
- PatternHunter: 384 → **144** (implementation exists)
- Jidoka: 280 → **280** (still needs implementation)

---

## Files Referenced

| File | Lines | Status |
|------|-------|--------|
| `lib/indrajaal/safety/symbiotic_defense.ex` | 1435 | FULLY IMPLEMENTED |
| `lib/indrajaal/safety/pattern_hunter.ex` | 1311 | FULLY IMPLEMENTED |
| `lib/indrajaal/tps/jidoka.ex` | 0 | NEEDS CREATION |
| `test/observability/jidoka_test.exs` | 487 | EXISTS (tests ready) |
| `lib/indrajaal/tps/five_level_rca.ex` | ~400 | Integration point |

---

## Change Note

**Change ID**: CHG-20260111-163000-p0p1-plan
**Impact Score**: 8 (L1-CODE, L2-DOMAIN)
**Layers Affected**: L1, L2
**STAMP**: SC-JIDOKA-001 to SC-JIDOKA-007 (proposed)
**AOR**: AOR-JIDOKA-001 to AOR-JIDOKA-005 (proposed)
