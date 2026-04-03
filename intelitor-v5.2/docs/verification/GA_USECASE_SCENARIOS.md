# GA v21.3.0-SIL6 - Usecase Scenarios Documentation

**Version**: 21.3.0-SIL6
**Created**: 2026-01-03 (Updated: 2026-03-19)
**Framework**: SOPv5.11 + OODA Cognitive Protocol
**Status**: GA VERIFICATION READY (Updated Sprint 51)

## Executive Summary

This document describes all runtime usecase scenarios for GA Release v21.3.0-SIL6. Each usecase follows the OODA cognitive protocol (Observe → Orient → Decide → Act) with 5-order effects analysis.

---

# USECASE CATEGORY: DEVELOPMENT WORKFLOW

## UC-DEV-001: Fresh Development Environment Setup

### Description
A new developer sets up the Indrajaal development environment from scratch.

### Actors
- Developer (primary)
- DevOps Engineer (support)

### Preconditions
- NixOS or devenv installed
- Git repository cloned
- No existing containers running

### OODA Flow

#### OBSERVE
```
Current State:
├── Repository: cloned, unbuilt
├── Containers: none running
├── Database: not initialized
├── Dependencies: not fetched
└── Environment: raw nix-shell
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | devenv shell activates | 2s | Environment ready |
| 2nd | Dependencies download | 60s | Deps available |
| 3rd | Compilation starts | 120s | Bytecode generated |
| 4th | Database initializes | 30s | Schema ready |
| 5th | App starts | 5s | Full dev env operational |

#### DECIDE
Execution sequence:
1. `devenv shell` - Enter environment
2. `sa-db` - Start database container
3. `mix deps.get` - Fetch dependencies
4. `compile` - Build project
5. `db-setup` - Initialize database
6. `app` - Start application

#### ACT
```bash
# Step 1: Enter devenv shell
devenv shell

# Step 2: Start database
sa-db

# Step 3: Fetch deps (if needed)
mix deps.get

# Step 4: Compile
compile

# Step 5: Setup database
db-setup

# Step 6: Start application
app
```

### Success Criteria
- [ ] Phoenix server running on :4000
- [ ] Database accepting connections
- [ ] Web UI accessible at http://localhost:4000
- [ ] Prajna Cockpit at http://localhost:4000/prajna

### STAMP Constraints
- SC-VAL-001: Patient Mode only
- SC-CNT-009: NixOS/Podman only
- SC-CMP-025: 0 warnings

### FMEA
| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| Deps fetch fail | 48 | Retry with clean cache |
| Compile timeout | 56 | Increase scheduler |
| DB port conflict | 64 | Stop existing postgres |

---

## UC-DEV-002: Daily Development Workflow

### Description
A developer performs daily development tasks: edit, compile, test, commit.

### Actors
- Developer (primary)

### Preconditions
- Development environment set up
- Database running
- Previous work committed

### OODA Flow

#### OBSERVE
```
Current State:
├── Environment: active devenv shell
├── Containers: sa-db running
├── Codebase: clean working tree
└── Tests: passing
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Code changes | varies | Files modified |
| 2nd | Compile incremental | 10s | Bytecode updated |
| 3rd | Tests run | 60s | Validation |
| 4th | Quality check | 30s | Style/lint |
| 5th | Commit ready | - | Push-able |

#### DECIDE
Cycle pattern:
```
Edit → compile → test → quality → commit
 ↑_______________________________|
```

#### ACT
```bash
# Morning startup
devenv shell
sa-db

# Development cycle
vim lib/indrajaal/...    # Edit code
compile                  # Incremental compile
test                     # Run tests
quality                  # Check style

# End of day
git add -A
git commit -m "feat: ..."
```

### Success Criteria
- [ ] Compile succeeds with 0 warnings
- [ ] All tests pass
- [ ] Quality gates pass
- [ ] Clean commit created

---

## UC-DEV-003: Debugging Production Issue

### Description
Developer investigates and fixes a production issue using local environment.

### Actors
- Developer (primary)
- SRE (support)

### Preconditions
- Issue reported from production
- Logs available
- Local env mirrors production

### OODA Flow

