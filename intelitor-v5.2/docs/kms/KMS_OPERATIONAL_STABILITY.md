# KMS: Operational Stability Knowledge Base
## Indrajaal v21.3.0 - Biomorphic Fractal Holon Architecture

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   KNOWLEDGE MANAGEMENT SYSTEM
     ╭╯ ╰─╯ ╰╮       Operational Stability
    ●╯       ╰●       v21.3.0 | 2026-01-05
```

## 1. Overview

This KMS document captures operational stability procedures, troubleshooting patterns, and recovery protocols for the Indrajaal system aligned with Biomorphic Fractal Holon architecture.

## 2. System Architecture Reference

### 2.1 Fractal Layers (L1-L7)

| Layer | Name | Scope | Time Scale |
|-------|------|-------|------------|
| L1 | Function | Single operation | Milliseconds |
| L2 | Module | Component group | Seconds |
| L3 | Domain | Business context | Minutes |
| L4 | Service | Distributed unit | Minutes-Hours |
| L5 | Platform | Full system | Hours |
| L6 | Organization | Multi-tenant | Days |
| L7 | Federation | Cross-system | Weeks |

### 2.2 Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     INDRAJAAL SYSTEM v21.3.0                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    PRAJNA COCKPIT (C3I)                   │  │
│  │  SmartMetrics │ Guardian │ Sentinel │ AI Copilot         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌──────────┐  ┌──────────┐  │  ┌──────────┐  ┌──────────┐     │
│  │ Domains  │  │  Safety  │  │  │Observ.  │  │  CEPAF   │     │
│  │   (30)   │  │ (Immune) │  │  │ (Zenoh) │  │   (F#)   │     │
│  └──────────┘  └──────────┘  │  └──────────┘  └──────────┘     │
│                              │                                  │
│  ┌───────────────────────────┼───────────────────────────────┐  │
│  │                   CONTAINER STACK                         │  │
│  │   indrajaal-app:4000  │  indrajaal-db:5433  │  obs:4317   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Operational Procedures

### 3.1 System Startup Sequence

```bash
# 1. Enter development environment
devenv shell

# 2. Start container stack
sa-up

# 3. Wait for health (30s)
sa-status

# 4. Verify database
db-setup

# 5. Compile system
compile

# 6. Start Phoenix
app
```

### 3.2 Quality Gate Pipeline

```bash
# Full quality pipeline
quality-full

# Or step-by-step:
mix format --check-formatted
mix credo --strict
mix dialyzer
mix sobelow --exit

# Run tests with coverage
test-cover
```

### 3.3 Container Management

| Command | Purpose |
|---------|---------|
| `sa-up` | Start all 4 containers |
| `sa-down` | Stop containers gracefully |
| `sa-clean` | Stop + remove volumes |
| `sa-status` | Show health status |
| `sa-logs [svc]` | Stream logs |
| `sa-db` | Start only database |
| `sa-obs` | Start only observability |
| `sa-app` | Start only application |

### 3.4 Database Operations

| Command | Purpose |
|---------|---------|
| `db-setup` | Create + migrate |
| `db-reset` | Drop + recreate |
| `db-migrate` | Apply migrations |
| `db-console` | Open psql prompt |

## 4. Troubleshooting Guide

### 4.1 Compilation Errors

#### EP-GEN-014: PropCheck/StreamData Conflict
**Symptom**: `function imported from both StreamData and PropCheck.BasicTypes`

**Solution**:
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD
```

#### Broken check all() Syntax
**Symptom**: `syntax error before: '<-'`

**Cause**: Wrong parenthesis pattern in ExUnitProperties

**Solution**:
```elixir
# WRONG
check all(x <- SD.integer()) do

# CORRECT
check all x <- SD.integer() do
```

### 4.2 Database Connection Issues

#### Connection Refused
**Symptom**: `connection refused :5433`

**Checklist**:
1. Verify container running: `podman ps | grep db`
2. Check port binding: `ss -tlnp | grep 5433`
3. Restart if needed: `sa-down && sa-clean && sa-up`

#### Authentication Failed
**Symptom**: `FATAL: password authentication failed`

**Solution**: Verify environment variables:
```bash
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test"
```

### 4.3 NIF Compilation Issues

#### Zenoh NIF Load Failure
**Symptom**: `Failed to load NIF library`

**Checklist**:
1. Verify Rust installed: `rustc --version`
2. Check Rustler version match:
   - `mix.exs`: `:rustler, "~> 0.31"`
   - `Cargo.toml`: `rustler = "0.31"`
3. Clean rebuild: `mix deps.clean zenoh_ex && mix deps.get && mix compile`

### 4.4 Test Failures

#### ExUnit Property Test Timeout
**Symptom**: Test hangs or times out

**Solution**: Ensure Patient Mode:
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test
```

#### Zenoh Test Skip
**Symptom**: Zenoh tests skipped

**Solution**: Enable NIF:
```bash
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test
```

### 4.5 Container Issues

#### Unhealthy Container
**Symptom**: `sa-status` shows unhealthy

**Diagnosis**:
```bash
# Check logs
sa-logs [container-name]

# Check health endpoint
curl http://localhost:4000/health

