# Application Container Build & Full Fractal Verification Plan
**Created**: 2026-04-02 12:30 CEST  
**Version**: v21.3.2-SIL6  
**Framework**: SOPv5.11 + STAMP + TDG + Patient Mode + Fractal Verification

---

## 1. Scope & Trigger

Build and fully verify the application containers required for complete Indrajaal functionality testing. This plan covers ALL fractal artifacts across all 8 fractal layers (L0-L7) with comprehensive verification matrix.

---

## 2. Pre-State Assessment

### Container Architecture (Application-Focused)

| Layer | Container | Purpose | Ports | Image Category |
|-------|-----------|---------|-------|----------------|
| **L4-DB** | `indrajaal-db-prod` | PostgreSQL + TimescaleDB | 5433 | Built |
| **L4-OBS** | `indrajaal-obs-prod` | OTEL/Prometheus/Grafana/Loki/SigNoz | 4317,9090,3000,3100 | Built |
| **L4-ZENOH** | `zenoh-router` | Zenoh Control Plane | 7447,8448,8000 | Pulled |
| **L4-COGNITIVE** | `cepaf-bridge` | F#-Elixir Bridge | 9876 | Built |
| **L4-CORTEX** | `indrajaal-cortex` | F# Cortex | 9877 | Built |
| **L4-APP-1** | `indrajaal-ex-app-1` | Phoenix Seed Node | 4000,4001,6379 | Built |
| **L4-APP-2** | `indrajaal-ex-app-2` | HA Node 2 | 4003,4004 | Shared |
| **L4-APP-3** | `indrajaal-ex-app-3` | HA Node 3 | 4005,4006 | Shared |
| **L4-CHAYA** | `indrajaal-chaya` | Digital Twin | 4002 | Shared |
| **L4-ML-1** | `indrajaal-ml-runner-1` | FLAME Runner 1 | - | Shared |
| **L4-ML-2** | `indrajaal-ml-runner-2` | FLAME Runner 2 | - | Shared |
| **L4-AI** | `indrajaal-ollama` | Local AI | 11435 | Pulled |

### Image Categories (per SC-SIL6-001)

| Category | Count | Examples |
|----------|-------|----------|
| BuiltFromDockerfile | 5 | db, obs, ex-app-1, cepaf-bridge, cortex |
| PulledFromRegistry | 2 | zenoh-router, ollama |
| SharedImage | 8 | ex-app-2/3, chaya, ml-runner-1/2 |

### Resource Requirements

| Resource | Requirement | Current |
|----------|-------------|---------|
| RAM | ~27GB | ⬜ |
| CPU | 16+ cores | ⬜ |
| Podman | 5.4.1+ | ⬜ |
| Disk | 50GB+ | ⬜ |

---

## 3. Execution Detail

### Phase 1: Pre-Flight & Fractal L0 Verification

```bash
# === L0: Runtime Layer ===

# 1.1 System Prerequisites
echo "=== L0: Runtime Prerequisites ==="
podman --version                    # Must be >= 5.4.1
nix --version                      # Must be available
dotnet --version                   # For F# tooling
git rev-parse --short HEAD         # Current commit

# 1.2 Substrate Integrity (SC-SIL6-002)
echo "Substrate cleanup..."
rm -rf _build deps 2>/dev/null || true

# 1.3 CPU Governor Check (SC-CPU-GOV-001)
./scripts/cpu-governor.sh status   # Must be < 85%

# 1.4 Patient Mode Environment
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"

# 1.5 Compile Verification
mix compile --jobs 16 2>&1 | tee ./data/tmp/1-compile.log
# Expected: 0 errors, 0 warnings
```

### Phase 2: Container Image Build (L4: Container Layer)

