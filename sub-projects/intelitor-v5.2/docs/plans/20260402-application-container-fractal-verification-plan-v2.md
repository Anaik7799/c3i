# Application Container Build & Full Fractal Verification Plan
**Created**: 2026-04-02 12:45 CEST  
**Version**: v21.3.2-SIL6  
**Framework**: SOPv5.11 + STAMP + TDG + Patient Mode + Fractal Verification

---

## 1. Scope & Trigger

Build and fully verify application containers for complete Indrajaal functionality testing. Focus on ALL fractal artifacts across 8 fractal layers with exact code paths specified.

---

## 2. Existing Codebase Artifacts (READ-ONLY Reference)

### 2.1 Dockerfiles (EXISTING - No Modification Required)

| Dockerfile | Location | Purpose | Status |
|-----------|----------|---------|--------|
| `Dockerfile.sopv51-app` | `./Dockerfile.sopv51-app` | Phoenix App + NixOS base | ✅ EXISTS |
| `Dockerfile.db` | `./Dockerfile.db` | TimescaleDB PostgreSQL | ✅ EXISTS |
| `Dockerfile.observability` | `./Dockerfile.observability` | OTEL/Prometheus/Grafana | ✅ EXISTS |
| `Dockerfile.cepaf-bridge` | `./Dockerfile.cepaf-bridge` | F#-Elixir Bridge | ✅ EXISTS |
| `Dockerfile.cortex` | `./Dockerfile.cortex` | F# Cortex | ✅ EXISTS |
| `Dockerfile.sopv51-base` | `./Dockerfile.sopv51-base` | NixOS Base Image | ✅ EXISTS |

### 2.2 Nix Container Definitions (EXISTING - No Modification Required)

| Nix File | Location | Purpose | Status |
|----------|----------|---------|--------|
| `containers/sopv51-elixir-app.nix` | `./containers/sopv51-elixir-app.nix` | Elixir App Container | ✅ EXISTS |
| `containers/indrajaal-timescaledb-demo.nix` | `./containers/indrajaal-timescaledb-demo.nix` | PostgreSQL Container | ✅ EXISTS |
| `containers/obs/flake.nix` | `./containers/obs/flake.nix` | Observability Stack | ✅ EXISTS |
| `containers/default.nix` | `./containers/default.nix` | Dev Containers | ✅ EXISTS |

### 2.3 Compose Files (EXISTING - Reference Only)

| Compose File | Location | Purpose | Status |
|-------------|----------|---------|--------|
| `podman-compose-sil6-full-mesh.yml` | `./lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml` | 16-Container Mesh | ✅ EXISTS |
| `podman-compose-testing.yml` | `./podman-compose-testing.yml` | Test Stack | ✅ EXISTS |

### 2.4 Elixir Application Code (EXISTING - Reference Only)

| Module | Location | Purpose | Status |
|--------|----------|---------|--------|
| `Indrajaal.Application` | `./lib/indrajaal/application.ex` | Application Supervisor | ✅ EXISTS |
| `Indrajaal.Telemetry` | `./lib/indrajaal/telemetry.ex` | Telemetry Handlers | ✅ EXISTS |
| `Indrajaal.Observability.*` | `./lib/indrajaal/observability/*.ex` | Observability Domain | ✅ EXISTS (50+ files) |
| `Indrajaal.Prajna.*` | `./lib/indrajaal/prajna/*.ex` | Prajna Cockpit | ✅ EXISTS |
| `Indrajaal.Sentinel.*` | `./lib/indrajaal/sentinel/*.ex` | Sentinel Health | ✅ EXISTS |
| `Indrajaal.Guardian.*` | `./lib/indrajaal/guardian/*.ex` | Guardian Approval | ✅ EXISTS |

### 2.5 F# CEPAF Code (EXISTING - Reference Only)

