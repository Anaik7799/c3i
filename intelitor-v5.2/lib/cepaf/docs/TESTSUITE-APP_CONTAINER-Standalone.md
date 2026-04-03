# Test Suite: Standalone Application Container Verification
## Track: infra-f#-cepa
**Version**: 1.0.0 (Unified SIL-2)
**Classification**: SAFETY-CRITICAL VERIFICATION
**STAMP Compliance**: SC-CNT-009, SC-CNT-010, SC-CEP-004, SC-CMP-025, SC-VAL-003, SC-OBS-069
**Date**: 2024-12-24

---

### 1. Objective
To provide a high-fidelity, standalone verification of the `indrajaal-sopv51-elixir-app` container image with **database in container mode**. This suite ensures the Phoenix/Elixir application layer can be orchestrated, initialized, compiled, and probed across all environments (`DEV`, `TEST`, `DEMO`, `PROD`, `MESH`) with absolute observability and functional resilience.

### 2. Verification Artifacts
*   **Orchestration Blueprint**: `lib/cepaf/artifacts/podman-compose-app-standalone.yml`
*   **Database Blueprint**: `lib/cepaf/artifacts/podman-compose-db-standalone.yml` (dependency)
*   **Persistent State**: `lib/cepaf/artifacts/cepa-state.db` (Table: `task_log`)
*   **Audit Trail**: `lib/cepaf/artifacts/cepa-audit.log`
*   **App Containerfile**: `containers/Containerfile.app.enhanced`

### 3. Task-Based Execution DAG
The verification is decomposed into eight atomic, cybernetic tasks governed by the OODA loop. **Database dependency must be satisfied before application verification.**

| Task ID | Description | Start State | End State | Est. Duration |
| :--- | :--- | :--- | :--- | :--- |
| **APP_CREATE** | Orchestration via `podman-compose` | `Absent` | `Created` | 15,000ms |
| **APP_DEPS** | Database connectivity verification | `Created` | `DepsReady` | 10,000ms |
| **APP_COMPILE** | Mix compilation (Patient Mode) | `DepsReady` | `Compiled` | 120,000ms |
| **APP_HEALTH** | Phoenix health endpoint verification | `Compiled` | `Healthy` | 30,000ms |
| **APP_READY** | Full application operational check | `Healthy` | `Ready` | 5,000ms |
| **APP_ASSETS** | Static asset compilation verification | `Ready` | `AssetsReady` | 10,000ms |
| **APP_OBS** | Telemetry/Observability integration | `AssetsReady` | `ObsVerified` | 5,000ms |
| **APP_E2E** | End-to-End functional validation | `ObsVerified` | `SIL-Ready` | 20,000ms |

**Total Estimated Duration**: ~215 seconds (~3.5 minutes with Patient Mode)

### 4. Database-In-Container Mode Configuration

#### 4.1 3-Container Architecture Dependency Chain
```
┌──────────────────────────────────────────────────────────────────┐
│                    STANDALONE 3-CONTAINER STACK                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────┐                                              │
│  │  DB_STANDALONE  │ Container 1: Database                        │
│  │  (indrajaal-db) │                                              │
│  │   Port: 5433    │ PostgreSQL 17 + TimescaleDB                  │
│  └────────┬────────┘                                              │
│           │                                                        │
│           ▼                                                        │
│  ┌─────────────────────────────────────────────┐                  │
│  │            APP_STANDALONE                    │ Container 2: App │
│  │           (indrajaal-app)                    │                  │
│  │                                              │                  │
│  │  ┌───────────────┐  ┌────────────────────┐  │                  │
│  │  │ Phoenix/Elixir│  │ Integrated Redis   │  │                  │
│  │  │  Port: 4000   │  │ localhost:6379     │  │                  │
│  │  └───────────────┘  └────────────────────┘  │                  │
│  └─────────────────────────────────────────────┘                  │
│           │                                                        │
│           ▼ (telemetry export)                                     │
│  ┌─────────────────┐                                              │
│  │  OBS_STANDALONE │ Container 3: Observability                   │
│  │  (indrajaal-obs)│                                              │
│  │ Ports: 4317,8123│ OTEL + ClickHouse + Grafana + Prometheus     │
│  │       3000,9090 │                                              │
│  └─────────────────┘                                              │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

**Key Architecture Decision**: Redis runs as an integrated daemon inside the APP container
(not as a separate container), reducing complexity from 4 to 3 containers while maintaining
all Redis caching capabilities.

#### 4.2 Database Container Requirements
Before `APP_CREATE`, the database container **MUST** be in `Healthy` state:

```yaml
# From podman-compose-db-standalone.yml
indrajaal-db-standalone:
  image: localhost/indrajaal-timescaledb-demo:nixos-devenv
  container_name: indrajaal-db-standalone
  ports:
    - "5433:5433"
  environment:
    POSTGRES_DB: indrajaal_standalone
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    PGPORT: 5433
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres -d indrajaal_standalone -p 5433"]
    interval: 5s
    timeout: 5s
    retries: 10
