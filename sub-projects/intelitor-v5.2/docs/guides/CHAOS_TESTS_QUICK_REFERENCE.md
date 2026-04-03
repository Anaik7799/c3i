# Chaos Tests Quick Reference (v21.3.0-SIL6)

**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)

## Files

```
TEST FILE (783 lines):
/home/an/dev/ver/indrajaal-v5.2/test/indrajaal/cockpit/prajna/chaos_test.exs

DOCUMENTATION:
/home/an/dev/ver/indrajaal-v5.2/docs/verification/CHAOS_TESTS_SIL6_SPRINT_31_8_3.md
/home/an/dev/ver/indrajaal-v5.2/docs/verification/CHAOS_TESTS_EXECUTION_SUMMARY.md
```

## Quick Commands

### Verify Compilation
```bash
cd /home/an/dev/ver/indrajaal-v5.2
MIX_ENV=test mix compile
```
**Expected**: 0 errors, 0 warnings

### Run All Chaos Tests
```bash
# SC-TEST-005: SKIP_ZENOH_NIF=0 mandatory for all tests
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test test/indrajaal/cockpit/prajna/chaos_test.exs --tag chaos -v
```

### Run Single Test
```bash
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test test/indrajaal/cockpit/prajna/chaos_test.exs -k "supervisor recovers killed"
```

### Run Only Slow Tests (Full Integration)
```bash
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test test/indrajaal/cockpit/prajna/chaos_test.exs --tag slow
```

## Test Categories (23 Total)

### Category 1: Process Termination (31.8.3.1) - 4 tests
- Kill SmartMetrics → Verifies restart with new PID
- Kill Orchestrator → Verifies restart
- Other processes survive → Actor isolation test
- Multiple sequential kills → Cascade recovery

### Category 2: Network Partitions (31.8.3.2) - 4 tests
- Sentinel unavailable → Graceful degradation
- Watchdog independent → Self-healing
- Connectivity restored → Recovery mechanism
- Message ordering preserved → State consistency

### Category 3: Clock Skew (31.8.3.3) - 4 tests
- Timestamp ordering → Block chain integrity
- Out-of-order metrics → Resilience
- Monotonic timeouts → Timer correctness
- Restart persistence → State recovery

### Category 4: Property Tests (PropCheck) - 3 tests
- Valid child list → PC.atom()
- All processes alive → PC.boolean()
- Count consistency → PC.integer()

### Category 5: Property Tests (ExUnitProperties) - 3 tests
- PID uniqueness → SD.integer(1..5)
- Recovery bounded → SD.positive_integer(1..3)
- Concurrent queries → SD.list_of()

### Category 6: Integration (Full System) - 3 tests
- Cascading failures → Multi-process recovery
- Emergency shutdown → < 5s (SC-EMR-057)
- State consistency → Data integrity

### Category 7: Edge Cases - 2 tests
- Rapid fire kills → 5x sequential kills
- Concurrent queries → Deadlock-free

## Key Patterns

### Process Recovery Pattern
```elixir
# 1. Get PID
pid = Enum.find_value(children, fn {Module, p, _, _} -> p end)

# 2. Kill it
Process.exit(pid, :kill)
Process.sleep(150)  # Allow restart

# 3. Verify recovery
new_pid = Enum.find_value(new_children, fn {Module, p, _, _} -> p end)
assert is_pid(new_pid)
refute new_pid == pid
assert Process.alive?(new_pid)
```

### Graceful Degradation Pattern
```elixir
# Kill one service
Process.exit(pid, :kill)

# Verify other services survive
assert Process.alive?(other_pid)

# Supervisor recovers it
assert Process.alive?(restarted_pid)
```

## STAMP Constraints

| ID | Constraint | Tests |
|----|-----------|-------|
| SC-SIL6-008 | Chaos engineering | All 23 tests |
| SC-IMMUNE-001 | Digital immune system | Tests 5-8, 19-21 |
| SC-IMMUNE-007 | Response time | Tests 17, 20 |
| SC-EMR-057 | Emergency stop < 5s | Test 20 |
| SC-IMMUNE-006 | Quarantine semantics | Tests 1-4 |

## Expected Test Results (Pre-Implementation)

**Current Status**: FAIL (TDG-compliant - tests written before implementation)

Tests will fail until implementation adds:
1. Proper supervisor restart mechanism
2. Graceful degradation in SmartMetrics
3. State persistence in ImmutableState
4. Recovery timing constraints

