# CEPAF AppVerifier Test Plan

**Version**: 1.0.0
**Date**: 2024-12-24
**Author**: CEPAF Framework
**STAMP Compliance**: SC-CNT-009, SC-CEP-004, SC-VAL-003, SC-CMP-025

## 1. Overview

This document defines the comprehensive test plan for the Application Container (Phoenix/Elixir) verification using `AppVerifier.fs`. The AppVerifier is responsible for validating the `indrajaal-app` container through a series of staged verification tasks.

### 1.1 Scope

- Phoenix/Elixir application container (`indrajaal-app` or `app`)
- Port 4000/4001 health checks
- Mix compilation verification
- Database connectivity dependency
- Asset compilation verification
- Telemetry/observability integration

### 1.2 STAMP Constraints

| Constraint ID | Description | Verification Method |
|---------------|-------------|---------------------|
| SC-CNT-009 | NixOS/Podman only | Container runtime check |
| SC-CEP-004 | Boot threshold compliance | Duration tracking |
| SC-VAL-003 | 100% Consensus validation | Multi-probe verification |
| SC-CMP-025 | Zero compilation warnings | Log analysis |
| SC-OBS-069 | Dual logging | Telemetry config check |

## 2. Prerequisites

### 2.1 Environment Requirements

```bash
# Required containers must be healthy before APP verification
- Database container (postgres/indrajaal-db) must be RUNNING and HEALTHY
- Network (indrajaal-network) must exist
- Compose file must be valid and accessible

# Required images
- localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv
- localhost/indrajaal-timescaledb-demo:nixos-devenv
```

### 2.2 Pre-Test Checklist

1. [ ] Database container is running (`podman ps | grep postgres`)
2. [ ] Database port 5433 is accessible (`nc -z localhost 5433`)
3. [ ] Network exists (`podman network ls | grep indrajaal`)
4. [ ] App image exists (`podman images | grep indrajaal-sopv51`)
5. [ ] Compose file exists (`ls podman-compose.yml`)

### 2.3 Database Dependency Verification

Before running AppVerifier, ensure DbVerifier has passed:

```fsharp
// From DbVerifier.fs
do! DbVerifier.execute logger runner config
```

## 3. Test Scenarios

### 3.1 Happy Path - Full Startup Verification

**Scenario ID**: APP-HP-001
**Description**: Complete application startup and verification
**Expected Duration**: ~3 minutes (Patient Mode)

```
Task Sequence:
1. APP_CREATE -> Container created via podman-compose
2. APP_DEPS -> Database connectivity verified
3. APP_COMPILE -> Mix compilation completed (Patient Mode)
4. APP_HEALTH -> Phoenix health endpoint responds HTTP 200
5. APP_READY -> Application fully operational
6. APP_ASSETS -> Static assets verified (optional)
7. APP_OBS -> Telemetry integration checked
```

**Expected State Transitions**:
```
Absent -> Created -> DepsReady -> Compiled -> Healthy -> Ready -> AssetsReady -> SIL-Ready
```

### 3.2 Database Dependency Failure

**Scenario ID**: APP-DF-001
**Description**: Application fails to start due to missing database
**Expected Behavior**: APP_DEPS task fails with SafetyViolation

```fsharp
// Expected error
Error (SafetyViolation("SC-DB-001", "Cannot connect to database at postgres:5433"))
```

**Recovery Steps**:
1. Start database container
2. Wait for DB health check
3. Retry APP verification

### 3.3 Compilation Failure

**Scenario ID**: APP-CF-001
**Description**: Mix compilation fails with errors
**Expected Behavior**: APP_COMPILE task fails with SafetyViolation

```fsharp
// Expected error
Error (SafetyViolation("SC-CMP-025", "Mix compilation failed with errors"))
```

**Detection Method**: Log parsing for `** (CompileError)` or `** (Mix)`

### 3.4 Health Endpoint Timeout

**Scenario ID**: APP-HT-001
**Description**: Phoenix health endpoint never responds
**Expected Behavior**: APP_HEALTH task fails with HealthCheckTimedOut

```fsharp
// Expected error (after 20 attempts * 3s = 60s)
Error (HealthCheckTimedOut("app", "phoenix_health"))
```

**Recovery Steps**:
1. Check container logs: `podman logs app`
2. Verify Phoenix configuration
3. Check for port binding issues

### 3.5 Container Restart Recovery

**Scenario ID**: APP-RR-001
**Description**: Application recovers after container restart
**Steps**:
1. Start app container
2. Wait for READY state
3. Stop container: `podman stop app`
4. Start container: `podman start app`
5. Verify recovery to READY state

**Expected Duration**: < 90s for recovery

## 4. FPPS 5-Method Verification

### 4.1 Pattern Matching Verification

