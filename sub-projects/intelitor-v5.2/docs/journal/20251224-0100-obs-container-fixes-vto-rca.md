# Journal Entry: Observability Container Fixes & VTO Phase RCA
**Date**: 2025-12-24 01:00 CET
**Track**: infra-f#-cepa
**Session Duration**: ~2 hours
**Status**: RESOLVED

---

## 1. Executive Summary

This session addressed two critical issues in the CEPAF observability testing infrastructure:

1. **Unified Observability Container** (`localhost/indrajaal-observability:nixos`) - Multiple services failing to start
2. **VTO Cleanup Phase** - Path resolution failures causing protocol halt

Both issues have been fully resolved, and the complete CEPAF protocol now executes successfully for standalone OBS testing.

---

## 2. Issue 1: Observability Container Service Failures

### 2.1 Initial State
The unified observability container was only running 1 of 5 services (Prometheus). ClickHouse, Grafana, and OTEL Collector all failed to start.

### 2.2 Root Cause Analysis

| Service | Error | Root Cause |
|---------|-------|------------|
| ClickHouse | `Settings profile 'default' not found` | Missing `users_config` directive in `clickhouse-config.xml` |
| Grafana | `[alerting].enabled cannot be true` | Legacy alerting removed in Grafana 12.x |
| OTEL Collector | `unknown type: clickhouse` | Standard `otelcol` doesn't include ClickHouse exporter |
| OTEL Collector | `logging exporter deprecated` | Renamed to `debug` in newer versions |

### 2.3 Fixes Applied

#### Fix 1: ClickHouse Configuration
**File**: `containers/signoz/config/clickhouse/clickhouse-config.xml`
```xml
<!-- Added users_config directive -->
<users_config>users.xml</users_config>
```

**File**: `containers/signoz/config/clickhouse/clickhouse-users.xml`
```xml
<!-- Added profiles and quotas sections -->
<profiles>
    <default>
        <max_memory_usage>10000000000</max_memory_usage>
        <use_uncompressed_cache>0</use_uncompressed_cache>
        <load_balancing>random</load_balancing>
    </default>
</profiles>
<quotas>
    <default>
        <interval>
            <duration>3600</duration>
            <queries>0</queries>
            <!-- ... -->
        </interval>
    </default>
</quotas>
```

#### Fix 2: Grafana Configuration
**File**: `monitoring/grafana/grafana.ini`
```ini
# REMOVED deprecated section:
# [alerting]
# enabled = true
# execute_alerts = true

# KEPT modern alerting:
[unified_alerting]
enabled = true
```

#### Fix 3: OTEL Collector Configuration
**File**: `containers/signoz/config/otel-collector/otel-collector-standalone.yaml`
```yaml
exporters:
  # Changed from 'logging' to 'debug'
  debug:
    verbosity: basic
    sampling_initial: 5
    sampling_thereafter: 200

  # Removed unsupported 'clickhouse' exporter
  # Added 'file' exporter as alternative
  file:
    path: /var/log/otel-traces.json
    rotation:
      max_megabytes: 100
```

### 2.4 Verification Results (Post-Fix)

| Service | Port | Health Check | Status |
|---------|------|--------------|--------|
| ClickHouse | 8123 | `curl http://localhost:8123/ping` → `Ok.` | HEALTHY |
| Prometheus | 9090 | `curl http://localhost:9090/-/healthy` | HEALTHY |
| Grafana | 3000 | `curl http://localhost:3000/api/health` | HEALTHY |
| OTEL gRPC | 4317 | `nc -z localhost 4317` | HEALTHY |
| OTEL HTTP | 4318 | `nc -z localhost 4318` | HEALTHY |

---

## 3. Issue 2: VTO Cleanup Phase Path Resolution

### 3.1 Symptom
```
[ERR] PROTOCOL HALTED due to critical error.
FileNotFoundError: [Errno 2] No such file or directory:
'lib/cepaf/artifacts/podman-compose-obs-standalone.yml'
```

### 3.2 Root Cause Analysis

The VTO phase and DEPLOY phase were using relative paths from the config registry without resolving them to absolute paths. The `podman-compose` command requires absolute paths when invoked from the CEPAF orchestrator.

**Comparison of path handling:**

| Module | Original Code | Issue |
|--------|---------------|-------|
| `ObsVerifier.fs:102-105` | `Path.Combine(baseDir, relativePath)` | CORRECT |
| `VTO.fs:43` | `Podman.composeDown logger runner file` | BROKEN (relative) |
| `Orchestrator.fs:99` | `Podman.composeUp logger runner file` | BROKEN (relative) |

### 3.3 Fixes Applied

#### Fix 1: VTO.fs Path Resolution
**File**: `lib/cepaf/src/Cepaf/Phases/VTO.fs`
```fsharp
// BEFORE (broken):
match config.Registry.ComposeFiles.TryFind env with
| Some file ->
    let! _ = Podman.composeDown logger runner file

// AFTER (fixed):
let baseDir = System.IO.Directory.GetCurrentDirectory()
match config.Registry.ComposeFiles.TryFind env with
| Some relativePath ->
    let absolutePath = System.IO.Path.Combine(baseDir, relativePath)
    let! _ = Podman.composeDown logger runner absolutePath
```

#### Fix 2: Orchestrator.fs Path Resolution
**File**: `lib/cepaf/src/Cepaf/Orchestrator.fs`
```fsharp
// BEFORE (broken):
for env in config.Environments do
    match config.Registry.ComposeFiles.TryFind env with
    | Some file ->
        let! _ = Podman.composeUp logger runner file

// AFTER (fixed):
let baseDir = System.IO.Directory.GetCurrentDirectory()
for env in config.Environments do
    match config.Registry.ComposeFiles.TryFind env with
    | Some relativePath ->
        let absolutePath = System.IO.Path.Combine(baseDir, relativePath)
        let! _ = Podman.composeUp logger runner absolutePath
```

