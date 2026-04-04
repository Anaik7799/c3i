---
paths: test/**/*.exs
globs: ["test/**/*.exs", "*.exs"]
---

# Mandatory Test Execution Rules

## SC-TEST-NIF-001: Zenoh NIF ACTIVE by Default

**CRITICAL**: All test commands MUST include `SKIP_ZENOH_NIF=0` to ensure NIF is ACTIVE.

### Mandatory Environment Variables for Tests (SC-METRICS-003)

```bash
SKIP_ZENOH_NIF=0 \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
MIX_ENV=test mix test [args]
```

### SC-METRICS-003: Parallelization MANDATORY

All test commands MUST include:
- `ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16"` (16 schedulers, 16 dirty I/O)
- `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8` (parallel dependency compilation)

### Why SKIP_ZENOH_NIF=0 (NIF Active)

1. **Production Parity**: Tests must match production NIF behavior
2. **Full Coverage**: NIF code paths are tested with real implementation
3. **Integration Testing**: Zenoh messaging verified end-to-end
4. **Runtime Transparency**: Full observability stack active during tests

### Validation

Before running tests, verify:
```bash
echo $SKIP_ZENOH_NIF  # Must output: 0 (NIF active)
```

### Using devenv Commands (Recommended)

```bash
devenv shell
test              # Automatically includes all required env vars with NIF active
test-cover        # With coverage, includes all required env vars with NIF active
test-e2e          # Wallaby E2E browser tests with Chrome via NixOS (SC-COV-008)
```

### SC-COV-008: Wallaby E2E Browser Testing

E2E browser tests use Wallaby + Chrome/chromedriver via NixOS devenv.

**Activation**: Set `WALLABY_ENABLED=true` or `TEST_TYPE=e2e` environment variable.

```bash
# Run Wallaby E2E tests (full mandatory env)
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test --only wallaby

# Or use the devenv command (recommended)
test-e2e
```

**Key files**:
- `config/wallaby.exs` — Chrome driver config, endpoint `server: true`
- `config/test.exs` — Conditional `import_config "wallaby.exs"` at end
- `test/test_helper.exs` — Conditional Wallaby start/stop + `:wallaby` tag exclude
- `test/support/feature_case.ex` — `IndrajaalWeb.FeatureCase` template
- `test/support/wallaby_page_objects.ex` — 23+ page object modules

**Requirements**:
- `chromium` and `chromedriver` packages in devenv.nix
- PostgreSQL container running on port 5433 (`indrajaal-db-prod`)
- Tests use `@moduletag :wallaby` and `async: false`
- Ecto Sandbox metadata passed via `Phoenix.Ecto.SQL.Sandbox.metadata_for/2`

**AOR Rules**:
- **AOR-COV-006**: ALL LiveView pages MUST have Wallaby E2E tests
- **AOR-E2E-001**: Wallaby tests MUST use `IndrajaalWeb.FeatureCase` (not raw ExUnit)
- **AOR-E2E-002**: Normal `mix test` MUST NOT trigger Wallaby (excluded by default)

### AOR Rules

- **AOR-TEST-NIF-001**: ALL test invocations MUST set SKIP_ZENOH_NIF=0
- **AOR-TEST-NIF-002**: Tests MUST use real Zenoh NIF implementations
- **AOR-TEST-NIF-003**: Fallback mode (SKIP_ZENOH_NIF=1) only for debugging

### STAMP Constraints

- **SC-TEST-NIF-001**: SKIP_ZENOH_NIF=0 MANDATORY for all test runs
- **SC-TEST-NIF-002**: Test environment MUST use production NIFs
- **SC-TEST-NIF-003**: NIF code paths MUST be tested

### Error Handling

If Zenoh router is not available, tests should gracefully handle connection failures:
```
[warning] [ZenohSession] Connection failed: "Unable to connect..."
```
This is expected behavior when zenoh router is not running - tests continue with fallback.
