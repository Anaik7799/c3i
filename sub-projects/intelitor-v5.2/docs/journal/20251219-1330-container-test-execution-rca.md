# Container Test Execution Failure - 5-Level RCA Analysis

**Date**: 2025-12-19T13:30:00+01:00
**Incident ID**: INC-20251219-001
**Severity**: C2-HIGH (Blocking Test Execution)
**STAMP Compliance**: SC-CNT-009, SC-TDG-001, AOR-CNT-001
**Status**: ANALYZED - REMEDIATION REQUIRED

---

## Executive Summary

Container-based test execution failed due to fundamental architectural gap: containers designed for demo/production mode cannot execute test suites. The issue manifests as PropCheck GenServer failures at compile-time and Ecto Repo startup conflicts.

---

## Issue Description

### Symptoms Observed

```
1. PropCheck.CounterStrike GenServer not alive
   File: test/indrajaal/authorization/access_matrix_test.exs:291

2. Ecto Repo not started (--no-start flag)
   File: test/support/data_case.ex:56
   Error: could not lookup Ecto repo Intelitor.Repo

3. Command timeout (exit code 143)
   Duration: >5 minutes
```

### Impact

| Metric | Value |
|--------|-------|
| Tests Blocked | 228 of 514 (C2-C5 levels) |
| C1 CRITICAL | PASSED (286 tests) |
| C2+ Tests | BLOCKED |
| GDE Goal Achievement | 55.6% (286/514) |

---

## 5-Level TPS Root Cause Analysis

### Level 1: Immediate Cause (WHAT happened?)

**Observation**: Tests fail when executed inside container with errors:
- PropCheck.CounterStrike GenServer not alive at compile time
- Ecto Repo not started when using `--no-start` flag

**Evidence**:
```elixir
# Error 1: PropCheck compile-time failure
** (EXIT) no process: the process is not alive or there's no process
currently associated with the given name, possibly because its
application isn't started

# Error 2: Ecto Repo failure
** (RuntimeError) could not lookup Ecto repo Intelitor.Repo because
it was not started or it does not exist
```

---

### Level 2: Contributing Cause (WHY did Level 1 happen?)

**Observation**: Container runs Phoenix server on port 4000, forcing use of `--no-start` flag

**Analysis**:
1. Phoenix server occupies port 4000 (PHX_PORT environment variable)
2. `mix test` without `--no-start` tries to start another Phoenix instance → port conflict
3. `mix test --no-start` prevents ALL applications from starting, including:
   - PropCheck.CounterStrike (required at compile-time for property test macros)
   - Ecto Repo (required for database tests)

**Evidence**:
```yaml
# From podman-compose-testing.yml lines 143-144
PHX_HOST: localhost
PHX_PORT: 4000
PHX_SERVER: "true"
```

---

### Level 3: Root Cause (WHY did Level 2 happen?)

**Observation**: Container entrypoint unconditionally starts Phoenix server

**Analysis**:
The container entrypoint script (`containers/sopv51-elixir-app.nix` lines 150-153) always executes:
```bash
exec ${pkgs.util-linux}/bin/setpriv --reuid=1000 --regid=1000 --init-groups \
  ${pkgs.bash}/bin/bash -c "cd /workspace && exec ${pkgs.elixir_1_19}/bin/mix phx.server"
```

No conditional logic for different execution modes (test vs. demo vs. dev).

**Evidence**:
```nix
# From sopv51-elixir-app.nix line 153
${pkgs.bash}/bin/bash -c "cd /workspace && exec ${pkgs.elixir_1_19}/bin/mix phx.server"
```

---

### Level 4: Systemic Cause (WHY did Level 3 happen?)

**Observation**: Container image designed ONLY for production/demo mode

**Analysis**:
1. Single-purpose container design: "run Phoenix server"
2. No multi-mode support architecture
3. MIX_ENV hardcoded to `demo` in container config (line 250)
4. No test infrastructure built into container (PropCheck app not started)