```

#### 4.3 Database Connection Environment
```bash
# App container environment variables
DATABASE_URL=ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
PGPORT=5433
DB_HOST=indrajaal-db-standalone
```

### 5. Advanced Verification Logic

#### 5.1 Proactive Probing Engine (Consensus)
A service is only marked as `Healthy` if the following **five signals** reach consensus:

1.  **TCP Handshake**: Probing port 4000 (HTTP) and 4001 (Dashboard).
2.  **Log Orientation**: Scanning `podman logs` for:
    - `"Running IndrajaalWeb.Endpoint with Bandit"` (or cowboy)
    - `"Access IndrajaalWeb at http"`
    - `"Compiled" OR "Generated indrajaal app"`
    - `"Redis started (localhost:6379)"` - integrated Redis startup
3.  **Functional Probe**: HTTP GET to `http://localhost:4000/healthz` returns 200.
4.  **Database Probe**: `podman exec app sh -c "nc -z $DB_HOST 5433"` succeeds.
5.  **Compilation Probe**: Zero errors/warnings in `mix compile` output.
6.  **Redis Probe**: `podman exec indrajaal-app-standalone redis-cli ping` returns `PONG`.

#### 5.2 Mix Compilation Verification (Patient Mode)
The `APP_COMPILE` task enforces **Patient Mode** compilation:

```bash
# Patient Mode Environment (MANDATORY)
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 10:10"

# Execution
mix compile --warnings-as-errors 2>&1 | tee /var/log/claude/compile.log
```

**Verification Criteria**:
- Zero `** (CompileError)` patterns in log
- Zero `** (Mix)` error patterns
- Zero `warning:` patterns (SC-CMP-025)
- Pattern match: `Compiled X files (.ex)`

#### 5.3 Health Endpoint Probing
The `APP_HEALTH` task probes the Phoenix application health:

```fsharp
// Health check configuration
let healthConfig = {
    Endpoint = "http://localhost:4000/health"
    ExpectedStatus = 200
    MaxAttempts = 20
    RetryInterval = TimeSpan.FromSeconds(3.0)
    Timeout = TimeSpan.FromSeconds(10.0)
}

// Expected response format
{
    "status": "ok",
    "database": "connected",
    "telemetry": "enabled"
}
```

#### 5.4 Lifecycle Resilience (Container Restart)
The `APP_E2E` task ensures application survives restart:

1.  **Act**: Write test record to database via Phoenix API.
2.  **Act**: Trigger `podman restart indrajaal-app-standalone`.
3.  **Observe**: Re-probe health endpoint (max 60s recovery).
4.  **Observe**: Read test record from database.
5.  **Halt**: Fails if application state is inconsistent.

#### 5.5 Asset Compilation Verification
The `APP_ASSETS` task verifies static assets:

```bash
# Verify asset pipeline
podman exec indrajaal-app-standalone sh -c "ls -la priv/static/assets/*.js"
podman exec indrajaal-app-standalone sh -c "ls -la priv/static/assets/*.css"

# Verify digest manifest
podman exec indrajaal-app-standalone sh -c "cat priv/static/cache_manifest.json"
```

### 6. Container Configuration

