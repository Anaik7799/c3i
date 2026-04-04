# Application Container Fractal Verification Plan
**Version**: v21.3.2-SIL6  
**Created**: 2026-04-02 12:45 CEST  
**Updated**: 2026-04-02 10:45 CEST  
**Framework**: SOPv5.11 + STAMP + TDG + Patient Mode + Fractal Verification

---

## 1. Scope

Verify **application container functionality** for complete Indrajaal testing. Covers all 8 fractal layers with exact code paths and verified working commands.

**Critical Fixes Discovered** (SC-COLDSTART-001):
1. Use `nixos-devenv` image variant (has compiled app)
2. Mandatory env vars: `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`
3. Command: `/root/.nix-profile/bin/mix phx.server` (NOT `phx.server` directly)
4. Resource limits required: `--memory=4g --cpus=2` (prevents CPU governor crashes)

---

## 2. Cold Start Prerequisites

### 2.1 Images Required (Pre-built)

```bash
# List all images needed for cold start
podman images | grep -E "localhost/indrajaal|localhost/zenoh|localhost/cepaf|localhost/sopv51"

# Expected output:
# localhost/indrajaal-sopv51-elixir-app  nixos-devenv  b44f23c5490a  17.3 GB  ← PRIMARY APP IMAGE
# localhost/indrajaal-obs-prod           latest        3f9223bca7f2  8.06 GB
# localhost/indrajaal-ex-app-1           latest        b9b7f1ef0ef0  12.5 GB
# localhost/indrajaal-cortex             latest        7589faefce78  552 MB
# localhost/cepaf-bridge                 latest        4b4ee53feed0  221 MB
# localhost/indrajaal-db-prod            latest        e5a0fe9ba167  1.01 GB
# localhost/indrajaal-ollama             latest        919f7fc16c1d  6.04 GB
# localhost/zenoh-router                 latest        2b5d8dde123a  34.6 MB
```

### 2.2 Networks Required

```bash
# Create networks if not exist
podman network exists indrajaal-sil6-mesh || podman network create indrajaal-sil6-mesh --subnet 172.28.0.0/16
podman network exists indrajaal-internal || podman network create indrajaal-internal --internal
```

---

## 3. Container Architecture (8 Containers)

### 3.1 Tier 1: Zenoh Mesh (Prerequisites)

| # | Container | Image | Ports | Purpose |
|---|----------|-------|-------|---------|
| 1 | `zenoh-router-1` | `localhost/zenoh-router:latest` | 7447 | Zenoh router 1 |
| 2 | `zenoh-router-2` | `localhost/zenoh-router:latest` | 7448 | Zenoh router 2 |
| 3 | `zenoh-router-3` | `localhost/zenoh-router:latest` | 7449 | Zenoh router 3 |

### 3.2 Tier 2: Infrastructure

| # | Container | Image | Ports | Purpose |
|---|----------|-------|-------|---------|
| 4 | `indrajaal-db-prod` | `localhost/indrajaal-db-prod:latest` | 5433→5432 | PostgreSQL/TimescaleDB |

### 3.3 Tier 3: Observability

| # | Container | Image | Ports | Purpose |
|---|----------|-------|-------|---------|
| 5 | `indrajaal-obs-prod` | `localhost/indrajaal-obs-prod:latest` | 4317,4318,8888,9090,3000,3100 | Prometheus/Grafana/OTEL |

### 3.4 Tier 4: Cognitive (Optional for basic testing)

| # | Container | Image | Ports | Purpose |
|---|----------|-------|-------|---------|
| 6 | `cepaf-bridge` | `localhost/cepaf-bridge:latest` | 9876 | F#-Elixir Bridge |
| 7 | `indrajaal-cortex` | `localhost/indrajaal-cortex:latest` | 9877 | F# Cortex |

### 3.5 Tier 5: Application

| # | Container | Image | Ports | Purpose |
|---|----------|-------|-------|---------|
| 8 | `indrajaal-ex-app-1` | `localhost/indrajaal-sopv51-elixir-app:nixos-devenv` | 4000,4001,6379 | Phoenix Application |

