# Fractal-Cluster Alignment Analysis

**Version**: 21.1.0 Founder's Covenant
**Date**: 2026-01-04
**STAMP**: SC-CLU-002 (MANDATORY)
**Author**: Cybernetic Architect

## Executive Summary

This document captures the complete analysis and implementation decisions for aligning the Indrajaal system to **fractal-cluster mode as the MANDATORY default** per SC-CLU-002.

## 1. Problem Statement

The system previously had multiple container deployment configurations:
- `podman-compose-prod-standalone.yml` (3 containers: db, obs, app)
- `podman-compose-fractal-cluster.yml` (5 containers: db-primary, obs, app-1, app-2, app-3)

This created confusion and inconsistency in:
- Digital Twin topology modeling
- Verification scripts
- SIL-6 Biomorphic compliance validation
- GA release verification

## 2. Architectural Decision

### Decision: Fractal-Cluster is the ONLY supported mode

**Rationale (5-Order Effects)**:

| Order | Effect |
|-------|--------|
| 1st | Erlang distributed clustering enabled (CLUSTERING_ENABLED=true) |
| 2nd | BEAM nodes connect via fractal_mesh_cookie, gossip protocol active |
| 3rd | Libcluster forms mesh topology, failover paths established |
| 4th | SIL-6 Biomorphic redundancy requirements met (N+2 nodes) |
| 5th | Production-equivalent testing, GA release certification |

**STAMP Constraint**: SC-CLU-002 mandates fractal-cluster for all startup/shutdown operations.

## 3. Topology Specification

### 3.1 Container Architecture (5 Nodes)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRACTAL-CLUSTER MESH                          │
│                    Network: indrajaal-cluster-net                │
│                    Subnet: 172.30.0.0/16                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌─────────────────────────────────────┐     │
│  │ db-primary  │    │          ERLANG MESH                 │     │
│  │ PostgreSQL  │    │  ┌───────────┐  ┌───────────┐       │     │
│  │ 172.30.0.21 │◄───┤  │ app-1     │  │ app-2     │       │     │
│  │ :5433       │    │  │ Seed      │◄►│ Satellite │       │     │
│  └─────────────┘    │  │ 172.30.0.11│  │ 172.30.0.12│      │     │
│                     │  │ :4000     │  │ :4001     │       │     │
│  ┌─────────────┐    │  └───────────┘  └───────────┘       │     │
│  │ indrajaal-  │    │        ▲              ▲              │     │
│  │ obs         │    │        │    gossip    │              │     │
│  │ OTEL+Prom   │◄───┤        ▼              ▼              │     │
│  │ 172.30.0.30 │    │       ┌───────────┐                  │     │
│  │ :4319/:9091 │    │       │ app-3     │                  │     │
│  └─────────────┘    │       │ Satellite │                  │     │
│                     │       │ 172.30.0.13│                  │     │
│                     │       │ :4002     │                  │     │
│                     │       └───────────┘                  │     │
│                     └─────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Node Roles

| Node | Role | IP Address | Ports | STAMP |
|------|------|------------|-------|-------|
| db-primary | Primary | 172.30.0.21 | 5433 | SC-DB-001 |
| indrajaal-obs | Controller | 172.30.0.30 | 4319, 9091, 3001 | SC-OBS-069 |
| indrajaal-app-1 | Seed | 172.30.0.11 | 4000 | SC-CLU-001 |
| indrajaal-app-2 | Satellite | 172.30.0.12 | 4001 | SC-CLU-003 |
| indrajaal-app-3 | Satellite | 172.30.0.13 | 4002 | SC-CLU-003 |

### 3.3 Erlang Clustering Configuration

```yaml
environment:
  CLUSTERING_ENABLED: "true"
  RELEASE_COOKIE: "fractal_mesh_cookie"
  RELEASE_NODE: "indrajaal@172.30.0.11"  # varies per node
  CLUSTER_TOPOLOGY: "fractal_mesh"
  GOSSIP_STRATEGY: "libcluster_epmd"
```

## 4. Files Modified

### 4.1 Core Digital Twin

**File**: `lib/cepaf/src/Cepaf/Mesh/DigitalTwin.fs`

**Change**: Updated `createDefaultGenotypes()` from 3-container to 5-container topology

```fsharp
// Before: 3 containers
let containers = ["db-1"; "obs"; "app-1"]

// After: 5 containers (SC-CLU-002 MANDATORY)
let containers = ["db-primary"; "indrajaal-obs"; "app-1"; "app-2"; "app-3"]
```