```bash
# === L4: Container Isolation ===

# 2.1 Build Database Image (BuiltFromDockerfile)
echo "Building indrajaal-db-prod..."
nix-build containers/indrajaal-timescaledb-demo.nix -o result-db
podman load < result-db
podman tag localhost/indrajaal-timescaledb-demo:latest localhost/indrajaal-db-prod:latest

# 2.2 Build Observability Image (BuiltFromDockerfile)
echo "Building indrajaal-obs-prod..."
nix-build containers/obs/flake.nix -o result-obs
podman load < result-obs
podman tag localhost/indrajaal-obs-prod:latest localhost/indrajaal-obs-prod:latest

# 2.3 Build Application Image (BuiltFromDockerfile)
echo "Building indrajaal-ex-app-1..."
nix-build containers/sopv51-elixir-app.nix -o result-app
podman load < result-app
podman tag localhost/indrajaal-app-hardened:latest localhost/indrajaal-ex-app-1:latest

# 2.4 Pull Zenoh Router (PulledFromRegistry)
echo "Pulling zenoh-router..."
podman pull eclipse/zenoh:latest
podman tag eclipse/zenoh:latest localhost/zenoh-router:latest

# 2.5 Pull Ollama (PulledFromRegistry)
echo "Pulling ollama..."
podman pull ollama/ollama:latest
podman tag ollama/ollama:latest localhost/indrajaal-ollama:latest

# 2.6 Verify All Images
echo "=== Image Verification ==="
podman images | grep -E "indrajaal|zenoh|ollama"
```

### Phase 3: Network & Volume Setup (L5: Node Layer)

```bash
# === L5: Node Layer - Network Isolation ===

# 3.1 Create Networks
podman network create indrajaal-sil6-mesh \
  --subnet 172.28.0.0/16 \
  --gateway 172.28.0.1

podman network create indrajaal-internal --internal

# 3.2 Verify Networks
podman network ls | grep indrajaal

# 3.3 Create Volumes (persistence)
podman volume create db_prod_data
podman volume create prometheus_prod_data
podman volume create grafana_prod_data
podman volume create otel_prod_data
podman volume create loki_prod_data
podman volume create app_prod_data
podman volume create redis_prod_data
```

### Phase 4: Tier-by-Tier Boot (L6: Cluster Layer)