# Inspect container
podman inspect [container-id]
```

#### Port Conflict
**Symptom**: `address already in use`

**Solution**:
```bash
# Find process using port
ss -tlnp | grep [port]

# Kill if safe
kill [pid]

# Or use different port in compose file
```

## 5. Recovery Procedures

### 5.1 Clean State Recovery

```bash
# 1. Stop everything
sa-down

# 2. Remove volumes and state
sa-clean
rm -rf _build deps

# 3. Rebuild from scratch
mix deps.get
mix compile

# 4. Restart containers
sa-up

# 5. Setup database
db-setup
```

### 5.2 Test Suite Recovery

```bash
# 1. Clean test state
mix propcheck.clean
rm -rf _build/test

# 2. Recompile tests
MIX_ENV=test mix compile

# 3. Run with fresh seed
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test --seed 0
```

### 5.3 F#/CEPAF Recovery

```bash
# 1. Clean F# build
cd lib/cepaf
dotnet clean

# 2. Restore packages
dotnet restore

# 3. Rebuild
dotnet build

# 4. Run tests
dotnet test
```

## 6. Monitoring Procedures

### 6.1 Health Checks

| Endpoint | Expected | Interval |
|----------|----------|----------|
| `/health` | 200 OK | 10s |
| `/api/prajna/metrics` | JSON with score | 30s |
| Prometheus:9090 | UP | 60s |
| Grafana:3000 | 200 OK | 60s |

### 6.2 Key Metrics

| Metric | Healthy Range | Alert Threshold |
|--------|---------------|-----------------|
| Health Score | 0.8 - 1.0 | < 0.6 |
| Response Time | < 50ms | > 100ms |
| Error Rate | < 1% | > 5% |
| Memory Usage | < 80% | > 90% |
| CPU Usage | < 70% | > 85% |

### 6.3 Zenoh KPI Topics

| Topic | Purpose |
|-------|---------|
| `indrajaal/prajna/kpi/health` | System health score |
| `indrajaal/prajna/kpi/agents` | Agent status |
| `indrajaal/prajna/kpi/threats` | Security alerts |
| `indrajaal/prajna/kpi/performance` | Latency metrics |

## 7. STAMP Compliance Checklist

### 7.1 Pre-Deployment

- [ ] SC-CMP-025: 0 compilation warnings
- [ ] SC-CMP-026: All files compile
- [ ] SC-TEST-001: Tests compile
- [ ] SC-TEST-005: SKIP_ZENOH_NIF=0
- [ ] SC-CNT-009: Podman containers only
- [ ] SC-SEC-044: Sobelow passes

### 7.2 Runtime

- [ ] SC-PRF-050: Response < 50ms
- [ ] SC-OBS-069: Dual logging active
- [ ] SC-EMR-057: Emergency stop < 5s
- [ ] SC-HOLON-001: SQLite state sovereign

## 8. Emergency Procedures

### 8.1 System Halt

```elixir
# From IEx console
Indrajaal.Safety.Guardian.emergency_halt(:reason)

# Or via API
curl -X POST http://localhost:4000/api/prajna/guardian/emergency-halt \
  -H "Content-Type: application/json" \
  -d '{"reason": "manual_intervention"}'
```

### 8.2 Rollback

```bash
# Database rollback
mix ecto.rollback

# Code rollback
git checkout [previous-tag]
mix deps.get && mix compile

# Container rollback
podman pull localhost/indrajaal-app:[previous-version]
sa-down && sa-up
```

### 8.3 Incident Response

1. **Assess**: Check health endpoints, logs, metrics
2. **Contain**: Isolate affected component if needed
3. **Identify**: Use 5-Why RCA methodology
4. **Resolve**: Apply fix with shadow testing
5. **Document**: Journal entry + KMS update
6. **Prevent**: FMEA analysis + test coverage

## 9. Related Documents

| Document | Location |
|----------|----------|
| 5-Level Stability Plan | `docs/planning/BIOMORPHIC_OPERATIONAL_STABILITY_PLAN_5LEVEL.md` |
| CLAUDE.md | Root directory |
| Holon Architecture | `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` |
| Founder's Directive | `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` |
| GA Release Checklist | Section 95-96 of CLAUDE.md |

## 10. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-05 | Claude Opus 4.5 | Initial creation |

---

## Appendix A: Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPERATIONAL QUICK REFERENCE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STARTUP:     devenv shell → sa-up → db-setup → compile → app  │
│  SHUTDOWN:    sa-down                                          │
│  CLEAN:       sa-clean → rm -rf _build deps                    │
│                                                                 │
│  COMPILE:     compile         (Patient Mode)                   │
│  TEST:        test            (NIF active)                     │
│  QUALITY:     quality-full    (format+credo+dialyzer+sobelow)  │
│                                                                 │
│  HEALTH:      curl localhost:4000/health                       │
│  METRICS:     curl localhost:4000/api/prajna/metrics           │
│  LOGS:        sa-logs [service]                                │
│                                                                 │
│  ENV VARS:    SKIP_ZENOH_NIF=0 PATIENT_MODE=enabled            │
│              DATABASE_URL=ecto://postgres:postgres@localhost:5433│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*KMS Entry maintained by Claude Opus 4.5 in compliance with Biomorphic Fractal Holon Architecture v21.3.0 and Founder's Covenant $\Omega_0$*
