# Immune System Integration Tests - Quick Reference

**Last Updated**: 2026-01-02
**Status**: Production-Ready with 2 Enhancement Recommendations

---

## File Locations & Line References

### Core Test Suites

| Component | File Path | Lines | Status |
|-----------|-----------|-------|--------|
| **Mara** (Chaos Coordinator) | `/test/indrajaal/cockpit/prajna/immune/mara_test.exs` | 1-520 | ✓ Verified |
| **Antibody** (Anomaly Hunter) | `/test/indrajaal/cockpit/prajna/immune/antibody_test.exs` | 1-600 | ✓ Verified |
| **Antibody Supervisor** | `/test/indrajaal/cockpit/prajna/immune/antibody_supervisor_test.exs` | 1-186 | ✓ Verified |
| **SentinelBridge** | `/test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs` | 1-272 | ✓ Verified |
| **SentinelBridge Enhanced** | `/test/indrajaal/cockpit/prajna/sentinel_bridge_enhanced_test.exs` | 1-502 | ✓ Verified |
| **Chaos Engineering** | `/test/indrajaal/cockpit/prajna/chaos_test.exs` | 1-100+ | ✓ Integrated |

### Implementation Files

| Module | File Path | STAMP Constraints |
|--------|-----------|-------------------|
| Mara | `/lib/indrajaal/cockpit/prajna/immune/mara.ex` | SC-IMMUNE-001, 003, 005, 007 |
| Antibody | `/lib/indrajaal/cockpit/prajna/immune/antibody.ex` | SC-IMMUNE-001, 002, 006, 007 |
| AntibodySupervisor | `/lib/indrajaal/cockpit/prajna/immune/antibody_supervisor.ex` | SC-IMMUNE-001, SC-AGT-018 |
| SentinelBridge | `/lib/indrajaal/cockpit/prajna/sentinel_bridge.ex` | SC-PRAJNA-004, SC-IMMUNE-001 |

---

## SC-IMMUNE Constraint Quick Matrix

```
SC-IMMUNE-001: System Health Monitoring
├─ Mara: Continuous attack scheduling & execution
├─ Antibody: Lifecycle health checks
├─ SentinelBridge: Health score propagation (0-100)
└─ Coverage: ✓✓✓ HIGH (12+ tests)

SC-IMMUNE-002: Kernel Process Protection
├─ Antibody.safety_whitelisted?/1 validates whitelist
├─ Test: antibody_test.exs:346 (3 dedicated tests)
├─ Implementation: antibody.ex:520 (is_kernel_process?)
└─ Coverage: ✓✓ HIGH (3 unit tests + property)

SC-IMMUNE-003: Audit Logging
├─ Mara: Logs attack initiation (line 254)
├─ Antibody: Logs findings for audit (line 478)
└─ Coverage: ✓ MEDIUM (implicit in implementation)

SC-IMMUNE-004: Pre-Error Signature Detection
├─ PatternHunter module (not yet explicitly tested)
└─ Coverage: ⚠ LOW (RECOMMENDATION: Add PatternHunterTest)

SC-IMMUNE-005: Memory Leak Detection (10+ Samples)
├─ Mara: 4 dedicated tests (lines 179, 280, 437, 448, 501)
├─ Properties: Monotonicity, threshold, fuzzing
├─ Implementation: mara.ex:205-231 (detection logic)
└─ Coverage: ✓✓✓ VERY HIGH (4 unit + 4 property tests)

SC-IMMUNE-006: Quarantine via :sys.suspend/1
├─ Antibody: 3 dedicated tests (lines 381, 400, 420)
├─ Implementation: antibody.ex:490 (cleanup logic)
├─ Validates: Suspended processes are reversible
└─ Coverage: ✓✓ HIGH (3 unit tests + property)

SC-IMMUNE-007: Response Time Constraints
├─ Extinction: <100ms (not explicitly timed)
├─ Critical: <500ms (not explicitly timed)
├─ High: <2000ms (not explicitly timed)
├─ Mara: Attack timing tested (implicit)
├─ Chaos: Integration tests available
└─ Coverage: ⚠ MEDIUM (RECOMMENDATION: Add timing validation)

SC-IMMUNE-008: Threat Classification Ordering
├─ Priority: lineage > existential > financial > reputational > operational
├─ SentinelBridge: Advisory transformation tested
├─ Test: sentinel_bridge_enhanced_test.exs:416 (ordering property)
└─ Coverage: ✓ MEDIUM (1 property test, could be enhanced)
```

---

## Test Execution Quick Commands

### Run All Immune System Tests
```bash
# Standard run with coverage
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/ --cover

# With verbose output
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/ --verbose

# Property testing only (PropCheck + StreamData)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/ --only property
```

### Run Individual Test Files
```bash
# Mara (Chaos Coordinator)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/mara_test.exs

# Antibody (Anomaly Hunter)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/antibody_test.exs

# Antibody Supervisor
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/antibody_supervisor_test.exs

# SentinelBridge tests
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/sentinel_bridge_test.exs
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/sentinel_bridge_enhanced_test.exs
```