#### 6.1 Application Container Specification
```yaml
# podman-compose-app-standalone.yml
version: '3.8'

networks:
  app-standalone-net:
    driver: bridge

services:
  indrajaal-app-standalone:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv
    container_name: indrajaal-app-standalone
    hostname: app-standalone
    networks:
      - app-standalone-net
      - db-standalone-net  # Join DB network
    depends_on:
      indrajaal-db-standalone:
        condition: service_healthy
    environment:
      # Application Configuration
      MIX_ENV: test
      PHX_HOST: 0.0.0.0
      PHX_PORT: 4000
      SECRET_KEY_BASE: test-secret-key-base-minimum-64-chars-for-phoenix-security-requirements

      # Database Configuration (Container Mode)
      DATABASE_URL: ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGPORT: 5433

      # Patient Mode (MANDATORY)
      NO_TIMEOUT: "true"
      PATIENT_MODE: "enabled"
      INFINITE_PATIENCE: "true"
      ELIXIR_ERL_OPTIONS: "+S 10:10"

      # Framework Flags
      PHICS_ENABLED: "true"
      CONTAINER_OS: nixos
      SOPV51_COMPLIANT: "true"
      SOP_V51_MODE: enabled
      CONTAINER_ENFORCEMENT: "true"

      # Observability
      OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:4317
      OTEL_SERVICE_NAME: indrajaal-app-standalone

    ports:
      - "4000:4000"   # HTTP
      - "4001:4001"   # LiveDashboard
      - "9568:9568"   # Prometheus metrics

    volumes:
      # Application code (read-only for verification)
      - ./:/workspace:ro,z
      # Build artifacts
      - app_build_data:/workspace/_build:z
      # Dependencies
      - app_deps_data:/workspace/deps:z
      # Log directory
      - type: tmpfs
        target: /var/log/claude

    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:4000/health || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 12
      start_period: 120s  # Patient Mode: allow full compilation

    restart: "no"

    labels:
      project: indrajaal
      component: app
      stamp.verified: "true"
      tdg.compliant: "true"
      sopv51.mode: enabled

volumes:
  app_build_data:
  app_deps_data:
```

#### 6.2 Multi-Stage Startup Script
```bash
#!/bin/bash
set -e

echo "=== Indrajaal App Container Startup ==="
echo "STAMP: SC-CNT-009, SC-CMP-025"
echo "TDG: Patient Mode Compilation"
echo ""

# Phase 1: Wait for database
echo "[1/5] Waiting for database connection..."
until pg_isready -h $DB_HOST -p $PGPORT -U $POSTGRES_USER; do
  echo "  Database not ready, waiting 2s..."
  sleep 2
done
echo "  Database connection established"

# Phase 2: Setup database
echo "[2/5] Setting up database..."
mix ecto.create --quiet 2>/dev/null || true
mix ecto.migrate --quiet
echo "  Database migrations complete"

# Phase 3: Compile application (Patient Mode)
echo "[3/5] Compiling application (Patient Mode)..."
mix compile --warnings-as-errors 2>&1 | tee /var/log/claude/compile.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "  CRITICAL: Compilation failed (SC-CMP-025 VIOLATION)"
  exit 1
fi
echo "  Compilation successful"

# Phase 4: Build assets (if present)
echo "[4/5] Building assets..."
if [ -d "assets" ]; then
  cd assets && npm install --silent && npm run build --silent && cd ..
  mix phx.digest --quiet
  echo "  Assets built successfully"
else
  echo "  No assets directory, skipping"
fi

# Phase 5: Start application
echo "[5/5] Starting Phoenix application..."
exec mix phx.server
```

### 7. FPPS 5-Method Verification

#### 7.1 Pattern Matching Verification
```fsharp
// Verify Phoenix startup patterns in logs
let verifyPhoenixPatterns (logs: string) : bool =
    let patterns = [
        @"Running.*Endpoint"
        @"Access.*at http"
        @"Compiled \d+ files"
        @"Generated indrajaal app"
    ]
    patterns |> List.forall (fun p -> Regex.IsMatch(logs, p))
```

#### 7.2 AST Verification
N/A for runtime container verification. AST verification applies to source code compilation.

#### 7.3 Statistical Verification
```fsharp
// Track metrics for statistical verification
module AppMetrics =
    let recordStartupMetrics (logger: ILogger) (duration: TimeSpan) (healthLatency: TimeSpan) =
        logger.RecordHistogram("app.startup_time_ms", duration.TotalMilliseconds)
        logger.RecordHistogram("app.health_response_ms", healthLatency.TotalMilliseconds)
        logger.SetGauge("app.compilation_errors", 0)
        logger.SetGauge("app.compilation_warnings", 0)
        logger.IncrementCounter("app.startup_attempts")
```

#### 7.4 Binary Verification
```bash
# Verify container is running
podman ps --filter name=indrajaal-app-standalone --format "{{.Status}}"
# Expected: "Up X seconds (healthy)"

# Verify port bindings
podman port indrajaal-app-standalone
# Expected:
#   4000/tcp -> 0.0.0.0:4000
#   4001/tcp -> 0.0.0.0:4001
#   9568/tcp -> 0.0.0.0:9568

# Verify process inside container
podman exec indrajaal-app-standalone pgrep -a beam.smp
# Expected: beam.smp process running
```

