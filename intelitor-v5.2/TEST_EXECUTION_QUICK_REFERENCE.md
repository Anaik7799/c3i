# Test Execution Quick Reference Guide
## Indrajaal Integration Test Commands & Verification

**Last Updated**: 2026-01-15
**Commands Status**: ✅ Ready to Execute

---

## Environment Setup

### 1. Enter Development Environment

```bash
devenv shell
```

**Verification**:
```bash
elixir --version       # Should be 1.19+
mix --version          # Should be available
OTP_VERSION=$(erl -eval 'erlang:halt(0).' 2>&1 | grep -o "OTP [0-9]*" | head -1)
echo "OTP Version: $OTP_VERSION"  # Should be 28+
```

### 2. Verify Key Environment Variables

```bash
echo "SKIP_ZENOH_NIF: $SKIP_ZENOH_NIF"  # Should output: 0 (NIF ACTIVE)
echo "MIX_ENV: $MIX_ENV"                # Should output: dev or test
echo "PATIENT_MODE: $PATIENT_MODE"      # Should output: enabled
```

### 3. Clean Build

```bash
rm -rf _build
mix compile
```

---

## Quick Test Commands

### All Tests (RECOMMENDED FOR RELEASE)

```bash
# Full suite with coverage report
SKIP_ZENOH_NIF=0 mix test --cover

# Expected: ~1000+ test cases
# Time: 20-45 minutes
# Output: Coverage report in coverage/index.html
```

### Fast Tests (Smoke Test)

```bash
# Core tests only (no E2E, no property shrinking)
SKIP_ZENOH_NIF=0 mix test --exclude slow --exclude e2e

# Time: 5-10 minutes
```

### By Category

```bash
# Fractal layer tests (ALL LAYERS)
mix test test/fractal/ --verbose

# Integration tests
mix test test/integration/ --timeout 300000

# Property tests
mix test test/property/ --timeout 600000

# Unit tests (fast)
mix test test/indrajaal/ --timeout 60000

# LiveView tests
mix test test/indrajaal_web/live/

# API controller tests
mix test test/indrajaal_web/controllers/

# Channel tests
mix test test/indrajaal_web/channels/

# Framework tests
mix test test/tdg/

# Compliance tests
mix test test/indrajaal/compliance/
```

### By Specific Layer (L1-L7)

```bash
# L1 System Context (API, load, chaos, security)
mix test test/fractal/l1_system_context_test.exs

# L2 Container Architecture (health, lifecycle, failover)
mix test test/fractal/l2_container_architecture_test.exs

# L3 Domain Architecture (resources, authorization)
mix test test/fractal/l3_domain_architecture_test.exs

# L4 Component Architecture (functions, invariants)
mix test test/fractal/l4_component_architecture_test.exs

# L5 Code Architecture (modules, patterns)
mix test test/fractal/l5_code_architecture_test.exs

# L6 Mesh Network (cluster, quorum)
mix test test/fractal/l6_mesh_network_test.exs

# L7 Federation (cross-holon)
mix test test/fractal/l7_federation_evolution_test.exs
```

### NIF-Specific Tests

```bash
# All NIF tests
SKIP_ZENOH_NIF=0 mix test --only zenoh_nif

# NIF unit tests (L1)
mix test test/fractal/l1_nif_unit_test.exs

# NIF integration (L2)
mix test test/fractal/l2_nif_integration_test.exs

# NIF system (L3)
mix test test/fractal/l3_nif_system_test.exs

# NIF stress tests (L4)
mix test test/fractal/l4_nif_stress_test.exs

# NIF safety tests (L5)
mix test test/fractal/l5_nif_safety_test.exs
```

### Property Tests

```bash
# All property tests (with shrinking)
mix test test/property/ test/fractal/

# Just the main property suite
mix test test/property/sopv511_framework_properties_test.exs

# Property tests only from fractal suite
mix test --only property

# With verbose output
mix test test/property/ --verbose
```

### BDD Feature Tests

```bash
# All BDD features (if Wallaby available)
mix test.features

# Specific feature file
mix test.features --name "GA Release"

# Features only from prajna
mix test.features --name prajna

# Features for zenoh
mix test.features --name zenoh
```

---

## Quality Gates

### Complete Quality Check