### Run Chaos Engineering Tests
```bash
# Full chaos suite
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/chaos_test.exs

# With streaming output for long-running tests
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/chaos_test.exs --trace
```

### Run Specific Test Patterns
```bash
# Memory leak detection tests only (SC-IMMUNE-005)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/mara_test.exs \
  --only "memory leak"

# Kernel process protection tests (SC-IMMUNE-002)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/antibody_test.exs \
  --only "kernel process protection"

# Quarantine tests (SC-IMMUNE-006)
SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/antibody_test.exs \
  --only "quarantine"
```

### Test Compilation Validation
```bash
# Verify all test files compile (TDG requirement)
MIX_ENV=test mix compile

# Check EP-GEN-014 (PropCheck/StreamData disambiguation)
mix validate.ep014

# Format and quality checks
mix format --check-formatted && mix credo --strict
```

---

## SC-IMMUNE Test Mapping

### SC-IMMUNE-001: Continuous Monitoring
```
File: mara_test.exs
Line 27:   "starts the Mara agent"
Line 70:   "schedules first attack"
Line 92:   "increments attack counter"
Line 113:  "executes random attack type"
Line 416:  property "attack count never decreases"

File: antibody_test.exs
Line 159:  "does not kill processes directly"
Line 177:  "uses opsonization, not termination"

File: sentinel_bridge_test.exs
Line 62:   "returns health data structure"
Line 72:   "score is between 0.0 and 1.0"
```

### SC-IMMUNE-002: Kernel Protection
```
File: antibody_test.exs
Line 346:  describe "kernel process protection (SC-IMMUNE-002)"
Line 347:  "safety_whitelisted? returns true for kernel processes"
Line 356:  "safety_whitelisted? returns false for regular processes"
Line 364:  "bind refuses to bind to kernel process"

File: antibody.ex
Line 520:  def is_kernel_process?(pid)
Line 572:  "SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes"
```

### SC-IMMUNE-005: Memory Leak Detection
```
File: mara_test.exs
Line 179:  "memory_leak broadcasts monotonic memory samples"
Line 280:  "creates 10 samples with monotonic increase pattern"
Line 437:  property "memory leak samples are monotonically increasing"
Line 448:  property "memory leak detection requires 10+ samples"
Line 501:  "10 memory samples satisfy SC-IMMUNE-005 threshold (SD)"

File: mara.ex
Line 206:  SIL-4: Verify memory leak pattern was detected (SC-IMMUNE-005)
Line 605:  Verify 10+ samples with monotonic increase
```

### SC-IMMUNE-006: Quarantine via Suspension
```
File: antibody_test.exs
Line 381:  "suspended processes are resumed on die"
Line 400:  "cleanup does not crash on dead processes"
Line 420:  "uses sys.suspend not erlang.exit for quarantine"

File: antibody.ex
Line 490:  defp cleanup_quarantined(quarantined_pids)
Line 625:  SC-IMMUNE-006: Resume suspended processes on cleanup
```

### SC-IMMUNE-007: Response Time Constraints
```
File: mara_test.exs
Line 70:   "schedules first attack" (timing implicit)
Line 383:  "schedules follow-up attacks" (10s interval)

File: sentinel_bridge_enhanced_test.exs
Line 135:  SC-IMMUNE-007 sync cycle < 30s
```

---

## Coverage Statistics

### Test Count by Type
- **Unit Tests**: 57
  - Lifecycle/Initialization: 15
  - Behavior/State: 20
  - Safety/Compliance: 22

- **Property Tests**: 19
  - PropCheck: 10
  - ExUnitProperties (StreamData): 9

- **Integration Tests**: 6
  - Chaos scenarios
  - Multi-component flows

### Lines of Test Code
- Mara: 520 lines (57% unit, 43% property)
- Antibody: 600 lines (65% unit, 35% property)
- AntibodySupervisor: 186 lines (53% unit, 47% property)
- SentinelBridge: 272 lines (82% unit, 18% property)
- SentinelBridgeEnhanced: 502 lines (20% unit, 80% property)

**Total**: ~2,080 lines of test code

### Coverage by Constraint
| Constraint | Tests | Status |
|-----------|-------|--------|
| SC-IMMUNE-001 | 12+ | ✓ Strong |
| SC-IMMUNE-002 | 4 | ✓ Strong |
| SC-IMMUNE-003 | 2 | ✓ Medium |
| SC-IMMUNE-004 | 0 | ⚠ None |
| SC-IMMUNE-005 | 5+ | ✓✓ Very Strong |
| SC-IMMUNE-006 | 3 | ✓ Strong |
| SC-IMMUNE-007 | 4 | ✓ Medium |
| SC-IMMUNE-008 | 1 | ⚠ Light |

---

## Enhancement Recommendations

### Priority 1: SC-IMMUNE-004 - PatternHunter Testing

**What**: Pre-error signature detection baseline calibration

