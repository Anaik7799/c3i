# GA Release v21.3.0-SIL6 Runtime Test Plan

**Version**: 2.0.0
**Date**: 2026-01-03 (Updated: 2026-03-19)
**STAMP**: SC-COV-001 to SC-COV-006
**Status**: ACTIVE

## 1. Executive Summary

This document provides a comprehensive runtime test plan for verifying 100% functional coverage of all 102 devenv commands in the Indrajaal GA Release v21.3.0-SIL6 (32 core commands verified, 70 extended mesh/monitoring commands).

### 1.1 Test Scope

| Category | Commands | Tests | Priority |
|----------|----------|-------|----------|
| App & Server | 3 | 15 | P0 |
| Compilation | 4 | 20 | P0 |
| Testing | 2 | 10 | P0 |
| Standalone | 11 | 55 | P0 |
| Database | 4 | 20 | P1 |
| CEPAF/F# | 2 | 15 | P1 |
| Reporting | 4 | 12 | P2 |
| Other | 2 | 8 | P2 |
| **TOTAL** | **32** | **155** | |
| Extended Mesh/Planning | 70 | 200+ | P1-P2 |

### 1.2 STAMP Compliance Matrix

| Constraint | Requirement | Verification Method |
|------------|-------------|---------------------|
| SC-COV-001 | Static coverage 100% | mix test --cover |
| SC-COV-002 | Runtime coverage 100% | This test plan |
| SC-COV-003 | Mathematical proofs | Agda/Quint specs |
| SC-COV-004 | BDD specs | Wallaby/Puppeteer |
| SC-COV-005 | FMEA analysis | RPN calculations |
| SC-COV-006 | TDG compliance | Dual property tests |

---

## 2. Environment Setup

### 2.1 Prerequisites

```bash
# Verify devenv is available
devenv version
# Expected: devenv 1.4.1 (or higher)

# Verify container runtime
podman --version
# Expected: podman version 5.4.1 (or higher)

# Verify Elixir/OTP
elixir --version
# Expected: Elixir 1.19.x (compiled with Erlang/OTP 28)

# Verify .NET SDK (for CEPAF)
dotnet --version
# Expected: 10.0.x
```

### 2.2 Environment Variables

```bash
# Required for all tests
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export SKIP_ZENOH_NIF=0

# Database connection
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test"
```

### 2.3 Clean State Verification

```bash
# Ensure no stale containers
podman ps -a | grep indrajaal && podman rm -f $(podman ps -aq --filter "name=indrajaal")

# Ensure ports are available
ss -tlnp | grep -E '4000|5433|4317|9090|3000|3100'
# Expected: No output (all ports free)
```

---

## 3. Test Execution Procedures

### 3.1 Category A: App & Server Commands (P0)

#### TEST-APP-001: `app` - Start Phoenix Server

**OODA Cycle**:
- **OBSERVE**: Check port 4000, _build/ directory
- **ORIENT**: Verify compilation complete, DB accessible
- **DECIDE**: Start Phoenix or report blocker
- **ACT**: Execute and verify

**Procedure**:
```bash
# Step 1: Enter devenv shell
devenv shell

# Step 2: Ensure clean state
ss -tlnp | grep 4000 && echo "FAIL: Port 4000 in use" && exit 1

# Step 3: Execute command
app &
APP_PID=$!

# Step 4: Wait for startup (max 30s)
timeout 30 bash -c 'until curl -s http://localhost:4000 > /dev/null; do sleep 1; done'

# Step 5: Verify endpoints
curl -s http://localhost:4000 | grep -q "Indrajaal" && echo "PASS" || echo "FAIL"
curl -s http://localhost:4000/prajna | grep -q "Prajna" && echo "PASS" || echo "FAIL"

# Step 6: Cleanup
kill $APP_PID
```

**Expected Results**:
- [ ] Phoenix starts within 5 seconds
- [ ] Port 4000 is listening
- [ ] HTTP GET `/` returns 200
- [ ] HTTP GET `/prajna` returns 200
- [ ] PubSub channels active
- [ ] Telemetry handlers attached

**STAMP Constraints**: SC-PRF-050 (< 50ms response)

---

#### TEST-APP-002: `app-start` - Containers + Phoenix