```bash
# === L6: Cluster Layer - Boot Sequence ===

# 4.1 Tier 1: Zenoh Control Plane (PARALLEL)
echo "=== TIER 1: Zenoh Routers ==="
podman run -d \
  --name zenoh-router-1 \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.40 \
  -p 7447:7447 -p 8448:8448 -p 8000:8000 \
  localhost/zenoh-router:latest

podman run -d \
  --name zenoh-router-2 \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.41 \
  -p 7448:7447 -p 8449:8448 -p 8001:8000 \
  localhost/zenoh-router:latest

podman run -d \
  --name zenoh-router-3 \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.42 \
  -p 7449:7447 -p 8450:8448 -p 8002:8000 \
  localhost/zenoh-router:latest

# Health check Zenoh
for i in {1..30}; do
  if nc -z localhost 7447; then
    echo "Zenoh router healthy"
    break
  fi
  echo "Waiting for Zenoh... ($i/30)"
  sleep 2
done

# 4.2 Tier 2: Database Layer (SEQUENTIAL)
echo "=== TIER 2: Database ==="
podman run -d \
  --name indrajaal-db-prod \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.20 \
  -p 5433:5433 \
  -e POSTGRES_DB=indrajaal_prod \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e PGPORT=5433 \
  -v db_prod_data:/var/lib/postgresql/pgdata \
  localhost/indrajaal-db-prod:latest

# Wait for PostgreSQL
for i in {1..60}; do
  if podman exec indrajaal-db-prod pg_isready -U postgres -d indrajaal_prod -p 5433 2>/dev/null; then
    echo "PostgreSQL healthy"
    break
  fi
  echo "Waiting for PostgreSQL... ($i/60)"
  sleep 2
done

# 4.3 Tier 3: Observability Stack (SEQUENTIAL)
echo "=== TIER 3: Observability ==="
podman run -d \
  --name indrajaal-obs-prod \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.30 \
  -p 4317:4317 -p 4318:4318 -p 8888:8888 \
  -p 9090:9090 -p 3000:3000 -p 3100:3100 \
  -p 3301:3301 -p 8080:8080 -p 8123:8123 -p 9000:9000 \
  -v prometheus_prod_data:/prometheus \
  -v grafana_prod_data:/var/lib/grafana \
  localhost/indrajaal-obs-prod:latest

# Wait for Prometheus
for i in {1..90}; do
  if curl -sf http://localhost:9090/-/healthy > /dev/null; then
    echo "Prometheus healthy"
    break
  fi
  echo "Waiting for Prometheus... ($i/90)"
  sleep 2
done

# 4.4 Tier 4: Cognitive Layer (PARALLEL)
echo "=== TIER 4: Cognitive ==="
podman run -d \
  --name cepaf-bridge \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.50 \
  -p 9876:9876 \
  -e ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router-1:7447 \
  localhost/cepaf-bridge:latest || echo "cepaf-bridge not built yet"

podman run -d \
  --name indrajaal-cortex \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.60 \
  -p 9877:9877 \
  -e ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router-1:7447 \
  localhost/indrajaal-cortex:latest || echo "indrajaal-cortex not built yet"

# 4.5 Tier 5: Application Seed (SEQUENTIAL)
echo "=== TIER 5: Application ==="
podman run -d \
  --name indrajaal-ex-app-1 \
  --network indrajaal-sil6-mesh \
  --network indrajaal-internal \
  --ip 172.28.0.10 \
  -p 4000:4000 -p 4001:4001 -p 6379:6379 \
  -e DATABASE_URL=ecto://postgres:postgres@indrajaal-db-prod:5433/indrajaal_prod \
  -e PHX_HOST=localhost \
  -e PHX_PORT=4000 \
  -e MIX_ENV=prod \
  -e ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router-1:7447 \
  -v app_prod_data:/app/data \
  -v redis_prod_data:/var/lib/redis \
  localhost/indrajaal-ex-app-1:latest

# Wait for Phoenix
for i in {1..180}; do
  if curl -sf http://localhost:4000/ > /dev/null; then
    echo "Phoenix healthy"
    break
  fi
  echo "Waiting for Phoenix... ($i/180)"
  sleep 5
done

# 4.6 Tier 6: HA Nodes + Digital Twin (PARALLEL)
echo "=== TIER 6: HA + Twin ==="
# Use SharedImage from ex-app-1
for name in indrajaal-ex-app-2 indrajaal-ex-app-3 indrajaal-chaya; do
  podman run -d \
    --name $name \
    --network indrajaal-sil6-mesh \
    --network indrajaal-internal \
    localhost/indrajaal-ex-app-1:latest || echo "$name may already exist"
done

# 4.7 Tier 7: ML Runners + Ollama (PARALLEL)
echo "=== TIER 7: ML + AI ==="
podman run -d \
  --name indrajaal-ollama \
  --network indrajaal-sil6-mesh \
  --ip 172.28.0.65 \
  -p 11435:11434 \
  localhost/indrajaal-ollama:latest || echo "ollama may already exist"
```

### Phase 5: Fractal L1-L3 Verification (Function/Holon)

