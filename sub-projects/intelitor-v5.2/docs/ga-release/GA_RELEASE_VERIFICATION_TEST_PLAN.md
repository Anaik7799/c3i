# GA Release v21.3.0-SIL6 Verification Test Plan
**Document**: VTP-GA-21.3.0
**Date**: 2026-01-03 (Updated: 2026-03-19)
**Status**: ACTIVE
**STAMP Compliance**: SC-CMD-001 to SC-CMD-029

## 1. Executive Summary

This Verification Test Plan (VTP) defines the comprehensive testing strategy for validating all 102 devenv shell commands (32 core + 70 extended) prior to GA Release v21.3.0-SIL6. The plan ensures 100% runtime functional coverage with documented STAMP constraints, AOR rules, TDG specifications, and FMEA mitigations.

### 1.1 Scope
- **Commands**: 102 devenv shell commands across 18 categories (32 core verified)
- **Coverage Target**: 100% runtime functional coverage
- **Test Types**: Unit, Integration, BDD, Property, Stress
- **Artifacts**: 6 BDD feature files, 1 verification script, 1 analysis document

### 1.2 Success Criteria
| Metric | Target | Verification |
|--------|--------|--------------|
| Command Pass Rate | 100% | All 32 core commands execute successfully |
| STAMP Compliance | 100% | All SC-CMD-* constraints verified |
| BDD Scenario Coverage | 100% | All 49 scenarios pass |
| FMEA Mitigations | 100% | All RPN > 50 mitigated |
| Prerequisites | 7/7 | All tools available |
| Dependencies | 9/9 | All files exist |

## 2. Test Environment

### 2.1 Prerequisites
```bash
# Mandatory tools
elixir >= 1.19.0
mix >= 1.19.0
podman >= 5.4.1
dotnet >= 10.0.0
psql >= 17.0
git >= 2.40

# Development environment
devenv shell
```

### 2.2 Container Stack
| Container | Image | Ports | Purpose |
|-----------|-------|-------|---------|
| indrajaal-db-prod | postgres:17-timescaledb | 5433 | PostgreSQL + TimescaleDB |
| indrajaal-obs-prod | custom | 4317, 4318, 9090, 3000, 3100 | OTEL + Prometheus + Grafana |
| indrajaal-ex-app-1 | custom | 4000, 4001, 6379 | Phoenix + FLAME + Redis |
| zenoh-router | eclipse-zenoh/zenoh:1.2 | 7447, 8000 | Zenoh control plane |

### 2.3 Environment Variables
```bash
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
SKIP_ZENOH_NIF=0
MIX_ENV=test
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_test
```

## 3. Test Categories

### 3.1 Category A: Application Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| app | SC-CMD-001 | Integration | 30s |
| app-start | SC-CMD-002 | Integration | 60s |
| app-iex | SC-CMD-003 | Interactive | 30s |

**Test Procedure**:
1. Start containers via `sa-up`
2. Execute command
3. Verify HTTP 200 on localhost:4000/health
4. Verify IEx console for `app-iex`

### 3.2 Category B: Compilation Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| compile | SC-CMD-004 | Unit | 180s |
| compile-strict | SC-CMD-005 | Unit | 180s |

**Test Procedure**:
1. Execute compile command
2. Verify NO_TIMEOUT and PATIENT_MODE env vars
3. Check log output in ./data/tmp/1-compile.log
4. Verify 0 errors for regular compile
5. Verify warning detection for compile-strict

### 3.3 Category C: Quality Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| quality | SC-CMD-006 | Unit | 120s |
| quality-full | SC-CMD-007 | Unit | 300s |

**Test Procedure**:
1. Execute quality command
2. Verify format + credo execution order
3. For quality-full, verify dialyzer + sobelow inclusion
4. Check combined exit code

### 3.4 Category D: Testing Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| test | SC-CMD-008 | Integration | 600s |
| test-cover | SC-CMD-009 | Integration | 900s |

**Test Procedure**:
1. Ensure database is running
2. Verify SKIP_ZENOH_NIF=0
3. Execute tests
4. For test-cover, verify coverage report generation
5. Check coverage >= 95%

### 3.5 Category E: Standalone Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| sa-up | SC-CMD-010 | Integration | 120s |
| sa-down | SC-CMD-011 | Integration | 30s |
| sa-clean | SC-CMD-012 | Integration | 30s |
| sa-status | SC-CMD-013 | Unit | 5s |
| sa-logs | SC-CMD-014 | Unit | 10s |

