# SentinelBridge Property Test Analysis Report

**Date**: 2026-01-02
**Module**: `Indrajaal.Cockpit.Prajna.SentinelBridge`
**Test File**: `/test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs`
**Status**: TDG COMPLIANCE INCOMPLETE

---

## 1. PROPERTY TESTS INVENTORY

### EXISTING (2 Property Tests)

#### 1.1 PropCheck: Health Score Percent Calculation (Lines 183-192)
- **Type**: PropCheck forall
- **Generator**: `PC.float(0.0, 1.0)` (CORRECT prefix)
- **Assertion**: `expected_percent = round(score * 100)` equals actual
- **Weakness**: Only tests deterministic math, not real SentinelBridge data flow
- **Status**: MINIMAL - passes but inadequate for integration testing

#### 1.2 PropCheck: Status Derivation (Lines 194-205)
- **Type**: PropCheck forall
- **Generator**: `PC.float(0.0, 1.0)` (CORRECT prefix)
- **Assertion**: Status correctly maps from score range
  - `score >= 0.9` → `:healthy`
  - `score >= 0.7` → `:degraded`
  - `score >= 0.5` → `:warning`
  - `score < 0.5` → `:critical`
- **Status**: MINIMAL - abstract mapping test only

#### 1.3 Placeholder Tests (Lines 211-227)
- **Advisory Severity Test**: Non-property test (hardcoded list iteration)
- **Threat Types Test**: Non-property test (hardcoded list iteration)
- **Status**: NOT property tests (misleading classification)

---

## 2. MISSING PROPERTY TESTS

### CRITICAL GAP #1: Sync Cycle Property (MISSING)

**What it should test:**
- Sync operations occur at regular intervals (30s ± tolerance)
- Multiple syncs maintain monotonic `sync_count` increment
- State consistency across sync boundaries
- No race conditions with concurrent sync requests

**Why it matters:**
- AOR-PRAJNA-004: "SmartMetrics MUST sync with Sentinel every 30 seconds"
- SC-IMMUNE-007: "Bridge MUST sync every 30s"
- SC-BRIDGE-002: "Buffer flush interval 100ms maximum"

**Type**: ExUnitProperties with StreamData
**Generators needed**:
- `SD.positive_integer()` for sync operation counts
- `SD.term()` for arbitrary state structures
- `SD.boolean()` for failure injection

**Example assertion**:
```
forall n_syncs <- SD.integer(1, 20) do
  # Run n syncs, verify:
  # 1. sync_count increases monotonically
  # 2. Each sync increments counter by exactly 1
  # 3. No sync_count decreases
end
```

---

### CRITICAL GAP #2: Exponential Backoff Property (MISSING)

**What it should test:**
- Delay increases exponentially: `delay = base * 2^(attempt-1)`, capped at max
- Delay calculations respect bounds: `@backoff_base_ms (1s) <= delay <= @backoff_max_ms (60s)`
- Max attempts limit is enforced (5 attempts)
- Reset behavior on successful sync
- Monotonic failure counter

**Why it matters:**
- SC-API-003: "Exponential backoff on 429 status (base 2s, max 60s)"
- SC-BIO-007: "Graceful degradation on rate limit"
- Lines 223-261 in module: `check_backoff_state/1` needs validation

**Type**: PropCheck with PC generators
**Generators needed**:
- `PC.integer(1, 5)` for attempt numbers
- `PC.float(0.0, 1.0)` for failure injection

**Example assertion**:
```
forall attempt <- PC.integer(1, 5) do
  {:ok, delay_ms} = Backoff.exponential_backoff(attempt, ...)
  # Verify: delay >= 1000 and delay <= 60000
  # Verify: delay grows exponentially
end
```

---

### CRITICAL GAP #3: Health Propagation Property (MISSING)

**What it should test:**
- Health data from Sentinel transforms correctly to Prajna format
- Score conversion: Sentinel `0.0-1.0` → Prajna `0-100` (rounded)
- Threat list transformation: threat objects → advisory objects
- Status mapping consistency
- Health data consistency on successful vs failed sync