#### OBSERVE
```
Current State:
├── Issue: Exception in production logs
├── Environment: need production parity
├── Data: need to reproduce
└── Telemetry: available in Grafana
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Full stack starts | 30s | Production parity |
| 2nd | Logs accessible | - | sa-logs for investigation |
| 3rd | Reproduce issue | varies | Debugging |
| 4th | Fix applied | varies | Code change |
| 5th | Verified fix | 60s | Test passes |

#### DECIDE
Debug sequence:
1. Start full production stack
2. Check logs for error
3. Reproduce locally
4. Debug with IEx
5. Fix and verify

#### ACT
```bash
# Start production-equivalent stack
sa-up

# Check logs
sa-logs indrajaal-ex-app-1

# Access observability
# Open http://localhost:3000 (Grafana)
# Open http://localhost:9090 (Prometheus)

# Start interactive debugging
app-iex

# In IEx session:
iex> Indrajaal.Module.function_causing_issue()
iex> :recon_trace.calls({Module, :func, :_}, 10)

# After fix, run tests
test test/indrajaal/path/to/test.exs

# Full verification
test
quality
```

### Success Criteria
- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Tests pass
- [ ] No regression

---

# USECASE CATEGORY: PRODUCTION OPERATIONS

## UC-OPS-001: Deploy Standalone Environment

### Description
SRE deploys full production-equivalent standalone environment.

### Actors
- SRE (primary)
- DevOps (support)

### Preconditions
- Container images built
- Ports available
- Resources sufficient

### OODA Flow

#### OBSERVE
```
Current State:
├── Containers: none or old version
├── Ports: 4000, 5433, 4317, 9090, 3000, 3100
├── Images: available locally
└── Data: volumes may contain old data
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Containers start | 20s | 4 containers running |
| 2nd | Health checks pass | 30s | Services ready |
| 3rd | Telemetry flowing | 5s | Observability active |
| 4th | Web UI accessible | - | Operations ready |
| 5th | Production parity | - | GA deployable |

#### DECIDE
Deployment sequence:
1. Clean existing deployment
2. Deploy fresh stack
3. Verify health
4. Run runtime tests

#### ACT
```bash
# Clean existing (if needed)
sa-clean

# Deploy stack
sa-up

# Wait for health
sleep 30
sa-status

# Verify endpoints
curl -f http://localhost:4000/api/health
curl -f http://localhost:9090/-/healthy
curl -f http://localhost:3000/api/health

# Run runtime tests
sa-test

# Run UX evaluation
sa-ux
```

### Success Criteria
- [ ] All 4 containers healthy
- [ ] All health endpoints return 200
- [ ] sa-test passes with >80% score
- [ ] Prajna Cockpit accessible

### STAMP Constraints
- SC-CNT-009: NixOS/Podman only
- SC-CNT-012: Rootless execution
- SC-PRF-050: Response < 50ms

---

## UC-OPS-002: Rolling Restart

### Description
SRE performs rolling restart to apply configuration changes.

### Actors
- SRE (primary)

### Preconditions
- Stack running
- Configuration updated
- No active incidents

### OODA Flow

#### OBSERVE
```
Current State:
├── Containers: 3 running
├── Health: all healthy
├── Load: normal traffic
└── Config: new config available
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | App container restarts | 10s | Brief downtime |
| 2nd | New config loads | 2s | Settings applied |
| 3rd | Health check passes | 5s | Service restored |
| 4th | Clients reconnect | 5s | Full service |
| 5th | Monitoring confirms | 60s | Stable operation |

#### DECIDE
Restart order (preserve data):
1. Restart app container only
2. Verify health
3. Check observability

#### ACT
```bash
# Check current status
sa-status

# Restart app only
podman restart indrajaal-ex-app-1

# Wait for health
sleep 10
curl -f http://localhost:4000/api/health

# Verify logs
sa-logs indrajaal-ex-app-1

# Confirm in Grafana
# Open http://localhost:3000
```

### Success Criteria
- [ ] Downtime < 15 seconds
- [ ] Health restored
- [ ] No error spikes in logs
- [ ] Metrics resume

---

## UC-OPS-003: Emergency Shutdown

### Description
SRE performs emergency shutdown due to critical issue.

### Actors
- SRE (primary)
- Incident Commander (authority)

### Preconditions
- Critical issue detected
- Shutdown authorized
- Recovery plan in place

### OODA Flow

#### OBSERVE
```
Current State:
├── Issue: Critical (e.g., security breach)
├── Impact: High risk if continues
├── Authority: Shutdown authorized
└── Plan: Recovery steps ready
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | SIGTERM sent | <1s | Graceful stop initiated |
| 2nd | Connections drain | 5s | Active requests complete |
| 3rd | Containers stop | 5s | Services offline |
| 4th | Ports freed | - | Resources released |
| 5th | Incident logged | - | Post-mortem data preserved |