**Test Procedure**:
1. Execute sa-up, verify 4 containers running (zenoh-router + db + obs + app)
2. Check ports 4000, 4317, 5433, 7447 active
3. Execute sa-status, verify output
4. Execute sa-logs, verify log streaming
5. Execute sa-down, verify graceful stop
6. Execute sa-clean, verify volume removal

Note: prod-standalone stack = 4 containers (zenoh-router + db + obs + app). Full-mesh = 15 containers.

### 3.6 Category F: Standalone Partial (P1)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| sa-db | SC-CMD-015 | Integration | 30s |
| sa-obs | SC-CMD-016 | Integration | 30s |
| sa-app | SC-CMD-017 | Integration | 60s |

**Test Procedure**:
1. Stop all containers first
2. Execute sa-db, verify only port 5433 active
3. Execute sa-obs, verify ports 4317, 9090, 3000 active
4. Execute sa-app, verify port 4000 active

### 3.7 Category G: Standalone Runtime (P1)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| sa-test | SC-CMD-018 | Integration | 300s |
| sa-ux | SC-CMD-019 | Integration | 180s |
| sa-orchestrate | SC-CMD-020 | Integration | 300s |

**Test Procedure**:
1. Ensure standalone stack running
2. Execute F# runtime tests
3. Verify ComprehensiveRuntimeTests.fsx execution
4. Check test summary output

### 3.8 Category H: Database Commands (P0)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| db-setup | SC-CMD-021 | Integration | 60s |
| db-reset | SC-CMD-022 | Integration | 60s |
| db-migrate | SC-CMD-023 | Integration | 30s |
| db-console | SC-CMD-024 | Interactive | 10s |

**Test Procedure**:
1. Ensure PostgreSQL on port 5433
2. Execute db-setup, verify database created
3. Execute db-migrate, verify schema version
4. Execute db-console, verify psql prompt

### 3.9 Category I: CEPAF Commands (P1)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| cockpitf | SC-CMD-025 | Integration | 120s |
| cepaf-build | SC-CMD-026 | Unit | 180s |

**Test Procedure**:
1. Verify .NET 10.0 SDK installed
2. Execute cepaf-build, verify successful compilation
3. Execute cockpitf status, verify output

### 3.10 Category J: Reporting Commands (P2)
| Command | STAMP | Test Type | Duration |
|---------|-------|-----------|----------|
| envelope | SC-CMD-027 | Unit | 10s |
| todo | SC-CMD-028 | Unit | 5s |
| help | SC-CMD-029 | Unit | 5s |

**Test Procedure**:
1. Execute each command
2. Verify expected output format
3. Check all sections present

## 4. BDD Test Scenarios

### 4.1 Feature Files
| File | Scenarios | Priority |
|------|-----------|----------|
| startup.feature | 6 | P0 |
| development.feature | 9 | P0 |
| database.feature | 7 | P0 |
| testing.feature | 8 | P0 |
| cepaf.feature | 9 | P1 |
| operations.feature | 10 | P2 |

### 4.2 Scenario Matrix
```
Total Scenarios: 49
├── Happy Path: 28 (one per command)
├── Error Recovery: 12 (FMEA scenarios)
├── TDG Property: 5 (determinism, idempotency)
└── Edge Cases: 4 (port conflicts, timeouts)
```

## 5. Property Tests (TDG)

### 5.1 TDG-CMD-001: Compilation Idempotency
```elixir
property "compile is idempotent" do
  forall files <- PC.list(PC.utf8()) do
    # First compile
    {output1, _} = System.cmd("mix", ["compile"])
    # Second compile
    {output2, _} = System.cmd("mix", ["compile"])
    # Should show no new files
    String.contains?(output2, "Compiling 0 files")
  end
end
```

### 5.2 TDG-CMD-002: Test Determinism
```elixir
property "tests are deterministic" do
  forall _seed <- PC.integer() do
    {result1, _} = System.cmd("mix", ["test"])
    {result2, _} = System.cmd("mix", ["test"])
    result1 == result2
  end
end
```

### 5.3 TDG-CMD-003: Container Lifecycle
```elixir
property "containers survive restart cycles" do
  forall cycles <- PC.pos_integer() do
    for _ <- 1..min(cycles, 5) do
      System.cmd("sa-up", [])
      System.cmd("sa-down", [])
    end
    # Final state should be clean
    {output, 0} = System.cmd("podman", ["ps", "-q"])
    output == ""
  end
end
```

## 6. FMEA Mitigations

### 6.1 High-Risk Failure Modes (RPN > 50)

| ID | Failure Mode | RPN | Mitigation | Verification |
|----|--------------|-----|------------|--------------|
| FMEA-001 | DB not running | 72 | Pre-check sa-db | Port 5433 test |
| FMEA-002 | Port conflict | 56 | Port availability check | ss -tlnp |
| FMEA-003 | .NET missing | 54 | dotnet version check | Version >= 10.0 |