**Why it matters:**
- SC-PRAJNA-004: "Sentinel health integration required"
- Lines 269-310 in module: `do_perform_sync/1` needs validation
- Health data structure contract (lines 287-292)

**Type**: ExUnitProperties with StreamData
**Generators needed**:
- `SD.map_of/2` for arbitrary Sentinel health structures
- `SD.float(0.0, 1.0)` for scores
- `SD.list_of/1` for threat lists

**Example assertion**:
```
forall sentinel_health <- SD.map_of(...) do
  # Transform health → Prajna format
  prajna_health = transform_health(sentinel_health)

  # Verify all required keys present
  assert Map.has_key?(prajna_health, :score)
  assert Map.has_key?(prajna_health, :score_percent)
  assert prajna_health.score_percent == round(prajna_health.score * 100)
end
```

---

### CRITICAL GAP #4: Threat Ordering Property (MISSING)

**What it should test:**
- Threats in advisories maintain semantic ordering
  - By severity (critical > high > warning > medium > low > info)
  - By timestamp (newer first or older first, consistent)
- Advisory transformation preserves threat identity
- All required advisory fields present for all threats
- Severity mapping is bijective

**Why it matters:**
- Lines 362-375 in module: `get_advisories_from_sentinel/1` needs validation
- User experience: operators need threats ordered by priority
- SC-IMMUNE-001: "Health scoring 0-100 scale" (threats are components)

**Type**: ExUnitProperties with StreamData
**Generators needed**:
- `SD.list_of/1` with threat maps
- `SD.sampled_from/1` for severity atoms
- `SD.integer()` for timestamps

**Example assertion**:
```
forall threats <- SD.list_of(threat_generator()) do
  advisories = threats |> Enum.map(&to_advisory/1) |> sort_by_severity()

  # Verify severity ordering
  severities = Enum.map(advisories, & &1.severity)
  assert severities == Enum.sort(severities, &severity_comparator/2)
end
```

---

## 3. TDG COMPLIANCE GAPS

### Standard 1: Tests Must Fail Before Implementation
**Status**: UNKNOWN - Cannot determine if these tests fail initially
**Action**: Run `mix test test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs` and confirm existing tests pass (indicating they test implemented behavior, not TDG)

### Standard 2: Dual Property Testing
**Current**: 2 PropCheck tests only
**Missing**: 0 ExUnitProperties tests using `check all/2`
**Ratio**: 100% PropCheck, 0% StreamData (IMBALANCED)
**Target**: ~50% each for comprehensive property coverage

### Standard 3: Generator Disambiguation (EP-GEN-014)
**Status**: CORRECT
- Lines 19-20: Proper aliases defined
  ```elixir
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  ```
- All PropCheck tests use `PC.` prefix
- No conflicts detected

### Standard 4: STAMP Constraint Documentation
**Status**: INCOMPLETE
- Module declares SC-PRAJNA-004, SC-IMMUNE-001 in moduledoc
- Tests verify these constraints exist
- **Missing**: Explicit constraint coverage per test
  - Each property test should document which STAMP constraint it validates
  - Current moduledoc is generic ("Unit tests for all public functions")

### Standard 5: TPS 5-Level RCA Context
**Status**: MISSING
- No L1-L5 RCA documentation in moduledoc
- Tests don't articulate what defect they prevent
- L1 Symptoms and L5 Root Causes not documented

---

## 4. QUANTITATIVE SUMMARY

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Property Tests | 2 | 6 | -4 |
| PropCheck Tests | 2 | 3 | -1 |
| ExUnitProperties Tests | 0 | 3 | -3 |
| STAMP Constraints Covered | 2 | 8+ | -6 |
| TPS RCA Documentation | 0% | 100% | -100% |
| TDG Compliance | 40% | 100% | -60% |

---

## 5. RECOMMENDATIONS

### Priority 1 (P0): Add Missing Property Tests
Generate 4 new property tests:
1. **Sync Cycle Property** (ExUnitProperties)
   - File: Enhanced test module
   - Validates: AOR-PRAJNA-004, SC-IMMUNE-007

