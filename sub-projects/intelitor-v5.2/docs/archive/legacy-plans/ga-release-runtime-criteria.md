# GA Release v21.1.0 - Runtime Verification Criteria

**Version**: 21.1.0 Founder's Covenant
**Date**: 2026-01-03
**Status**: Pre-Release Verification

---

## 1. RELEASE CRITERIA CHECKLIST

### 1.1 Pre-Flight Gates (MANDATORY)

| Gate | Criteria | Status | Command |
|------|----------|--------|---------|
| G1 | Compilation: 0 errors | PENDING | `mix compile --warnings-as-errors` |
| G2 | Format: All formatted | PENDING | `mix format --check-formatted` |
| G3 | Credo: 0 issues | PENDING | `mix credo --strict` |
| G4 | Sobelow: 0 high severity | PENDING | `mix sobelow --exit` |
| G5 | Tests: 0 failures | PENDING | `mix test` |
| G6 | Coverage: >= 80% | PENDING | `mix test --cover` |

### 1.2 Runtime Gates (MANDATORY)

| Gate | Criteria | Status | Verification |
|------|----------|--------|--------------|
| R1 | Phoenix starts | PENDING | Port 4000 responds |
| R2 | DB connection | PENDING | Ecto connects |
| R3 | Prajna Cockpit | PENDING | /prajna accessible |
| R4 | Guardian active | PENDING | Safety kernel running |
| R5 | Sentinel active | PENDING | Health monitoring |
| R6 | Zenoh mesh | PENDING | Pub/sub operational |

---

## 2. 7-LEVEL FRACTAL OPERATIONAL CHECK

### L1 - Function Level
- [ ] All public functions documented
- [ ] Type specs present for critical paths
- [ ] No undefined function warnings

### L2 - Module Level
- [ ] All modules compile
- [ ] Module dependencies valid
- [ ] No circular dependencies

### L3 - Domain Level
- [ ] 10 Ash domains aligned
- [ ] Domain APIs consistent
- [ ] Cross-domain calls validated

### L4 - Component Level
- [ ] Phoenix endpoint starts
- [ ] LiveView socket active
- [ ] Channel handlers ready

### L5 - System Level
- [ ] OTP application starts
- [ ] Supervision tree healthy
- [ ] All GenServers running

### L6 - Federation Level
- [ ] Erlang distribution ready
- [ ] Cluster configuration valid
- [ ] Node discovery functional

### L7 - Ecosystem Level
- [ ] External APIs configured
- [ ] Telemetry exporting
- [ ] Observability stack ready

---

## 3. TEST EXECUTION PLAN

### Run 1 - Full Suite Execution
```bash
SKIP_ZENOH_NIF=0 \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true PATIENT_MODE=enabled \
MIX_ENV=test mix test --cover 2>&1 | tee run1.log
```

### Run 2 - Verification Run
```bash
SKIP_ZENOH_NIF=0 \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true PATIENT_MODE=enabled \
MIX_ENV=test mix test --max-failures 0 2>&1 | tee run2.log
```

---

## 4. IMPACT ANALYSIS (1st-5th Order)

### 1st Order - Direct Code Changes
- lib/indrajaal/**/*.ex - Core modules
- lib/indrajaal_web/**/*.ex - Web layer
- test/**/*.exs - Test suite

### 2nd Order - Configuration
- mix.exs - Version 21.1.0
- config/*.exs - Environment configs
- devenv.nix - Development environment

### 3rd Order - Documentation
- CLAUDE.md - Agent instructions
- GEMINI.md - Architecture spec
- README.md - User documentation
- RELEASE_NOTES.md - Release changelog

### 4th Order - CI/CD
- .github/workflows/*.yml - GitHub Actions
- podman-compose*.yml - Container orchestration

### 5th Order - External
- Zenoh key prefixes: indrajaal/*
- OTEL service name: indrajaal
- API endpoints: /api/v1/*

---

## 5. ACCEPTANCE CRITERIA

**GA Release APPROVED when**:
- [ ] All G1-G6 gates PASS
- [ ] All R1-R6 gates PASS
- [ ] L1-L7 checks COMPLETE
- [ ] Test Run 1: 0 failures
- [ ] Test Run 2: 0 failures
- [ ] Coverage >= 80%
- [ ] No blocking issues

---

## 6. SIGN-OFF

| Role | Name | Status | Date |
|------|------|--------|------|
| Architect | Claude Opus 4.5 | PENDING | |
| QA | Claude Code | PENDING | |
| Release Manager | Abhijit Naik | PENDING | |

---

**STAMP Compliance**: SC-VAL-001, SC-CMP-025, SC-TEST-001
**Framework**: SOPv5.11 + TDG + STAMP