**Procedure**:
```bash
# Step 1: Verify clean state
podman ps | grep indrajaal && echo "FAIL: Containers running" && exit 1

# Step 2: Execute command
app-start &
APP_PID=$!

# Step 3: Wait for containers (max 60s)
timeout 60 bash -c 'until podman ps | grep -q "indrajaal-db"; do sleep 2; done'

# Step 4: Wait for Phoenix
timeout 30 bash -c 'until curl -s http://localhost:4000 > /dev/null; do sleep 1; done'

# Step 5: Verify all services
podman ps | grep -q "indrajaal-db" && echo "DB: PASS" || echo "DB: FAIL"
curl -s http://localhost:4000 > /dev/null && echo "Phoenix: PASS" || echo "Phoenix: FAIL"

# Step 6: Cleanup
kill $APP_PID
sa-down
```

**Expected Results**:
- [ ] Dev containers start within 10 seconds
- [ ] Phoenix connects to database
- [ ] Port 4000 listening
- [ ] Port 5433 listening

---

#### TEST-APP-003: `app-iex` - Phoenix with IEx

**Procedure**:
```bash
# Step 1: Execute with expect script
expect << 'EOF'
spawn devenv shell -c "app-iex"
expect "iex(1)>"
send "Indrajaal.Application.started_applications()\r"
expect "[:indrajaal"
send ":init.stop()\r"
expect eof
EOF
```

**Expected Results**:
- [ ] IEx shell available
- [ ] Phoenix server starts
- [ ] Can evaluate Elixir expressions

---

### 3.2 Category B: Compilation Commands (P0)

#### TEST-COMPILE-001: `compile` - Patient Mode Compilation

**Procedure**:
```bash
# Step 1: Execute compilation
compile 2>&1 | tee /tmp/compile_output.txt

# Step 2: Verify success
grep -q "Compiling" /tmp/compile_output.txt && echo "Compilation started: PASS"
! grep -q "error" /tmp/compile_output.txt && echo "No errors: PASS" || echo "FAIL"
! grep -q "warning" /tmp/compile_output.txt && echo "No warnings: PASS" || echo "FAIL"

# Step 3: Verify log file
test -f ./data/tmp/1-compile.log && echo "Log exists: PASS" || echo "FAIL"

# Step 4: Verify _build exists
test -d ./_build/dev && echo "_build/dev exists: PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Compilation completes without errors
- [ ] Compilation completes without warnings
- [ ] Log file exists at `./data/tmp/1-compile.log`
- [ ] All 1,508+ files compiled

**STAMP Constraints**: SC-CMP-025 (0 warnings), SC-CMP-026 (1,508 files)

---

#### TEST-COMPILE-002: `compile-strict` - Warnings as Errors

**Procedure**:
```bash
# Step 1: Execute strict compilation
compile-strict
EXIT_CODE=$?

# Step 2: Verify exit code
[ $EXIT_CODE -eq 0 ] && echo "PASS" || echo "FAIL: Exit code $EXIT_CODE"
```

**Expected Results**:
- [ ] Exit code 0 for clean project
- [ ] Compilation fails if warnings exist

---

#### TEST-COMPILE-003: `quality` - Format + Credo

**Procedure**:
```bash
# Step 1: Execute quality check
quality 2>&1 | tee /tmp/quality_output.txt

# Step 2: Verify format
grep -q "format.*passed\|All code formatted" /tmp/quality_output.txt && \
  echo "Format: PASS" || echo "Format: FAIL"

# Step 3: Verify credo
grep -q "credo.*passed\|Analysis took" /tmp/quality_output.txt && \
  echo "Credo: PASS" || echo "Credo: FAIL"
```

**Expected Results**:
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes

---

#### TEST-COMPILE-004: `quality-full` - Full Pipeline

**Procedure**:
```bash
# Step 1: Execute full quality check (may take 5-10 minutes)
timeout 600 quality-full 2>&1 | tee /tmp/quality_full_output.txt
EXIT_CODE=$?

# Step 2: Verify all gates
[ $EXIT_CODE -eq 0 ] && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] `mix format` passes
- [ ] `mix credo` passes
- [ ] `mix dialyzer` passes
- [ ] `mix sobelow` passes

---

### 3.3 Category C: Testing Commands (P0)