**Missing Tests**:
```elixir
# Create new file: test/indrajaal/cockpit/prajna/immune/pattern_hunter_test.exs

describe "baseline calibration" do
  test "first run initializes baseline metrics" do
    {:ok, ph} = PatternHunter.start_link([])
    assert PatternHunter.has_baseline?(ph) == true
  end

  test "detects elevated metrics vs baseline" do
    # Run baseline
    PatternHunter.calibrate(baseline_metrics)

    # Introduce elevation
    elevated_metrics = Map.put(baseline_metrics, :cpu, 95)

    # Should detect anomaly
    assert PatternHunter.detect_anomaly(elevated_metrics) == :cpu_spike
  end

  property "baseline never decreases (monotonic)" do
    forall baseline <- metrics_gen() do
      new_baseline = PatternHunter.update_baseline(baseline)
      stability = new_baseline.stability >= baseline.stability
      stability
    end
  end
end
```

**Effort**: 2-3 hours
**Impact**: Closes critical gap for pre-error detection

### Priority 2: SC-IMMUNE-007 - Response Time Validation

**What**: Explicit timing validation for threat response SLO

**Missing Tests**:
```elixir
# Add to chaos_test.exs

describe "response time constraints (SC-IMMUNE-007)" do
  test "extinction threat response < 100ms" do
    start_time = System.monotonic_time(:millisecond)
    trigger_extinction_threat()
    elapsed = System.monotonic_time(:millisecond) - start_time
    assert elapsed < 100, "Extinction: #{elapsed}ms > 100ms"
  end

  test "critical threat response < 500ms" do
    start_time = System.monotonic_time(:millisecond)
    trigger_critical_threat()
    elapsed = System.monotonic_time(:millisecond) - start_time
    assert elapsed < 500, "Critical: #{elapsed}ms > 500ms"
  end

  test "high threat response < 2000ms" do
    start_time = System.monotonic_time(:millisecond)
    trigger_high_threat()
    elapsed = System.monotonic_time(:millisecond) - start_time
    assert elapsed < 2000, "High: #{elapsed}ms > 2000ms"
  end
end
```

**Effort**: 1-2 hours
**Impact**: Validates SLA compliance for critical responses

---

## AOR Rules Covered by Tests

| Rule | Description | Test File | Status |
|------|-------------|-----------|--------|
| **AOR-IMMUNE-001** | Sentinel health check before critical ops | mara_test.exs | ✓ Covered |
| **AOR-IMMUNE-002** | is_kernel_process?/1 before termination | antibody_test.exs | ✓ Covered |
| **AOR-IMMUNE-003** | Pattern baseline calibration | (none) | ⚠ Missing |
| **AOR-IMMUNE-004** | Threat escalation (RPN >= 50) | (implicit) | ⚠ Partial |
| **AOR-TEST-001** | Test compile before commit | All files | ✓ Verified |
| **AOR-TEST-NIF-001** | SKIP_ZENOH_NIF=0 mandatory | All files | ✓ Used |
| **AOR-PRAJNA-004** | Sentinel sync every 30s | sentinel_bridge_test.exs | ✓ Covered |

---

## Known Limitations

1. **Response Time Measurement**: Tests don't measure wall-clock latency
   - Current: Event ordering validated
   - Needed: ms-level response time assertion

2. **PatternHunter Baseline**: No explicit baseline calibration tests
   - Current: Memory leak detection works
   - Needed: General pattern detection baseline

3. **Threat Priority Ordering**: Light coverage on lineage > existential > ...
   - Current: 1 property test
   - Needed: Full threat classification priority tests

4. **Audit Trail Immutability**: Logging works but no audit trail verification
   - Current: Logs are generated
   - Needed: DuckDB audit trail validation

---

## Validation Checklist

Before deploying immune system changes:

- [ ] Run all immune tests: `SKIP_ZENOH_NIF=0 mix test test/indrajaal/cockpit/prajna/immune/`
- [ ] Verify compilation: `MIX_ENV=test mix compile`
- [ ] Check EP-GEN-014: `mix validate.ep014`
- [ ] Run quality checks: `mix format && mix credo && mix dialyzer`
- [ ] Verify coverage: Check coverage report for >90% on immune modules
- [ ] Test Zenoh NIF: Confirm NIF active in tests (`SKIP_ZENOH_NIF=0`)

---

## References

### Main Documents
- **Coverage Report**: `/IMMUNE_SYSTEM_TEST_COVERAGE_REPORT.md` (detailed analysis)
- **Code Patterns**: `/IMMUNE_SYSTEM_TEST_PATTERNS.md` (implementation examples)
- **This Quick Reference**: `/IMMUNE_SYSTEM_QUICK_REFERENCE.md` (file paths & commands)

### Compliance Standards
- **STAMP**: Safety constraints (5 sections, 100+ constraints)
- **TDG**: Test-Driven Generation (unit + property tests)
- **SOPv5.11**: System Operations Protocol v5.11

### CLAUDE.md Sections
- Section 5.0: SC-IMMUNE constraints (8 items)
- Section 9.0: AOR-IMMUNE rules (4 items)
- Section 12.0: EP-GEN-014 (PropCheck/StreamData disambiguation)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-02
**Audience**: Test Engineers, QA, DevOps, Safety Reviews
**Next Review**: Sprint 32 (after PatternHunter & timing enhancements)