```bash
# === L1: Function Layer - I/O Contracts ===

echo "=== L1: Function Verification ==="

# 1.1 Database I/O Contract
podman exec indrajaal-ex-app-1 \
  mix run -e "Ecto.Adapters.SQL.query(Indrajaal.Repo, \"SELECT 1\").rows"
# Expected: [[1]]

# 1.2 Phoenix HTTP Contract
curl -sf http://localhost:4000/api/health | jq .
# Expected: {status: "healthy", ...}

# 1.3 Redis I/O Contract
curl -sf http://localhost:6379/ 2>/dev/null || echo "Redis ping test"
podman exec indrajaal-ex-app-1 redis-cli ping
# Expected: PONG

# === L2: Component Layer - Module Cohesion ===

echo "=== L2: Component Verification ==="

# 2.1 Phoenix Component
curl -sf http://localhost:4000/ | grep -i "indrajaal" || echo "Phoenix serving"
curl -sf http://localhost:4001/health

# 2.2 Ecto Component
podman exec indrajaal-ex-app-1 \
  mix run -e "IO.puts(Indrajaal.Repo.__adapter__)"
# Expected: Ecto.Adapters.Postgres

# 2.3 Zenoh Component (if NIF loaded)
podman exec indrajaal-ex-app-1 \
  mix run -e "IO.inspect(Application.spec(:zenoh), label: 'Zenoh')"
# Expected: zenoh application info

# === L3: Holon Layer - Agent Logic ===

echo "=== L3: Holon Verification ==="

# 3.1 Guardian Holon
curl -sf http://localhost:4000/api/prajna/guardian/health
# Expected: Guardian health status

# 3.2 Sentinel Holon
curl -sf http://localhost:4000/api/prajna/sentinel/health
# Expected: Sentinel health status

# 3.3 Prajna Holon
curl -sf http://localhost:4000/prajna
# Expected: Prajna dashboard
```

### Phase 6: L7 Federation Verification (Global Invariants)

```bash
# === L7: Federation Layer - Global Invariants ===

echo "=== L7: Federation Verification ==="

# 7.1 Cluster Consensus
podman exec indrajaal-ex-app-1 \
  mix run -e "IO.inspect(Node.list(), label: 'Cluster Nodes')"
# Expected: List of connected nodes

# 7.2 Zenoh Mesh (2oo3 Quorum)
echo "Checking 2oo3 quorum..."
for router in zenoh-router-1 zenoh-router-2 zenoh-router-3; do
  status=$(podman exec $router sh -c "nc -z localhost 8000 && echo OK" 2>/dev/null || echo "FAIL")
  echo "$router: $status"
done

# 7.3 Telemetry Pipeline (OTEL → Prometheus → Grafana)
curl -sf http://localhost:9090/api/v1/query?query=up
# Expected: Prometheus metrics

curl -sf http://localhost:3000/api/health
# Expected: Grafana healthy

# 7.4 F# Bridge Connectivity
if podman ps | grep -q cepaf-bridge; then
  curl -sf http://localhost:9876/health || echo "CEPAF bridge may not be running"
fi
```

### Phase 7: Swarm Verification (SC-SWARM-VERIFY)

```bash
# === Swarm Deep Verification ===

# 7 Actions × 16 Containers × 8 Layers

# 7.1 OODA Compliance
echo "=== OODA Verification ==="
# Observe
curl -sf http://localhost:4000/api/health
curl -sf http://localhost:9090/-/healthy
# Orient
# Decide (based on health)
# Act

# 7.2 Observability Pipeline
echo "=== Observability Verification ==="
curl -sf http://localhost:4317/health || echo "OTEL may not have health endpoint"
curl -sf http://localhost:9090/-/healthy
curl -sf http://localhost:3000/api/health

# 7.3 Zenoh Telemetry
echo "=== Zenoh Verification ==="
curl -sf http://localhost:8000/@/router/local 2>/dev/null || echo "Zenoh REST"
```

---

## 4. Root Cause Analysis (TPS 5-Level)

### Known Failure Modes

| Level | Symptom | Surface Cause | System Behavior | Config Gap | Design |
|-------|---------|---------------|-----------------|------------|--------|
| L1 | HTTP 500 | DB query fails | Ecto timeout | Missing env var | Connection pool size |
| L2 | Module crash | GenServer dead | Supervisor restart | Max restart exceeded | L2 isolation |
| L3 | Agent loop | Pattern match error | F# exception | Missing NIF | Railway error |
| L4 | Container exit | OOM kill | Health check fail | Memory limit | Resource spec |
| L5 | Node partition | Network timeout | Cluster split | Firewall rules | Network design |
| L6 | Quorum loss | 1 of 3 routers | 2oo3 fail | Config drift | Router count |
| L7 | Global state corrupt | Write conflict | Hash chain break | No signatures | Byzantine tolerance |