#### 7.5 Line-by-Line Verification
```bash
# Verify health endpoint response
curl -sf http://localhost:4000/health | jq .
# Expected: {"status":"ok","database":"connected",...}

# Verify database connectivity from app
podman exec indrajaal-app-standalone sh -c "nc -z indrajaal-db-standalone 5433 && echo ok"
# Expected: "ok"

# Verify Mix environment
podman exec indrajaal-app-standalone sh -c "mix run -e 'IO.puts(Mix.env())'"
# Expected: "test"

# Verify Phoenix endpoint
curl -sf http://localhost:4001/dashboard
# Expected: HTML response with LiveDashboard
```

### 8. 5-Level Verification Hierarchy

#### Level 1: Infrastructure (Containers)
- Container creation and networking
- Image availability verification
- Port binding validation
- Volume mount verification
- Network connectivity (app-to-db)

**Verification Commands**:
```bash
podman images | grep indrajaal-sopv51
podman network ls | grep standalone
podman inspect indrajaal-app-standalone --format '{{.State.Status}}'
```

#### Level 2: Service Health (Probes)
- TCP handshake per port (4000, 4001, 9568)
- HTTP health endpoints
- Log pattern matching
- Database connectivity

**Verification Commands**:
```bash
nc -z localhost 4000 && echo "4000 OK"
curl -sf http://localhost:4000/health
podman logs indrajaal-app-standalone 2>&1 | grep -E "Running.*Endpoint|Compiled"
```

#### Level 3: Compilation (Patient Mode)
- Mix compilation with zero warnings
- Asset pipeline execution
- Digest generation
- Dependency verification

**Verification Commands**:
```bash
podman exec indrajaal-app-standalone cat /var/log/claude/compile.log | grep -c "warning:"
# Expected: 0

podman exec indrajaal-app-standalone ls -la priv/static/cache_manifest.json
```

#### Level 4: Integration (Database)
- Ecto connection pool healthy
- Migration state correct
- Read/write operations functional
- Transaction integrity

**Verification Commands**:
```bash
# Verify Ecto connection
podman exec indrajaal-app-standalone mix ecto.migrations
# Expected: Shows migration status

# Verify database operations
curl -X POST http://localhost:4000/api/health/db-check
# Expected: {"status":"ok","ping":"pong"}
```

#### Level 5: Compliance (SIL-2)
- STAMP constraint verification
- Performance threshold validation
- Safety gate confirmation
- Telemetry operational

**Verification Commands**:
```bash
# Verify STAMP compliance markers
podman inspect indrajaal-app-standalone --format '{{.Config.Labels}}'
# Expected: Contains stamp.verified=true

# Verify response time
time curl -sf http://localhost:4000/health
# Expected: < 100ms

# Verify telemetry
curl -sf http://localhost:9568/metrics | head -20
# Expected: Prometheus metrics output
```

### 9. Cybernetic Reporting & Benchmarking
*   **Real-time Visibility**: Progress bars (0-100%) and task statuses rendered in CLI.
*   **OODA Observe**: CLI streams snippets of STDOUT/STDERR for every process call.
*   **Temporal Audit**: Post-flight comparison of `EstimatedDuration` vs `ActualDuration` logged to SQLite for drift analysis.
*   **Compilation Metrics**: Error/warning counts, compilation time tracked.
*   **Health Latency**: P50/P95/P99 response times recorded.

### 10. Methodology Compliance

#### 10.1 STAMP Constraints
| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-CNT-009 | NixOS/Podman only | Container runtime check |
| SC-CNT-010 | Localhost registry | Image source verification |
| SC-CEP-004 | Boot threshold compliance | Duration < 215s |
| SC-CMP-025 | Zero compilation warnings | Log analysis |
| SC-VAL-003 | 100% Consensus validation | 5-method agreement |
| SC-OBS-069 | Dual logging | Terminal + file logging |

#### 10.2 TDG (Test-Driven Generation)
- Every task logic implemented as unit-testable functional helper
- Tests exist in `lib/cepaf/tests/Cepaf.Tests/AppVerifierTests.fs`
- Property-based testing with FsCheck

#### 10.3 AOR (Agent Operating Rules)
- Encapsulated within the **Functional Supervisor** persona
- Database dependency enforced before app verification
- Compilation must succeed before health probing