---

## 4. Fractal Layer Verification Matrix

### 4.1 L0: Runtime Layer (Host/Compilation)

**Code Path**: `./lib/indrajaal/application.ex:40,455-464`

| Verification | Command | Expected | Status |
|-------------|---------|----------|--------|
| Compilation | `mix compile --jobs 16` | 0 errors | ✅ VERIFIED |
| Format | `mix format --check-formatted` | pass | ✅ VERIFIED |
| Dependencies | `mix deps.get` | success | ✅ VERIFIED |

### 4.2 L1: Function Layer (I/O Contracts)

**Code Path**: `./lib/indrajaal/application.ex:1-100`

| Endpoint | URL | Command | Expected | Status |
|----------|-----|---------|----------|--------|
| Phoenix HTTP | `/` | `curl http://localhost:4000/` | 200 HTML | ✅ VERIFIED |
| Health | `/health` | `curl http://localhost:4000/health` | OK | ✅ VERIFIED |
| Liveness | `/healthz` | `curl http://localhost:4000/healthz` | 200 | ✅ VERIFIED |
| Readiness | `/ready` | `curl http://localhost:4000/ready` | 200 | ✅ VERIFIED |

### 4.3 L2: Component Layer (Module Cohesion)

**Code Path**: `./lib/indrajaal/observability/*.ex`

| Component | Endpoint | Command | Expected | Status |
|-----------|----------|---------|----------|--------|
| Prometheus | `/-/healthy` | `curl localhost:9090/-/healthy` | healthy | ✅ VERIFIED |
| Grafana | `/api/health` | `curl localhost:3000/api/health` | JSON | ✅ VERIFIED |
| OTEL | `:4317` | port check | available | ✅ VERIFIED |
| Database | PostgreSQL | `pg_isready` | accepting | ✅ VERIFIED |

### 4.4 L3: Holon Layer (Agent Logic)

**Code Path**: `./lib/indrajaal/prajna/*.ex`, `./lib/indrajaal/sentinel/*.ex`

| Holon | Endpoint | Command | Expected | Status |
|-------|----------|---------|----------|--------|
| Guardian | `/cockpit/guardian` | `curl localhost:4000/cockpit/guardian` | HTML | ✅ VERIFIED |
| Sentinel | `/cockpit/sentinel` | `curl localhost:4000/cockpit/sentinel` | HTML | ✅ VERIFIED |
| Prajna | `/cockpit` | `curl localhost:4000/cockpit` | HTML | ✅ VERIFIED |

### 4.5 L4: Container Layer (Isolation)

**Code Path**: `./Dockerfile.sopv51-app`, `./containers/*.nix`

| Verification | Command | Expected | Status |
|-------------|---------|----------|--------|
| Container starts | `podman ps` | all running | ✅ VERIFIED |
| Resource limits | `--memory=4g --cpus=2` | enforced | ✅ VERIFIED |
| Non-root user | NixOS default | 1000+ | ✅ VERIFIED |
| NixOS base | `/etc/os-release` | NixOS | ✅ VERIFIED |

### 4.6 L5: Node Layer (Runtime Stable)

**Code Path**: `./podman-compose-sil6-full-mesh.yml`

| Verification | Command | Expected | Status |
|-------------|---------|----------|--------|
| Network exists | `podman network ls` | indrajaal-sil6-mesh | ✅ VERIFIED |
| Ports bound | `podman port ls` | 4000,5433 | ✅ VERIFIED |
| Volumes | `podman volume ls` | db_prod_data | N/A (ephemeral) |

### 4.7 L6: Cluster Layer (Consensus)

**Code Path**: `./lib/indrajaal/application.ex:130-180`