**Evidence**:
```nix
# From sopv51-elixir-app.nix line 250
"MIX_ENV=demo"  # Hardcoded, no flexibility
```

---

### Level 5: Organizational/Process Cause (WHY did Level 4 happen?)

**Observation**: Missing TDG-Container specification for test execution

**Analysis**:
1. **Missing Requirement**: No formal requirement for container-based test execution
2. **Design Gap**: Container architecture focused on demo deployment, not testing
3. **TDG Violation**: Tests written before container test infrastructure existed
4. **STAMP Gap**: No SC-CNT-TEST constraints defined for test execution in containers

**Root Cause Statement**:
> The container infrastructure was designed with a single-purpose architecture (demo/production)
> without considering test execution as a first-class use case. This violates the TDG principle
> that test infrastructure should precede or accompany code infrastructure.

---

## Affected Artifacts

### Files Requiring Updates

| File | Change Required | Priority |
|------|-----------------|----------|
| `containers/sopv51-elixir-app.nix` | Add multi-mode entrypoint | P0 |
| `podman-compose-testing.yml` | Add dedicated test container service | P0 |
| `scripts/container/test_mode_entrypoint.sh` | Create new file | P0 |
| `CLAUDE.md` | Add SC-CNT-TEST constraints | P1 |
| `docs/architecture/container-modes.md` | Document container modes | P1 |
| `test/support/container_test_helper.ex` | Create container test setup | P2 |

### Container Images

| Image | Current State | Required State |
|-------|---------------|----------------|
| `localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28` | Demo-only | Multi-mode support |
| NEW: `localhost/indrajaal-sopv51-test-runner:elixir-1.19-otp28` | N/A | Dedicated test image |

---

## STAMP Constraints (New/Updated)

### New Constraints Required

```mathematica
(* SC-CNT-TEST: Container Test Execution Safety *)
SC_CNT_TEST := {
  "SC-CNT-TEST-001" -> O[Container, SupportMultipleModes[{demo, test, dev, compile}]],
  "SC-CNT-TEST-002" -> O[TestContainer, StartRequiredApps[{PropCheck, Ecto, ExUnit}]],
  "SC-CNT-TEST-003" -> O[TestContainer, ¬StartPhoenixServer],
  "SC-CNT-TEST-004" -> O[Container, EntrypointModeSelection[ENV_VAR]],
  "SC-CNT-TEST-005" -> O[TestContainer, DatabaseConnectivity[Verified]]
}
```

### Updated Constraints

```mathematica
(* SC-CNT-009 Extension *)
SC_CNT_009_EXT := O[Container, NixOSContainers ∧ MultiModeSupport]

(* TDG-CNT: Container TDG Rules *)
TDG_CNT := {
  "TDG-CNT-001" -> O[_, ContainerDesign ⟹ TestModeFirst],
  "TDG-CNT-002" -> O[_, NewContainer ⟹ TestableByDefault],
  "TDG-CNT-003" -> O[_, ContainerImage ⟹ ModeValidationTest]
}
```

---

## AOR Rules (New)

```mathematica
(* AOR-CNT-TEST: Container Test Operation Rules *)
AOR_CNT_TEST := {
  "AOR-CNT-TEST-001" -> O[Agent, ContainerTest ⟹ UseTestModeContainer],
  "AOR-CNT-TEST-002" -> F[Agent, RunTestsInDemoContainer],
  "AOR-CNT-TEST-003" -> O[Agent, ContainerTestFail ⟹ CheckContainerMode],
  "AOR-CNT-TEST-004" -> O[Agent, PropCheckTest ⟹ VerifyPropCheckAppStarted]
}
```

---

## Remediation Plan

### Phase 1: Immediate Fix (P0)

1. **Create multi-mode entrypoint script**:
```bash
#!/usr/bin/env bash
# scripts/container/multi_mode_entrypoint.sh
MODE="${CONTAINER_MODE:-demo}"

case "$MODE" in
  test)
    exec mix test "$@"
    ;;
  compile)
    exec mix compile "$@"
    ;;
  dev)
    exec iex -S mix phx.server
    ;;
  demo|prod)
    exec mix phx.server
    ;;
esac
```