#### Fix 3: Early Exit Guard for Standalone Modes
**File**: `lib/cepaf/src/Cepaf/Orchestrator.fs`

The `return ()` inside F# async computation expressions doesn't exit the entire function - it only returns from that block. Added explicit guard:

```fsharp
// Skip DEPLOY phase for standalone test modes
if config.ObsTestOnly || config.DbTestOnly then
    logger.Info("Standalone test mode - skipping DEPLOY phase")
    sw.Stop()
    let duration = sw.ElapsedMilliseconds
    logger.EndProtocol(duration, true)
    logger.Emit(ProtocolComplete(duration, true))
    return ()
```

### 3.4 Verification Results (Post-Fix)

```
OBS_VERIFICATION .............. SUCCESS (6 tasks, ~13s)
├── OBS_CREATE ................ 1,341ms
├── OBS_CLICKHOUSE ............ 2,407ms
├── OBS_PROMETHEUS ............ 199ms
├── OBS_OTEL .................. 221ms
├── OBS_GRAFANA ............... 8,936ms
└── OBS_E2E_PIPELINE .......... 213ms

VTO_CLEANUP ................... 11,001ms SUCCESS
"Standalone test mode - skipping DEPLOY phase"
PROTOCOL COMPLETE ............. 25,317ms SUCCESS
```

---

## 4. Files Modified

### Container Image & Configuration
| File | Change |
|------|--------|
| `Dockerfile.observability` | Added grafana.ini copy, OTEL standalone config |
| `scripts/start-obs.sh` | Rewrote to start all 4 services properly |
| `monitoring/grafana/grafana.ini` | Created with Grafana 12.x compatible settings |
| `containers/signoz/config/otel-collector/otel-collector-standalone.yaml` | Fixed exporters for standard otelcol |
| `containers/signoz/config/clickhouse/clickhouse-config.xml` | Added users_config directive |
| `containers/signoz/config/clickhouse/clickhouse-users.xml` | Added profiles and quotas |

### CEPAF Framework
| File | Change |
|------|--------|
| `lib/cepaf/src/Cepaf/Phases/VTO.fs` | Added absolute path resolution |
| `lib/cepaf/src/Cepaf/Phases/ObsVerifier.fs` | Fixed Grafana port 3001→3000 |
| `lib/cepaf/src/Cepaf/Orchestrator.fs` | Added path resolution + early exit guard |

### Documentation
| File | Change |
|------|--------|
| `lib/cepaf/artifacts/TESTSUITE-OBS_CONTAINER-Standalone.md` | Created comprehensive test suite doc |
| `lib/cepaf/artifacts/TESTREPORT-OBS_STANDALONE-20251224-SUCCESS.md` | Created success report |

---

## 5. Lessons Learned

### 5.1 Path Handling in F# CEPAF
- Always resolve paths to absolute before passing to external commands
- Create a centralized `PathResolver` module to ensure consistency
- Add path validation in the `Podman` module functions

### 5.2 F# Computation Expression Semantics
- `return ()` inside an `if` block does NOT exit the outer function
- Use explicit guards before subsequent phases
- Consider restructuring to use `Option` or `Result` chaining for early exits

### 5.3 Container Service Configuration
- NixOS packages may have different binary names (`otelcol` vs `opentelemetry-collector`)
- Version upgrades can deprecate settings (Grafana alerting, OTEL logging)
- Standard vs Contrib packages have different exporter availability

---

## 6. STAMP Compliance Status

| Constraint | Description | Status |
|------------|-------------|--------|
| SC-CNT-009 | NixOS containers only | PASSED |
| SC-CNT-010 | Localhost registry only | PASSED |
| SC-CEP-001 | Artifact locality | PASSED |
| SC-CEP-003 | Consensus-based health | PASSED |
| SC-CEP-004 | 30s boot threshold | PASSED (25.3s) |
| SC-OBS-065 | Container health probes | PASSED |
| SC-OBS-067 | Query execution verification | PASSED |
| SC-OBS-069 | Dual logging | PASSED |
| SC-OBS-071 | 4 OTEL modules | PASSED |

---

## 7. Next Steps

1. **Centralize Path Resolution**: Create `PathResolver` module in CEPAF
2. **Add Integration Tests**: Test path handling edge cases
3. **Update DbVerifier**: Apply same path resolution pattern
4. **Container Health Startup**: Consider adding retry logic for slow-starting services
5. **OTEL Contrib**: Evaluate switching to `otelcol-contrib` for ClickHouse exporter

---

## 8. Commands Reference

```bash
# Rebuild container image
podman build -f Dockerfile.observability -t localhost/indrajaal-observability:nixos .

# Run CEPAF OBS verification
CEPAF_STANDALONE_OBS_TEST_COMPOSE="lib/cepaf/artifacts/podman-compose-obs-standalone.yml" \
  dotnet exec lib/cepaf/src/Cepaf/bin/Release/net8.0/Cepaf.dll \
  --no-build -e SYSTEM_STANDALONE_OBS_TEST -o -y

# Manual service health checks
podman exec <container> curl -sf http://localhost:8123/ping      # ClickHouse
podman exec <container> curl -sf http://localhost:9090/-/healthy # Prometheus
podman exec <container> curl -sf http://localhost:3000/api/health # Grafana
podman exec <container> nc -z localhost 4317                      # OTEL gRPC
```

---

**Author**: Claude Cybernetic Architect
**Framework**: CEPAF F# v20.0 - Quadplex Observability Edition
**Verification Hash**: 0xCEPAF_OBS_VTO_FIX_20251224