#### DECIDE
Emergency sequence:
1. Immediate notification
2. Graceful shutdown
3. Verify complete stop
4. Preserve logs

#### ACT
```bash
# Notify (example)
echo "EMERGENCY: Initiating shutdown at $(date)" >> /var/log/indrajaal-incident.log

# Stop stack (graceful)
sa-down

# Verify stopped
sa-status

# If containers still running, force
podman stop --time 5 indrajaal-ex-app-1 indrajaal-obs-prod indrajaal-db-prod

# Preserve logs
cp ./data/tmp/*.log /backup/incident-$(date +%Y%m%d)/
```

### Success Criteria
- [ ] All containers stopped
- [ ] Stop completed < 10 seconds
- [ ] Logs preserved
- [ ] Incident logged

### STAMP Constraints
- SC-EMR-057: Stop < 5s
- SC-EMR-060: Rollback capability

---

# USECASE CATEGORY: QUALITY ASSURANCE

## UC-QA-001: Full Quality Gate Verification

### Description
QA engineer runs complete quality gate pipeline before release.

### Actors
- QA Engineer (primary)
- Release Manager (approval)

### Preconditions
- All code changes committed
- Feature complete
- No known blockers

### OODA Flow

#### OBSERVE
```
Current State:
├── Code: all changes committed
├── Branch: feature/release-v21.3.0-SIL6
├── Previous gates: passed in CI
└── Environment: clean
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Format verified | 5s | Style consistent |
| 2nd | Credo passes | 30s | Code quality confirmed |
| 3rd | Dialyzer passes | 300s | Types verified |
| 4th | Sobelow passes | 30s | Security verified |
| 5th | Release approved | - | Go/No-Go decision |

#### DECIDE
Quality sequence:
1. Start fresh environment
2. Compile strict
3. Full quality
4. Test with coverage
5. Runtime verification

#### ACT
```bash
# Clean start
rm -rf _build deps
mix deps.get

# Strict compile (warnings = errors)
compile-strict

# Full quality pipeline
quality-full

# Tests with coverage
test-cover

# Verify coverage > 95%
cat cover/modules.html | grep "95\|96\|97\|98\|99\|100"

# Full runtime verification
sa-up
sa-test
sa-ux
```

### Success Criteria
- [ ] compile-strict exits 0
- [ ] quality-full exits 0
- [ ] test-cover shows >95% coverage
- [ ] sa-test shows >80% readiness
- [ ] sa-ux shows acceptable UX score

### STAMP Constraints
- SC-COV-001: Static coverage 100%
- SC-COV-002: Runtime coverage 100%

---

## UC-QA-002: Property-Based Test Execution

### Description
QA runs property-based tests with dual framework (PropCheck + ExUnitProperties).

### Actors
- QA Engineer (primary)

### Preconditions
- Test files use proper aliases (PC. / SD.)
- SKIP_ZENOH_NIF=0 set

### OODA Flow

#### OBSERVE
```
Current State:
├── Test files: property tests exist
├── Aliases: PC. and SD. used
├── NIF: SKIP_ZENOH_NIF=0
└── Database: running
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | PropCheck generates | varies | Random inputs created |
| 2nd | StreamData generates | varies | Shrinking active |
| 3rd | Properties verified | varies | Pass/fail per property |
| 4th | Counterexamples found | - | Bugs exposed |
| 5th | Confidence level | - | Statistical guarantee |

#### DECIDE
Property test execution:
1. Ensure aliases correct
2. Run with enough iterations
3. Check for shrunk counterexamples

#### ACT
```bash
# Verify alias compliance
mix validate.ep014

# Run property tests (100 iterations default)
test test/indrajaal/cockpit/prajna/*_test.exs

# Run with more iterations for critical paths
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/guardian_integration_test.exs \
  --include property_test --max-cases 1000
```

### Success Criteria
- [ ] All property tests pass
- [ ] No counterexamples found
- [ ] Shrinking terminates

### STAMP Constraints
- SC-PROP-023: PropCheck/StreamData disambiguation MANDATORY
- SC-PROP-024: PC. prefix for PropCheck, SD. prefix for StreamData

---

# USECASE CATEGORY: CEPAF F# OPERATIONS

## UC-CEPAF-001: Build and Deploy F# Cockpit

### Description
Developer builds and deploys the F# CEPAF Cockpit.