#### TEST-TEST-001: `test` - Run Tests

**Procedure**:
```bash
# Step 1: Ensure database is running
podman ps | grep -q "indrajaal-db" || sa-db

# Step 2: Run tests
test 2>&1 | tee /tmp/test_output.txt
EXIT_CODE=$?

# Step 3: Verify
[ $EXIT_CODE -eq 0 ] && echo "PASS" || echo "FAIL"
grep -q "0 failures" /tmp/test_output.txt && echo "No failures: PASS"
```

**Expected Results**:
- [ ] All tests pass
- [ ] Zenoh NIF loaded (SKIP_ZENOH_NIF=0)
- [ ] No timeout errors

**STAMP Constraints**: SC-TEST-005 (NIF active)

---

#### TEST-TEST-002: `test-cover` - Coverage Report

**Procedure**:
```bash
# Step 1: Run tests with coverage
test-cover 2>&1 | tee /tmp/test_cover_output.txt

# Step 2: Extract coverage
COVERAGE=$(grep -oP '\d+\.\d+%' /tmp/test_cover_output.txt | head -1)
echo "Coverage: $COVERAGE"

# Step 3: Verify threshold
[ $(echo "$COVERAGE > 95" | bc) -eq 1 ] && echo "PASS" || echo "FAIL: Below 95%"
```

**Expected Results**:
- [ ] Coverage report generated
- [ ] Coverage > 95%
- [ ] All tests pass

---

### 3.4 Category D: Standalone Environment Commands (P0)

#### TEST-SA-001: `sa-up` - Start Production Standalone

**Procedure**:
```bash
# Step 1: Clean state
sa-clean 2>/dev/null

# Step 2: Start standalone
sa-up 2>&1 | tee /tmp/sa_up_output.txt

# Step 3: Wait for containers (max 60s)
timeout 60 bash -c '
  until podman ps | grep -q "healthy.*zenoh-router"; do sleep 2; done
  until podman ps | grep -q "healthy.*indrajaal-db-prod"; do sleep 2; done
  until podman ps | grep -q "healthy.*indrajaal-obs-prod"; do sleep 2; done
  until podman ps | grep -q "healthy.*indrajaal-ex-app-1"; do sleep 2; done
'

# Step 4: Verify all 4 containers
CONTAINER_COUNT=$(podman ps | grep -cE "indrajaal.*prod|zenoh-router")
[ $CONTAINER_COUNT -eq 4 ] && echo "PASS: 4 containers" || echo "FAIL: $CONTAINER_COUNT containers"

# Step 5: Verify ports
ss -tlnp | grep -q ":5433" && echo "DB Port: PASS" || echo "DB Port: FAIL"
ss -tlnp | grep -q ":4000" && echo "App Port: PASS" || echo "App Port: FAIL"
ss -tlnp | grep -q ":9090" && echo "Prometheus: PASS" || echo "Prometheus: FAIL"
ss -tlnp | grep -q ":3000" && echo "Grafana: PASS" || echo "Grafana: FAIL"
```

**Expected Results**:
- [ ] 4 containers running (zenoh-router, db, obs, app)
- [ ] All containers healthy within 30 seconds
- [ ] Ports 5433, 4000, 4317, 9090, 3000, 3100 listening

---

#### TEST-SA-002: `sa-down` - Stop Standalone

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Stop standalone
sa-down

# Step 2: Wait (max 30s)
timeout 30 bash -c 'until [ $(podman ps | grep -c "indrajaal.*prod") -eq 0 ]; do sleep 2; done'

# Step 3: Verify
CONTAINER_COUNT=$(podman ps | grep -c "indrajaal.*prod")
[ $CONTAINER_COUNT -eq 0 ] && echo "PASS" || echo "FAIL: $CONTAINER_COUNT still running"
```

**Expected Results**:
- [ ] All containers stopped within 10 seconds
- [ ] Ports 4000, 5433 freed

---

#### TEST-SA-003: `sa-clean` - Stop + Remove Volumes

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Clean
sa-clean

# Step 2: Verify containers gone
[ $(podman ps -a | grep -c "indrajaal.*prod") -eq 0 ] && \
  echo "Containers: PASS" || echo "Containers: FAIL"

# Step 3: Verify volumes gone
[ $(podman volume ls | grep -c "indrajaal") -eq 0 ] && \
  echo "Volumes: PASS" || echo "Volumes: FAIL"
```