```fsharp
// Verify Phoenix startup patterns in logs
let patterns = [
    "Running.*Endpoint"
    "Access.*at http"
    "Compiled"
    "Generated indrajaal app"
]
```

### 4.2 AST Verification

Not applicable for container verification (runtime only).

### 4.3 Statistical Verification

```fsharp
// Track metrics for statistical verification
logger.RecordHistogram("app.startup_time_ms", startupDuration)
logger.RecordHistogram("app.health_response_ms", healthCheckLatency)
logger.SetGauge("app.compilation_errors", 0)
logger.SetGauge("app.compilation_warnings", 0)
```

### 4.4 Binary Verification

```bash
# Verify container is running
podman ps --filter name=app --format "{{.Status}}"
# Expected: "Up X seconds" or "Up X minutes"

# Verify port bindings
podman port app
# Expected: 4000/tcp -> 0.0.0.0:4000
#           4001/tcp -> 0.0.0.0:4001
```

### 4.5 Line-by-Line Verification

```bash
# Verify health endpoint response
curl -sf http://localhost:4000/health
# Expected: HTTP 200 with JSON body

# Verify database connectivity from app
podman exec app sh -c "nc -z postgres 5433 && echo ok"
# Expected: "ok"
```

## 5. Integration with Service Chain

### 5.1 Service DAG Position

```
         [db]
           |
           v
         [app] <-- AppVerifier
           |
           v
         [obs]
```

### 5.2 Dependency Declaration

```fsharp
// AppVerifier.fs
let getDependencies () : string list =
    ["db"]  // App depends on database being healthy
```

### 5.3 Service Chain Verification Order

```
1. DbVerifier.execute
2. AppVerifier.execute (waits for DB HEALTHY)
3. ObsVerifier.execute (optional, parallel)
```

## 6. Error Codes and Recovery

| Error Type | Error Code | Recovery Action |
|------------|------------|-----------------|
| HealthCheckTimedOut | APP-001 | Check logs, restart container |
| SafetyViolation SC-DB-001 | APP-002 | Start database container |
| SafetyViolation SC-CMP-025 | APP-003 | Fix compilation errors |
| ProcessError | APP-004 | Check Podman status |
| CircuitBreakerOpen | APP-005 | Wait for cooldown |

## 7. Test Commands

### 7.1 Run AppVerifier Standalone

```bash
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf
dotnet run -- --env DEV --no-sterilize --no-build
```

### 7.2 Run With Full Verification

```bash
dotnet run -- --env DEV --verify
```

### 7.3 Debug Mode

```bash
CEPAF_DEBUG=1 dotnet run -- --env DEV
```

## 8. Metrics and Observability

### 8.1 Counters

- `app.startup_attempts` - Number of startup attempts
- `ace.consensus_achieved` - Successful consensus checks
- `ace.consensus_failed` - Failed consensus checks
- `app.health_check_failures` - Health endpoint failures

### 8.2 Histograms

- `app.startup_time_ms` - Total startup duration
- `app.compile_time_ms` - Mix compilation duration
- `app.health_response_ms` - Health endpoint latency
- `phase.duration_ms{phase=APP_VERIFICATION}` - Total phase duration

### 8.3 Gauges

- `app.state` - Current state (0=Absent, 1=Created, 2=Healthy, 3=Ready)
- `app.ports_open` - Number of open ports

## 9. Test Matrix

| Scenario | DB State | Expected Result | Duration |
|----------|----------|-----------------|----------|
| APP-HP-001 | Healthy | SIL-Ready | ~180s |
| APP-DF-001 | Absent | SafetyViolation | ~10s |
| APP-CF-001 | Healthy | SafetyViolation | ~120s |
| APP-HT-001 | Healthy | HealthCheckTimedOut | ~60s |
| APP-RR-001 | Healthy | SIL-Ready | ~90s |

## 10. Acceptance Criteria

1. [ ] All 7 verification tasks complete successfully
2. [ ] Total startup time < 180s (Patient Mode)
3. [ ] Health endpoint responds < 100ms
4. [ ] Database connectivity verified from app
5. [ ] No compilation errors (SC-CMP-025)
6. [ ] Telemetry configured (SC-OBS-069)
7. [ ] Service chain dependency on DB enforced

## 11. Related Documents

- [TESTSUITE-DB_CONTAINER-Standalone.md](./TESTSUITE-DB_CONTAINER-Standalone.md)
- [TESTSUITE-OBS_CONTAINER-Standalone.md](./TESTSUITE-OBS_CONTAINER-Standalone.md)
- [SERVICE-CHAIN-DAG-Dev-Demo.md](./SERVICE-CHAIN-DAG-Dev-Demo.md)
- [SAFETY.md](./SAFETY.md)