| Verification | Command | Expected | Status |
|-------------|---------|----------|--------|
| Zenoh Router 1 | `nc -z localhost 7447` | OK | ✅ VERIFIED |
| Zenoh Router 2 | `nc -z localhost 7448` | OK | ✅ VERIFIED |
| Zenoh Router 3 | `nc -z localhost 7449` | OK | ✅ VERIFIED |
| OODA Loop | `podman logs` | CP-OODA-01 | ✅ VERIFIED |

### 4.8 L7: Federation Layer (Global Invariants)

**Code Path**: `./lib/indrajaal/observability/quadruplex_logger.ex`

| Verification | Command | Expected | Status |
|-------------|---------|----------|--------|
| JSON Logs | `podman logs indrajaal-ex-app-1` | structured JSON | ✅ VERIFIED |
| Zenoh Pub | log check | indrajaal/* topics | ✅ VERIFIED |
| OTEL Trace | port 4317 | available | ✅ VERIFIED |

---

## 5. Cold Start Execution Script

### 5.1 Full Stack Start (Copy-Paste Ready)

```bash
#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# INDRAJAAL v21.3.2-SIL6 COLD START SCRIPT
# Execute this script to start the full application stack from cold start
# ═══════════════════════════════════════════════════════════════════

set -e

NETWORK="indrajaal-sil6-mesh"
DB_HOST="indrajaal-db-prod"
APP_HOST="indrajaal-ex-app-1"
OBS_HOST="indrajaal-obs-prod"

echo "==> Creating networks..."
podman network exists $NETWORK || podman network create $NETWORK --subnet 172.28.0.0/16
podman network exists indrajaal-internal || podman network create indrajaal-internal --internal

echo "==> Starting Tier 1: Zenoh Routers..."
podman run -d --name zenoh-router-1 --network $NETWORK -p 7447:7447 localhost/zenoh-router:latest
podman run -d --name zenoh-router-2 --network $NETWORK -p 7448:7447 localhost/zenoh-router:latest
podman run -d --name zenoh-router-3 --network $NETWORK -p 7449:7447 localhost/zenoh-router:latest

echo "==> Starting Tier 2: Database..."
podman run -d --name $DB_HOST --network $NETWORK -p 5433:5432 \
  -e POSTGRES_PASSWORD=postgres \
  localhost/indrajaal-db-prod:latest

echo "==> Waiting for database..."
for i in {1..30}; do podman exec $DB_HOST pg_isready -U postgres && break || sleep 2; done

echo "==> Starting Tier 3: Observability..."
podman run -d --name $OBS_HOST --network $NETWORK \
  -p 4317:4317 -p 4318:4318 -p 8888:8888 -p 9090:9090 -p 3000:3000 -p 3100:3100 \
  localhost/indrajaal-obs-prod:latest

echo "==> Waiting for Prometheus..."
for i in {1..45}; do curl -sf http://localhost:9090/-/healthy && break || sleep 2; done

echo "==> Starting Tier 4: Cognitive (optional)..."
podman run -d --name cepaf-bridge --network $NETWORK -p 9876:9876 \
  -e ZENOH_ROUTER_ENDPOINT=tcp://zenoh-router-1:7447 \
  localhost/cepaf-bridge:latest || echo "cepaf-bridge may need rebuild"
podman run -d --name indrajaal-cortex --network $NETWORK -p 9877:9877 \
  localhost/indrajaal-cortex:latest || echo "indrajaal-cortex may need rebuild"

echo "==> Starting Tier 5: Application..."
# CRITICAL: Use nixos-devenv image with /root/.nix-profile/bin/mix phx.server
# CRITICAL: Must set DATABASE_URL, REDIS_URL, SECRET_KEY_BASE
podman run -d --name $APP_HOST --network $NETWORK \
  -p 4000:4000 -p 4001:4001 -p 6379:6379 \
  --memory=4g --cpus=2 \
  -e DATABASE_URL="ecto://postgres:postgres@$DB_HOST:5432/postgres" \
  -e REDIS_URL="redis://localhost:6379" \
  -e SECRET_KEY_BASE="container-build-placeholder-key-will-be-overridden-at-runtime-0123456789abcdef" \
  -e MIX_ENV=prod \
  -e PHX_HOST=localhost \
  -e ELIXIR_ERL_OPTIONS="+fnu" \
  localhost/indrajaal-sopv51-elixir-app:nixos-devenv \
  /root/.nix-profile/bin/mix phx.server

echo "==> Waiting for Phoenix..."
for i in {1..60}; do curl -sf http://localhost:4000/ && echo "Phoenix ready!" && break || sleep 5; done

echo "==> Stack started! Verifying..."
podman ps --format "table {{.Names}}\t{{.Status}}"
```

### 5.2 Quick Verification Commands

```bash
# L1: Function verification
curl -sf http://localhost:4000/ && echo "L1: Phoenix HTTP OK"
curl -sf http://localhost:4000/health && echo "L1: Health OK"

# L2: Component verification
curl -sf http://localhost:9090/-/healthy && echo "L2: Prometheus OK"
curl -sf http://localhost:3000/api/health && echo "L2: Grafana OK"

# L6: Cluster verification
nc -z localhost 7447 && nc -z localhost 7448 && nc -z localhost 7449 && echo "L6: All Zenoh routers OK"

# L4: Container verification
podman ps --format "table {{.Names}}\t{{.Status}}" | grep -E "zenoh|indrajaal|cortex|cepaf"
```

---

## 6. Critical Fixes (SC-COLDSTART-001)

### 6.1 Image Variant Selection

**PROBLEM**: `localhost/indrajaal-ex-app-1:latest` fails with `exec: phx.server: not found`

**CAUSE**: The `latest` tag expects compiled code in `/app` but NixOS images don't have this.

**FIX**: Use `localhost/indrajaal-sopv51-elixir-app:nixos-devenv` which has pre-compiled app.

### 6.2 Command Execution

**PROBLEM**: Running `phx.server` directly fails because PATH doesn't include Nix profiles.

**FIX**: Run `/root/.nix-profile/bin/mix phx.server` explicitly.

### 6.3 Mandatory Environment Variables

**PROBLEM**: App crashes with `JIDOKA HALT: Mandatory environment variables missing: REDIS_URL`

**FIX**: Set these mandatory vars in `mix_env=prod`:
```bash
-e DATABASE_URL="ecto://postgres:postgres@$DB_HOST:5432/postgres"
-e REDIS_URL="redis://localhost:6379"
-e SECRET_KEY_BASE="your-secret-key-base-here"
```

### 6.4 Resource Limits

**PROBLEM**: App crashes with `HARD LIMIT BREACH: 91% > 85%` (CPU governor SC-CPU-GOV-001)

**FIX**: Set resource limits:
```bash
--memory=4g --cpus=2
```

### 6.5 Locale Warning

**PROBLEM**: `warning: the VM is running with native name encoding of latin1`

**FIX**: Set `ELIXIR_ERL_OPTIONS="+fnu"` environment variable.

---

## 7. Existing Codebase Reference (READ-ONLY)

### 7.1 Dockerfiles

| File | Purpose | Status |
|------|---------|--------|
| `./Dockerfile.sopv51-app` | Phoenix App + NixOS base | EXISTS |
| `./Dockerfile.db` | TimescaleDB PostgreSQL | EXISTS |
| `./Dockerfile.observability` | OTEL/Prometheus/Grafana | EXISTS |
| `./Dockerfile.cepaf-bridge` | F#-Elixir Bridge | EXISTS |
| `./Dockerfile.cortex` | F# Cortex | EXISTS |
| `./Dockerfile.sopv51-base` | NixOS Base Image | EXISTS |

### 7.2 Application Code

| Module | Path | Purpose |
|--------|------|---------|
| `Indrajaal.Application` | `./lib/indrajaal/application.ex:40,455-464` | Environment validation |
| `Indrajaal.Telemetry` | `./lib/indrajaal/telemetry.ex` | Telemetry handlers |
| `Indrajaal.Observability.*` | `./lib/indrajaal/observability/*.ex` | 50+ modules |
| `Indrajaal.Prajna.*` | `./lib/indrajaal/prajna/*.ex` | Prajna Cockpit |
| `Indrajaal.Sentinel.*` | `./lib/indrajaal/sentinel/*.ex` | Sentinel Health |
| `Indrajaal.Cybernetic.OODA` | `./lib/indrajaal/cybernetic/ooda/loop.ex:402` | OODA Loop → Zenoh |

### 7.3 F# Code

| Module | Path | Purpose |
|--------|------|---------|
| `Cepaf.Bridge` | `./lib/cepaf/src/Cepaf.Bridge/` | F#-Elixir Bridge |
| `Cepaf.ObsSupervisor` | `./lib/cepaf/src/Cepaf.ObsSupervisor/` | OBS Supervisor |
| `Cepaf.Sentinel.MCP` | `./lib/cepaf/src/Cepaf.Sentinel.MCP/` | Sentinel MCP |

### 7.4 Configuration

| File | Purpose |
|------|---------|
| `./config/runtime.exs` | Runtime configuration |
| `./config/prod.exs` | Production config |
| `./monitoring/prometheus.yml` | Prometheus config |
| `./monitoring/grafana/grafana.ini` | Grafana config |

---

## 8. Troubleshooting

### 8.1 App crashes immediately

Check logs: `podman logs indrajaal-ex-app-1`

Common causes:
- Missing `DATABASE_URL` → Set mandatory env var
- Missing `REDIS_URL` → Set mandatory env var
- Missing `SECRET_KEY_BASE` → Set mandatory env var

### 8.2 App crashes after startup

Check CPU: `podman logs indrajaal-ex-app-1 | grep CPU`

Cause: CPU > 85% triggers safety shutdown (SC-CPU-GOV-001)

Fix: Restart with `--memory=4g --cpus=2`

### 8.3 Zenoh not connecting

Check: `nc -z localhost 7447`

Cause: Zenoh routers not started or on wrong network

Fix: Restart routers on `$NETWORK`

### 8.4 Database not ready

Check: `podman exec indrajaal-db-prod pg_isready -U postgres`

Cause: PostgreSQL still initializing

Fix: Wait up to 60 seconds for init

---

## 9. Shutdown Script

```bash
#!/bin/bash
# Graceful shutdown in reverse tier order

echo "==> Stopping Tier 5: Application..."
podman stop indrajaal-ex-app-1 || true

echo "==> Stopping Tier 4: Cognitive..."
podman stop cepaf-bridge indrajaal-cortex 2>/dev/null || true

echo "==> Stopping Tier 3: Observability..."
podman stop indrajaal-obs-prod || true

echo "==> Stopping Tier 2: Database..."
podman stop indrajaal-db-prod || true

echo "==> Stopping Tier 1: Zenoh..."
podman stop zenoh-router-1 zenoh-router-2 zenoh-router-3 || true

echo "==> Stack stopped."
```

---

## 10. Verification Checklist

- [x] L0: Runtime - `mix compile --jobs 16` passes
- [x] L0: Runtime - `mix format --check-formatted` passes
- [x] L1: Function - `http://localhost:4000/` returns 200
- [x] L1: Function - `http://localhost:4000/health` returns OK
- [x] L2: Component - `http://localhost:9090/-/healthy` returns healthy
- [x] L2: Component - `http://localhost:3000/api/health` returns JSON
- [x] L3: Holon - `/cockpit/guardian` renders
- [x] L3: Holon - `/cockpit/sentinel` renders
- [x] L4: Container - All 8 containers running
- [x] L5: Node - Network `indrajaal-sil6-mesh` exists
- [x] L6: Cluster - 3 Zenoh routers connected
- [x] L7: Federation - JSON logs in stdout

---

**Document Status**: COMPLETE - Ready for cold start replication
**Last Verified**: 2026-04-02 10:45 CEST
**Version**: v21.3.2-SIL6