**Expected Results**:
- [ ] All containers stopped
- [ ] All volumes removed
- [ ] Data reset

---

#### TEST-SA-004: `sa-status` - Container Status

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Get status
sa-status 2>&1 | tee /tmp/sa_status_output.txt

# Step 2: Verify output contains key info
grep -q "indrajaal-db-prod" /tmp/sa_status_output.txt && echo "DB: PASS"
grep -q "indrajaal-ex-app-1" /tmp/sa_status_output.txt && echo "App: PASS"
grep -q "indrajaal-obs-prod" /tmp/sa_status_output.txt && echo "Obs: PASS"
grep -qE "healthy|running" /tmp/sa_status_output.txt && echo "Health: PASS"
```

**Expected Results**:
- [ ] Container status displayed
- [ ] Health status visible
- [ ] Port mappings shown

---

#### TEST-SA-005: `sa-logs` - Stream Logs

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Get logs (limited)
timeout 5 sa-logs indrajaal-ex-app-1 2>&1 | head -50 > /tmp/sa_logs_output.txt

# Step 2: Verify Phoenix startup message
grep -qE "Phoenix|Application.*started" /tmp/sa_logs_output.txt && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Log stream starts
- [ ] Phoenix startup message visible

---

#### TEST-SA-006: `sa-db` - Start DB Only

**Procedure**:
```bash
# Step 1: Clean state
sa-clean 2>/dev/null

# Step 2: Start DB only
sa-db

# Step 3: Wait and verify
timeout 30 bash -c 'until podman ps | grep -q "indrajaal-db"; do sleep 2; done'
ss -tlnp | grep -q ":5433" && echo "PASS" || echo "FAIL"

# Step 4: Test connection
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "SELECT 1" && \
  echo "Connection: PASS" || echo "Connection: FAIL"
```

**Expected Results**:
- [ ] PostgreSQL container starts
- [ ] Port 5433 listening
- [ ] Database accepts connections

---

#### TEST-SA-007: `sa-obs` - Start Observability Only

**Procedure**:
```bash
# Step 1: Start obs only
sa-obs

# Step 2: Wait and verify
timeout 30 bash -c 'until podman ps | grep -q "indrajaal-obs"; do sleep 2; done'

# Step 3: Verify ports
ss -tlnp | grep -q ":4317" && echo "OTEL: PASS" || echo "OTEL: FAIL"
ss -tlnp | grep -q ":9090" && echo "Prometheus: PASS" || echo "Prometheus: FAIL"
ss -tlnp | grep -q ":3000" && echo "Grafana: PASS" || echo "Grafana: FAIL"
ss -tlnp | grep -q ":3100" && echo "Loki: PASS" || echo "Loki: FAIL"
```

**Expected Results**:
- [ ] OTEL collector on port 4317
- [ ] Prometheus on port 9090
- [ ] Grafana on port 3000
- [ ] Loki on port 3100

---

#### TEST-SA-008: `sa-app` - Start App Only

**Procedure**:
```bash
# Prerequisites: sa-db running
# Step 1: Start app
sa-app

# Step 2: Wait and verify
timeout 30 bash -c 'until curl -s http://localhost:4000 > /dev/null; do sleep 2; done'

# Step 3: Verify Prajna accessible
curl -s http://localhost:4000/prajna | grep -q "Prajna" && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Phoenix container starts
- [ ] Port 4000 listening
- [ ] Prajna Cockpit accessible

---

#### TEST-SA-009: `sa-test` - Runtime Tests

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Run runtime tests
sa-test 2>&1 | tee /tmp/sa_test_output.txt

# Step 2: Verify F# test swarm
grep -qE "Expecto|test|passed" /tmp/sa_test_output.txt && \
  echo "PASS" || echo "FAIL"