---

## 5. Fix Taxonomy

| Pattern | Trigger | Solution |
|---------|---------|----------|
| NIF Failure | glibc conflict | `rm -rf _build deps` |
| Socket Missing | PostgreSQL fail | Create `/run/postgresql` |
| OOM Kill | Memory limit | Increase container memory |
| Port Conflict | Already bound | Stop existing, rebind |
| Health Timeout | Slow startup | Increase `start_period` |
| Network Partition | Firewall | Check `indralink` rules |

---

## 6. Patterns & Anti-Patterns

### DO:
- ✅ Always use `localhost/` registry
- ✅ Use Patient Mode for builds
- ✅ Verify health after each tier
- ✅ Use F# CLI (`sa-*`) for orchestration
- ✅ Test with `@skill(swarm-verify)` after boot

### AVOID:
- ❌ Don't skip health verification
- ❌ Don't mix Docker/Podman
- ❌ Don't build on host with `_build` present
- ❌ Don't skip STAMP validation

---

## 7. Verification Matrix

### Layer Coverage Matrix

| Layer | Verification | Command | Expected | Status |
|-------|--------------|---------|---------|--------|
| **L0** | Compilation | `mix compile` | 0 errors | ⬜ |
| **L0** | Format | `mix format --check` | pass | ⬜ |
| **L0** | Credo | `mix credo` | 0 issues | ⬜ |
| **L1** | DB I/O | `mix run -e "..."` | rows returned | ⬜ |
| **L1** | HTTP Contract | `curl localhost:4000/api/health` | 200 OK | ⬜ |
| **L1** | Redis I/O | `redis-cli ping` | PONG | ⬜ |
| **L2** | Phoenix | `curl localhost:4000/` | HTML response | ⬜ |
| **L2** | Ecto | `mix ecto.migrate` | success | ⬜ |
| **L2** | Zenoh NIF | `mix run -e "..."` | loaded | ⬜ |
| **L3** | Guardian | `curl /api/prajna/guardian/health` | healthy | ⬜ |
| **L3** | Sentinel | `curl /api/prajna/sentinel/health` | healthy | ⬜ |
| **L3** | Prajna | `curl /prajna` | dashboard | ⬜ |
| **L4** | Container build | `nix-build` | image created | ⬜ |
| **L4** | Non-root user | `podman run id` | uid=1000 | ⬜ |
| **L4** | Resource limits | `podman inspect` | memory/cpu set | ⬜ |
| **L5** | Network | `podman network ls` | 2 networks | ⬜ |
| **L5** | Volumes | `podman volume ls` | volumes present | ⬜ |
| **L6** | Cluster nodes | `Node.list()` | 3+ nodes | ⬜ |
| **L6** | 2oo3 Quorum | `sa-verify` | consensus | ⬜ |
| **L7** | Prometheus | `curl :9090/api/v1/query` | metrics | ⬜ |
| **L7** | Grafana | `curl :3000/api/health` | healthy | ⬜ |
| **L7** | OTEL | `curl :4317/health` | healthy | ⬜ |

### Container Health Matrix

| Container | Health Check | Port | Status |
|-----------|--------------|------|--------|
| indrajaal-db-prod | pg_isready | 5433 | ⬜ |
| indrajaal-obs-prod | curl :9090 | 9090 | ⬜ |
| zenoh-router-1 | nc :8000 | 8000 | ⬜ |
| zenoh-router-2 | nc :8000 | 8000 | ⬜ |
| zenoh-router-3 | nc :8000 | 8000 | ⬜ |
| cepaf-bridge | curl :9876 | 9876 | ⬜ |
| indrajaal-cortex | curl :9877 | 9877 | ⬜ |
| indrajaal-ex-app-1 | curl :4000 | 4000 | ⬜ |
| indrajaal-ex-app-2 | curl :4000 | 4000 | ⬜ |
| indrajaal-ex-app-3 | curl :4000 | 4000 | ⬜ |
| indrajaal-chaya | curl :4002 | 4002 | ⬜ |
| indrajaal-ml-runner-1 | file exists | - | ⬜ |
| indrajaal-ml-runner-2 | file exists | - | ⬜ |
| indrajaal-ollama | nc :11434 | 11434 | ⬜ |