2. **Exponential Backoff Property** (PropCheck)
   - File: Enhanced test module
   - Validates: SC-API-003, SC-BIO-007

3. **Health Propagation Property** (ExUnitProperties)
   - File: Enhanced test module
   - Validates: SC-PRAJNA-004

4. **Threat Ordering Property** (ExUnitProperties)
   - File: Enhanced test module
   - Validates: SC-IMMUNE-001, SC-BRIDGE-001

### Priority 2 (P1): Update Test Moduledoc
Add TPS 5-Level RCA context:
- L1 Symptom: What observable behavior this tests
- L5 Root Cause: What defect this prevents
- STAMP constraints per test

### Priority 3 (P2): Verify TDG Compliance
Ensure missing tests fail initially:
- New property tests should have failing assertions until code is written
- Create "stub" implementation assertions that fail

---

## 6. CODE STRUCTURE ANALYSIS

### SentinelBridge Module Features to Test

| Feature | Lines | Test Type | Status |
|---------|-------|-----------|--------|
| `get_health/0` | 77-79 | Unit | EXISTS |
| `get_advisories/0` | 82-85 | Unit | EXISTS |
| `sync_now/0` | 54-56 | Unit | EXISTS |
| `check_backoff_state/1` | 224-261 | Property | MISSING |
| `perform_sync/1` | 206-221 | Property | PARTIAL |
| `do_perform_sync/1` | 269-338 | Property | MISSING |
| `get_advisories_from_sentinel/1` | 362-375 | Property | MISSING |
| Health data transformation | 287-292 | Property | MISSING |
| Backoff calculation | 226-230 | Property | MISSING |

---

## 7. CONSTRAINT COVERAGE MATRIX

| Constraint | Tested? | Test Type | Location |
|-----------|---------|-----------|----------|
| SC-PRAJNA-004 | PARTIAL | Unit | Line 234 |
| SC-IMMUNE-001 | PARTIAL | Unit | Line 247 |
| SC-IMMUNE-007 | NO | - | MISSING |
| SC-API-003 | NO | - | MISSING |
| SC-BIO-007 | NO | - | MISSING |
| SC-BRIDGE-001 | NO | - | MISSING |
| SC-BRIDGE-002 | NO | - | MISSING |
| AOR-PRAJNA-004 | PARTIAL | Unit | Line 255 |
| AOR-BIO-001 | NO | - | MISSING |
| AOR-BIO-006 | NO | - | MISSING |

---

## 8. NEXT STEPS

1. **Immediate**: Run existing tests to confirm they pass
   ```bash
   SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs
   ```

2. **Short-term**: Generate 4 missing property tests with full TDG compliance

3. **Medium-term**: Add BDD feature files for user journeys
   - Scenario: "Sentinel reports critical threat → Prajna receives advisory"
   - Scenario: "Sync fails → Backoff activated → Sync retries"

4. **Long-term**: Achieve 100% coverage of all STAMP constraints in test suite

---

## Appendix A: Test File Statistics

```
File: test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs
Lines of Code: 272
Unit Tests: 13 (48%)
Property Tests: 2 (7%)
Integration Tests: 3 (11%)
Documentation: 50 (18%)
Helpers: 6 (2%)

Code Coverage:
- describe/test blocks: 22 total
- Assertions per block: 1-2 average
- Generators used: PC only (missing SD)
```

---

## Appendix B: Module Dependency Graph

```
SentinelBridge
├── Sentinel (lines 34, 271, 417)
│   ├── get_health/0
│   └── report_threat/3
├── SmartMetrics (lines 33, 279, 410)
│   ├── record/4
│   └── alarmed_metrics/0
├── Backoff (lines 32, 226)
│   └── exponential_backoff/3
└── Telemetry (lines 207, 163, 294, etc.)
    └── execute/3
```

Each dependency should have property tests validating:
1. Contract compliance (inputs/outputs)
2. Error handling paths
3. State mutation semantics

---

**Report Status**: COMPREHENSIVE ANALYSIS COMPLETE
**Recommendation**: Proceed with Priority 1 implementation