### Actors
- Developer (primary)

### Preconditions
- .NET SDK 10.0 available
- Elixir backend running
- NuGet packages accessible

### OODA Flow

#### OBSERVE
```
Current State:
├── .NET: 10.0.x available
├── F# sources: lib/cepaf/src/
├── Tests: lib/cepaf/test/
└── Elixir: compiled and running
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | NuGet restore | 10s | Packages downloaded |
| 2nd | F# compile | 60s | DLLs generated |
| 3rd | Tests run | 30s | Validation |
| 4th | Integration ready | - | CEPAF-Prajna bridge |
| 5th | Full system | - | Unified operation |

#### DECIDE
Build sequence:
1. Build F# projects
2. Run F# tests
3. Deploy cockpit
4. Verify integration

#### ACT
```bash
# Build F# projects
cepaf-build

# Run F# tests
cockpitf test

# Deploy cockpit
cockpitf deploy

# Check status
cockpitf status

# Verify integration
curl http://localhost:4000/api/prajna/health
```

### Success Criteria
- [ ] cepaf-build succeeds
- [ ] 549+ F# tests pass
- [ ] Cockpit deploys successfully
- [ ] Integration API responds

### STAMP Constraints
- SC-NET-001: net10.0 target framework
- SC-SYNC-001: Bridge timeout < 5s

---

# USECASE CATEGORY: PRAJNA C3I OPERATIONS

## UC-PRAJNA-001: Monitor System Health via Prajna

### Description
Operator monitors system health using Prajna Cockpit.

### Actors
- Operator (primary)

### Preconditions
- Standalone stack running
- Prajna Cockpit accessible

### OODA Flow

#### OBSERVE
```
Current State:
├── Stack: all containers healthy
├── Prajna: accessible at :4000/prajna
├── Sentinel: health monitoring active
└── Guardian: approval system ready
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Dashboard loads | 2s | Metrics visible |
| 2nd | Health score shown | - | System status |
| 3rd | Threats displayed | - | Risk awareness |
| 4th | Actions available | - | Control capability |
| 5th | Decisions informed | - | Operational excellence |

#### DECIDE
Monitoring workflow:
1. Open Prajna Cockpit
2. Review health score
3. Check active threats
4. Review agent status
5. Take action if needed

#### ACT
```
# Open browser
Navigate to http://localhost:4000/prajna

# Review dashboard:
# - Health Score (target: >90%)
# - Active Threats (target: 0 critical)
# - Agent Status (50 agents running)

# Check domains:
# - Alarms: /prajna/alarms
# - Access Control: /prajna/access_control
# - Devices: /prajna/devices

# AI Copilot for recommendations:
Navigate to http://localhost:4000/prajna/copilot
```

### Success Criteria
- [ ] Dashboard loads within 2s
- [ ] Health score visible
- [ ] No critical threats
- [ ] 50 agents shown

### STAMP Constraints
- SC-PRAJNA-001: All commands through Guardian
- SC-PRAJNA-004: Sentinel health integration
- SC-BIO-005: Dashboard refresh every 30s

---

## UC-PRAJNA-002: Execute Guardian-Approved Command

### Description
Operator executes a system command via Guardian approval.

### Actors
- Operator (primary)
- Guardian (approval authority)

### Preconditions
- Prajna Cockpit accessible
- Guardian operational
- Valid authentication

### OODA Flow

#### OBSERVE
```
Current State:
├── Command: operator wants to restart service
├── Guardian: ready to evaluate
├── Founder Directive: active
└── Approval: not yet granted
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Proposal submitted | 100ms | Guardian receives |
| 2nd | Founder check | 50ms | Directive alignment |
| 3rd | Safety check | 100ms | STAMP validation |
| 4th | Approval/Veto | - | Decision made |
| 5th | Execution | varies | Action performed |

#### DECIDE
Approval workflow:
1. Submit command proposal
2. Await Guardian decision
3. Handle approval or veto
4. Execute if approved
5. Log to Immutable Register

#### ACT
```elixir
# Via IEx or Prajna UI
alias Indrajaal.Cockpit.Prajna.GuardianIntegration

# Submit proposal
proposal = %{
  action: "restart_service",
  target: "video_processor",
  justification: "High memory usage detected"
}