| Module | Location | Purpose | Status |
|--------|----------|---------|--------|
| `Cepaf.Bridge` | `./lib/cepaf/src/Cepaf.Bridge/` | F#-Elixir Bridge | ✅ EXISTS |
| `Cepaf.Cockpit` | `./lib/cepaf/src/Cepaf.Cockpit/` | Cockpit UI | ✅ EXISTS |
| `Cepaf.Podman` | `./lib/cepaf/src/Cepaf.Podman/` | Podman API Client | ✅ EXISTS |
| `Cepaf.Database` | `./lib/cepaf/src/Cepaf.Database/` | SQLite/DuckDB | ✅ EXISTS |
| `Cepaf.GitIntelligence` | `./lib/cepaf/src/Cepaf.GitIntelligence/` | Git Integration | ✅ EXISTS |
| `Cepaf.Sentinel.MCP` | `./lib/cepaf/src/Cepaf.Sentinel.MCP/` | Sentinel MCP Server | ✅ EXISTS |

### 2.6 F# Scripts (EXISTING - Reference Only)

| Script | Location | Purpose | Status |
|--------|----------|---------|--------|
| `sa-up.fsx` | `./sa-up.fsx` | Mesh Boot | ✅ EXISTS |
| `sa-down.fsx` | `./sa-down.fsx` | Mesh Shutdown | ✅ EXISTS |
| `sa-status.fsx` | `./sa-status.fsx` | Mesh Status | ✅ EXISTS |
| `sa-verify.fsx` | `./sa-verify.fsx` | 2oo3 Verification | ✅ EXISTS |
| `sa-fractal-verify.fsx` | `./sa-fractal-verify.fsx` | Fractal Verification | ✅ EXISTS |

---

## 3. Container Architecture (12 Containers)

### 3.1 BuiltFromDockerfile (5 containers)

| # | Container | Dockerfile | Image Tag | Ports |
|---|----------|-----------|----------|-------|
| 1 | `indrajaal-db-prod` | `Dockerfile.db` | `localhost/indrajaal-db-prod:latest` | 5433 |
| 2 | `indrajaal-obs-prod` | `Dockerfile.observability` | `localhost/indrajaal-obs-prod:latest` | 4317,9090,3000,3100 |
| 3 | `indrajaal-ex-app-1` | `Dockerfile.sopv51-app` | `localhost/indrajaal-ex-app-1:latest` | 4000,4001,6379 |
| 4 | `cepaf-bridge` | `Dockerfile.cepaf-bridge` | `localhost/cepaf-bridge:latest` | 9876 |
| 5 | `indrajaal-cortex` | `Dockerfile.cortex` | `localhost/indrajaal-cortex:latest` | 9877 |

### 3.2 PulledFromRegistry (2 containers)

| # | Container | Registry Image | Ports |
|---|----------|----------------|-------|
| 6 | `zenoh-router` | `eclipse/zenoh:latest` | 7447,8448,8000 |
| 7 | `indrajaal-ollama` | `ollama/ollama:latest` | 11435 |

### 3.3 SharedImage (5 containers)

| # | Container | Shared From | Ports |
|---|----------|------------|-------|
| 8 | `indrajaal-ex-app-2` | `indrajaal-ex-app-1` | 4003,4004 |
| 9 | `indrajaal-ex-app-3` | `indrajaal-ex-app-1` | 4005,4006 |
| 10 | `indrajaal-chaya` | `indrajaal-ex-app-1` | 4002 |
| 11 | `indrajaal-ml-runner-1` | `indrajaal-ex-app-1` | - |
| 12 | `indrajaal-ml-runner-2` | `indrajaal-ex-app-1` | - |

---

## 4. Fractal Layer Verification Matrix

### 4.1 L0: Runtime Layer (Host/Compilation)

**Code Path**: `./lib/indrajaal/application.ex:33-180`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Compilation | `mix compile` | `NO_TIMEOUT=true mix compile --jobs 16` | 0 errors |
| Format | `mix format --check` | `mix format --check-formatted` | pass |
| Credo | `mix credo --strict` | `mix credo --strict` | 0 issues |
| Dependencies | `mix deps.get` | `mix deps.get` | success |

### 4.2 L1: Function Layer (I/O Contracts)