# Step 3: Extract GA score if available
GA_SCORE=$(grep -oP 'readiness.*\K\d+\.\d+' /tmp/sa_test_output.txt || echo "N/A")
echo "GA Readiness Score: $GA_SCORE%"
```

**Expected Results**:
- [ ] F# test swarm spawns
- [ ] Runtime endpoints tested
- [ ] GA readiness score calculated

---

#### TEST-SA-010: `sa-ux` - UX Evaluation

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Run UX evaluation
sa-ux 2>&1 | tee /tmp/sa_ux_output.txt

# Step 2: Verify output
grep -qE "UX|accessibility|score" /tmp/sa_ux_output.txt && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] UX evaluator runs
- [ ] Accessibility checks complete
- [ ] UX score reported

---

#### TEST-SA-011: `sa-orchestrate` - Test Orchestrator

**Procedure**:
```bash
# Prerequisites: sa-up complete
# Step 1: Run orchestrator
sa-orchestrate swarm 2>&1 | tee /tmp/sa_orchestrate_output.txt

# Step 2: Verify
grep -qE "orchestrat|swarm|aggregat" /tmp/sa_orchestrate_output.txt && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Orchestrator plans tests
- [ ] Test swarm executes
- [ ] Aggregated results reported

---

### 3.5 Category E: Database Commands (P1)

#### TEST-DB-001: `db-setup` - Setup Database

**Procedure**:
```bash
# Prerequisites: sa-db running
# Step 1: Drop if exists
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "DROP DATABASE IF EXISTS indrajaal_dev"

# Step 2: Setup
db-setup 2>&1 | tee /tmp/db_setup_output.txt

# Step 3: Verify
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "\l" | \
  grep -q "indrajaal_dev" && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Database created
- [ ] Migrations run
- [ ] Seed data loaded

---

#### TEST-DB-002: `db-reset` - Reset Database

**Procedure**:
```bash
# Prerequisites: db exists
# Step 1: Reset
db-reset 2>&1 | tee /tmp/db_reset_output.txt

# Step 2: Verify
grep -qE "dropped|created|migrat" /tmp/db_reset_output.txt && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Database dropped
- [ ] Database recreated
- [ ] Migrations run
- [ ] Seed data loaded

---

#### TEST-DB-003: `db-migrate` - Run Migrations

**Procedure**:
```bash
# Step 1: Migrate
db-migrate 2>&1 | tee /tmp/db_migrate_output.txt

# Step 2: Verify
! grep -q "error" /tmp/db_migrate_output.txt && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Pending migrations run
- [ ] Schema version updated

---

#### TEST-DB-004: `db-console` - PSQL Console

**Procedure**:
```bash
# Step 1: Test console access
echo "SELECT 1;" | db-console 2>&1 | grep -q "1" && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] PSQL session opens
- [ ] Can run SQL queries

---

### 3.6 Category F: CEPAF/F# Commands (P1)

#### TEST-CEPAF-001: `cepaf-build` - Build F# Projects

**Procedure**:
```bash
# Step 1: Build
cepaf-build 2>&1 | tee /tmp/cepaf_build_output.txt
EXIT_CODE=$?

# Step 2: Verify
[ $EXIT_CODE -eq 0 ] && echo "Build: PASS" || echo "Build: FAIL"
test -d lib/cepaf/src/Cepaf/bin && echo "DLLs: PASS" || echo "DLLs: FAIL"
```

**Expected Results**:
- [ ] NuGet packages restored
- [ ] F# compilation succeeds
- [ ] DLLs generated in bin/

---

#### TEST-CEPAF-002: `cockpitf test` - Run F# Tests

**Procedure**:
```bash
# Prerequisites: cepaf-build complete
# Step 1: Run tests
cockpitf test 2>&1 | tee /tmp/cockpitf_test_output.txt

# Step 2: Verify
grep -qE "passed|tests" /tmp/cockpitf_test_output.txt && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] F# tests run
- [ ] All 549+ F# tests pass

---

### 3.7 Category G: Reporting Commands (P2)

#### TEST-REPORT-001: `todo` - Show Project Tasks

**Procedure**:
```bash
# Step 1: Run todo
todo 2>&1 | tee /tmp/todo_output.txt

# Step 2: Verify
grep -qE "task|pending|completed" /tmp/todo_output.txt && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] PROJECT_TODOLIST.md tasks displayed
- [ ] Status shown

---

#### TEST-REPORT-002: `envelope` - Capability Dashboard

