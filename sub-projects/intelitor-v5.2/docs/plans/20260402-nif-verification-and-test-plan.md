# NIF Verification & Full Test Execution Plan
**Version**: v21.3.2-SIL6
**Created**: 2026-04-02 13:22 CEST
**Framework**: SOPv5.11 + STAMP + TDG + Fractal Coverage

---

## 1. Pre-Fix Status

### 1.1 Rustler Version Fix Completed ✅

| NIF | Before | After | Status |
|-----|--------|-------|--------|
| `math_engine` | `0.36.1` | `0.37` | ✅ FIXED |
| `zenoh_nif` | `0.37` | `0.37` | ✅ OK |
| `lineage_auth` | `0.37` | `0.37` | ✅ OK |

**Build Result**: ✅ `cargo build --release` completed in 3.23s

**Journal**: `docs/journal/20260402-1530-nif-rustler-version-fix.md`

---

## 2. Next Steps

### 2.1 Step 1: Recompile Elixir NIFs

```bash
# Compile all NIFs with Elixir
mix rustler.compile

# Verify NIFs are loaded
mix run -e "IO.inspect(Indrajaal.Native.MathEngine.hello(), label: \"math_engine\")"
mix run -e "IO.inspect(Indrajaal.Native.Zenoh.verify_proof_token(\"test\", \"token\"), label: \"zenoh\")"
```

### 2.2 Step 2: Run NIF Unit Tests

```bash
# L1: NIF Unit Tests
mix test test/fractal/l1_nif_unit_test.exs --trace

# L2: NIF Integration Tests  
mix test test/fractal/l2_nif_integration_test.exs --trace

# L3: NIF System Tests
mix test test/fractal/l3_nif_system_test.exs --trace
```

### 2.3 Step 3: Run Core Test Suite

```bash
# FPPS Consensus (already verified: 52 tests, 0 failures)
mix test test/indrajaal/core/fpps_consensus_test.exs --trace

# TUI Tests (already verified: 33 tests, 0 failures)
mix test test/indrajaal/cockpit/tui_ansi_dashboard_test.exs --trace

# Safety Pattern Hunter (already verified: 39 tests, 0 failures)
mix test test/indrajaal/safety/sentinel_pattern_hunter_calibration_test.exs --trace
```

### 2.4 Step 4: Run Wallaby E2E Tests

```bash
# Requires Phoenix running
mix test test/indrajaal_web/live/prajna/ --trace
mix test test/indrajaal_web/live/admin/ --trace
mix test test/indrajaal_web/live/operations/ --trace
mix test test/indrajaal_web/live/analytics/ --trace
```

### 2.5 Step 5: Full Coverage Report

```bash
mix test --cover
mix coverage.html
```

---

## 3. Verification Checklist

### NIF Verification
- [ ] `mix rustler.compile` succeeds
- [ ] `Indrajaal.Native.MathEngine` loads
- [ ] `Indrajaal.Native.Zenoh` loads
- [ ] `Indrajaal.Native.LineageAuth` loads

### Fractal Layer Tests
- [ ] L1 NIF unit tests pass
- [ ] L2 NIF integration tests pass
- [ ] L3 NIF system tests pass

### Core Tests
- [ ] FPPS consensus tests pass
- [ ] TUI ANSI dashboard tests pass
- [ ] Safety pattern hunter tests pass

### Wallaby E2E
- [ ] All cockpit pages pass
- [ ] All operations pages pass
- [ ] All analytics pages pass

### Coverage
- [ ] Overall coverage > 95%
- [ ] Critical path coverage = 100%

---

## 4. Expected Outcome

After all steps complete:

| Metric | Target | Status |
|--------|--------|--------|
| Rustler version mismatches | 0 | ✅ FIXED |
| NIF tests failing | 0 | PENDING |
| Core tests passing | 100% | PARTIAL |
| Wallaby E2E passing | 100% | PENDING |
| Coverage | > 95% | PENDING |

---

**Document Status**: READY FOR EXECUTION
**Created**: 2026-04-02 13:22 CEST
**Version**: v21.3.2-SIL6
