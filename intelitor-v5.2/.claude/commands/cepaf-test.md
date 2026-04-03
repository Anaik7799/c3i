---
description: F# Expecto test runner — start, stop, status, results, logs via MCP
allowed-tools: mcp__sentinel-zenoh__test_fsharp_start, mcp__sentinel-zenoh__test_fsharp_stop, mcp__sentinel-zenoh__test_fsharp_status, mcp__sentinel-zenoh__test_fsharp_results, mcp__sentinel-zenoh__test_fsharp_logs, Read
argument-hint: [run|status|results|logs|stop] [--level 1-5] [--verbose]
---

# F# Test Runner (SC-NET-001, SC-FFI-001)

Execute F# Expecto tests via MCP test agent with 5 regression levels.

## Usage
```
/cepaf-test run                # Run ALL 5 regression levels
/cepaf-test run --level 1      # Level 1: Compile only
/cepaf-test run --level 1,2    # Levels 1+2: Compile + Full Tests
/cepaf-test status             # Check current run status
/cepaf-test results            # Get recent test results
/cepaf-test logs               # Get failure stack traces
/cepaf-test stop               # Stop current run
```

## Regression Levels (5-Level Fractal)
| Level | Name | Tests | Time | STAMP |
|-------|------|-------|------|-------|
| 1 | Compile | F# build check | ~30s | SC-NET-001 |
| 2 | FullTests | 770+ Expecto tests | ~2-5min | SC-COV-001 |
| 3 | SIL6 | Safety-critical tests | ~3min | SC-SIL6-001 |
| 4 | Quality | Credo + format | ~1min | SC-QUA-001 |
| 5 | Health | Container health | ~30s | SC-IMMUNE-001 |

## Commands

### Start Test Run
`test_fsharp_start(levels: [1,2,3,4,5], timeout_s: 900, verbose: true)`
- Levels 1-5 map to regression depth
- Default timeout: 15 minutes
- Returns run_id for tracking

### Check Status
`test_fsharp_status()` — Returns:
- State: idle | running | completed | failed
- Current level being executed
- Progress percentage
- Elapsed time

### Get Results
`test_fsharp_results(count: 5)` — Returns:
- Last N run summaries
- Pass/fail/skip counts per level
- Duration per level
- Overall verdict

### Get Failure Logs
`test_fsharp_logs(count: 10)` — Returns:
- Stack traces for failures
- Error context with file:line
- Related STAMP constraints
- Suggested fixes

### Stop Run
`test_fsharp_stop(run_id: "")` — Cancels within 1s

## Workflow: Full Regression
1. Start: `test_fsharp_start(levels: [1,2,3,4,5], verbose: true)`
2. Monitor: `test_fsharp_status()` (poll every 30s)
3. On completion: `test_fsharp_results(count: 1)`
4. On failure: `test_fsharp_logs(count: 20)`
5. Report with STAMP constraint mapping

## F# Test Project
- **Project**: `lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj`
- **Framework**: Expecto (not xUnit/NUnit)
- **Tests**: 770+ across 30+ test lists
- **Key lists**: ZenohFfiBridge, MathematicalSystemMonitor, DigitalTwin, SmokeTest
- **Env**: LD_LIBRARY_PATH must include target/release/ for Zenoh FFI tests

## Mathematical Foundation

**Test Reliability**: $R = 1 - \prod_{i=1}^{n}(1 - r_i)$ — probability of detecting at least one defect

**Coverage**: $C = \frac{|tested\_paths|}{|total\_paths|}$ — fraction of execution paths exercised

**Defect Escape Rate**: $DER = \frac{D_{prod}}{D_{total}}$ — defects found in production vs total

**Regression Level Coverage**: $C_L = \frac{\sum_{l=1}^{5} w_l \cdot pass_l}{\sum_{l=1}^{5} w_l}$ — weighted pass rate

## Direct CLI (alternative)
```bash
# Via devenv
cepaf-test                          # Run ALL
cepaf-test "ZenohFfiBridge"         # Filter by test list

# Via dotnet
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- \
  --filter-test-list "ZenohFfiBridge" --summary
```