**Code Path**: `./lib/indrajaal/application.ex:180-300`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Phoenix HTTP | `http://localhost:4000/` | `curl -sf http://localhost:4000/` | 200 OK |
| Health Endpoint | `http://localhost:4001/health` | `curl -sf http://localhost:4001/health` | JSON health |
| Database Query | Ecto.Adapters.SQL | `mix run -e "..."` | rows returned |
| Redis Cache | `redis-cli ping` | `redis-cli -h localhost ping` | PONG |

### 4.3 L2: Component Layer (Module Cohesion)

**Code Path**: `./lib/indrajaal/observability/*.ex`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Telemetry | `Indrajaal.Telemetry` | `mix run -e "Indrajaal.Telemetry.list_handlers()"` | handlers |
| OTEL | OpenTelemetry | `curl localhost:4317/health` | 200 OK |
| Prometheus | Prometheus metrics | `curl localhost:9090/-/healthy` | healthy |
| Grafana | Grafana API | `curl localhost:3000/api/health` | healthy |
| Zenoh Session | `Indrajaal.Observability.ZenohSession` | `mix run -e "..."` | session started |

### 4.4 L3: Holon Layer (Agent Logic)

**Code Path**: `./lib/indrajaal/prajna/*.ex`, `./lib/indrajaal/sentinel/*.ex`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Guardian | `http://localhost:4000/api/prajna/guardian/health` | `curl -sf ...` | healthy |
| Sentinel | `http://localhost:4000/api/prajna/sentinel/health` | `curl -sf ...` | healthy |
| Prajna Cockpit | `http://localhost:4000/prajna` | `curl -sf ...` | HTML |
| AI Copilot | `http://localhost:4000/prajna/copilot` | `curl -sf ...` | HTML |

### 4.5 L4: Container Layer (Isolation)

**Code Path**: `./Dockerfile.*`, `./containers/*.nix`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Container Build | `podman build` | `podman build -t localhost/indrajaal-ex-app-1:latest -f Dockerfile.sopv51-app .` | image ID |
| Non-Root User | `User` label | `podman inspect --format='{{.Config.User}}'` | `1000` |
| Resource Limits | `deploy.resources` | `podman inspect --format='{{.HostConfig.Memory}}'` | 2G |
| NixOS Base | `/etc/os-release` | `podman run --rm cat /etc/os-release` | NixOS |

### 4.6 L5: Node Layer (Runtime Stable)

**Code Path**: `./lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Network | `indrajaal-sil6-mesh` | `podman network ls` | exists |
| Internal Network | `indrajaal-internal` | `podman network ls` | exists |
| Volumes | `db_prod_data` | `podman volume ls` | exists |
| Ports | 4000, 5433, 9090 | `podman port ls` | bound |

### 4.7 L6: Cluster Layer (Consensus)

**Code Path**: `./lib/indrajaal/application.ex:130-180`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| BEAM Clustering | `Node.list()` | `mix run -e "IO.inspect(Node.list())"` | 3+ nodes |
| Zenoh Routers | 3 routers healthy | `nc -z localhost 7447 && nc -z localhost 7448 && nc -z localhost 7449` | all OK |
| 2oo3 Quorum | `sa-verify` | `./sa-verify` | consensus |
| F# Bridge | `http://localhost:9876/health` | `curl -sf ...` | healthy |

### 4.8 L7: Federation Layer (Global Invariants)

**Code Path**: `./lib/indrajaal/observability/quadruplex_logger.ex`

| Artifact | Verification | Command | Expected |
|----------|-------------|---------|---------|
| Console Log | STDOUT | `podman logs indrajaal-ex-app-1` | structured JSON |
| JSON Log | JSON file | `cat ./data/logs/*.json` | JSON lines |
| Zenoh Pub | `indrajaal/*` topics | `zenoh_query(action: "metrics")` | metrics |
| OTEL Trace | `localhost:4317` | `curl localhost:4318/v1/traces` | 200 OK |

---

## 5. Execution Plan