### 6.2 Recovery Procedures

**FMEA-001 Recovery**:
```bash
# If database not running
sa-db                    # Start DB container only
sleep 5                  # Wait for startup
pg_isready -h localhost -p 5433  # Verify
```

**FMEA-002 Recovery**:
```bash
# If port conflict
ss -tlnp | grep :4000    # Identify process
kill -15 <pid>           # Graceful stop
sa-up                    # Retry start
```

**FMEA-003 Recovery**:
```bash
# If .NET missing in devenv
nix develop              # Enter Nix shell
dotnet --version         # Verify
```

## 7. Test Execution Schedule

### 7.1 Quick Verification (15 minutes)
```bash
# Run verification script
elixir scripts/ga-release/runtime_command_verifier.exs

# Expected output:
# - Prerequisites: 7/7 PASSED
# - Dependencies: 9/9 PASSED
# - Quick checks: 5/5 PASSED
```

### 7.2 Full Verification (2 hours)
```
Phase 1: Environment Setup (5 min)
├── devenv shell
├── Prerequisites check
└── File dependencies check

Phase 2: Infrastructure (15 min)
├── sa-up
├── Port verification
└── Container health check

Phase 3: Compilation (20 min)
├── compile
├── compile-strict
└── Log verification

Phase 4: Quality (25 min)
├── quality
├── quality-full
└── 0 issues verification

Phase 5: Testing (35 min)
├── test
├── test-cover
└── Coverage report

Phase 6: Database (10 min)
├── db-setup
├── db-migrate
└── db-console

Phase 7: CEPAF (15 min)
├── cepaf-build
├── cockpitf status
└── sa-test

Phase 8: Reporting (5 min)
├── envelope
├── todo
└── help

Phase 9: Cleanup (5 min)
├── sa-down
├── sa-clean
└── Orphan check
```

## 8. Reporting

### 8.1 Test Report Format
```
╔═══════════════════════════════════════════════════════════════╗
║  GA RELEASE v21.3.0-SIL6 VERIFICATION REPORT                  ║
╠═══════════════════════════════════════════════════════════════╣
║  Date: YYYY-MM-DD HH:MM:SS                                    ║
║  Status: [PASS/FAIL]                                          ║
╠═══════════════════════════════════════════════════════════════╣
║  SUMMARY                                                       ║
║  ├── Commands Tested: 32/32 core (102 total)                  ║
║  ├── STAMP Verified: 29/29                                    ║
║  ├── BDD Scenarios: 49/49                                     ║
║  ├── FMEA Mitigated: 5/5                                      ║
║  └── Coverage: 95%+                                           ║
╠═══════════════════════════════════════════════════════════════╣
║  CATEGORIES                                                    ║
║  ├── App Commands: ✓ PASS                                     ║
║  ├── Compilation: ✓ PASS                                      ║
║  ├── Quality: ✓ PASS                                          ║
║  ├── Testing: ✓ PASS                                          ║
║  ├── Standalone: ✓ PASS                                       ║
║  ├── Database: ✓ PASS                                         ║
║  ├── CEPAF: ✓ PASS                                            ║
║  └── Reporting: ✓ PASS                                        ║
╚═══════════════════════════════════════════════════════════════╝
```

### 8.2 Issue Tracking
- Critical issues block release
- High issues require mitigation documentation
- Medium issues tracked for post-GA
- Low issues logged for future sprints

## 9. Sign-Off

### 9.1 Approval Matrix
| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Lead | | | |
| Dev Lead | | | |
| Ops Lead | | | |
| Release Manager | | | |

### 9.2 Release Criteria
- [ ] All 32 core commands verified (102 total)
- [ ] 100% STAMP compliance
- [ ] All BDD scenarios pass
- [ ] Coverage >= 95%
- [ ] No critical FMEA issues unmitigated
- [ ] Sign-off from all leads

## 10. Appendix

### 10.1 Reference Documents
- `docs/ga-release/RUNTIME_COMMANDS_5LEVEL_ANALYSIS.md` - 5-Level Analysis
- `scripts/ga-release/runtime_command_verifier.exs` - Verification Script
- `test/features/ga_release/*.feature` - BDD Feature Files
- `CLAUDE.md Section 95.0` - GA Release Checklist

### 10.2 Command Reference
See `devenv.nix` for full command implementations.

### 10.3 STAMP Constraint Reference
See `CLAUDE.md Section 95.3` for SC-CMD-* constraints.