```bash
# 1. Compile check
echo "=== COMPILE CHECK ==="
mix compile --warnings-as-errors
if [ $? -ne 0 ]; then echo "FAILED: Compilation errors"; exit 1; fi

# 2. Format check
echo "=== FORMAT CHECK ==="
mix format --check-formatted
if [ $? -ne 0 ]; then echo "FAILED: Format issues"; exit 1; fi

# 3. Credo check
echo "=== CREDO CHECK ==="
mix credo --strict
if [ $? -ne 0 ]; then echo "FAILED: Code style issues"; exit 1; fi

# 4. Security check
echo "=== SECURITY CHECK ==="
mix sobelow --exit
if [ $? -ne 0 ]; then echo "FAILED: Security vulnerabilities"; exit 1; fi

# 5. Test run
echo "=== TEST RUN ==="
SKIP_ZENOH_NIF=0 mix test --cover
if [ $? -ne 0 ]; then echo "FAILED: Test failures"; exit 1; fi

echo "✅ ALL QUALITY GATES PASSED"
```

### Individual Gates

```bash
# Compilation only
mix compile --warnings-as-errors

# Formatting only
mix format --check-formatted

# Credo (code quality)
mix credo --strict

# Sobelow (security)
mix sobelow --exit

# Test (with coverage)
SKIP_ZENOH_NIF=0 mix test --cover

# Coverage report
open coverage/index.html
```

---

## Container Dependencies

### Verify Container Stack

```bash
# Status check
sa-status

# Expected output:
# indrajaal-db-prod:     RUNNING
# indrajaal-obs-prod:    RUNNING
# indrajaal-ex-app-1:    CREATED (may not be running)
```

### Start Container Stack

```bash
# Full stack startup (3 containers)
sa-up

# Expected: All 3 containers healthy within 30s

# Individual containers (if needed)
sa-db    # Database only
sa-obs   # Observability only
sa-app   # Application only
```

### Container Health

```bash
# Full health check
sa-health

# Individual health checks
curl -s http://localhost:5433 && echo "✅ Database"
curl -s http://localhost:4317 && echo "✅ OTEL"
curl -s http://localhost:4000/health && echo "✅ App"
```

### Shutdown (Clean)

```bash
# Graceful shutdown with checkpoint
sa-down

# Force cleanup (volumes deleted)
sa-clean
```

---

## Test Monitoring

### Watch Test Output

```bash
# With timestamps
SKIP_ZENOH_NIF=0 mix test --verbose 2>&1 | while IFS= read -r line; do echo "[$(date '+%H:%M:%S')] $line"; done

# With colors (for log readability)
SKIP_ZENOH_NIF=0 mix test --cover | tee test_run.log
```

### Coverage Report

```bash
# Generate coverage
SKIP_ZENOH_NIF=0 mix test --cover

# View in browser
open coverage/index.html

# Command line summary
grep "Total coverage" coverage/index.html
```

### Test Results Archive

```bash
# Save test results
SKIP_ZENOH_NIF=0 mix test --cover > test_results_$(date +%Y%m%d_%H%M%S).log 2>&1

# View recent results
tail -f test_results_*.log
```

---

## Troubleshooting

### Issue: "cannot add module after suite starts"

**Fix**: This is handled in test_helper.exs with `max_cases: 1`

```bash
# Force sequential compilation
rm -rf _build
mix test --max-failures 1
```

### Issue: "Connection refused" to database

**Fix**: Start container stack first

```bash
sa-up
sleep 10  # Wait for containers to be healthy
mix test
```

### Issue: "NIF not loaded" warning

**Verify**: Zenoh NIF is active

```bash
echo $SKIP_ZENOH_NIF  # Should output: 0
# If not:
export SKIP_ZENOH_NIF=0
```

### Issue: Property tests are very slow

**Expected**: Normal behavior with PropCheck shrinking

```bash
# Option 1: Run with timeout
mix test test/property/ --timeout 600000

# Option 2: Skip shrinking (development only)
export PROPCHECK_SHRINKING=false
mix test test/property/
```

### Issue: Timeout errors on slow system

**Fix**: Disable timeout for development

```bash
# In test_helper.exs:
# timeout: :infinity  (already set)

# Or pass to test:
mix test --timeout 300000  # 5 minutes
```

### Issue: Feature tests don't run

**Check**: Wallaby availability

```bash
# Feature tests require Wallaby/Puppeteer
# If not available:
MIX_ENV=test mix compile  # Verify compilation works
mix test --exclude feature  # Skip feature tests
```

---

## Performance Optimization

### Parallel Test Execution (Already Optimized)