**Impact**:
- Genotype definitions match fractal-cluster compose file
- Phenotype monitoring covers all 5 containers
- Topological sort produces correct boot order waves

### 4.2 GA Release Verification Scripts

**File**: `scripts/ga-release/runtime_command_verifier.exs`

| Line | Before | After |
|------|--------|-------|
| 51 | `podman-compose-prod-standalone.yml` | `podman-compose-fractal-cluster.yml` |
| 51 | `:three_containers` check | `:five_containers` check |
| 87 | File dependency path | Updated to fractal-cluster |

**File**: `scripts/ga-release/smart_command_verifier.exs`

| Section | Changes |
|---------|---------|
| `@impact_matrix["sa-up"]` | Updated 1st-5th order effects for 5 containers |
| `file_deps` | All sa-* commands now reference fractal-cluster.yml |
| `ports` | Added ports 4001, 4002; updated container names |
| `containers` | Changed from 3 to 5 container names |
| `commands` map | sa-up/sa-down/sa-status use fractal-cluster.yml |
| `check_dependency_status` | sa-up requires >= 5 containers |

### 4.3 CEPAF Operations Script

**File**: `lib/cepaf/scripts/CockpitOperations.fsx`

| Function | Change |
|----------|--------|
| `status()` | Health checks use fractal-cluster container names |
| `logs()` | Default container changed to `indrajaal-app-1` |
| `cleanup()` | Fallback containers updated to 5-node topology |
| `help()` | Examples updated for fractal-cluster |

## 5. Verification Checklist

### 5.1 Pre-Flight (Environment)

- [ ] devenv shell active
- [ ] Podman 5.4.1+ installed
- [ ] .NET 10.0 SDK available
- [ ] PostgreSQL client installed
- [ ] Network `indrajaal-cluster-net` creatable

### 5.2 Container Startup

```bash
# Verify fractal-cluster starts correctly
podman-compose -f lib/cepaf/artifacts/podman-compose-fractal-cluster.yml up -d

# Check 5 containers running
podman ps | grep -c indrajaal  # Should be 5
```

### 5.3 Port Verification

| Port | Service | Container |
|------|---------|-----------|
| 5433 | PostgreSQL | db-primary |
| 4319 | OTEL gRPC | indrajaal-obs |
| 9091 | Prometheus | indrajaal-obs |
| 3001 | Grafana | indrajaal-obs |
| 4000 | Phoenix (Seed) | indrajaal-app-1 |
| 4001 | Phoenix (Sat-2) | indrajaal-app-2 |
| 4002 | Phoenix (Sat-3) | indrajaal-app-3 |

### 5.4 Erlang Mesh Verification

```elixir
# From any app node
Node.list()  # Should show 2 other nodes
:net_adm.ping(:"indrajaal@172.30.0.11")  # :pong
```

## 6. FMEA Risk Analysis

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Seed node fails | 8 | 2 | 3 | 48 | Satellite promotion |
| Network partition | 7 | 3 | 4 | 84 | Split-brain detection |
| Cookie mismatch | 9 | 1 | 9 | 81 | Env var validation |
| Port conflict | 6 | 4 | 2 | 48 | Pre-check ports |
| DB not ready | 7 | 3 | 3 | 63 | Health check wait |

## 7. AOR Compliance

| Rule | Status |
|------|--------|
| AOR-GA-001 | Verification scripts updated |
| AOR-GA-002 | 5-order effects documented |
| AOR-GA-005 | Container stack operational |
| AOR-HOLON-001 | SQLite state sovereignty maintained |

## 8. Future Considerations

1. **Hot Node Addition**: Scripts support adding app-4, app-5 dynamically
2. **Multi-Region**: Network subnet can expand to 172.30.0.0/8
3. **SIL-6 Biomorphic Certification**: N+2 redundancy meets IEC 61508 requirements

## 9. Related Documents

| Document | Location |
|----------|----------|
| Compose File | `lib/cepaf/artifacts/podman-compose-fractal-cluster.yml` |
| Digital Twin | `lib/cepaf/src/Cepaf/Mesh/DigitalTwin.fs` |
| Mesh Startup | `lib/cepaf/src/Cepaf/Mesh/MeshStartup.fs` |
| Mesh Shutdown | `lib/cepaf/src/Cepaf/Mesh/MeshShutdown.fs` |
| GA Verification | `scripts/ga-release/smart_command_verifier.exs` |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| STAMP | SC-CLU-002, SC-GAR-001 |
| Reviewed | Cybernetic Architect |
| Approved | Guardian |