---

## 8. Files Modified

| File | Action | Purpose |
|------|--------|---------|
| `containers/*.nix` | Built | Container images |
| `podman network` | Created | Mesh network |
| `podman volume` | Created | Data persistence |
| `lib/cepaf/artifacts/build-history.db` | Created | Build timing EMA |

---

## 9. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL SIL-6 FRACTAL MESH                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L7: FEDERATION (Global Invariants)                               │    │
│  │   • Prometheus/Grafana OTEL Dashboard                           │    │
│  │   • 2oo3 Quorum Consensus                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L6: CLUSTER (Consensus)                                          │    │
│  │   • BEAM Node Clustering                                         │    │
│  │   • Zenoh Pub/Sub Mesh                                          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L5: NODE (Runtime Stable)                                         │    │
│  │   • Podman Networks (2)                                          │    │
│  │   • Persistent Volumes (8+)                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L4: CONTAINER (Isolation)                                         │    │
│  │   • 12 Containers (5 Built + 2 Pulled + 5 Shared)                  │    │
│  │   • Rootless Podman                                             │    │
│  │   • Resource Limits                                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L3: HOLON (Agent Logic)                                          │    │
│  │   • Guardian / Sentinel / Prajna                                  │    │
│  │   • F# CEPAF Bridge / Cortex                                      │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L2: COMPONENT (Module Cohesion)                                   │    │
│  │   • Phoenix LiveView                                             │    │
│  │   • Ecto / PostgreSQL                                            │    │
│  │   • Zenoh NIF                                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L1: FUNCTION (I/O Contracts)                                      │    │
│  │   • HTTP Endpoints (:4000)                                       │    │
│  │   • Database Queries (:5433)                                     │    │
│  │   • Redis Cache (:6379)                                          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ L0: RUNTIME (Compilation/Boot)                                   │    │
│  │   • mix compile --jobs 16                                        │    │
│  │   • NixOS Container Build                                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Remaining Gaps

| Gap | Priority | Tracking |
|-----|----------|----------|
| cepaf-bridge Dockerfile | HIGH | Missing |
| indrajaal-cortex Dockerfile | HIGH | Missing |
| Zenoh NIF verification | HIGH | Needs testing |
| FLAME cluster verification | MEDIUM | Needs testing |

---

## 11. Metrics Summary

| Metric | Target | Current |
|--------|--------|---------|
| Containers Built | 5 | 0 |
| Containers Running | 12 | 0 |
| Health Score | 100% | 0% |
| Fractal Layers Verified | 8 | 0 |
| STAMP Constraints | 100% | 0% |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Requirement | Verification |
|------------|-------------|--------------|
| SC-CNT-009 | NixOS/Podman only | Image labels |
| SC-CNT-010 | localhost/ registry | `grep localhost/` |
| SC-CNT-012 | Rootless containers | `podman info \| grep Rootless` |
| SC-CNT-014 | Resource limits | `podman inspect \| grep Memory` |
| SC-SIL6-001 | 7-tier boot | Tier sequence |
| SC-SIL6-006 | 2oo3 quorum | 3 routers healthy |
| Ω₁ Patient Mode | 16 schedulers | `ELIXIR_ERL_OPTIONS` |
| Ω₇ Holon State | SQLite/DuckDB | DB files |

---

## 13. Conclusion

This plan provides comprehensive fractal verification across all 8 layers (L0-L7) for the application container stack. Execute tier-by-tier with health verification at each stage.

**Estimated Execution Time**: 90-120 minutes (includes NixOS builds)
**Success Criteria**: All 21 verification checks pass, all 12 containers healthy