## TDG Compliance

- [x] Tests written BEFORE implementation
- [x] Dual property testing (PropCheck + ExUnitProperties)
- [x] Generator disambiguation (PC./SD. prefixes)
- [x] STAMP constraints documented
- [x] TPS 5-level RCA context
- [x] 23+ distinct test cases
- [x] Unit + Integration + Edge case coverage

## Generator Syntax

### PropCheck (PC. prefix)
```elixir
property "test name" do
  forall x <- PC.integer() do
    # assertion
  end
end
```

### ExUnitProperties (SD. prefix)
```elixir
test "test name" do
  check all(x <- SD.integer()) do
    # assertion
  end
end
```

## Key Assertions

```elixir
# Process state
assert Process.alive?(pid)
refute restarted_pid == metrics_pid

# Supervisor consistency
counts.active == length(children)

# State validity
assert match?(:valid, chain_status)

# Timing constraints
assert shutdown_time < 5000  # SC-EMR-057
assert recovery_time < 500   # SIL-6 Biomorphic constraint
```

## Modules Under Test

```elixir
Indrajaal.Cockpit.Prajna.Supervisor     # main test subject
Indrajaal.Cockpit.Prajna.SmartMetrics
Indrajaal.Cockpit.Prajna.Orchestrator
Indrajaal.Cockpit.Prajna.SentinelBridge
Indrajaal.Cockpit.Prajna.ImmutableState
Indrajaal.Cockpit.Prajna.Watchdog
Indrajaal.Cockpit.Prajna.AiCopilot
```

## Test Execution Timeline

| Phase | Duration | Typical Output |
|-------|----------|----------------|
| Compilation | <30s | "0 warnings" |
| Test execution | 30-60s | "23 tests, X failures" |
| Property tests | 10-20s | "PropCheck: 100 shrinks" |

## Troubleshooting

### Timeout Errors
```
Expected: Tests handle :exit/{:timeout, _} gracefully
Solution: Try-catch blocks allow timeouts during chaos
```

### Process Not Found
```
Expected: Supervisor should restart killed processes
Solution: Add 150-200ms sleep before querying restarted process
```

### State Inconsistency
```
Expected: Multiple kills shouldn't corrupt supervisor state
Solution: Verify all child processes alive after chaos
```

## References

- **Supervisor Strategy**: `:one_for_one` (independent restart)
- **Recovery Time**: < 500ms (SIL-6 Biomorphic)
- **Shutdown Time**: < 5s (SC-EMR-057)
- **Process Sleep Intervals**:
  - Single restart: 100-150ms
  - Multiple restarts: 200-300ms
  - Shutdown: 5000ms

## Implementation Checklist

- [ ] Ensure supervisor uses :one_for_one strategy
- [ ] Add graceful degradation to SmartMetrics
- [ ] Implement state persistence in ImmutableState
- [ ] Verify recovery timing < 500ms
- [ ] Test graceful degradation under partition
- [ ] Validate timestamp ordering
- [ ] Run full test suite: `mix test --tag chaos`
- [ ] Verify all 23 tests pass
- [ ] Check coverage > 80%
- [ ] Review STAMP constraints

## Document Links

- **Full Specification**: `docs/verification/CHAOS_TESTS_SIL6_SPRINT_31_8_3.md`
- **Execution Summary**: `docs/verification/CHAOS_TESTS_EXECUTION_SUMMARY.md`
- **Test File**: `test/indrajaal/cockpit/prajna/chaos_test.exs`

---

## Related Documents

- [CLAUDE.md](../../CLAUDE.md) - System specifications and STAMP constraints
- [USER_OPERATIONS_GUIDE.md](../../USER_OPERATIONS_GUIDE.md) - User operations and command reference
- [testing.md](./testing.md) - Testing guidelines and patterns
- [comprehensive-testing-rules.md](./comprehensive-testing-rules.md) - Comprehensive testing standards
- [TEST_DEMO_INTEGRATION_MATRIX.md](./TEST_DEMO_INTEGRATION_MATRIX.md) - Test/demo integration matrix

---

**Status**: Ready for Compilation and Execution
**TDG Compliance**: Yes - Tests written before implementation
**SIL Level**: 6 (SIL-6 Biomorphic Extended)
**Last Updated**: 2026-01-11