> **⚠️ CRITICAL COLD START FIXES (SC-COLDSTART-001)**
> 
> The following fixes were discovered during cold start testing and are REQUIRED for replication:
> 
> 1. **Use `nixos-devenv` image**: `localhost/indrajaal-sopv51-elixir-app:nixos-devenv` (NOT `localhost/indrajaal-ex-app-1:latest`)
> 2. **Correct command**: `/root/.nix-profile/bin/mix phx.server` (NOT `phx.server` directly)
> 3. **Mandatory env vars**: `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`
> 4. **Resource limits**: `--memory=4g --cpus=2` (prevents CPU governor SC-CPU-GOV-001 crashes)
> 5. **Locale fix**: `ELIXIR_ERL_OPTIONS="+fnu"`
> 
> See **v3-COLDSTART.md** for full cold start script.

### Phase 1: Build Container Images (L4)

```bash
# Patient Mode Environment
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"

# Build Base Image (if needed)
podman build -t localhost/sopv51-base:latest -f Dockerfile.sopv51-base .

# Build 5 BuiltFromDockerfile images
podman build -t localhost/indrajaal-db-prod:latest -f Dockerfile.db .
podman build -t localhost/indrajaal-obs-prod:latest -f Dockerfile.observability .
podman build -t localhost/indrajaal-ex-app-1:latest -f Dockerfile.sopv51-app .
podman build -t localhost/cepaf-bridge:latest -f Dockerfile.cepaf-bridge .
podman build -t localhost/indrajaal-cortex:latest -f Dockerfile.cortex .

# Pull 2 Registry images
podman pull eclipse/zenoh:latest && podman tag eclipse/zenoh:latest localhost/zenoh-router:latest
podman pull ollama/ollama:latest && podman tag ollama/ollama:latest localhost/indrajaal-ollama:latest

# Tag shared images
podman tag localhost/indrajaal-ex-app-1:latest localhost/indrajaal-ex-app-2:latest
podman tag localhost/indrajaal-ex-app-1:latest localhost/indrajaal-ex-app-3:latest
podman tag localhost/indrajaal-ex-app-1:latest localhost/indrajaal-chaya:latest
podman tag localhost/indrajaal-ex-app-1:latest localhost/indrajaal-ml-runner-1:latest
podman tag localhost/indrajaal-ex-app-1:latest localhost/indrajaal-ml-runner-2:latest

# Verify all images
podman images | grep -E "indrajaal|zenoh|ollama|cepaf"
```

### Phase 2: Start Infrastructure (L4-L5)

```bash
# Create networks
podman network create indrajaal-sil6-mesh --subnet 172.28.0.0/16
podman network create indrajaal-internal --internal

# Start Zenoh routers (Tier 1)
podman run -d --name zenoh-router-1 --network indrajaal-sil6-mesh -p 7447:7447 localhost/zenoh-router:latest
podman run -d --name zenoh-router-2 --network indrajaal-sil6-mesh -p 7448:7447 localhost/zenoh-router:latest
podman run -d --name zenoh-router-3 --network indrajaal-sil6-mesh -p 7449:7447 localhost/zenoh-router:latest

# Start Database (Tier 2)
podman run -d --name indrajaal-db-prod --network indrajaal-sil6-mesh -p 5433:5433 \
  -e POSTGRES_DB=indrajaal_prod -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  localhost/indrajaal-db-prod:latest

# Wait for DB
for i in {1..60}; do podman exec indrajaal-db-prod pg_isready -U postgres && break; sleep 2; done

# Start Observability (Tier 3)
podman run -d --name indrajaal-obs-prod --network indrajaal-sil6-mesh \
  -p 4317:4317 -p 4318:4318 -p 8888:8888 -p 9090:9090 -p 3000:3000 -p 3100:3100 \
  localhost/indrajaal-obs-prod:latest

# Wait for Prometheus
for i in {1..90}; do curl -sf http://localhost:9090/-/healthy && break; sleep 2; done

# Start Cognitive (Tier 4)
podman run -d --name cepaf-bridge --network indrajaal-sil6-mesh -p 9876:9876 \
  -e ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router-1:7447 localhost/cepaf-bridge:latest || echo "cepaf-bridge may need build"

# Start Application (Tier 5)
podman run -d --name indrajaal-ex-app-1 --network indrajaal-sil6-mesh \
  -p 4000:4000 -p 4001:4001 -p 6379:6379 \
  -e DATABASE_URL=ecto://postgres:postgres@indrajaal-db-prod:5433/indrajaal_prod \
  -e MIX_ENV=prod -e PHX_HOST=localhost -e PHX_PORT=4000 \
  localhost/indrajaal-ex-app-1:latest

# Wait for Phoenix
for i in {1..180}; do curl -sf http://localhost:4000/ && break; sleep 5; done
```