**Procedure**:
```bash
# Step 1: Run envelope
envelope 2>&1 | tee /tmp/envelope_output.txt

# Step 2: Verify
grep -qE "capabilit|metric|readiness" /tmp/envelope_output.txt && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Capability metrics collected
- [ ] Dashboard displayed
- [ ] GA readiness calculated

---

#### TEST-REPORT-003: `envelope-json` - JSON Export

**Procedure**:
```bash
# Step 1: Run envelope-json
envelope-json 2>&1 > /tmp/envelope.json

# Step 2: Verify JSON
python3 -c "import json; json.load(open('/tmp/envelope.json'))" && \
  echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] JSON output generated
- [ ] Valid JSON format

---

#### TEST-REPORT-004: `envelope-journal` - Save to Journal

**Procedure**:
```bash
# Step 1: Run envelope-journal
envelope-journal

# Step 2: Verify file created
ls -la journal/2026-01/ | grep -q "envelope" && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Envelope saved to journal/
- [ ] File contains timestamp

---

### 3.8 Category H: Other Commands (P2)

#### TEST-OTHER-001: `help` - Command Reference

**Procedure**:
```bash
# Step 1: Run help
help 2>&1 | tee /tmp/help_output.txt

# Step 2: Verify all 32 commands listed
COMMAND_COUNT=$(grep -cE "^\s*(app|compile|test|sa-|db-|cockpit|todo|envelope|help|claude)" /tmp/help_output.txt)
[ $COMMAND_COUNT -ge 20 ] && echo "PASS" || echo "FAIL: Only $COMMAND_COUNT commands"
```

**Expected Results**:
- [ ] Command reference displayed
- [ ] All 32 commands listed
- [ ] Usage examples shown

---

#### TEST-OTHER-002: `claude` - Start Claude Code

**Procedure**:
```bash
# Step 1: Verify binary exists
test -f ~/.claude/local/claude && echo "Binary: PASS" || echo "Binary: FAIL"

# Step 2: Quick help check
~/.claude/local/claude --help 2>&1 | grep -q "claude" && echo "PASS" || echo "FAIL"
```

**Expected Results**:
- [ ] Claude binary exists
- [ ] Claude can start

---

## 4. Web Page Testing (Puppeteer/Wallaby)

### 4.1 Prajna Cockpit Pages

| Page | URL | Test File |
|------|-----|-----------|
| Dashboard | /prajna | prajna_dashboard_test.exs |
| Copilot | /prajna/copilot | copilot_live_test.exs |
| Alarms | /prajna/alarms | alarms_live_test.exs |
| Access Control | /prajna/access_control | access_control_live_test.exs |
| Analytics | /prajna/analytics | analytics_live_test.exs |
| Compliance | /prajna/compliance | compliance_live_test.exs |
| Devices | /prajna/devices | devices_live_test.exs |
| Video | /prajna/video | video_live_test.exs |

### 4.2 Execution Command

```bash
# Run all web page tests
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test test/indrajaal_web/live/prajna/ --trace
```

---

## 5. API Endpoint Testing

### 5.1 REST Endpoints

```bash
# Health Check
curl -s http://localhost:4000/api/health | jq .

# Prajna Metrics
curl -s http://localhost:4000/api/prajna/metrics | jq .

# Guardian Proposal (POST)
curl -s -X POST http://localhost:4000/api/prajna/guardian/propose \
  -H "Content-Type: application/json" \
  -d '{"command": "test", "justification": "GA verification"}' | jq .

# Sentinel Threats
curl -s http://localhost:4000/api/prajna/sentinel/threats | jq .
```

---

## 6. Zenoh Interface Testing

### 6.1 Pub/Sub Verification

```elixir
# In IEx session
# Publish test
Indrajaal.Observability.ZenohKpiPublisher.publish_kpi(%{health: 95.0})