```bash
# Current configuration (sequential, safe)
# max_cases: 1

# For high-parallelism systems (use with caution):
# This may cause race conditions - NOT RECOMMENDED
```

### Scheduler Configuration (Already Optimized)

```bash
# Current (SC-METRICS-003 compliant):
# ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"  (16 schedulers)
# MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8    (parallel deps)

# View current setup:
mix compile --verbose 2>&1 | grep -i "scheduler\|partition"
```

### Test Suite Breakdown

```
L0 Runtime:           ~5 seconds
L1 System:            ~30 seconds
L2 Container:         ~45 seconds
L3 Domain:            ~60 seconds
L4 Component:         ~90 seconds
L5 Code:              ~45 seconds
L6 Mesh:              ~60 seconds
L7 Federation:        ~45 seconds
Integration:          ~300 seconds
Property Tests:       ~180 seconds
API/Web Tests:        ~120 seconds
---
TOTAL (approx):       ~1000+ seconds (~17 minutes)
WITH COVERAGE:        ~1200-1500 seconds (~20-25 minutes)
```

---

## Continuous Integration (CI) Pattern

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - uses: erlef/setup-beam@v1
        with:
          otp-version: 28
          elixir-version: 1.19

      - name: Install dependencies
        run: mix deps.get

      - name: Compile with warnings as errors
        run: mix compile --warnings-as-errors

      - name: Format check
        run: mix format --check-formatted

      - name: Credo
        run: mix credo --strict

      - name: Security
        run: mix sobelow --exit

      - name: Run tests
        run: |
          export SKIP_ZENOH_NIF=0
          mix test --cover

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage.json
```

---

## Verification Checklist

### Pre-Commit

- [ ] `mix compile` succeeds with 0 warnings
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes
- [ ] `mix test test/indrajaal/` passes (unit tests)

### Pre-Push

- [ ] `SKIP_ZENOH_NIF=0 mix test` all pass
- [ ] `mix sobelow --exit` clean
- [ ] Coverage >95% for critical paths

### Pre-Release

- [ ] `SKIP_ZENOH_NIF=0 mix test --cover` all pass
- [ ] All fractal layer tests pass
- [ ] `mix test.features` (BDD) passes
- [ ] `sa-health` verifies container mesh healthy
- [ ] Coverage report reviewed and acceptable

---

## Command Summary Table

| Command | Purpose | Time | NIF |
|---------|---------|------|-----|
| `mix compile` | Verify compilation | 30s | Required |
| `mix test` | Run unit tests | 5m | Optional |
| `SKIP_ZENOH_NIF=0 mix test` | Full tests with NIF | 20m | Active |
| `mix test --cover` | With coverage | 25m | Optional |
| `SKIP_ZENOH_NIF=0 mix test --cover` | Full with NIF+coverage | 30m | Active |
| `mix test test/fractal/` | All layers | 12m | Optional |
| `mix test test/property/` | Property tests | 5m | Optional |
| `mix test.features` | BDD scenarios | 10m | Optional |
| `mix credo --strict` | Code quality | 2m | N/A |
| `mix sobelow --exit` | Security | 1m | N/A |
| `sa-up` | Start containers | 30s | N/A |
| `sa-health` | Container health | 5s | N/A |

---

## File Locations Quick Reference

```
Test Files:
  Fractal:      test/fractal/*.exs
  Integration:  test/integration/**/*.exs
  Domain:       test/indrajaal/**/*.exs
  Web/API:      test/indrajaal_web/**/*.exs
  Framework:    test/tdg/*.exs
  Properties:   test/property/*.exs
  BDD:          test/features/**/*.feature

Configuration:
  Main:         test/test_helper.exs
  Property Rules: .claude/rules/property-testing.md
  Test Rules:   .claude/rules/test-execution.md
  Framework:    docs/testing/FRACTAL_TEST_FRAMEWORK_MASTER_PLAN.md

Output:
  Coverage:     coverage/index.html
  Logs:         test_results_*.log
```

---

## Next Steps

1. **Setup**: `devenv shell`
2. **Verify**: `mix compile --warnings-as-errors`
3. **Quick test**: `SKIP_ZENOH_NIF=0 mix test test/fractal/`
4. **Full suite**: `SKIP_ZENOH_NIF=0 mix test --cover`
5. **Review coverage**: `open coverage/index.html`

---

**Status**: ✅ Ready to Execute
**Last Verified**: 2026-01-15
**Environment**: Production-Equivalent Configuration