### Phase 3: Fractal Verification (L0-L7)

```bash
# === L0: Runtime Verification ===
mix compile --jobs 16
mix format --check-formatted
mix credo --strict

# === L1: Function Verification ===
curl -sf http://localhost:4000/api/health | jq .
curl -sf http://localhost:4001/health | jq .
podman exec indrajaal-ex-app-1 redis-cli ping

# === L2: Component Verification ===
curl -sf http://localhost:9090/-/healthy
curl -sf http://localhost:3000/api/health
curl -sf http://localhost:4317/health || echo "OTEL check"

# === L3: Holon Verification ===
curl -sf http://localhost:4000/api/prajna/guardian/health | jq .
curl -sf http://localhost:4000/api/prajna/sentinel/health | jq .
curl -sf http://localhost:4000/prajna | head -5

# === L4: Container Verification ===
podman images | grep localhost/indrajaal
podman ps --format "{{.Names}} {{.Status}}"

# === L5: Node Verification ===
podman network ls
podman volume ls
podman port indrajaal-ex-app-1

# === L6: Cluster Verification ===
podman exec indrajaal-ex-app-1 mix run -e "IO.inspect(Node.list())"
./sa-verify

# === L7: Federation Verification ===
curl -sf http://localhost:9090/api/v1/query?query=up | jq .
curl -sf http://localhost:3000/api/health | jq .
```

---

## 6. Code Modification Tracking

### NO MODIFICATIONS REQUIRED - READ-ONLY EXECUTION

All code is EXISTING and will be used as-is:

| Category | Files | Action |
|----------|-------|--------|
| Dockerfiles | 6 | READ-ONLY |
| Nix Files | 4 | READ-ONLY |
| Compose Files | 2 | READ-ONLY |
| Elixir Code | 50+ | READ-ONLY |
| F# Code | 40+ | READ-ONLY |
| Scripts | 10+ | READ-ONLY |

---

## 7. Verification Checklist

| Layer | Check | Status |
|-------|-------|--------|
| L0 | `mix compile` | ⬜ |
| L0 | `mix format --check` | ⬜ |
| L0 | `mix credo` | ⬜ |
| L1 | HTTP /health | ⬜ |
| L1 | DB query | ⬜ |
| L1 | Redis ping | ⬜ |
| L2 | Prometheus | ⬜ |
| L2 | Grafana | ⬜ |
| L2 | OTEL | ⬜ |
| L3 | Guardian | ⬜ |
| L3 | Sentinel | ⬜ |
| L3 | Prajna | ⬜ |
| L4 | Images built | ⬜ |
| L4 | Non-root user | ⬜ |
| L5 | Networks | ⬜ |
| L5 | Volumes | ⬜ |
| L6 | Cluster nodes | ⬜ |
| L6 | 2oo3 quorum | ⬜ |
| L7 | Telemetry pipeline | ⬜ |

---

## 8. Summary

| Metric | Value |
|--------|-------|
| Dockerfiles to build | 5 |
| Registry images to pull | 2 |
| Shared images to tag | 5 |
| Fractal layers | 8 |
| Verification checks | 19 |
| Estimated time | 60-90 minutes |

**No code modifications required.** All artifacts are existing and will be used in READ-ONLY mode for verification.