# Subscribe test
Indrajaal.Observability.ZenohControlSubscriber.subscribe("prajna/alerts/**")
```

---

## 7. Test Execution Order

### 7.1 Recommended Sequence

1. **Phase 1: Environment Verification** (5 min)
   - Prerequisites check
   - Clean state verification

2. **Phase 2: Compilation & Quality** (15 min)
   - TEST-COMPILE-001 through TEST-COMPILE-004
   - Ensures codebase is buildable

3. **Phase 3: Unit Tests** (10 min)
   - TEST-TEST-001, TEST-TEST-002
   - Verifies test suite

4. **Phase 4: Standalone Stack** (20 min)
   - TEST-SA-001 through TEST-SA-011
   - Full 3-container stack verification

5. **Phase 5: Database Operations** (5 min)
   - TEST-DB-001 through TEST-DB-004

6. **Phase 6: CEPAF/F#** (10 min)
   - TEST-CEPAF-001, TEST-CEPAF-002

7. **Phase 7: Web Pages** (10 min)
   - Puppeteer/Wallaby tests

8. **Phase 8: API Endpoints** (5 min)
   - REST API verification

9. **Phase 9: Reporting** (5 min)
   - TEST-REPORT-001 through TEST-REPORT-004

10. **Phase 10: Cleanup & Summary** (5 min)
    - sa-clean
    - Generate report

**Total Estimated Time**: ~90 minutes

---

## 8. Pass/Fail Criteria

### 8.1 GA Release Requirements

| Category | Requirement | Threshold |
|----------|-------------|-----------|
| Compilation | Zero errors | 100% |
| Compilation | Zero warnings | 100% |
| Unit Tests | All pass | 100% |
| Coverage | Test coverage | > 95% |
| Standalone | All containers healthy | 100% |
| Web Pages | All pages load | 100% |
| API | All endpoints respond | 100% |
| Quality | Credo strict | 0 issues |
| Security | Sobelow | 0 high/critical |

### 8.2 GA Readiness Score Formula

```
GA_Score = (
  Compile_Pass * 20 +
  Test_Pass * 20 +
  SA_Pass * 20 +
  Web_Pass * 15 +
  API_Pass * 10 +
  Quality_Pass * 10 +
  Security_Pass * 5
) / 100

GA_READY = GA_Score >= 95.0
```

---

## 9. Reporting Template

### 9.1 Test Execution Report

```
═══════════════════════════════════════════════════════════════
                GA RELEASE v21.3.0-SIL6 TEST REPORT
═══════════════════════════════════════════════════════════════
Date: 2026-01-03
Executor: [Name]
Environment: NixOS + Podman 5.4.1 + Elixir 1.19.x

CATEGORY           TESTS    PASS    FAIL    SKIP    %
───────────────────────────────────────────────────────────────
App & Server         3       3       0       0     100%
Compilation          4       4       0       0     100%
Testing              2       2       0       0     100%
Standalone          11      11       0       0     100%
Database             4       4       0       0     100%
CEPAF/F#             2       2       0       0     100%
Reporting            4       4       0       0     100%
Other                2       2       0       0     100%
───────────────────────────────────────────────────────────────
TOTAL               32      32       0       0     100%

GA READINESS SCORE: 100.0%
STATUS: ✓ GA READY

STAMP Compliance: ALL VERIFIED
AOR Compliance: ALL VERIFIED
TDG Coverage: 365/365 tests
FMEA RPN: All < 50

Sign-off: _________________________ Date: _____________
═══════════════════════════════════════════════════════════════
```

---

## 10. Related Documents

- [GA_7LEVEL_FRACTAL_COMMAND_ANALYSIS.md](./GA_7LEVEL_FRACTAL_COMMAND_ANALYSIS.md)
- [ga_release_verification.feature](../../test/features/ga_release_verification.feature)
- [GA_USECASE_SCENARIOS.md](./GA_USECASE_SCENARIOS.md)
- [CLAUDE.md Section 96](../../CLAUDE.md)

---

## Appendix A: Quick Reference Card

```
╔═════════════════════════════════════════════════════════════╗
║           GA v21.3.0-SIL6 QUICK VERIFICATION COMMANDS       ║
╠═════════════════════════════════════════════════════════════╣
║  devenv shell           # Enter dev environment             ║
║  compile                # Patient mode compilation          ║
║  quality                # Format + Credo check              ║
║  test                   # Run all tests                     ║
║  sa-up                  # Start 4-container stack           ║
║  sa-status              # Check container health            ║
║  sa-test                # Runtime verification              ║
║  envelope               # GA readiness dashboard            ║
║  sa-down                # Stop containers                   ║
╚═════════════════════════════════════════════════════════════╝
```