2. **Update sopv51-elixir-app.nix**:
   - Remove hardcoded `mix phx.server`
   - Add mode-aware entrypoint
   - Set default MIX_ENV based on CONTAINER_MODE

3. **Add test container service to podman-compose-testing.yml**:
```yaml
indrajaal-test-runner:
  image: localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28
  environment:
    CONTAINER_MODE: test
    MIX_ENV: test
    # ... other env vars
  command: ["mix", "test"]
```

### Phase 2: Infrastructure Hardening (P1)

1. Create dedicated test runner container image
2. Add container mode validation tests
3. Update CLAUDE.md with SC-CNT-TEST constraints
4. Add pre-commit hook for container mode verification

### Phase 3: Process Improvement (P2)

1. Update container design checklist
2. Add TDG-CNT to development workflow
3. Create container test execution runbook

---

## Prevention Measures

### Design Checklist for Future Containers

- [ ] Multi-mode support (test/dev/demo/prod)
- [ ] Mode selection via environment variable
- [ ] Test infrastructure built-in (PropCheck, ExUnit)
- [ ] Database connectivity verification at startup
- [ ] Health check for each mode
- [ ] Mode-specific resource limits
- [ ] TDG compliance verification

### CI/CD Integration

```yaml
# .github/workflows/container-validation.yml
container-mode-tests:
  - name: Verify test mode works
    run: |
      podman run -e CONTAINER_MODE=test \
        localhost/indrajaal-sopv51-elixir-app:$TAG \
        mix test --dry-run

  - name: Verify demo mode works
    run: |
      podman run -e CONTAINER_MODE=demo \
        localhost/indrajaal-sopv51-elixir-app:$TAG \
        curl -f http://localhost:4000/health
```

---

## Learnings

### Technical Learnings

1. **PropCheck Compile-Time Dependency**: PropCheck macros execute at compile time, requiring GenServer to be running before compilation begins. `--exclude property` does not help because the error occurs during compilation, not execution.

2. **Ecto Sandbox Pattern**: The Ecto sandbox pattern requires the Repo to be started before tests can run. This conflicts with `--no-start` flag.

3. **Single-Purpose Containers Are Fragile**: Containers designed for only one purpose become blocking points when other use cases emerge.

### Process Learnings

1. **TDG for Infrastructure**: Test infrastructure should be designed alongside production infrastructure, not as an afterthought.

2. **Container Mode as First-Class Concept**: Container execution mode should be an explicit, configurable parameter, not implicit in the entrypoint.

3. **STAMP for Containers**: Safety constraints should cover test execution, not just production behavior.

---

## Metrics

| Metric | Before | After (Expected) |
|--------|--------|------------------|
| Container modes supported | 1 (demo) | 4 (test/dev/demo/prod) |
| Test execution success rate | 55.6% | 100% |
| Mode switch time | N/A (manual) | <5s (env var) |
| Container startup to test | Impossible | <30s |

---

## References

- **Incident**: INC-20251219-001
- **STAMP**: SC-CNT-009, SC-CNT-010, SC-CNT-012
- **TDG**: TDG-CNT-001 to TDG-CNT-003 (new)
- **AOR**: AOR-CNT-TEST-001 to AOR-CNT-TEST-004 (new)
- **Files Analyzed**:
  - `containers/sopv51-elixir-app.nix` (275 lines)
  - `podman-compose-testing.yml` (371 lines)
  - `test/indrajaal/authorization/access_matrix_test.exs` (line 291)
  - `test/support/data_case.ex` (line 56)

---

**Document Generated**: 2025-12-19T13:30:00+01:00
**Author**: Claude Code (Opus 4.5)
**Framework**: SOPv5.11 + TPS 5-Level RCA + STAMP/STPA
