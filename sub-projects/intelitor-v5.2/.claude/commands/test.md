---
description: SIL-6 test execution with NIF, Zenoh telemetry, dual property testing, and coverage analysis
allowed-tools: Bash(mix:*), Bash(MIX_ENV=test:*), mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_pub, mcp__sentinel-zenoh__zenoh_query, Read, Grep
argument-hint: [test-path] [--seed N] [--trace] [--cover]
---

# Test Command (SC-METRICS-003, SC-TEST-NIF-001, $\Omega_4$ TDG)

SIL-6 test execution with NIF active, Zenoh telemetry, and 5-level fractal coverage.

## Mathematical Foundation

**Test Completeness** $\mathcal{T}$:
$$\mathcal{T}(S) \iff |\text{Pass}| = |\text{Total}| \wedge \text{Coverage}(S) \geq 0.95$$

**Dual Property Testing** ($\Omega_4$):
$$\forall p \in \text{Properties}: \text{PropCheck}(p) \wedge \text{ExUnitProperties}(p)$$

**6-Level Fractal Coverage**:
$$\text{Coverage} = \bigwedge_{i=1}^{6} L_i, \quad L_1 = \text{Unit}, L_2 = \text{Integration}, L_3 = \text{BDD}, L_4 = \text{Property}, L_5 = \text{Formal}, L_6 = \text{E2E Browser}$$

## Execute

```bash
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test $ARGUMENTS
```

## CRITICAL Requirements
- **SC-TEST-NIF-001**: `SKIP_ZENOH_NIF=0` MANDATORY
- **SC-METRICS-003**: 16 schedulers MANDATORY
- **EP-GEN-014**: PropCheck/StreamData aliases (PC/SD) required

## Post-Test Verification (SIL-6)

1. Summarize pass/fail counts
2. For failures: test name, file:line, error, SC-* constraint
3. Check EP-GEN-014 (PropCheck/StreamData alias conflict)
4. **Health check**: `sentinel(action: "health")` — verify post-test health
5. **FFI verify**: `zenoh_query(action: "verify")` — NIF invariants intact
6. **Publish**: `zenoh_pub(key: "indrajaal/test/results", payload: "{summary}")`
7. Verify: `:erlang.system_info(:schedulers_online)` = 16

## SIL-6 SDLC Coverage

| Phase | Test Level | Constraint |
|-------|-----------|-----------|
| **Impl** | Unit (ExUnit) | SC-COV-001 |
| **Test** | Property (PropCheck+SD) | SC-PROP-023, $\Omega_4$ |
| **Runtime** | Integration (containers) | SC-COV-002 |
| **Evolution** | Regression tracking | SC-GDE-002 |

## E2E Browser Tests (Level 6 — Wallaby + Chrome)

```bash
# Activate Wallaby E2E mode
WALLABY_ENABLED=true \
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test --only wallaby
```

Or use: `test-e2e` (devenv command, includes all env vars).

- **FeatureCase**: `use IndrajaalWeb.FeatureCase, async: false`
- **Tag**: `@moduletag :wallaby`
- **Config**: `config/wallaby.exs` (Chrome headless, Ecto Sandbox, server: true)

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-TEST-NIF-001 | SKIP_ZENOH_NIF=0 mandatory |
| SC-METRICS-003 | 16 schedulers mandatory |
| SC-COV-001 | 100% critical path coverage |
| SC-COV-002 | >= 95% runtime coverage |
| SC-COV-008 | Wallaby E2E for all LiveView pages |
| SC-PROP-023 | PropCheck/StreamData disambiguation |