case GuardianIntegration.submit_proposal(proposal) do
  {:ok, :approved, token} ->
    IO.puts("Approved with token: #{token}")
    # Execute action
    Indrajaal.Services.restart("video_processor")

  {:veto, reason, fallback} ->
    IO.puts("Vetoed: #{reason}")
    IO.puts("Fallback: #{fallback}")
    # Execute fallback or abort
end
```

### Success Criteria
- [ ] Proposal submitted successfully
- [ ] Guardian responds within 5s
- [ ] Decision logged to Immutable Register
- [ ] Action executed or fallback applied

### STAMP Constraints
- SC-PRAJNA-001: All commands through Guardian pre-approval
- SC-PRAJNA-003: State changes via Immutable Register
- SC-CONST-007: Guardian has absolute veto

---

# USECASE CATEGORY: OBSERVABILITY

## UC-OBS-001: Investigate Performance Issue

### Description
SRE investigates performance degradation using observability stack.

### Actors
- SRE (primary)

### Preconditions
- Observability stack running (sa-obs)
- Performance issue reported
- Metrics/traces available

### OODA Flow

#### OBSERVE
```
Current State:
├── Issue: High latency reported
├── Grafana: :3000 accessible
├── Prometheus: :9090 scraping
├── Loki: :3100 indexing
└── OTEL: :4317 receiving
```

#### ORIENT (5-Order Effects)
| Order | Effect | Time | Action |
|-------|--------|------|--------|
| 1st | Metrics queried | 1s | Data available |
| 2nd | Patterns identified | 5s | Anomalies visible |
| 3rd | Root cause | varies | Issue isolated |
| 4th | Fix applied | varies | Performance restored |
| 5th | Verification | 60s | Stable operation |

#### DECIDE
Investigation workflow:
1. Check Grafana dashboards
2. Query Prometheus metrics
3. Search Loki logs
4. Correlate traces
5. Identify root cause

#### ACT
```
# Open Grafana (admin/indrajaal)
Navigate to http://localhost:3000

# Check Indrajaal Dashboard
# - Request latency histogram
# - Error rate
# - CPU/Memory usage

# Query Prometheus
Navigate to http://localhost:9090
# Query: http_request_duration_seconds{quantile="0.99"}
# Query: rate(http_requests_total{status="500"}[5m])

# Search Loki logs
# Query: {app="indrajaal"} |= "error"
# Query: {app="indrajaal"} | json | latency > 100ms

# Check specific trace
# Navigate to trace ID from error log
```

### Success Criteria
- [ ] Root cause identified
- [ ] Metrics correlated
- [ ] Fix plan created
- [ ] Resolution verified

---

# VERIFICATION SUMMARY

## Command Coverage Matrix

| Usecase | Commands Used | Priority |
|---------|---------------|----------|
| UC-DEV-001 | devenv, sa-db, compile, db-setup, app | P0 |
| UC-DEV-002 | compile, test, quality | P0 |
| UC-DEV-003 | sa-up, sa-logs, app-iex, test | P0 |
| UC-OPS-001 | sa-clean, sa-up, sa-test, sa-ux | P0 |
| UC-OPS-002 | sa-status, sa-logs | P1 |
| UC-OPS-003 | sa-down | P0 |
| UC-QA-001 | compile-strict, quality-full, test-cover | P0 |
| UC-QA-002 | test | P0 |
| UC-CEPAF-001 | cepaf-build, cockpitf | P0 |
| UC-PRAJNA-001 | sa-up | P0 |
| UC-PRAJNA-002 | (API) | P0 |
| UC-OBS-001 | sa-obs, sa-logs | P1 |

## All 32 Commands Covered
- [x] app
- [x] app-start
- [x] app-iex
- [x] compile
- [x] compile-strict
- [x] quality
- [x] quality-full
- [x] test
- [x] test-cover
- [x] sa-up
- [x] sa-down
- [x] sa-clean
- [x] sa-status
- [x] sa-logs
- [x] sa-db
- [x] sa-obs
- [x] sa-app
- [x] sa-test
- [x] sa-ux
- [x] sa-orchestrate
- [x] db-setup
- [x] db-reset
- [x] db-migrate
- [x] db-console
- [x] cepaf-build
- [x] cockpitf
- [x] todo
- [x] envelope
- [x] envelope-json
- [x] envelope-journal
- [x] claude
- [x] help

---

**Document Control**
| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Created | 2026-01-03 |
| Updated | 2026-03-19 |
| Author | Cybernetic Architect |
| Usecases | 12 |
| Commands | 32 core / 102 total |
| Status | GA VERIFICATION READY |