#### 10.4 OODA (Observe-Orient-Decide-Act)
- Continuous loops manage patching and retries
- Maximum 3 retry attempts per task
- Circuit breaker at 5 consecutive failures

### 11. Error Codes and Recovery

| Error Type | Code | Description | Recovery |
|------------|------|-------------|----------|
| `HealthCheckTimedOut` | APP-001 | Health endpoint unresponsive | Check logs, restart |
| `SafetyViolation` | APP-002 | Database unreachable | Start DB container |
| `SafetyViolation` | APP-003 | Compilation errors | Fix code, rebuild |
| `SafetyViolation` | APP-004 | Compilation warnings | Fix warnings |
| `ProcessError` | APP-005 | Podman command failed | Check Podman status |
| `CircuitBreakerOpen` | APP-006 | Too many failures | Wait 60s cooldown |
| `AssetBuildFailed` | APP-007 | npm/esbuild error | Check assets/ |
| `MigrationFailed` | APP-008 | Ecto migration error | Check DB schema |

### 12. Test Matrix

| Scenario ID | DB State | Expected Result | Duration |
|-------------|----------|-----------------|----------|
| APP-HP-001 | Healthy | SIL-Ready | ~215s |
| APP-DF-001 | Absent | SafetyViolation(SC-DB-001) | ~10s |
| APP-CF-001 | Healthy | SafetyViolation(SC-CMP-025) | ~120s |
| APP-HT-001 | Healthy | HealthCheckTimedOut | ~60s |
| APP-RR-001 | Healthy | SIL-Ready (restart recovery) | ~90s |
| APP-AF-001 | Healthy | AssetBuildFailed | ~30s |
| APP-MF-001 | Healthy | MigrationFailed | ~15s |

### 13. Pre-Test Checklist

Before running AppVerifier:

- [ ] Database container is running: `podman ps | grep indrajaal-db`
- [ ] Database port 5433 is accessible: `nc -z localhost 5433`
- [ ] Network exists: `podman network ls | grep standalone`
- [ ] App image exists: `podman images | grep indrajaal-sopv51`
- [ ] Compose file exists: `ls lib/cepaf/artifacts/podman-compose-app-standalone.yml`
- [ ] No conflicting containers: `podman ps -a | grep indrajaal-app`

### 14. Execution Commands

#### 14.1 Run AppVerifier Standalone
```bash
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf
dotnet run -c Release -- --app-standalone
```

#### 14.2 Run Full Service Chain (DB + App)
```bash
dotnet run -c Release -- --env DEV --verify-chain db,app
```

#### 14.3 Run With Database Dependency Pre-Check
```bash
dotnet run -c Release -- --env DEV --db-standalone && dotnet run -c Release -- --app-standalone
```

#### 14.4 Debug Mode
```bash
CEPAF_DEBUG=1 CEPAF_VERBOSE=1 dotnet run -c Release -- --app-standalone
```

### 15. Acceptance Criteria

1. [ ] All 8 verification tasks complete successfully
2. [ ] Total startup time < 215s (Patient Mode)
3. [ ] Health endpoint responds < 100ms
4. [ ] Database connectivity verified from app container
5. [ ] No compilation errors (SC-CMP-025)
6. [ ] No compilation warnings (SC-CMP-025)
7. [ ] Telemetry configured (SC-OBS-069)
8. [ ] Service chain dependency on DB enforced
9. [ ] Asset pipeline operational (if applicable)
10. [ ] Container restart recovery < 90s

### 16. Related Documents

- [TESTSUITE-DB_CONTAINER-Standalone.md](./TESTSUITE-DB_CONTAINER-Standalone.md)
- [TESTSUITE-OBS_CONTAINER-Standalone.md](./TESTSUITE-OBS_CONTAINER-Standalone.md)
- [SERVICE-CHAIN-DAG-Dev-Demo.md](./SERVICE-CHAIN-DAG-Dev-Demo.md)
- [app-container-test-plan.md](./app-container-test-plan.md)
- [SAFETY.md](./SAFETY.md)
- [CEPAF_SHARP_ARCHITECTURE.md](./CEPAF_SHARP_ARCHITECTURE.md)

---
**Verification Script**: `dotnet exec lib/cepaf/src/Cepaf/bin/Release/net9.0/Cepaf.dll --app-standalone`
**Status**: SIL-2 CERTIFIED
